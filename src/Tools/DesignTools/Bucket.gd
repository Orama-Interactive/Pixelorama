extends BaseTool

enum FillArea { AREA, COLORS, SELECTION }
enum FillWith { COLOR, PATTERN }

const COLOR_REPLACE_SHADER := preload("res://src/Shaders/ColorReplace.gdshader")
const PATTERN_FILL_SHADER := preload("res://src/Shaders/PatternFill.gdshader")

var _undo_data := {}
var _picking_color := false
var _prev_mode := 0
var _pattern: Patterns.Pattern
var _tolerance := 0.003
var _fill_area: int = FillArea.AREA
var _fill_with: int = FillWith.COLOR
var _offset_x := 0
var _offset_y := 0
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


func _ready() -> void:
	super._ready()
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
	$ToleranceSlider.visible = (_fill_area != FillArea.SELECTION)


func _on_FillWithOptions_item_selected(index: int) -> void:
	_fill_with = index
	update_config()
	save_config()


func _on_tolerance_slider_value_changed(value: float) -> void:
	_tolerance = value / 255.0
	update_config()
	save_config()


func _on_PatternType_pressed() -> void:
	var popup: Popup = Global.patterns_popup
	if !popup.pattern_selected.is_connected(_on_Pattern_selected):
		popup.pattern_selected.connect(_on_Pattern_selected.bind(), CONNECT_ONE_SHOT)
	popup.popup_on_parent(Rect2i($FillPattern/Type.global_position, Vector2i(226, 72)))


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
		return {"fill_area": _fill_area, "fill_with": _fill_with, "tolerance": _tolerance}
	return {
		"pattern_index": _pattern.index,
		"fill_area": _fill_area,
		"fill_with": _fill_with,
		"tolerance": _tolerance,
		"offset_x": _offset_x,
		"offset_y": _offset_y,
	}


func set_config(config: Dictionary) -> void:
	if _pattern:
		var index = config.get("pattern_index", _pattern.index)
		_pattern = Global.patterns_popup.get_pattern(index)
	_fill_area = config.get("fill_area", _fill_area)
	_fill_with = config.get("fill_with", _fill_with)
	_tolerance = config.get("tolerance", _tolerance)
	_offset_x = config.get("offset_x", _offset_x)
	_offset_y = config.get("offset_y", _offset_y)
	update_pattern()


func update_config() -> void:
	_select_fill_area_optionbutton()
	$FillWithOptions.selected = _fill_with
	$ToleranceSlider.value = _tolerance * 255.0
	$FillPattern.visible = _fill_with == FillWith.PATTERN
	$FillPattern/OffsetX.value = _offset_x
	$FillPattern/OffsetY.value = _offset_y


func update_pattern() -> void:
	if _pattern == null:
		if Global.patterns_popup.default_pattern == null:
			return
		else:
			_pattern = Global.patterns_popup.default_pattern
	var tex: ImageTexture
	if !_pattern.image.is_empty():
		tex = ImageTexture.create_from_image(_pattern.image)
	$FillPattern/Type/Texture2D.texture = tex
	var pattern_size := _pattern.image.get_size()
	$FillPattern/OffsetX.max_value = pattern_size.x - 1
	$FillPattern/OffsetY.max_value = pattern_size.y - 1


func draw_start(pos: Vector2i) -> void:
	super.draw_start(pos)
	if Input.is_action_pressed(&"draw_color_picker", true):
		_picking_color = true
		_pick_color(pos)
		return
	_picking_color = false
	_undo_data = _get_undo_data()
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return
	if not Global.current_project.can_pixel_get_drawn(pos):
		return
	fill(pos)


func draw_move(pos: Vector2i) -> void:
	super.draw_move(pos)
	if _picking_color:  # Still return even if we released Alt
		if Input.is_action_pressed(&"draw_color_picker", true):
			_pick_color(pos)
		return
	Global.canvas.selection.transform_content_confirm()
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return
	if not Global.current_project.can_pixel_get_drawn(pos):
		return
	fill(pos)


func draw_end(pos: Vector2i) -> void:
	super.draw_end(pos)
	if _picking_color:
		return
	commit_undo()


func draw_tile(pos: Vector2i, cel: CelTileMap) -> void:
	var tile_position := get_cell_position(pos)
	cel.set_index(tile_position, TileSetPanel.selected_tile_index)


func fill(pos: Vector2i) -> void:
	match _fill_area:
		FillArea.AREA:
			fill_in_area(pos)
		FillArea.COLORS:
			fill_in_color(pos)
		FillArea.SELECTION:
			fill_in_selection()
	Global.canvas.sprite_changed_this_frame = true


func fill_in_color(pos: Vector2i) -> void:
	var project := Global.current_project
	if Tools.is_placing_tiles():
		for cel in _get_selected_draw_cels():
			if cel is not CelTileMap:
				continue
			var tilemap_cel := cel as CelTileMap
			var tile_index := tilemap_cel.get_cell_index_at_coords(pos)
			for i in tilemap_cel.cells.size():
				var cell := tilemap_cel.cells[i]
				if cell.index == tile_index:
					tilemap_cel.set_index(i, TileSetPanel.selected_tile_index)
		return
	var color := project.get_current_cel().get_image().get_pixelv(pos)
	var images := _get_selected_draw_images()
	for image in images:
		if Tools.check_alpha_lock(image, pos):
			continue
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
		var selection_tex: ImageTexture
		if project.has_selection:
			selection = project.selection_map.return_cropped_copy(project.size)
		else:
			selection = project.new_empty_image()
			selection.fill(Color(1, 1, 1, 1))

		selection_tex = ImageTexture.create_from_image(selection)

		var pattern_tex: ImageTexture
		if _pattern and pattern_image:
			pattern_tex = ImageTexture.create_from_image(pattern_image)

		var params := {
			"size": project.size,
			"old_color": color,
			"new_color": tool_slot.color,
			"tolerance": _tolerance,
			"selection": selection_tex,
			"pattern": pattern_tex,
			"has_pattern": true if _fill_with == FillWith.PATTERN else false
		}
		if is_instance_valid(pattern_tex):
			var pattern_size := Vector2i(pattern_tex.get_size())
			params["pattern_size"] = pattern_size
			# pixel offset converted to pattern uv offset
			params["pattern_uv_offset"] = (
				Vector2i.ONE / pattern_size * Vector2i(_offset_x, _offset_y)
			)
		var gen := ShaderImageEffect.new()
		gen.generate_image(image, COLOR_REPLACE_SHADER, params, project.size)


func fill_in_area(pos: Vector2i) -> void:
	var project := Global.current_project
	_flood_fill(pos)
	# Handle mirroring
	for mirror_pos in Tools.get_mirrored_positions(pos, project):
		if project.can_pixel_get_drawn(mirror_pos):
			_flood_fill(mirror_pos)


func fill_in_selection() -> void:
	var project := Global.current_project
	var images := _get_selected_draw_images()
	if _fill_with == FillWith.COLOR or _pattern == null:
		if project.has_selection:
			var filler := project.new_empty_image()
			filler.fill(tool_slot.color)
			var rect: Rect2i = Global.canvas.selection.big_bounding_rectangle
			var selection_map_copy := project.selection_map.return_cropped_copy(project.size)
			for image in images:
				image.blit_rect_mask(filler, selection_map_copy, rect, rect.position)
				image.convert_rgb_to_indexed()
		else:
			for image in images:
				image.fill(tool_slot.color)
				image.convert_rgb_to_indexed()
	else:
		# End early if we are filling with an empty pattern
		var pattern_image: Image = _pattern.image
		var pattern_size := pattern_image.get_size()
		if pattern_size.x == 0 or pattern_size.y == 0:
			return

		var selection: Image
		var selection_tex: ImageTexture
		if project.has_selection:
			selection = project.selection_map.return_cropped_copy(project.size)
		else:
			selection = project.new_empty_image()
			selection.fill(Color(1, 1, 1, 1))

		selection_tex = ImageTexture.create_from_image(selection)

		var pattern_tex: ImageTexture
		if _pattern and pattern_image:
			pattern_tex = ImageTexture.create_from_image(pattern_image)

		var params := {
			"selection": selection_tex,
			"size": project.size,
			"pattern": pattern_tex,
		}
		if is_instance_valid(pattern_tex):
			params["pattern_size"] = pattern_size
			# pixel offset converted to pattern uv offset
			params["pattern_uv_offset"] = (
				Vector2i.ONE / pattern_size * Vector2i(_offset_x, _offset_y)
			)
		for image in images:
			var gen := ShaderImageEffect.new()
			gen.generate_image(image, PATTERN_FILL_SHADER, params, project.size)


func _flood_fill(pos: Vector2i) -> void:
	# implements the floodfill routine by Shawn Hargreaves
	# from https://www1.udel.edu/CIS/software/dist/allegro-4.2.1/src/flood.c
	var project := Global.current_project
	if Tools.is_placing_tiles():
		for cel in _get_selected_draw_cels():
			if cel is not CelTileMap:
				continue
			var tile_index := (cel as CelTileMap).get_cell_index_at_coords(pos)
			# init flood data structures
			_allegro_flood_segments = []
			_allegro_image_segments = []
			_compute_segments_for_tilemap(pos, cel, tile_index)
			_color_segments_tilemap(cel)
		return

	var images := _get_selected_draw_images()
	for image in images:
		if Tools.check_alpha_lock(image, pos):
			continue
		var color: Color = image.get_pixelv(pos)
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
		_compute_segments_for_image(pos, project, image, color)
		# now actually color the image: since we have already checked a few things for the points
		# we'll process here, we're going to skip a bunch of safety checks to speed things up.
		_color_segments(image)


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


## Add a new segment to the array
func _add_new_segment(y := 0) -> void:
	_allegro_flood_segments.append(Segment.new(y))


## Fill an horizontal segment around the specified position, and adds it to the
## list of segments filled. Returns the first x coordinate after the part of the
## line that has been filled.
## Τhis method is called by [method _flood_fill] after the required data structures
## have been initialized.
func _flood_line_around_point(
	pos: Vector2i, project: Project, image: Image, src_color: Color
) -> int:
	if not DrawingAlgos.similar_colors(image.get_pixelv(pos), src_color, _tolerance):
		return pos.x + 1
	var west := pos
	var east := pos
	if project.has_selection:
		while (
			project.can_pixel_get_drawn(west)
			&& DrawingAlgos.similar_colors(image.get_pixelv(west), src_color, _tolerance)
		):
			west += Vector2i.LEFT
		while (
			project.can_pixel_get_drawn(east)
			&& DrawingAlgos.similar_colors(image.get_pixelv(east), src_color, _tolerance)
		):
			east += Vector2i.RIGHT
	else:
		while (
			west.x >= 0
			&& DrawingAlgos.similar_colors(image.get_pixelv(west), src_color, _tolerance)
		):
			west += Vector2i.LEFT
		while (
			east.x < project.size.x
			&& DrawingAlgos.similar_colors(image.get_pixelv(east), src_color, _tolerance)
		):
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
	var c: int = 0
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


func _color_segments(image: ImageExtended) -> void:
	if _fill_with == FillWith.COLOR or _pattern == null:
		# This is needed to ensure that the color used to fill is not wrong, due to float
		# rounding issues.
		var color_str: String = tool_slot.color.to_html()
		var color := Color(color_str)
		# short circuit for flat colors
		for c in _allegro_image_segments.size():
			var p := _allegro_image_segments[c]
			for px in range(p.left_position, p.right_position + 1):
				# We don't have to check again whether the point being processed is within the bounds
				image.set_pixel_custom(px, p.y, color)
	else:
		# shortcircuit tests for patternfills
		var pattern_size := _pattern.image.get_size()
		# we know the pattern had a valid size when we began flooding, so we can skip testing that
		# again for every point in the pattern.
		for c in _allegro_image_segments.size():
			var p := _allegro_image_segments[c]
			for px in range(p.left_position, p.right_position + 1):
				_set_pixel_pattern(image, px, p.y, pattern_size)


func _set_pixel_pattern(image: ImageExtended, x: int, y: int, pattern_size: Vector2i) -> void:
	var px := (x + _offset_x) % pattern_size.x
	var py := (y + _offset_y) % pattern_size.y
	var pc := _pattern.image.get_pixel(px, py)
	image.set_pixel_custom(x, y, pc)


func _compute_segments_for_tilemap(pos: Vector2i, cel: CelTileMap, src_index: int) -> void:
	# initially allocate at least 1 segment per line of the tilemap
	for j in cel.vertical_cells:
		_add_new_segment(j)
	pos /= cel.tileset.tile_size
	# start flood algorithm
	_flood_line_around_point_tilemap(pos, cel, src_index)
	# test all segments while also discovering more
	var done := false
	while not done:
		done = true
		var max_index := _allegro_flood_segments.size()
		for c in max_index:
			var p := _allegro_flood_segments[c]
			if p.todo_below:  # check below the segment?
				p.todo_below = false
				if _check_flooded_segment_tilemap(
					p.y + 1, p.left_position, p.right_position, cel, src_index
				):
					done = false
			if p.todo_above:  # check above the segment?
				p.todo_above = false
				if _check_flooded_segment_tilemap(
					p.y - 1, p.left_position, p.right_position, cel, src_index
				):
					done = false


## Fill an horizontal segment around the specified position, and adds it to the
## list of segments filled. Returns the first x coordinate after the part of the
## line that has been filled.
## Τhis method is called by [method _flood_fill] after the required data structures
## have been initialized.
func _flood_line_around_point_tilemap(pos: Vector2i, cel: CelTileMap, src_index: int) -> int:
	if cel.get_cell_index_at_coords_in_tilemap_space(pos) != src_index:
		return pos.x + 1
	var west := pos
	var east := pos
	while west.x >= 0 && cel.get_cell_index_at_coords_in_tilemap_space(west) == src_index:
		west += Vector2i.LEFT
	while (
		east.x < cel.horizontal_cells
		&& cel.get_cell_index_at_coords_in_tilemap_space(east) == src_index
	):
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
	segment.todo_below = pos.y < cel.vertical_cells - 1
	# this is an actual segment we should be coloring, so we add it to the results for the
	# current image
	if segment.right_position >= segment.left_position:
		_allegro_image_segments.append(segment)
	# we know the point just east of the segment is not part of a segment that should be
	# processed, else it would be part of this segment
	return east.x + 1


func _check_flooded_segment_tilemap(
	y: int, left: int, right: int, cel: CelTileMap, src_index: int
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
				left = _flood_line_around_point_tilemap(Vector2i(left, y), cel, src_index)
				ret = true
				break
	return ret


func _color_segments_tilemap(cel: CelTileMap) -> void:
	for c in _allegro_image_segments.size():
		var p := _allegro_image_segments[c]
		for px in range(p.left_position, p.right_position + 1):
			draw_tile(Vector2i(px, p.y) * cel.tileset.tile_size, cel)


func commit_undo() -> void:
	var project := Global.current_project
	project.update_tilemaps(_undo_data)
	var redo_data := _get_undo_data()
	var frame := -1
	var layer := -1
	if Global.animation_timeline.animation_timer.is_stopped() and project.selected_cels.size() == 1:
		frame = project.current_frame
		layer = project.current_layer

	project.undos += 1
	project.undo_redo.create_action("Draw")
	project.deserialize_cel_undo_data(redo_data, _undo_data)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false, frame, layer))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true, frame, layer))
	project.undo_redo.commit_action()
	_undo_data.clear()


func _get_undo_data() -> Dictionary:
	var data := {}
	if Global.animation_timeline.animation_timer.is_stopped():
		Global.current_project.serialize_cel_undo_data(_get_selected_draw_cels(), data)
	else:
		var cels: Array[BaseCel]
		for frame in Global.current_project.frames:
			var cel := frame.cels[Global.current_project.current_layer]
			if not cel is PixelCel:
				continue
			cels.append(cel)
		Global.current_project.serialize_cel_undo_data(cels, data)
	return data
