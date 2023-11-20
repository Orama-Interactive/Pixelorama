extends SelectionTool

## Working array used as buffer for segments while flooding
var _allegro_flood_segments: Array[Segment]
## Results array per image while flooding
var _allegro_image_segments: Array[Segment]


class Segment:
	var flooding := false
	var todo_above := false
	var todo_below := false
	var left_position := -5
	var right_position := -5
	var y := 0
	var next := 0

	func _init(_y: int) -> void:
		y = _y


func apply_selection(pos: Vector2i) -> void:
	super.apply_selection(pos)
	var project := Global.current_project
	if pos.x < 0 or pos.y < 0 or pos.x >= project.size.x or pos.y >= project.size.y:
		return
	if !_add and !_subtract and !_intersect:
		Global.canvas.selection.clear_selection()

	if _intersect:
		project.selection_map.clear()

	var cel_image := Image.new()
	cel_image.copy_from(_get_draw_image())
	_flood_fill(pos, cel_image, project.selection_map)

	# Handle mirroring
	if Tools.horizontal_mirror:
		var mirror_x := pos
		mirror_x.x = Global.current_project.x_symmetry_point - pos.x
		_flood_fill(mirror_x, cel_image, project.selection_map)
		if Tools.vertical_mirror:
			var mirror_xy := mirror_x
			mirror_xy.y = Global.current_project.y_symmetry_point - pos.y
			_flood_fill(mirror_xy, cel_image, project.selection_map)
	if Tools.vertical_mirror:
		var mirror_y := pos
		mirror_y.y = Global.current_project.y_symmetry_point - pos.y
		_flood_fill(mirror_y, cel_image, project.selection_map)
	Global.canvas.selection.big_bounding_rectangle = project.selection_map.get_used_rect()
	Global.canvas.selection.commit_undo("Select", undo_data)


# Add a new segment to the array
func _add_new_segment(y := 0) -> void:
	_allegro_flood_segments.append(Segment.new(y))


# fill an horizontal segment around the specified position, and adds it to the
# list of segments filled. Returns the first x coordinate after the part of the
# line that has been filled.
func _flood_line_around_point(
	pos: Vector2i, project: Project, image: Image, src_color: Color
) -> int:
	# this method is called by `_flood_fill` after the required data structures
	# have been initialized
	if not image.get_pixelv(pos).is_equal_approx(src_color):
		return pos.x + 1
	var west := pos
	var east := pos
	while west.x >= 0 && image.get_pixelv(west).is_equal_approx(src_color):
		west += Vector2i.LEFT
	while east.x < project.size.x && image.get_pixelv(east).is_equal_approx(src_color):
		east += Vector2i.RIGHT
	# Make a note of the stuff we processed
	var c := pos.y
	var segment := _allegro_flood_segments[c]
	# we may have already processed some segments on this y coordinate
	if segment.flooding:
		while segment.next > 0:
			c = segment.next  # index of next segment in this line of image
			segment = _allegro_flood_segments[c]
		# found last current segment on this line
		c = _allegro_flood_segments.size()
		segment.next = c
		_add_new_segment(pos.y)
		segment = _allegro_flood_segments[c]
	# set the values for the current segment
	segment.flooding = true
	segment.left_position = west.x + 1
	segment.right_position = east.x - 1
	segment.y = pos.y
	segment.next = 0
	# Should we process segments above or below this one?
	# when there is a selected area, the pixels above and below the one we started creating this
	# segment from may be outside it. It's easier to assume we should be checking for segments
	# above and below this one than to specifically check every single pixel in it, because that
	# test will be performed later anyway.
	# On the other hand, this test we described is the same `project.can_pixel_get_drawn` does if
	# there is no selection, so we don't need branching here.
	segment.todo_above = pos.y > 0
	segment.todo_below = pos.y < project.size.y - 1
	# this is an actual segment we should be coloring, so we add it to the results for the
	# current image
	if segment.right_position >= segment.left_position:
		_allegro_image_segments.append(segment)
	# we know the point just east of the segment is not part of a segment that should be
	# processed, else it would be part of this segment
	return east.x + 1


func _check_flooded_segment(
	y: int, left: int, right: int, project: Project, image: Image, src_color: Color
) -> bool:
	var ret := false
	var c := 0
	while left <= right:
		c = y
		while true:
			var segment := _allegro_flood_segments[c]
			if left >= segment.left_position and left <= segment.right_position:
				left = segment.right_position + 2
				break
			c = segment.next
			if c == 0:  # couldn't find a valid segment, so we draw a new one
				left = _flood_line_around_point(Vector2i(left, y), project, image, src_color)
				ret = true
				break
	return ret


func _flood_fill(pos: Vector2i, image: Image, selection_map: SelectionMap) -> void:
	# implements the floodfill routine by Shawn Hargreaves
	# from https://www1.udel.edu/CIS/software/dist/allegro-4.2.1/src/flood.c
	var project := Global.current_project
	var color := image.get_pixelv(pos)
	# init flood data structures
	_allegro_flood_segments = []
	_allegro_image_segments = []
	_compute_segments_for_image(pos, project, image, color)
	# now actually color the image: since we have already checked a few things for the points
	# we'll process here, we're going to skip a bunch of safety checks to speed things up.
	_select_segments(selection_map)


func _compute_segments_for_image(
	pos: Vector2i, project: Project, image: Image, src_color: Color
) -> void:
	# initially allocate at least 1 segment per line of image
	for j in image.get_height():
		_add_new_segment(j)
	# start flood algorithm
	_flood_line_around_point(pos, project, image, src_color)
	# test all segments while also discovering more
	var done := false
	while not done:
		done = true
		var max_index := _allegro_flood_segments.size()
		for c in max_index:
			var p := _allegro_flood_segments[c]
			if p.todo_below:  # check below the segment?
				p.todo_below = false
				if _check_flooded_segment(
					p.y + 1, p.left_position, p.right_position, project, image, src_color
				):
					done = false
			if p.todo_above:  # check above the segment?
				p.todo_above = false
				if _check_flooded_segment(
					p.y - 1, p.left_position, p.right_position, project, image, src_color
				):
					done = false


func _select_segments(selection_map: SelectionMap) -> void:
	# short circuit for flat colors
	for c in _allegro_image_segments.size():
		var p := _allegro_image_segments[c]
		for px in range(p.left_position, p.right_position + 1):
			# We don't have to check again whether the point being processed is within the bounds
			_set_bit(Vector2i(px, p.y), selection_map)


func _set_bit(p: Vector2i, selection_map: SelectionMap) -> void:
	var project := Global.current_project
	if _intersect:
		selection_map.select_pixel(p, project.selection_map.is_pixel_selected(p))
	else:
		selection_map.select_pixel(p, !_subtract)
