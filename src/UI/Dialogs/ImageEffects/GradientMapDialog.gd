extends ImageEffect

var shader: Shader = preload("res://src/Shaders/GradientMap.gdshader")
var confirmed := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func _about_to_show() -> void:
	confirmed = false
	._about_to_show()


func _confirmed() -> void:
	confirmed = true
	._confirmed()


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	var selection_tex := ImageTexture.new()
	if selection_checkbox.pressed and project.has_selection:
		var selection: Image = project.bitmap_to_image(project.selection_bitmap)
		selection_tex.create_from_image(selection, 0)

	var params := {"selection": selection_tex, "map": $VBoxContainer/GradientEdit.texture}

	if !confirmed:
		preview.material.shader = shader
		for param in params:
			preview.material.set_shader_param(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)
		yield(gen, "done")


func _on_GradientEdit_updated(_gradient, _cc) -> void:
	update_preview()
