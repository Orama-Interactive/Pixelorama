extends "res://src/Tools/Base.gd"

func draw_start(_position : Vector2) -> void:
	Global.camera.drag = true
	Global.camera2.drag = true


func draw_move(_position : Vector2) -> void:
	pass


func draw_end(_position : Vector2) -> void:
	Global.camera.drag = false
	Global.camera2.drag = false
