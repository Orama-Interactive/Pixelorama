extends ImageEffect

var shader := load("res://src/Shaders/Effects/FlatToIsometric.gdshader")

@onready var origin: ValueSlider = $VBoxContainer/Origin
@onready var iso_step: ValueSlider = $VBoxContainer/IsoStep
@onready var deadzone: ValueSlider = $VBoxContainer/Deadzone


func _ready() -> void:
	super._ready()
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)


func _on_about_to_popup() -> void:
	origin.max_value = Global.current_project.size.x
	@warning_ignore("integer_division")
	origin.value = Global.current_project.size.x / 2


func commit_action(cel: Image, project := Global.current_project) -> void:
	var selection_tex: ImageTexture
	if selection_checkbox.button_pressed and project.has_selection:
		var selection := project.selection_map.return_cropped_copy(project, project.size)
		selection_tex = ImageTexture.create_from_image(selection)
	var params := {
		"origin": origin.value,
		"iso_step": iso_step.value,
		"deadzone": deadzone.value,
		"selection": selection_tex
	}

	if !has_been_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)


func _on_origin_value_changed(_value: float) -> void:
	update_preview()


func _on_iso_step_value_changed(_value: float) -> void:
	update_preview()


func _on_deadzone_value_changed(_value: float) -> void:
	update_preview()
