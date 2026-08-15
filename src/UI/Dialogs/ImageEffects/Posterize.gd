extends ImageEffect

var levels := 2.0
var dither := 0.0
var shader_inc := load("uid://bbliuetkqn3dm")
var shader: Shader


func _ready() -> void:
	shader = ShaderLoader.generate_texture_blit_shader(shader_inc)
	super()
	var sm := ShaderMaterial.new()
	sm.shader = ShaderLoader.generate_canvas_item_shader(shader_inc)
	preview.set_material(sm)


func commit_action(cel: Image, project := Global.current_project) -> void:
	var selection_tex: ImageTexture
	if selection_checkbox.button_pressed and project.has_selection:
		var selection := project.selection_map.return_cropped_copy(project, project.size)
		selection_tex = ImageTexture.create_from_image(selection)

	var params := {"colors": levels, "dither_intensity": dither, "selection": selection_tex}

	if !has_been_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)


func _on_LevelsSlider_value_changed(value: float) -> void:
	levels = value - 1.0
	update_preview()


func _on_DitherSlider_value_changed(value: float) -> void:
	dither = value
	update_preview()
