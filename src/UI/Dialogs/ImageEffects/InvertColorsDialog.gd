extends ImageEffect

var red := true
var green := true
var blue := true
var alpha := false

var shader := preload("res://src/Shaders/Effects/Invert.gdshader")


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

	var params := {
		"red": red, "blue": blue, "green": green, "alpha": alpha, "selection": selection_tex
	}

	if !has_been_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)


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
