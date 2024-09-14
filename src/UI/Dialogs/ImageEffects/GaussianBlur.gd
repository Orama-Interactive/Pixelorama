extends ImageEffect

var blur_type := 0
var blur_amount := 16
var blur_radius := 1.0
var blur_direction := Vector2.ONE
var shader := preload("res://src/Shaders/Effects/GaussianBlur.gdshader")


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
		"blur_type": blur_type,
		"blur_amount": blur_amount,
		"blur_radius": blur_radius,
		"blur_direction": blur_direction,
		"selection": selection_tex
	}
	if !has_been_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)


func _on_blur_type_item_selected(index: int) -> void:
	blur_type = index
	update_preview()


func _on_blur_amount_value_changed(value: float) -> void:
	blur_amount = value
	update_preview()


func _on_blur_radius_value_changed(value: float) -> void:
	blur_radius = value
	update_preview()


func _on_blur_direction_value_changed(value: Vector2) -> void:
	blur_direction = value
	update_preview()
