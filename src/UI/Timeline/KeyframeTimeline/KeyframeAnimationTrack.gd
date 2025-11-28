class_name KeyframeAnimationTrack
extends Control

var is_property := false
var popup_menu := PopupMenu.new()


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup_menu.add_item("Insert keyframe")
	add_child(popup_menu)


func _gui_input(event: InputEvent) -> void:
	if not is_property:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var rect := Rect2()
			rect.position = event.global_position
			rect.size = Vector2(100, 0)
			popup_menu.popup(rect)
