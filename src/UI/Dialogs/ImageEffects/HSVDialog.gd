extends ImageEffect

var shader: Shader = preload("res://src/Shaders/HSV.shader")

var live_preview: bool = true
var confirmed: bool = false

onready var hue_slider = $VBoxContainer/HBoxContainer/Sliders/Hue
onready var sat_slider = $VBoxContainer/HBoxContainer/Sliders/Saturation
onready var val_slider = $VBoxContainer/HBoxContainer/Sliders/Value

onready var hue_spinbox = $VBoxContainer/HBoxContainer/TextBoxes/Hue
onready var sat_spinbox = $VBoxContainer/HBoxContainer/TextBoxes/Saturation
onready var val_spinbox = $VBoxContainer/HBoxContainer/TextBoxes/Value
onready var wait_apply_timer = $WaitApply
onready var wait_time_spinbox = $VBoxContainer/WaitSettings/WaitTime


func _about_to_show() -> void:
	reset()
	var sm := ShaderMaterial.new()
	sm.shader = shader
	preview.set_material(sm)
	._about_to_show()


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/AffectHBoxContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/AffectHBoxContainer/AffectOptionButton


func _confirmed() -> void:
	confirmed = true
	._confirmed()
	reset()


func commit_action(cel: Image, project: Project = Global.current_project) -> void:
	var selection: Image = project.bitmap_to_image(project.selection_bitmap, false)
	var selection_tex := ImageTexture.new()
	selection_tex.create_from_image(selection)

	if !confirmed:
		preview.material.set_shader_param("hue_shift_amount", hue_slider.value / 360)
		preview.material.set_shader_param("sat_shift_amount", sat_slider.value / 100)
		preview.material.set_shader_param("val_shift_amount", val_slider.value / 100)
		preview.material.set_shader_param("selection", selection_tex)
		preview.material.set_shader_param("affect_selection", selection_checkbox.pressed)
		preview.material.set_shader_param("has_selection", project.has_selection)
	else:
		var params := {
			"hue_shift_amount": hue_slider.value / 360,
			"sat_shift_amount": sat_slider.value / 100,
			"val_shift_amount": val_slider.value / 100,
			"selection": selection_tex,
			"affect_selection": selection_checkbox.pressed,
			"has_selection": project.has_selection
		}
		var gen := ShaderImageEffect.new()
		gen.generate_image(cel, shader, params, project.size)
		yield(gen, "done")


func reset() -> void:
	disconnect_signals()
	wait_apply_timer.wait_time = wait_time_spinbox.value / 1000.0
	hue_slider.value = 0
	sat_slider.value = 0
	val_slider.value = 0
	hue_spinbox.value = 0
	sat_spinbox.value = 0
	val_spinbox.value = 0
	reconnect_signals()
	confirmed = false


func disconnect_signals() -> void:
	hue_slider.disconnect("value_changed", self, "_on_Hue_value_changed")
	sat_slider.disconnect("value_changed", self, "_on_Saturation_value_changed")
	val_slider.disconnect("value_changed", self, "_on_Value_value_changed")
	hue_spinbox.disconnect("value_changed", self, "_on_Hue_value_changed")
	sat_spinbox.disconnect("value_changed", self, "_on_Saturation_value_changed")
	val_spinbox.disconnect("value_changed", self, "_on_Value_value_changed")


func reconnect_signals() -> void:
	hue_slider.connect("value_changed", self, "_on_Hue_value_changed")
	sat_slider.connect("value_changed", self, "_on_Saturation_value_changed")
	val_slider.connect("value_changed", self, "_on_Value_value_changed")
	hue_spinbox.connect("value_changed", self, "_on_Hue_value_changed")
	sat_spinbox.connect("value_changed", self, "_on_Saturation_value_changed")
	val_spinbox.connect("value_changed", self, "_on_Value_value_changed")


func _on_Hue_value_changed(value: float) -> void:
	hue_spinbox.value = value
	hue_slider.value = value
	if live_preview:
		update_preview()
	else:
		wait_apply_timer.start()


func _on_Saturation_value_changed(value: float) -> void:
	sat_spinbox.value = value
	sat_slider.value = value
	if live_preview:
		update_preview()
	else:
		wait_apply_timer.start()


func _on_Value_value_changed(value: float) -> void:
	val_spinbox.value = value
	val_slider.value = value
	if live_preview:
		update_preview()
	else:
		wait_apply_timer.start()


func _on_WaitApply_timeout() -> void:
	update_preview()


func _on_WaitTime_value_changed(value: float) -> void:
	wait_apply_timer.wait_time = value / 1000.0


func _on_LiveCheckbox_toggled(button_pressed: bool) -> void:
	live_preview = button_pressed
	wait_time_spinbox.editable = !live_preview
	wait_time_spinbox.get_parent().visible = !live_preview
