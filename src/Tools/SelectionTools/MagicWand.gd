extends SelectionTool

# working array used as buffer for segments while flooding
var _allegro_flood_segments: Array
# results array per image while flooding
var _allegro_image_segments: Array


func apply_selection(position: Vector2) -> void:
	.apply_selection(position)
	var project: Project = Global.current_project
	var size: Vector2 = project.size
	if position.x < 0 or position.y < 0 or position.x >= size.x or position.y >= size.y:
		return
	if !_add and !_subtract and !_intersect:
		Global.canvas.selection.clear_selection()

	var selection_map_copy := SelectionMap.new()
	selection_map_copy.copy_from(project.selection_map)
	if _intersect:
		selection_map_copy.clear()

	var cel_image := Image.new()
	cel_image.copy_from(_get_draw_image())
	cel_image.lock()
	_flood_fill(position, cel_image, selection_map_copy)

	# Handle mirroring
	if Tools.horizontal_mirror:
		var mirror_x := position
		mirror_x.x = Global.current_project.x_symmetry_point - position.x
		_flood_fill(mirror_x, cel_image, selection_map_copy)
		if Tools.vertical_mirror:
			var mirror_xy := mirror_x
			mirror_xy.y = Global.current_project.y_symmetry_point - position.y
			_flood_fill(mirror_xy, cel_image, selection_map_copy)
	if Tools.vertical_mirror:
		var mirror_y := position
		mirror_y.y = Global.current_project.y_symmetry_point - position.y
		_flood_fill(mirror_y, cel_image, selection_map_copy)
	cel_image.unlock()
	project.selection_map = selection_map_copy
	Global.canvas.selection.big_bounding_rectangle = project.selection_map.get_used_rect()
	Global.canvas.selection.commit_undo("Select", undo_data)


# Add a new segment to the array
func _add_new_segment(y: int = 0) -> void:
	var segment = {}
	segment.flooding = false
	segment.todo_above = false
	segment.todo_below = false
	segment.left_position = -5  # anything less than -1 is ok
	segment.right_position = -5
	segment.y = y
	segment.next = 0
	_allegro_flood_segments.append(segment)


# fill an horizontal segment around the specified position, and adds it to the
# list of segments filled. Returns the first x coordinate after the part of the
# line that has been filled.
func _flood_line_around_point(
	position: Vector2, project: Project, image: Image, src_color: Color
) -> int:
	# this method is called by `_flood_fill` after the required data structures
	# have been initialized
	if not image.get_pixelv(position).is_equal_approx(src_color):
		return int(position.x) + 1
	var west: Vector2 = position
	var east: Vector2 = position
	while west.x >= 0 && image.get_pixelv(west).is_equal_approx(src_color):
		west += Vector2.LEFT
	while east.x < project.size.x && image.get_pixelv(east).is_equal_approx(src_color):
		east += Vector2.RIGHT
	# Make a note of the stuff we processed
	var c = int(position.y)
	var segment = _allegro_flood_segments[c]
	# we may have already processed some segments on this y coordinate
	if segment.flooding:
		while segment.next > 0:
			c = segment.next  # index of next segment in this line of image
			segment = _allegro_flood_segments[c]
		# found last current segment on this line
		c = _allegro_flood_segments.size()
		segment.next = c
		_add_new_segment(position.y)
		segment = _allegro_flood_segments[c]
	# set the values for the current segment
	segment.flooding = true
	segment.left_position = west.x + 1
	segment.right_position = east.x - 1
	segment.y = position.y
	segment.next = 0
	# Should we process segments above or below this one?
	# when there is a selected area, the pixels above and below the one we started creating this
	# segment from may be outside it. It's easier to assume we should be checking for segments
	# above and below this one than to specifically check every single pixel in it, because that
	# test will be performed later anyway.
	# On the other hand, this test we described is the same `project.can_pixel_get_drawn` does if
	# there is no selection, so we don't need branching here.
	segment.todo_above = position.y > 0
	segment.todo_below = position.y < project.size.y - 1
	# this is an actual segment we should be coloring, so we add it to the results for the
	# current image
	if segment.right_position >= segment.left_position:
		_allegro_image_segments.append(segment)
	# we know the point just east of the segment is not part of a segment that should be
	# processed, else it would be part of this segment
	return int(east.x) + 1


func _check_flooded_segment(
	y: int, left: int, right: int, project: Project, image: Image, src_color: Color
) -> bool:
	var ret = false
	var c: int = 0
	while left <= right:
		c = y
		while true:
			var segment = _allegro_flood_segments[c]
			if left >= segment.left_position and left <= segment.right_position:
				left = segment.right_position + 2
				break
			c = segment.next
			if c == 0:  # couldn't find a valid segment, so we draw a new one
				left = _flood_line_around_point(Vector2(left, y), project, image, src_color)
				ret = true
				break
	return ret


func _flood_fill(position: Vector2, image: Image, selection_map: SelectionMap) -> void:
	# implements the floodfill routine by Shawn Hargreaves
	# from https://www1.udel.edu/CIS/software/dist/allegro-4.2.1/src/flood.c
	var project: Project = Global.current_project
	var color: Color = image.get_pixelv(position)
	# init flood data structures
	_allegro_flood_segments = []
	_allegro_image_segments = []
	_compute_segments_for_image(position, project, image, color)
	# now actually color the image: since we have already checked a few things for the points
	# we'll process here, we're going to skip a bunch of safety checks to speed things up.
	_select_segments(selection_map)


func _compute_segments_for_image(
	position: Vector2, project: Project, image: Image, src_color: Color
) -> void:
	# initially allocate at least 1 segment per line of image
	for j in image.get_height():
		_add_new_segment(j)
	# start flood algorithm
	_flood_line_around_point(position, project, image, src_color)
	# test all segments while also discovering more
	var done := false
	while not done:
		done = true
		var max_index = _allegro_flood_segments.size()
		for c in max_index:
			var p = _allegro_flood_segments[c]
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
		var p = _allegro_image_segments[c]
		for px in range(p.left_position, p.right_position + 1):
			# We don't have to check again whether the point being processed is within the bounds
			_set_bit(Vector2(px, p.y), selection_map)


func _set_bit(p: Vector2, selection_map: SelectionMap) -> void:
	var project: Project = Global.current_project
	if _intersect:
		selection_map.select_pixel(p, project.selection_map.is_pixel_selected(p))
	else:
		selection_map.select_pixel(p, !_subtract)
