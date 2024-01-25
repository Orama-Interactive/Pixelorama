extends Node2D


func _input(event: InputEvent) -> void:
	if event is InputEventMouse or event is InputEventKey:
		queue_redraw()


func _draw() -> void:
	# Draw rectangle to indicate the pixel currently being hovered on
	if Global.can_draw:
		Tools.draw_indicator()
