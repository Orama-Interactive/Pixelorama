extends ImageEffect

var red := true
var green := true
var blue := true
var alpha := false

var shader: Shader = preload("res://src/Shaders/Desaturate.shader")


func _ready() -> void:
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	var selection_tex := ImageTexture.new()
	if selection_checkbox.pressed and project.has_selection:
		selection_tex.create_from_image(project.selection_map, 0)

	var params := {
		"red": red,
		"blue": blue,
		"green": green,
		"alpha": alpha,
		"selection": selection_tex,
		"affect_selection": selection_checkbox.pressed,
		"has_selection": project.has_selection
	}
	if !confirmed:
		for param in params:
			preview.material.set_shader_param(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)
		yield(gen, "done")


func _on_RButton_toggled(button_pressed: bool) -> void:
	red = button_pressed
	update_preview()


func _on_GButton_toggled(button_pressed: bool) -> void:
	green = button_pressed
	update_preview()


func _on_BButton_toggled(button_pressed: bool) -> void:
	blue = button_pressed
	update_preview()


func _on_AButton_toggled(button_pressed: bool) -> void:
	alpha = button_pressed
	update_preview()
