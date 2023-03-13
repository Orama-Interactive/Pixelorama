extends BaseTool

enum FillArea { AREA, COLORS, SELECTION }
enum FillWith { COLOR, PATTERN }

const COLOR_REPLACE_SHADER := preload("res://src/Shaders/ColorReplace.shader")
const PATTERN_FILL_SHADER := preload("res://src/Shaders/PatternFill.gdshader")

var _prev_mode := 0
var _pattern: Patterns.Pattern
var _similarity := 100
var _fill_area: int = FillArea.AREA
var _fill_with: int = FillWith.COLOR
var _offset_x := 0
var _offset_y := 0
# working array used as buffer for segments while flooding
var _allegro_flood_segments: Array
# results array per image while flooding
var _allegro_image_segments: Array


func _ready() -> void:
	update_pattern()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("change_tool_mode"):
		_prev_mode = _fill_area
	if event.is_action("change_tool_mode"):
		if _fill_area == FillArea.SELECTION:
			_fill_area = FillArea.AREA
		else:
			_fill_area = _prev_mode ^ 1
		_select_fill_area_optionbutton()
	if event.is_action_released("change_tool_mode"):
		_fill_area = _prev_mode
		_select_fill_area_optionbutton()


func _on_FillAreaOptions_item_selected(index: int) -> void:
	_fill_area = index
	update_config()
	save_config()


func _select_fill_area_optionbutton() -> void:
	$FillAreaOptions.selected = _fill_area
	$SimilaritySlider.visible = (_fill_area == FillArea.COLORS)


func _on_FillWithOptions_item_selected(index: int) -> void:
	_fill_with = index
	update_config()
	save_config()


func _on_SimilaritySlider_value_changed(value: float) -> void:
	_similarity = value
	update_config()
	save_config()


func _on_PatternType_pressed() -> void:
	var popup: Popup = Global.patterns_popup
	if !popup.is_connected("pattern_selected", self, "_on_Pattern_selected"):
		popup.connect("pattern_selected", self, "_on_Pattern_selected", [], CONNECT_ONESHOT)
	popup.popup(Rect2($FillPattern/Type.rect_global_position, Vector2(226, 72)))


func _on_Pattern_selected(pattern: Patterns.Pattern) -> void:
	_pattern = pattern
	update_pattern()
	save_config()


func _on_PatternOffsetX_value_changed(value: float) -> void:
	_offset_x = int(value)
	update_config()
	save_config()


func _on_PatternOffsetY_value_changed(value: float) -> void:
	_offset_y = int(value)
	update_config()
	save_config()


func get_config() -> Dictionary:
	if !_pattern:
		return {"fill_area": _fill_area, "fill_with": _fill_with, "similarity": _similarity}
	return {
		"pattern_index": _pattern.index,
		"fill_area": _fill_area,
		"fill_with": _fill_with,
		"similarity": _similarity,
		"offset_x": _offset_x,
		"offset_y": _offset_y,
	}


func set_config(config: Dictionary) -> void:
	if _pattern:
		var index = config.get("pattern_index", _pattern.index)
		_pattern = Global.patterns_popup.get_pattern(index)
	_fill_area = config.get("fill_area", _fill_area)
	_fill_with = config.get("fill_with", _fill_with)
	_similarity = config.get("similarity", _similarity)
	_offset_x = config.get("offset_x", _offset_x)
	_offset_y = config.get("offset_y", _offset_y)
	update_pattern()


func update_config() -> void:
	_select_fill_area_optionbutton()
	$FillWithOptions.selected = _fill_with
	$SimilaritySlider.value = _similarity
	$FillPattern.visible = _fill_with == FillWith.PATTERN
	$FillPattern/OffsetX.value = _offset_x
	$FillPattern/OffsetY.value = _offset_y


func update_pattern() -> void:
	if _pattern == null:
		if Global.patterns_popup.default_pattern == null:
			return
		else:
			_pattern = Global.patterns_popup.default_pattern
	var tex := ImageTexture.new()
	if !_pattern.image.is_empty():
		tex.create_from_image(_pattern.image, 0)
	$FillPattern/Type/Texture.texture = tex
	var size := _pattern.image.get_size()
	$FillPattern/OffsetX.max_value = size.x - 1
	$FillPattern/OffsetY.max_value = size.y - 1


func draw_start(position: Vector2) -> void:
	.draw_start(position)
	if Input.is_action_pressed("draw_color_picker"):
		_pick_color(position)
		return

	Global.canvas.selection.transform_content_confirm()
	if (
		!Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn()
		or !Rect2(Vector2.ZERO, Global.current_project.size).has_point(position)
	):
		return
	if (
		Global.current_project.has_selection
		and not Global.current_project.can_pixel_get_drawn(position)
	):
		return
	var undo_data := _get_undo_data()
	match _fill_area:
		FillArea.AREA:
			fill_in_area(position)
		FillArea.COLORS:
			fill_in_color(position)
		FillArea.SELECTION:
			fill_in_selection()
	commit_undo("Draw", undo_data)


func draw_move(position: Vector2) -> void:
	.draw_move(position)


func draw_end(position: Vector2) -> void:
	.draw_end(position)


func fill_in_color(position: Vector2) -> void:
	var project: Project = Global.current_project
	var images := _get_selected_draw_images()
	for image in images:
		var color: Color = image.get_pixelv(position)
		var pattern_image: Image
		if _fill_with == FillWith.COLOR or _pattern == null:
			if tool_slot.color.is_equal_approx(color):
				continue
		else:
			# End early if we are filling with an empty pattern
			pattern_image = _pattern.image
			var pattern_size := pattern_image.get_size()
			if pattern_size.x == 0 or pattern_size.y == 0:
				return

		var selection: Image
		var selection_tex := ImageTexture.new()
		if project.has_selection:
			selection = project.selection_map
		else:
			selection = Image.new()
			selection.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
			selection.fill(Color(1, 1, 1, 1))

		selection_tex.create_from_image(selection)

		var pattern_tex := ImageTexture.new()
		if _pattern and pattern_image:
			pattern_tex.create_from_image(pattern_image)

		var params := {
			"size": project.size,
			"old_color": color,
			"new_color": tool_slot.color,
			"similarity_percent": _similarity,
			"selection": selection_tex,
			"pattern": pattern_tex,
			"pattern_size": pattern_tex.get_size(),
			# pixel offset converted to pattern uv offset
			"pattern_uv_offset":
			Vector2.ONE / pattern_tex.get_size() * Vector2(_offset_x, _offset_y),
			"has_pattern": true if _fill_with == FillWith.PATTERN else false
		}
		var gen := ShaderImageEffect.new()
		gen.generate_image(image, COLOR_REPLACE_SHADER, params, project.size)


func fill_in_area(position: Vector2) -> void:
	var project: Project = Global.current_project
	_flood_fill(position)

	# Handle Mirroring
	var mirror_x = project.x_symmetry_point - position.x
	var mirror_y = project.y_symmetry_point - position.y
	var mirror_x_inside: bool
	var mirror_y_inside: bool

	mirror_x_inside = project.can_pixel_get_drawn(Vector2(mirror_x, position.y))
	mirror_y_inside = project.can_pixel_get_drawn(Vector2(position.x, mirror_y))

	if Tools.horizontal_mirror and mirror_x_inside:
		_flood_fill(Vector2(mirror_x, position.y))
		if Tools.vertical_mirror and mirror_y_inside:
			_flood_fill(Vector2(mirror_x, mirror_y))
	if Tools.vertical_mirror and mirror_y_inside:
		_flood_fill(Vector2(position.x, mirror_y))


func fill_in_selection() -> void:
	var project: Project = Global.current_project
	var images := _get_selected_draw_images()
	if _fill_with == FillWith.COLOR or _pattern == null:
		if project.has_selection:
			var filler := Image.new()
			filler.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
			filler.fill(tool_slot.color)
			var rect: Rect2 = Global.canvas.selection.big_bounding_rectangle
			var selection_map_copy := SelectionMap.new()
			selection_map_copy.copy_from(project.selection_map)
			# In case the selection map is bigger than the canvas
			selection_map_copy.crop(project.size.x, project.size.y)
			for image in images:
				image.blit_rect_mask(filler, selection_map_copy, rect, rect.position)
		else:
			for image in images:
				image.fill(tool_slot.color)
	else:
		# End early if we are filling with an empty pattern
		var pattern_image: Image = _pattern.image
		var pattern_size := pattern_image.get_size()
		if pattern_size.x == 0 or pattern_size.y == 0:
			return

		var selection: Image
		var selection_tex := ImageTexture.new()
		if project.has_selection:
			selection = project.selection_map
		else:
			selection = Image.new()
			selection.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
			selection.fill(Color(1, 1, 1, 1))

		selection_tex.create_from_image(selection)

		var pattern_tex := ImageTexture.new()
		if _pattern and pattern_image:
			pattern_tex.create_from_image(pattern_image)

		var params := {
			"selection": selection_tex,
			"size": project.size,
			"pattern": pattern_tex,
			"pattern_size": pattern_tex.get_size(),
			# pixel offset converted to pattern uv offset
			"pattern_uv_offset":
			Vector2.ONE / pattern_tex.get_size() * Vector2(_offset_x, _offset_y),
		}
		for image in images:
			var gen := ShaderImageEffect.new()
			gen.generate_image(image, PATTERN_FILL_SHADER, params, project.size)


# Add a new segment to the array
func _add_new_segment(y: int = 0) -> void:
	var segment := {}
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
	if project.has_selection:
		while (
			project.can_pixel_get_drawn(west)
			&& image.get_pixelv(west).is_equal_approx(src_color)
		):
			west += Vector2.LEFT
		while (
			project.can_pixel_get_drawn(east)
			&& image.get_pixelv(east).is_equal_approx(src_color)
		):
			east += Vector2.RIGHT
	else:
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


func _flood_fill(position: Vector2) -> void:
	# implements the floodfill routine by Shawn Hargreaves
	# from https://www1.udel.edu/CIS/software/dist/allegro-4.2.1/src/flood.c
	var project: Project = Global.current_project
	var images := _get_selected_draw_images()
	for image in images:
		var color: Color = image.get_pixelv(position)
		if _fill_with == FillWith.COLOR or _pattern == null:
			# end early if we are filling with the same color
			if tool_slot.color.is_equal_approx(color):
				continue
		else:
			# end early if we are filling with an empty pattern
			var pattern_size := _pattern.image.get_size()
			if pattern_size.x == 0 or pattern_size.y == 0:
				return
		# init flood data structures
		_allegro_flood_segments = []
		_allegro_image_segments = []
		_compute_segments_for_image(position, project, image, color)
		# now actually color the image: since we have already checked a few things for the points
		# we'll process here, we're going to skip a bunch of safety checks to speed things up.
		_color_segments(image)


func _compute_segments_for_image(
	position: Vector2, project: Project, image: Image, src_color: Color
) -> void:
	# initially allocate at least 1 segment per line of image
	for j in image.get_height():
		_add_new_segment(j)
	# start flood algorithm
	_flood_line_around_point(position, project, image, src_color)
	# test all segments while also discovering more
	var done = false
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


func _color_segments(image: Image) -> void:
	if _fill_with == FillWith.COLOR or _pattern == null:
		var color_str = tool_slot.color.to_html()
		# short circuit for flat colors
		for c in _allegro_image_segments.size():
			var p = _allegro_image_segments[c]
			for px in range(p.left_position, p.right_position + 1):
				# We don't have to check again whether the point being processed is within the bounds
				image.set_pixel(px, p.y, Color(color_str))
	else:
		# shortcircuit tests for patternfills
		var pattern_size = _pattern.image.get_size()
		# we know the pattern had a valid size when we began flooding, so we can skip testing that
		# again for every point in the pattern.
		for c in _allegro_image_segments.size():
			var p = _allegro_image_segments[c]
			for px in range(p.left_position, p.right_position + 1):
				_set_pixel_pattern(image, px, p.y, pattern_size)


func _set_pixel_pattern(image: Image, x: int, y: int, pattern_size: Vector2) -> void:
	_pattern.image.lock()
	var px := int(x + _offset_x) % int(pattern_size.x)
	var py := int(y + _offset_y) % int(pattern_size.y)
	var pc := _pattern.image.get_pixel(px, py)
	_pattern.image.unlock()
	image.set_pixel(x, y, pc)


func commit_undo(action: String, undo_data: Dictionary) -> void:
	var redo_data := _get_undo_data()
	var project: Project = Global.current_project
	var frame := -1
	var layer := -1
	if Global.animation_timer.is_stopped() and project.selected_cels.size() == 1:
		frame = project.current_frame
		layer = project.current_layer

	project.undos += 1
	project.undo_redo.create_action(action)
	for image in redo_data:
		project.undo_redo.add_do_property(image, "data", redo_data[image])
		image.unlock()
	for image in undo_data:
		project.undo_redo.add_undo_property(image, "data", undo_data[image])
	project.undo_redo.add_do_method(Global, "undo_or_redo", false, frame, layer)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true, frame, layer)
	project.undo_redo.commit_action()


func _get_undo_data() -> Dictionary:
	var data := {}
	var images := _get_selected_draw_images()
	for image in images:
		image.unlock()
		data[image] = image.data
		image.lock()
	return data


func _pick_color(position: Vector2) -> void:
	var project: Project = Global.current_project
	position = project.tiles.get_canon_position(position)

	if position.x < 0 or position.y < 0:
		return

	var image := Image.new()
	image.copy_from(_get_draw_image())
	if position.x > image.get_width() - 1 or position.y > image.get_height() - 1:
		return

	image.lock()
	var color := image.get_pixelv(position)
	image.unlock()
	var button := BUTTON_LEFT if Tools._slots[BUTTON_LEFT].tool_node == self else BUTTON_RIGHT
	Tools.assign_color(color, button, false)
