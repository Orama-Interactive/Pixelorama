class_name KeyframeButton
extends TextureButton

signal updated_position

const KEYFRAME_ICON := preload("uid://yhha3l44svgs")
const KEYFRAME_SELECTED_ICON := preload("uid://dtx6hygsgoifb")

var keyframe_id := 0
var dict: Dictionary
var param_name: String
var frame_index: int
var is_dragged := false
var drag_mouse_start_pos := 0.0
var drag_pos := 0.0


func _init() -> void:
	add_to_group(&"KeyframeButtons")
	toggle_mode = true
	texture_normal = KEYFRAME_ICON
	texture_pressed = KEYFRAME_SELECTED_ICON
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	var selected_keyframe_buttons := KeyframeTimeline.get_selected_keyframe_buttons()
	if not self in selected_keyframe_buttons:
		return
	var parent := get_parent() as Control
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragged = true
			drag_mouse_start_pos = parent.get_local_mouse_position().x
			for keyframe_button in selected_keyframe_buttons:
				keyframe_button.drag_pos = keyframe_button.position.x
		else:
			if is_dragged:
				is_dragged = false
				updated_position.emit()
	if event is InputEventMouseMotion and is_dragged:
		var mouse_pos: float = parent.get_local_mouse_position().x
		var delta := mouse_pos - drag_mouse_start_pos
		for keyframe_button in selected_keyframe_buttons:
			var new_pos := keyframe_button.drag_pos + delta
			keyframe_button.position.x = snappedi(new_pos, KeyframeTimeline.frame_ui_size)
			if keyframe_button.position.x < 0:
				keyframe_button.position.x = 0
