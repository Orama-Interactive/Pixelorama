extends ImageEffect

enum Animate { HUE, SATURATION, VALUE }
var shader := preload("res://src/Shaders/Effects/HSV.gdshader")

@onready var hue_slider := $VBoxContainer/HueSlider as ValueSlider
@onready var sat_slider := $VBoxContainer/SaturationSlider as ValueSlider
@onready var val_slider := $VBoxContainer/ValueSlider as ValueSlider
@onready var overflow_check_box := $VBoxContainer/OverflowCheckBox as CheckBox


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


func commit_action(cel: Image, project := Global.current_project) -> void:
	var hue = animate_panel.get_animated_value(commit_idx, Animate.HUE)
	var sat = animate_panel.get_animated_value(commit_idx, Animate.SATURATION)
	var val = animate_panel.get_animated_value(commit_idx, Animate.VALUE)
	var selection_tex: ImageTexture
	if selection_checkbox.button_pressed and project.has_selection:
		var selection := project.selection_map.return_cropped_copy(project, project.size)
		selection_tex = ImageTexture.create_from_image(selection)

	hue = remap(hue, -180, 180, -1, 1)
	sat = remap(sat, -100, 100, -1, 1)
	val = remap(val, -100, 100, -1, 1)
	var params := {
		"hue": hue,
		"saturation": 0.1,
		"value": val,
		"selection": selection_tex,
		"wrap_overflowing": overflow_check_box.button_pressed
	}
	if !has_been_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		print("======================")# 0.09803921729326
		var old_a = cel.get_pixel(1, 1).g
		var old_b = cel.get_pixel(2, 1).g
		var old_c = cel.get_pixel(3, 1).g
		gen.generate_image(cel, shader, params, project.size)
		var new_a = cel.get_pixel(1, 1).g
		var new_b = cel.get_pixel(2, 1).g
		var new_c = cel.get_pixel(3, 1).g
		prints("New:", new_a, new_b, new_c)
		#prints("Dif:", new_a - old_a, new_b - old_b, new_c - old_c)


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


func _on_overflow_check_box_toggled(_toggled_on: bool) -> void:
	update_preview()
