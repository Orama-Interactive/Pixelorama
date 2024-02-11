extends AcceptDialog

@onready var slider := $VBoxContainer/ValueSlider as ValueSlider
@onready var fullscreen_warning := $VBoxContainer/FullscreenWarning as Label
@onready var main_canvas := Global.control.find_child("Main Canvas") as Control


func _ready() -> void:
	await get_tree().process_frame
	Global.control.main_ui.sort_children.connect(_recalculate_opacity)


func _on_WindowOpacityDialog_about_to_show() -> void:
	get_tree().root.transparent = true
	get_tree().root.transparent_bg = true
	slider.editable = not is_fullscreen()
	fullscreen_warning.visible = not slider.editable


func _recalculate_opacity() -> void:
	set_window_opacity(slider.value)


func set_window_opacity(value: float) -> void:
	if is_fullscreen():
		value = 100.0
		slider.value = value
	value = value / 100.0
	# Find the TabContainer that has the Main Canvas panel
	for container: Control in Global.control.main_ui._panel_container.get_children():
		if container is TabContainer:
			var center := container.get_rect().get_center()
			if main_canvas.get_rect().has_point(center):
				container.self_modulate.a = value
	Global.transparent_checker.update_transparency(value)


func _on_visibility_changed() -> void:
	Global.dialog_open(false)


func is_fullscreen() -> bool:
	return (
		(get_parent().get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN)
		or (get_parent().get_window().mode == Window.MODE_FULLSCREEN)
	)
