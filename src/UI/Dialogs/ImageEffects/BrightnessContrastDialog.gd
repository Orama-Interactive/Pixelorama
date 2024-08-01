extends ImageEffect

enum Animate { BRIGHTNESS, CONTRAST, SATURATION, RED, GREEN, BLUE, TINT_EFFECT_FACTOR }

var shader := preload("res://src/Shaders/Effects/BrightnessContrast.gdshader")


func _ready() -> void:
	super._ready()
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)
	animate_panel.add_float_property("Brightness", $VBoxContainer/BrightnessSlider)
	animate_panel.add_float_property("Contrast", $VBoxContainer/ContrastSlider)
	animate_panel.add_float_property("Saturation", $VBoxContainer/SaturationSlider)
	animate_panel.add_float_property("Red", $VBoxContainer/RedSlider)
	animate_panel.add_float_property("Green", $VBoxContainer/GreenSlider)
	animate_panel.add_float_property("Blue", $VBoxContainer/BlueSlider)
	animate_panel.add_float_property("Tint effect factor", $VBoxContainer/TintSlider)


func commit_action(cel: Image, project := Global.current_project) -> void:
	var brightness := animate_panel.get_animated_value(commit_idx, Animate.BRIGHTNESS) / 100.0
	var contrast := animate_panel.get_animated_value(commit_idx, Animate.CONTRAST) / 100.0
	var saturation := animate_panel.get_animated_value(commit_idx, Animate.SATURATION) / 100.0
	var red := animate_panel.get_animated_value(commit_idx, Animate.RED) / 100.0
	var green := animate_panel.get_animated_value(commit_idx, Animate.GREEN) / 100.0
	var blue := animate_panel.get_animated_value(commit_idx, Animate.BLUE) / 100.0
	var tint_color: Color = $VBoxContainer/TintColorContainer/TintColor.color
	var tint_effect_factor := (
		animate_panel.get_animated_value(commit_idx, Animate.TINT_EFFECT_FACTOR) / 100.0
	)
	var selection_tex: ImageTexture
	if selection_checkbox.button_pressed and project.has_selection:
		var selection := project.selection_map.return_cropped_copy(project.size)
		selection_tex = ImageTexture.create_from_image(selection)

	var params := {
		"brightness": brightness,
		"contrast": contrast,
		"saturation": saturation,
		"red_value": red,
		"blue_value": blue,
		"green_value": green,
		"tint_color": tint_color,
		"tint_effect_factor": tint_effect_factor,
		"selection": selection_tex
	}

	if !has_been_confirmed:
		for param in params:
			preview.material.set_shader_parameter(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)


func _on_brightness_slider_value_changed(_value: float) -> void:
	update_preview()


func _on_contrast_slider_value_changed(_value: float) -> void:
	update_preview()


func _on_saturation_slider_value_changed(_value: float) -> void:
	update_preview()


func _on_red_slider_value_changed(_value: float) -> void:
	update_preview()


func _on_green_slider_value_changed(_value: float) -> void:
	update_preview()


func _on_blue_slider_value_changed(_value: float) -> void:
	update_preview()


func _on_tint_color_color_changed(_color: Color) -> void:
	update_preview()


func _on_tint_slider_value_changed(_value: float) -> void:
	update_preview()
