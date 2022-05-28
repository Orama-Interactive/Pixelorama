extends AcceptDialog

onready var hslider: HSlider = $VBoxContainer/HBoxContainer/HSlider
onready var spinbox: SpinBox = $VBoxContainer/HBoxContainer/SpinBox
onready var fullscreen_warning: Label = $VBoxContainer/FullscreenWarning


func _on_WindowOpacityDialog_about_to_show() -> void:
	OS.window_per_pixel_transparency_enabled = true
	hslider.editable = !OS.window_fullscreen
	spinbox.editable = hslider.editable
	fullscreen_warning.visible = !spinbox.editable


func _on_value_changed(value: float) -> void:
	set_window_opacity(value)


func set_window_opacity(value: float) -> void:
	if OS.window_fullscreen:
		value = 100.0
	hslider.value = value
	spinbox.value = value

	value = value / 100.0
	for container in Global.control.ui._panel_container.get_children():
		container.self_modulate.a = value
	Global.transparent_checker.transparency(value)


func _on_WindowOpacityDialog_popup_hide() -> void:
	Global.dialog_open(false)
