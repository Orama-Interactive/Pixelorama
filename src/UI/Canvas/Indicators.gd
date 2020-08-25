extends Node2D


func _input(event : InputEvent) -> void:
	if Global.has_focus and event is InputEventMouseMotion:
		update()


func _draw() -> void:
	# Draw rectangle to indicate the pixel currently being hovered on
	if Global.has_focus and Global.can_draw:
		Tools.draw_indicator()
