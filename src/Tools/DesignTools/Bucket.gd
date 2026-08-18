extends BaseTool

enum FillArea { AREA, COLORS, SELECTION }
enum FillWith { COLOR, PATTERN }

const COLOR_REPLACE_SHADER := preload("res://src/Shaders/ColorReplace.gdshader")
const PATTERN_FILL_SHADER := preload("res://src/Shaders/PatternFill.gdshader")

var _undo_data := {}
var _prev_mode := 0
var _pattern: Patterns.Pattern
var _tolerance := 0.003
var _fill_area: int = FillArea.AREA
var _fill_with: int = FillWith.COLOR
var _fill_merged_area := false  ## Fill regions from the merging of all layers
var _offset_x := 0
var _offset_y := 0
## Used for _fill_merged_area = true
var _sample_masks: Dictionary[Frame, Image] = {}


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


func _on_merge_area_options_toggled(toggled_on: bool) -> void:
	_fill_merged_area = toggled_on
	update_config()
	save_config()


func _select_fill_area_optionbutton() -> void:
	$FillAreaOptions.selected = _fill_area
	$MergeAreaOptions.visible = _fill_area == FillArea.AREA
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
		return {
			"fill_area": _fill_area,
			"fill_merged_area": _fill_merged_area,
			"fill_with": _fill_with,
			"tolerance": _tolerance
		}
	return {
		"pattern_index": _pattern.index,
		"fill_area": _fill_area,
		"fill_merged_area": _fill_merged_area,
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
	_fill_merged_area = config.get("fill_merged_area", _fill_merged_area)
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
	$MergeAreaOptions.button_pressed = _fill_merged_area


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
	Global.transform_content_confirmed.emit()
	_undo_data = _get_undo_data()
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return
	if not Global.current_project.can_pixel_get_drawn(pos):
		return
	if _fill_merged_area and _fill_area == FillArea.AREA:
		var project := Global.current_project
		for frame_layer: Array in project.selected_cels:
			if project.frames[frame_layer[0]].cels[frame_layer[1]] is PixelCel:
				var frame := project.frames[frame_layer[0]]
				if not _sample_masks.has(frame):
					var mask := Image.create(
						project.size.x, project.size.y, false, Image.FORMAT_RGBA8
					)
					mask.fill(Color(0, 0, 0, 0))
					DrawingAlgos.blend_layers(mask, frame)
					_sample_masks[frame] = mask
	fill(pos)


func draw_move(pos: Vector2i) -> void:
	super.draw_move(pos)
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return
	if not Global.current_project.can_pixel_get_drawn(pos):
		return
	fill(pos)


func draw_end(pos: Vector2i) -> void:
	super.draw_end(pos)
	_sample_masks.clear()
	commit_undo()


func cancel_tool() -> void:
	super()
	for data in _undo_data:
		if data is not Image:
			continue
		var image_data = _undo_data[data]["data"]
		data.set_data(
			data.get_width(), data.get_height(), data.has_mipmaps(), data.get_format(), image_data
		)
	Global.canvas.sprite_changed_this_frame = true


func draw_tile(cell_coords: Vector2i, index: int, tilemap_cel: CelTileMap) -> void:
	if TileSetPanel.autotiling_enabled:
		tilemap_cel.autotile([cell_coords], index == 0)
	else:
		tilemap_cel.set_index(tilemap_cel.get_cell_at(cell_coords), index)


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
			for cell_coords: Vector2i in tilemap_cel.cells:
				var cell := tilemap_cel.get_cell_at(cell_coords)
				if cell.index == tile_index:
					var paint_index := TileSetPanel.selected_tile_index
					if TileSetPanel.autotiling_enabled:
						tilemap_cel.autotile([cell_coords], paint_index == 0)
					else:
						tilemap_cel.set_index(cell, paint_index)
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
			selection = project.selection_map.return_cropped_copy(project, project.size)
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
			var pattern_size := Vector2(pattern_tex.get_size())
			params["pattern_size"] = pattern_size
			# pixel offset converted to pattern uv offset
			params["pattern_uv_offset"] = (
				Vector2.ONE / pattern_size * Vector2(_offset_x, _offset_y)
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
			var selection_map_copy := project.selection_map.return_cropped_copy(
				project, project.size
			)
			var rect := selection_map_copy.get_used_rect()
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
			selection = project.selection_map.return_cropped_copy(project, project.size)
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
				Vector2.ONE / Vector2(pattern_size) * Vector2(_offset_x, _offset_y)
			)
		for image in images:
			var gen := ShaderImageEffect.new()
			gen.generate_image(image, PATTERN_FILL_SHADER, params, project.size)


func _flood_fill(pos: Vector2i) -> void:
	# implements the floodfill routine by Shawn Hargreaves
	# from https://www1.udel.edu/CIS/software/dist/allegro-4.2.1/src/flood.c
	var project := Global.current_project
	if project.has_selection:
		project.selection_map.lock_selection_rect(project, true)
	if Tools.is_placing_tiles():
		for cel in _get_selected_draw_cels(false):
			if cel is not CelTileMap:
				continue
			var tilemap_cel := cel as CelTileMap
			var cell_pos := tilemap_cel.get_cell_position(pos)
			tilemap_cel.bucket_fill(cell_pos, draw_tile.bind(tilemap_cel))
		if project.has_selection:
			project.selection_map.lock_selection_rect(project, false)
		return

	var cels := _get_selected_draw_cels(false)
	for cel: PixelCel in cels:
		var image: ImageExtended = cel.image
		if Tools.check_alpha_lock(image, pos):
			continue
		var color: Color = image.get_pixelv(pos)
		if _fill_merged_area:
			color = _sample_masks.get(cel.get_frame(project), cel.image).get_pixelv(pos)
		if _fill_with == FillWith.COLOR or _pattern == null:
			# end early if we are filling with the same color
			if tool_slot.color.is_equal_approx(color):
				continue
			# Fill all area if it's completely empty and _fill_merged_area = false
			if image.get_used_rect().size == Vector2i.ZERO and not _fill_merged_area:
				if project.has_selection:
					var filler := project.new_empty_image()
					filler.fill(tool_slot.color)
					var selection_map_copy := project.selection_map.return_cropped_copy(
						project, project.size
					)
					var rect := selection_map_copy.get_used_rect()
					image.blit_rect_mask(filler, selection_map_copy, rect, rect.position)
					image.convert_rgb_to_indexed()
					continue
				else:
					image.fill(tool_slot.color)
					image.convert_rgb_to_indexed()
					continue
		else:
			# end early if we are filling with an empty pattern
			var pattern_size := _pattern.image.get_size()
			if pattern_size.x == 0 or pattern_size.y == 0:
				if project.has_selection:
					project.selection_map.lock_selection_rect(project, false)
				return
		var source_image: Image = image
		if _fill_merged_area:
			source_image = _sample_masks.get(cel.get_frame(project), cel.image)
		var flood_fill_object := FloodFillObject.new()
		flood_fill_object.tolerance = _tolerance
		flood_fill_object.selection_matters = true
		flood_fill_object.flood_fill(pos, source_image, image, project, _color_segments)
	if project.has_selection:
		project.selection_map.lock_selection_rect(project, false)


func _color_segments(image: ImageExtended, segments: Array[FloodFillObject.Segment]) -> void:
	if _fill_with == FillWith.COLOR or _pattern == null:
		# This is needed to ensure that the color used to fill is not wrong, due to float
		# rounding issues.
		var color_str: String = tool_slot.color.to_html()
		var color := Color(color_str)
		# short circuit for flat colors
		for c in segments.size():
			var p := segments[c]
			# We don't have to check again whether the point being processed is within the bounds
			var rect := Rect2(
				Vector2i(p.left_position, p.y), Vector2i(p.right_position - p.left_position + 1, 1)
			)
			image.fill_rect(rect, color)
		image.convert_rgb_to_indexed()
	else:
		# shortcircuit tests for patternfills
		var pattern_size := _pattern.image.get_size()
		# we know the pattern had a valid size when we began flooding, so we can skip testing that
		# again for every point in the pattern.
		for c in segments.size():
			var p := segments[c]
			for px in range(p.left_position, p.right_position + 1):
				_set_pixel_pattern(image, px, p.y, pattern_size)


func _set_pixel_pattern(image: ImageExtended, x: int, y: int, pattern_size: Vector2i) -> void:
	var px := (x + _offset_x) % pattern_size.x
	var py := (y + _offset_y) % pattern_size.y
	var pc := _pattern.image.get_pixel(px, py)
	image.set_pixel_custom(x, y, pc)


func commit_undo() -> void:
	var project := Global.current_project
	var tile_editing_mode := TileSetPanel.tile_editing_mode
	if TileSetPanel.placing_tiles:
		tile_editing_mode = TileSetPanel.TileEditingMode.STACK
	var used_tilesets := project.update_tilemaps(_undo_data, tile_editing_mode)
	var redo_data := _get_undo_data()
	var frame := -1
	var layer := -1
	if Global.animation_timeline.animation_timer.is_stopped() and project.selected_cels.size() == 1:
		frame = project.current_frame
		layer = project.current_layer

	project.undo_redo.create_action("Draw")
	manage_undo_redo_palettes()
	var layers_to_update := PackedInt32Array()
	for l in Global.current_project.layers:
		if l is LayerTileMap:
			if l.tileset in used_tilesets:
				layers_to_update.append(l.index)
	project.deserialize_cel_undo_data(redo_data, _undo_data)
	# we may be on a different layer during undo/redo
	project.undo_redo.add_do_property(Global.canvas, "mandatory_update_layers", layers_to_update)
	project.undo_redo.add_undo_property(Global.canvas, "mandatory_update_layers", layers_to_update)
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
