extends AcceptDialog

var main_canvas := Global.control.find_child("Main Canvas", true, false)

@onready var slider := $VBoxContainer/ValueSlider as ValueSlider
@onready var fullscreen_warning := $VBoxContainer/FullscreenWarning as Label


func _ready() -> void:
	if main_canvas is FloatingWindow:  # If it's shifted to a window then get the content.
		main_canvas = main_canvas.window_content
	await get_tree().process_frame
	Global.control.main_ui.sort_children.connect(_recalculate_opacity)


func _on_WindowOpacityDialog_about_to_show() -> void:
	var canvas_window = main_canvas.get_window()
	canvas_window.transparent = true
	canvas_window.transparent_bg = true
	slider.editable = not is_fullscreen()
	fullscreen_warning.visible = not slider.editable


func _recalculate_opacity() -> void:
	set_window_opacity(slider.value)


func set_window_opacity(value: float) -> void:
	if is_fullscreen():
		value = 100.0
		slider.value = value
	value = value / 100.0
	# Find the TabContainer that has the Main Canvas panel.
	for container: Control in Global.control.main_ui._panel_container.get_children():
		if container is TabContainer:
			var center := container.get_rect().get_center()
			if main_canvas.get_rect().has_point(center):
				if main_canvas.get_window() != get_tree().root:
					# In case we converted to window while trransparency was active.
					container.self_modulate.a = 1.0
				else:
					container.self_modulate.a = value
	Global.transparent_checker.update_transparency(value)


func _on_visibility_changed() -> void:
	Global.dialog_open(false)


func is_fullscreen() -> bool:
	return (
		(get_parent().get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN)
		or (get_parent().get_window().mode == Window.MODE_FULLSCREEN)
	)
