extends ImageEffect


onready var hue_slider = $VBoxContainer/HBoxContainer/Sliders/Hue
onready var sat_slider = $VBoxContainer/HBoxContainer/Sliders/Saturation
onready var val_slider = $VBoxContainer/HBoxContainer/Sliders/Value

onready var hue_spinbox = $VBoxContainer/HBoxContainer/TextBoxes/Hue
onready var sat_spinbox = $VBoxContainer/HBoxContainer/TextBoxes/Saturation
onready var val_spinbox = $VBoxContainer/HBoxContainer/TextBoxes/Value

var shaderPath : String = "res://src/Shaders/HSV.shader"

var confirmed: bool = false
func _about_to_show():
	reset()
	var sm : ShaderMaterial = ShaderMaterial.new()
	sm.shader = load(shaderPath)
	preview.set_material(sm)
	._about_to_show()


func set_nodes() -> void:
	preview = $VBoxContainer/Preview
	selection_checkbox = $VBoxContainer/AffectHBoxContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/AffectHBoxContainer/AffectOptionButton


func _confirmed() -> void:
	confirmed = true
	._confirmed()
	reset()


func commit_action(_cel : Image, _project : Project = Global.current_project) -> void:
	var selection = _project.bitmap_to_image(_project.selection_bitmap, false)
	var selection_tex = ImageTexture.new()
	selection_tex.create_from_image(selection)

	if !confirmed:
		preview.material.set_shader_param("hue_shift_amount", hue_slider.value /360)
		preview.material.set_shader_param("sat_shift_amount", sat_slider.value /100)
		preview.material.set_shader_param("val_shift_amount", val_slider.value /100)
		preview.material.set_shader_param("selection", selection_tex)
		preview.material.set_shader_param("affect_selection", selection_checkbox.pressed)
		preview.material.set_shader_param("has_selection", _project.has_selection)
	else:
		var params = {
			"hue_shift_amount": hue_slider.value /360,
			"sat_shift_amount": sat_slider.value /100,
			"val_shift_amount": val_slider.value /100,
			"selection": selection_tex,
			"affect_selection": selection_checkbox.pressed,
			"has_selection": _project.has_selection
		}
		var gen: ShaderImageEffect = ShaderImageEffect.new()
		gen.generate_image(_cel, shaderPath, params, _project.size)
		yield(gen, "done")


func reset() -> void:
	disconnect_signals()
	hue_slider.value = 0
	sat_slider.value = 0
	val_slider.value = 0
	hue_spinbox.value = 0
	sat_spinbox.value = 0
	val_spinbox.value = 0
	reconnect_signals()
	confirmed = false


func disconnect_signals() -> void:
	hue_slider.disconnect("value_changed",self,"_on_Hue_value_changed")
	sat_slider.disconnect("value_changed",self,"_on_Saturation_value_changed")
	val_slider.disconnect("value_changed",self,"_on_Value_value_changed")
	hue_spinbox.disconnect("value_changed",self,"_on_Hue_value_changed")
	sat_spinbox.disconnect("value_changed",self,"_on_Saturation_value_changed")
	val_spinbox.disconnect("value_changed",self,"_on_Value_value_changed")


func reconnect_signals() -> void:
	hue_slider.connect("value_changed",self,"_on_Hue_value_changed")
	sat_slider.connect("value_changed",self,"_on_Saturation_value_changed")
	val_slider.connect("value_changed",self,"_on_Value_value_changed")
	hue_spinbox.connect("value_changed",self,"_on_Hue_value_changed")
	sat_spinbox.connect("value_changed",self,"_on_Saturation_value_changed")
	val_spinbox.connect("value_changed",self,"_on_Value_value_changed")


func _on_Hue_value_changed(value : float) -> void:
	hue_spinbox.value = value
	hue_slider.value = value
	update_preview()


func _on_Saturation_value_changed(value : float) -> void:
	sat_spinbox.value = value
	sat_slider.value = value
	update_preview()


func _on_Value_value_changed(value : float) -> void:
	val_spinbox.value = value
	val_slider.value = value
	update_preview()
