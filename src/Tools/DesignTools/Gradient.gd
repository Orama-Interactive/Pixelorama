class_name GradientTool
extends BaseTool

static var gradient_shader: Shader

var gradient_shader_inc := load("uid://dj3bi0pycege2")

var _undo_data := {}
var _click_pos: Vector2
var _selected_dither_matrix := ShaderLoader.dither_matrices[0]

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


func draw_start(pos: Vector2i) -> void:
	super.draw_start(pos)
	Global.transform_content_confirmed.emit()
	_undo_data = _get_undo_data()
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return
	if not Global.current_project.can_pixel_get_drawn(pos):
		return
	_click_pos = pos
	apply_gradient(pos)
	Global.canvas.sprite_changed_this_frame = true


func draw_move(pos: Vector2i) -> void:
	apply_gradient(pos)
	Global.canvas.sprite_changed_this_frame = true


func draw_end(pos: Vector2i) -> void:
	super.draw_end(pos)
	apply_gradient(pos)
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


func apply_gradient(pos: Vector2) -> void:
	var project := Global.current_project
	var selection_tex: ImageTexture
	if project.has_selection:
		var selection := project.selection_map.return_cropped_copy(project, project.size)
		selection_tex = ImageTexture.create_from_image(selection)
	var angle := rad_to_deg(-pos.angle_to_point(_click_pos))
	var radius := pos - _click_pos
	if Input.is_action_pressed("shape_perfect"):
		angle = snappedf(angle, 22.5)
		var square_size := maxi(absi(radius.x), absi(radius.y))
		radius = Vector2i(square_size, square_size)
	radius /= Vector2(project.size)

	var params := {
		"gradient_texture": gradient_edit.texture,
		"gradient_texture_no_interpolation": gradient_edit.get_gradient_texture_no_interpolation(),
		"gradient_offset_texture": gradient_edit.get_gradient_offsets_texture(),
		"use_dithering": dithering_option_button.selected > 0,
		"selection": selection_tex,
		"repeat": repeat_option_button.selected,
		"position": _click_pos.x / project.size.x - 0.5,
		"size": pos.distance_to(_click_pos) / project.size.x,
		"angle": angle,
		"center": _click_pos / Vector2(project.size),
		"radius": radius,
		"dither_texture": _selected_dither_matrix.texture,
		"shape": shape_option_button.selected,
	}
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


func _on_dithering_option_button_item_selected(index: int) -> void:
	if index > 0:
		_selected_dither_matrix = ShaderLoader.dither_matrices[index - 1]
