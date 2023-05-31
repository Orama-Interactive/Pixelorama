extends ImageEffect

var red := true
var green := true
var blue := true
var alpha := false

var shader: Shader = preload("res://src/Shaders/Invert.gdshader")


func _ready() -> void:
	super._ready()
	var sm := ShaderMaterial.new()
	sm.shader = shader
	if preview:
		preview.set_material(sm)


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	var selection_tex: ImageTexture
	if selection_checkbox.button_pressed and project.has_selection:
		selection_tex = ImageTexture.create_from_image(project.selection_map)

	var params := {
		"red": red,
		"blue": blue,
		"green": green,
		"alpha": alpha,
		"selection": selection_tex,
		"affect_selection": selection_checkbox.button_pressed,
		"has_selection": project.has_selection
	}

	if !is_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)
		await gen.done


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
