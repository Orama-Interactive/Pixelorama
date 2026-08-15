extends ImageEffect

var red := true
var green := true
var blue := true
var alpha := false

var shader_inc := load("uid://l1rt2q7jthsm")
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
