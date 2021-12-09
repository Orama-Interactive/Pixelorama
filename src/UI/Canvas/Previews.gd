extends Node2D


func _input(event: InputEvent) -> void:
	if Global.has_focus:
		if (
			event is InputEventMouse
			or event.is_action("shift")
			or event.is_action("ctrl")
			or event.is_action("alt")
		):
			update()


func _draw() -> void:
	if Global.has_focus and Global.can_draw:
		Tools.draw_preview()
