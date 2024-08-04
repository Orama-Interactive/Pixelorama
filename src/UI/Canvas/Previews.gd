extends Node2D


func _ready() -> void:
	Global.camera.zoom_changed.connect(_update_on_zoom)


func _input(event: InputEvent) -> void:
	if event is InputEventMouse or event is InputEventKey:
		queue_redraw()


func _draw() -> void:
	if Global.can_draw:
		Tools.draw_preview()


func _update_on_zoom() -> void:
	material.set_shader_parameter("width", 1.0 / Global.camera.zoom.x)
