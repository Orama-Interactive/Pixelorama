extends Node2D


func _input(event: InputEvent) -> void:
	if Global.has_focus:
		if event is InputEventMouse or event is InputEventKey:
			queue_redraw()


func _draw() -> void:
	if Global.has_focus and Global.can_draw:
		Tools.draw_preview()
