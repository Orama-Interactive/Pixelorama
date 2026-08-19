class_name GradientTool
extends BaseTool

enum Shape { LINEAR, RADIAL }
enum Repeat { NONE, REPEAT, MIRROR, TRUNCATE }
enum FillArea { AREA, COLORS, SELECTION }

static var gradient_shader: Shader

var gradient_shader_inc := load("uid://dj3bi0pycege2")

var _shape := Shape.LINEAR
var _selected_dither_index := 0:
	set(value):
		_selected_dither_index = value
		if value > 0:
			_selected_dither_matrix = ShaderLoader.dither_matrices[value - 1]
var _selected_dither_matrix := ShaderLoader.dither_matrices[0]
var _repeat := Repeat.NONE
var _fill_area := FillArea.AREA
var _tolerance := 0.003

var _undo_data := {}
var _click_pos: Vector2
var _click_color: Color
var _offset := Vector2i.ZERO
var _drawing := false
var _displace_origin := false
var _selection_tex: ImageTexture

@onready var gradient_edit: GradientEditNode = $GradientEdit
@onready var shape_option_button: OptionButton = %ShapeOptionButton
@onready var dithering_option_button: OptionButton = %DitheringOptionButton
@onready var repeat_option_button: OptionButton = %RepeatOptionButton


func _init() -> void:
	if gradient_shader == null:
		gradient_shader = ShaderLoader.generate_texture_blit_shader(gradient_shader_inc)


func _ready() -> void:
	for matrix in ShaderLoader.dither_matrices:
		dithering_option_button.add_item(matrix.name)
	super()


func _input(event: InputEvent) -> void:
	if _drawing:
		if event.is_action_pressed(&"shape_displace"):
			_displace_origin = true
			get_viewport().set_input_as_handled()
		elif event.is_action_released(&"shape_displace"):
			_displace_origin = false
			get_viewport().set_input_as_handled()


func get_config() -> Dictionary:
	return {
		"gradient": GradientEditNode.serialize_gradient(gradient_edit.gradient),
		"shape": _shape,
		"selected_dither_index": _selected_dither_index,
		"repeat": _repeat,
		"fill_area": _fill_area,
		"tolerance": _tolerance,
	}


func set_config(config: Dictionary) -> void:
	var gradient_dict = config.get("gradient")
	if gradient_dict:
		var gradient := GradientEditNode.deserialize_gradient(gradient_dict)
		gradient_edit.set_gradient(gradient)
	_shape = config.get("shape", _shape)
	_selected_dither_index = config.get("selected_dither_index", _selected_dither_index)
	_repeat = config.get("repeat", _repeat)
	_fill_area = config.get("fill_area", _fill_area)
	_tolerance = config.get("tolerance", _tolerance)


func update_config() -> void:
	%ShapeOptionButton.selected = _shape
	%DitheringOptionButton.selected = _selected_dither_index
	%RepeatOptionButton.selected = _repeat
	_select_fill_area_optionbutton()
	%ToleranceSlider.value = _tolerance * 255.0


func draw_start(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super(pos)
	Global.transform_content_confirmed.emit()
	_undo_data = _get_undo_data()
	var project := Global.current_project
	if not project.layers[project.current_layer].can_layer_get_drawn():
		return
	if not project.can_pixel_get_drawn(pos):
		return
	_click_pos = pos
	var cel := project.get_current_cel()
	_click_color = cel.get_image().get_pixelv(pos)
	_offset = pos
	_drawing = true
	_selection_tex = ImageTexture.new()
	if project.has_selection:
		var selection := project.selection_map.return_cropped_copy(project, project.size)
		_selection_tex = ImageTexture.create_from_image(selection)
	if _fill_area == FillArea.AREA:
		var source_image := project.get_current_cel().get_image()
		var draw_mask := SelectionMap.new()
		draw_mask.copy_from(project.selection_map)
		draw_mask.clear()
		var flood_fill_object := FloodFillObject.new()
		flood_fill_object.tolerance = _tolerance
		flood_fill_object.flood_fill(
			pos, source_image, draw_mask, project, _select_segments.bind(project.selection_map)
		)
		_selection_tex = ImageTexture.create_from_image(draw_mask)
	apply_gradient(pos)
	Global.canvas.sprite_changed_this_frame = true


func draw_move(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super(pos)
	if _drawing:
		if _displace_origin:
			_click_pos += Vector2(pos - _offset)
		apply_gradient(pos)
		_offset = pos
		Global.canvas.sprite_changed_this_frame = true


func draw_end(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super(pos)
	apply_gradient(pos)
	commit_undo()
	_reset_tool()


func cancel_tool() -> void:
	super()
	_restore_image_data()
	Global.canvas.sprite_changed_this_frame = true
	_reset_tool()


func _restore_image_data() -> void:
	for data in _undo_data:
		if data is not Image:
			continue
		var image_data = _undo_data[data]["data"]
		data.set_data(
			data.get_width(), data.get_height(), data.has_mipmaps(), data.get_format(), image_data
		)


func _reset_tool() -> void:
	_click_pos = Vector2.ZERO
	_drawing = false
	_displace_origin = false


func apply_gradient(pos: Vector2) -> void:
	var project := Global.current_project
	var angle := rad_to_deg(-pos.angle_to_point(_click_pos))
	var pivot := _click_pos / Vector2(project.size)
	var radius := pos - _click_pos
	if Input.is_action_pressed("shape_perfect"):
		angle = snappedf(angle, 22.5)
		var square_size := maxi(absi(radius.x), absi(radius.y))
		radius = Vector2i(square_size, square_size)
	radius /= Vector2(project.size)
	var use_color_masking := _fill_area != FillArea.SELECTION
	var params := {
		"gradient_texture": gradient_edit.texture,
		"gradient_texture_no_interpolation": gradient_edit.get_gradient_texture_no_interpolation(),
		"gradient_offset_texture": gradient_edit.get_gradient_offsets_texture(),
		"use_dithering": dithering_option_button.selected > 0,
		"selection": _selection_tex,
		"shape": _shape,
		"repeat": _repeat,
		"size": pos.distance_to(_click_pos) / project.size.x,
		"angle": angle,
		"pivot": pivot,
		"center": _click_pos / Vector2(project.size),
		"radius": radius,
		"dither_texture": _selected_dither_matrix.texture,
		"use_color_masking": use_color_masking,
		"color_mask": _click_color,
		"tolerance": _tolerance
	}
	_restore_image_data()
	var images := _get_selected_draw_images()
	for image in images:
		var gen := ShaderImageEffect.new()
		gen.generate_image(image, gradient_shader, params, project.size)


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
	# We may be on a different layer during undo/redo.
	project.undo_redo.add_do_property(Global.canvas, &"mandatory_update_layers", layers_to_update)
	project.undo_redo.add_undo_property(Global.canvas, &"mandatory_update_layers", layers_to_update)
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


func _select_fill_area_optionbutton() -> void:
	%FillAreaOptions.selected = _fill_area
	%ToleranceLabel.visible = (_fill_area != FillArea.SELECTION)
	%ToleranceSlider.visible = (_fill_area != FillArea.SELECTION)


## Used when the fill area is set to similar area.
func _select_segments(
	mask: SelectionMap, segments: Array[FloodFillObject.Segment], selection_map: SelectionMap
) -> void:
	for c in segments.size():
		var p := segments[c]
		for px in range(p.left_position, p.right_position + 1):
			# We don't have to check again whether the point being processed is within the bounds
			_set_bit(Vector2i(px, p.y), mask, selection_map)


## Used when the fill area is set to similar area.
func _set_bit(p: Vector2i, mask: SelectionMap, selection_map: SelectionMap) -> void:
	if selection_map.is_invisible() or selection_map.is_pixel_selected(p):
		mask.select_pixel(p, true)


func _on_gradient_edit_updated(_gradient: Gradient, _cc: bool) -> void:
	update_config()
	save_config()


func _on_shape_option_button_item_selected(index: Shape) -> void:
	_shape = index
	update_config()
	save_config()


func _on_repeat_option_button_item_selected(index: Repeat) -> void:
	_repeat = index
	update_config()
	save_config()


func _on_dithering_option_button_item_selected(index: int) -> void:
	_selected_dither_index = index
	update_config()
	save_config()


func _on_fill_area_options_item_selected(index: FillArea) -> void:
	_fill_area = index
	update_config()
	save_config()


func _on_tolerance_slider_value_changed(value: float) -> void:
	_tolerance = value / 255.0
	update_config()
	save_config()
