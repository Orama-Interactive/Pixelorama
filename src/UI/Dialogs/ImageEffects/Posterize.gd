extends ImageEffect

var shader: Shader = preload("res://src/Shaders/Posterize.gdshader")
var levels := 2.0
var dither := 0.0


func _ready() -> void:
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	var selection_tex := ImageTexture.new()
	if selection_checkbox.pressed and project.has_selection:
		selection_tex.create_from_image(project.selection_map.return_cropped_copy(project.size), 0)

	var params := {"colors": levels, "dither": dither, "selection": selection_tex}

	if !confirmed:
		for param in params:
			preview.material.set_shader_param(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)


func _on_LevelsSlider_value_changed(value: float) -> void:
	levels = value - 1.0
	update_preview()


func _on_DitherSlider_value_changed(value: float) -> void:
	dither = value
	update_preview()
