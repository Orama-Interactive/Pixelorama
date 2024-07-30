class_name RegionUnpacker
extends RefCounted
# THIS CLASS TAKES INSPIRATION FROM PIXELORAMA'S FLOOD FILL
# AND HAS BEEN MODIFIED FOR OPTIMIZATION

enum { DETECT_VERTICAL_EMPTY_LINES, DETECT_HORIZONTAL_EMPTY_LINES }

var slice_thread := Thread.new()

var _include_boundary_threshold: int  ## Τhe size of rect below which merging accounts for boundary
## After crossing threshold the smaller image will merge with larger image
## if it is within the _merge_dist
var _merge_dist: int

## Working array used as buffer for segments while flooding
var _allegro_flood_segments: Array[Segment]
## Results array per image while flooding
var _allegro_image_segments: Array[Segment]


class RectData:
	var rects: Array[Rect2i]
	var frame_size: Vector2i

	func _init(_rects: Array[Rect2i], _frame_size: Vector2i):
		rects = _rects
		frame_size = _frame_size


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


func _init(threshold: int, merge_dist: int) -> void:
	_include_boundary_threshold = threshold
	_merge_dist = merge_dist


func get_used_rects(
	image: Image, lazy_check := false, scan_dir := DETECT_VERTICAL_EMPTY_LINES
) -> RectData:
	if ProjectSettings.get_setting("rendering/driver/threads/thread_model") != 2:
		# Single-threaded mode
		return get_rects(image, lazy_check, scan_dir)
	else:  # Multi-threaded mode
		if slice_thread.is_started():
			slice_thread.wait_to_finish()
		var error := slice_thread.start(get_rects.bind(image))
		if error == OK:
			return slice_thread.wait_to_finish()
		else:
			return get_rects(image, lazy_check, scan_dir)


func get_rects(
	image: Image, lazy_check := false, scan_dir := DETECT_VERTICAL_EMPTY_LINES
) -> RectData:
	var skip_amount = 0
	# Make a smaller image to make the loop shorter
	var used_rect := image.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		return clean_rects([])
	var test_image := image.get_region(used_rect)
	# Prepare a bitmap to keep track of previous places
	var scanned_area := Image.create(
		test_image.get_size().x, test_image.get_size().y, false, Image.FORMAT_LA8
	)
	# Scan the image
	var rects: Array[Rect2i] = []
	var frame_size := Vector2i.ZERO

	var found_pixels_this_line := false
	var has_jumped_last_line := false
	var scanned_lines := PackedInt32Array()
	var side_a: int
	var side_b: int
	match scan_dir:
		DETECT_VERTICAL_EMPTY_LINES:
			side_a = test_image.get_size().x
			side_b = test_image.get_size().y
		DETECT_HORIZONTAL_EMPTY_LINES:
			side_a = test_image.get_size().y
			side_b = test_image.get_size().x
	var line := 0
	while line < side_a:
		for element: int in side_b:
			var position := Vector2i(line, element)
			if scan_dir == DETECT_HORIZONTAL_EMPTY_LINES:
				position = Vector2i(element, line)
			if test_image.get_pixelv(position).a > 0:  # used portion of image detected
				found_pixels_this_line = true
				if scanned_area.get_pixelv(position).a == 0:
					var rect := _estimate_rect(test_image, position)
					scanned_area.fill_rect(rect, Color.WHITE)
					rect.position += used_rect.position
					rects.append(rect)
		if lazy_check:
			if !line in scanned_lines:
				scanned_lines.append(line)

			if found_pixels_this_line and not has_jumped_last_line:
				found_pixels_this_line = false
				line += 1
				if line in scanned_lines:  ## We have scanned all skipped lines, re calculate current index
					scanned_lines.sort()
					line = scanned_lines[-1] + 1
			elif not found_pixels_this_line:
				## we haven't found any pixels in this line and are assuming next line is empty as well
				skip_amount += 1
				has_jumped_last_line = true
				line += 1 + skip_amount
			elif found_pixels_this_line and has_jumped_last_line:
				found_pixels_this_line = false
				has_jumped_last_line = false
				## if we skipped a line then go back and make sure it was really empty or not
				line -= skip_amount
				skip_amount = 0
		else:
			line += 1
	var rects_info := clean_rects(rects)
	rects_info.rects.sort_custom(sort_rects)
	return rects_info


func clean_rects(rects: Array[Rect2i]) -> RectData:
	var frame_size := Vector2i.ZERO
	for i: int in rects.size():
		var target: Rect2i = rects.pop_front()
		var test_rect := target
		if (
			target.size.x < _include_boundary_threshold
			or target.size.y < _include_boundary_threshold
		):
			test_rect.size += Vector2i(_merge_dist, _merge_dist)
			test_rect.position -= Vector2i(_merge_dist, _merge_dist) / 2
		var merged := false
		for rect_i: int in rects.size():
			if test_rect.intersects(rects[rect_i]):
				rects[rect_i] = target.merge(rects[rect_i])
				merged = true
				break
		if !merged:
			rects.append(target)

		# calculation for a suitable frame size
		if target.size.x > frame_size.x:
			frame_size.x = target.size.x
		if target.size.y > frame_size.y:
			frame_size.y = target.size.y
	return RectData.new(rects, frame_size)


func sort_rects(rect_a: Rect2i, rect_b: Rect2i) -> bool:
	# After many failed attempts, this version works for some reason (it's best not to disturb it)
	if rect_a.end.y < rect_b.position.y:
		return true
	if rect_a.position.x < rect_b.position.x:
		# if both lie in the same row
		var start := rect_a.position
		var size := Vector2i(rect_b.end.x, rect_a.end.y)
		if Rect2i(start, size).intersects(rect_b):
			return true
	return false


func _estimate_rect(image: Image, position: Vector2) -> Rect2i:
	var cel_image := Image.new()
	cel_image.copy_from(image)
	var small_rect := _flood_fill(position, cel_image)
	return small_rect


## Add a new segment to the array
func _add_new_segment(y := 0) -> void:
	_allegro_flood_segments.append(Segment.new(y))


## Fill an horizontal segment around the specified position, and adds it to the
## list of segments filled. Returns the first x coordinate after the part of the
## line that has been filled.
## this method is called by `_flood_fill` after the required data structures
## have been initialized
func _flood_line_around_point(position: Vector2i, image: Image) -> int:
	if not image.get_pixelv(position).a > 0:
		return position.x + 1
	var west := position
	var east := position
	while west.x >= 0 && image.get_pixelv(west).a > 0:
		west += Vector2i.LEFT
	while east.x < image.get_width() && image.get_pixelv(east).a > 0:
		east += Vector2i.RIGHT
	# Make a note of the stuff we processed
	var c := position.y
	var segment := _allegro_flood_segments[c]
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
	segment.todo_below = position.y < image.get_height() - 1
	# this is an actual segment we should be coloring, so we add it to the results for the
	# current image
	if segment.right_position >= segment.left_position:
		_allegro_image_segments.append(segment)
	# we know the point just east of the segment is not part of a segment that should be
	# processed, else it would be part of this segment
	return east.x + 1


func _check_flooded_segment(y: int, left: int, right: int, image: Image) -> bool:
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
				left = _flood_line_around_point(Vector2i(left, y), image)
				ret = true
				break
	return ret


func _flood_fill(position: Vector2i, image: Image) -> Rect2i:
	# implements the floodfill routine by Shawn Hargreaves
	# from https://www1.udel.edu/CIS/software/dist/allegro-4.2.1/src/flood.c
	# init flood data structures
	_allegro_flood_segments = []
	_allegro_image_segments = []
	_compute_segments_for_image(position, image)
	# now actually color the image: since we have already checked a few things for the points
	# we'll process here, we're going to skip a bunch of safety checks to speed things up.
	return _select_segments()


func _compute_segments_for_image(position: Vector2i, image: Image) -> void:
	# initially allocate at least 1 segment per line of image
	for j: int in image.get_height():
		_add_new_segment(j)
	# start flood algorithm
	_flood_line_around_point(position, image)
	# test all segments while also discovering more
	var done := false
	while not done:
		done = true
		var max_index := _allegro_flood_segments.size()
		for c: int in max_index:
			var p := _allegro_flood_segments[c]
			if p.todo_below:  # check below the segment?
				p.todo_below = false
				if _check_flooded_segment(p.y + 1, p.left_position, p.right_position, image):
					done = false
			if p.todo_above:  # check above the segment?
				p.todo_above = false
				if _check_flooded_segment(p.y - 1, p.left_position, p.right_position, image):
					done = false


func _select_segments() -> Rect2i:
	# short circuit for flat colors
	var used_rect := Rect2i()
	for c: int in _allegro_image_segments.size():
		var p := _allegro_image_segments[c]
		var rect := Rect2i()
		rect.position = Vector2i(p.left_position, p.y)
		rect.end = Vector2i(p.right_position + 1, p.y + 1)
		if used_rect.size == Vector2i.ZERO:
			used_rect = rect
		else:
			used_rect = used_rect.merge(rect)
	return used_rect
