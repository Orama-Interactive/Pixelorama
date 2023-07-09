extends AcceptDialog

@onready var slider: ValueSlider = $VBoxContainer/ValueSlider
@onready var fullscreen_warning: Label = $VBoxContainer/FullscreenWarning
@onready var main_canvas = Global.control.find_child("Main Canvas")


func _ready() -> void:
	await get_tree().process_frame
	Global.control.ui.sort_children.connect(_recalculate_opacity)


func _on_WindowOpacityDialog_about_to_show() -> void:
	get_tree().root.transparent = true
	get_tree().root.transparent_bg = true
	slider.editable = !(
		(get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN)
		or (get_window().mode == Window.MODE_FULLSCREEN)
	)
	fullscreen_warning.visible = !slider.editable


func _recalculate_opacity() -> void:
	set_window_opacity(slider.value)


func set_window_opacity(value: float) -> void:
	if ((get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN) or (get_window().mode == Window.MODE_FULLSCREEN)):
		value = 100.0
		slider.value = value

	value = value / 100.0
	for container in Global.control.ui._panel_container.get_children():
		if container is TabContainer:
			var point = container.get_rect().position + (container.get_rect().size / 2.0)
			if main_canvas.get_rect().has_point(point):
				container.self_modulate.a = value
			else:
				container.self_modulate.a = 1.0
	Global.transparent_checker.update_transparency(value)


func _on_visibility_changed() -> void:
	Global.dialog_open(false)
