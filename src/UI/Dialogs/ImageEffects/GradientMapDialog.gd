extends ImageEffect

var shader: Shader = preload("res://src/Shaders/GradientMap.gdshader")


func _ready() -> void:
	var sm := ShaderMaterial.new()
	sm.gdshader = shader
	preview.set_material(sm)


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	var selection_tex := ImageTexture.new()
	if selection_checkbox.pressed and project.has_selection:
		selection_tex.create_from_image(project.selection_map) #,0

	var params := {"selection": selection_tex, "map": $VBoxContainer/GradientEdit.texture}

	if !has_been_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)
		await gen.done


func _on_GradientEdit_updated(_gradient, _cc) -> void:
	update_preview()
