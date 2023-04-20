extends ImageEffect

enum Animate { HUE, SATURATION, VALUE }
var shader: Shader = preload("res://src/Shaders/HSV.shader")

onready var hue_slider := $VBoxContainer/HueSlider as ValueSlider
onready var sat_slider := $VBoxContainer/SaturationSlider as ValueSlider
onready var val_slider := $VBoxContainer/ValueSlider as ValueSlider


func _ready() -> void:
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)


func _about_to_show() -> void:
	_reset()
	._about_to_show()


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton
	animate_options_container = $VBoxContainer/AnimationOptions
	animate_menu = $"%AnimateMenu".get_popup()
	initial_button = $"%InitalButton"


func set_animate_menu(_elements) -> void:
	# set as in enum
	animate_menu.add_check_item("Hue", Animate.HUE)
	animate_menu.add_check_item("Saturation", Animate.SATURATION)
	animate_menu.add_check_item("Value", Animate.VALUE)
	.set_animate_menu(Animate.size())


func set_initial_values() -> void:
	initial_values[Animate.HUE] = hue_slider.value
	initial_values[Animate.SATURATION] = sat_slider.value
	initial_values[Animate.VALUE] = val_slider.value


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	.commit_action(cel, project)
	var hue = get_animated_value(project, hue_slider.value / 360, Animate.HUE)
	var sat = get_animated_value(project, sat_slider.value / 360, Animate.SATURATION)
	var val = get_animated_value(project, val_slider.value / 360, Animate.VALUE)
	var selection_tex := ImageTexture.new()
	if selection_checkbox.pressed and project.has_selection:
		selection_tex.create_from_image(project.selection_map, 0)

	var params := {"hue_shift": hue, "sat_shift": sat, "val_shift": val, "selection": selection_tex}
	if !confirmed:
		for param in params:
			preview.material.set_shader_param(param, params[param])
	else:
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)
		yield(gen, "done")


func _reset() -> void:
	hue_slider.value = 0
	sat_slider.value = 0
	val_slider.value = 0
	confirmed = false


func _on_HueSlider_value_changed(_value: float) -> void:
	update_preview()


func _on_SaturationSlider_value_changed(_value: float) -> void:
	update_preview()


func _on_ValueSlider_value_changed(_value: float) -> void:
	update_preview()
