extends ImageEffect

enum Animate { HUE, SATURATION, VALUE }
var shader: Shader = preload("res://src/Shaders/HSV.gdshader")

@onready var hue_slider := $VBoxContainer/HueSlider as ValueSlider
@onready var sat_slider := $VBoxContainer/SaturationSlider as ValueSlider
@onready var val_slider := $VBoxContainer/ValueSlider as ValueSlider


func _ready() -> void:
	super._ready()
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)
	# set as in enum
	animate_panel.add_float_property("Hue", hue_slider)
	animate_panel.add_float_property("Saturation", sat_slider)
	animate_panel.add_float_property("Value", val_slider)


func _about_to_popup() -> void:
	_reset()
	super._about_to_popup()


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	var hue = animate_panel.get_animated_value(commit_idx, Animate.HUE) / 360
	var sat = animate_panel.get_animated_value(commit_idx, Animate.SATURATION) / 100
	var val = animate_panel.get_animated_value(commit_idx, Animate.VALUE) / 100
	var selection_tex := ImageTexture.new()
	if selection_checkbox.button_pressed and project.has_selection:
		selection_tex.create_from_image(project.selection_map) #,0

	var params := {"hue_shift": hue, "sat_shift": sat, "val_shift": val, "selection": selection_tex}
	if !has_been_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)
		await gen.done


func _reset() -> void:
	hue_slider.value = 0
	sat_slider.value = 0
	val_slider.value = 0
	has_been_confirmed = false


func _on_HueSlider_value_changed(_value: float) -> void:
	update_preview()


func _on_SaturationSlider_value_changed(_value: float) -> void:
	update_preview()


func _on_ValueSlider_value_changed(_value: float) -> void:
	update_preview()
