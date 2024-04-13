extends ImageEffect

var shader := preload("res://src/Shaders/Effects/GradientMap.gdshader")


func _ready() -> void:
	super._ready()
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)


func commit_action(cel: Image, project := Global.current_project) -> void:
	var selection_tex: ImageTexture
	if selection_checkbox.button_pressed and project.has_selection:
		var selection := project.selection_map.return_cropped_copy(project.size)
		selection_tex = ImageTexture.create_from_image(selection)

	var params := {"selection": selection_tex, "gradient_map": $VBoxContainer/GradientEdit.texture}

	if !has_been_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)


func _on_GradientEdit_updated(_gradient: Gradient, _cc: bool) -> void:
	update_preview()
