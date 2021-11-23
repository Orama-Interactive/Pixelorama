extends AcceptDialog

onready var hslider: HSlider = $HBoxContainer2/HSlider
onready var spinbox: SpinBox = $HBoxContainer2/SpinBox
onready var alternate_transparent_background: ColorRect = Global.control.alternate_transparent_background


func _on_WindowOpacityDialog_about_to_show() -> void:
	hslider.editable = !OS.window_fullscreen
	spinbox.editable = hslider.editable


func _on_value_changed(value: float) -> void:
	if OS.window_fullscreen:
		value = 100.0
	hslider.value = value
	spinbox.value = value

	value = value / 100.0
	alternate_transparent_background.visible = value < 1.0

	Global.default_clear_color.a = value
	alternate_transparent_background.color = Global.default_clear_color
	Global.transparent_checker.transparency(value)


func _on_WindowOpacityDialog_popup_hide() -> void:
	Global.dialog_open(false)
