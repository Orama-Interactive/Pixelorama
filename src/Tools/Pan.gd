extends BaseTool


func draw_start(position: Vector2) -> void:
	.draw_start(position)
	Global.camera.drag = true
	Global.camera2.drag = true


func draw_move(position: Vector2) -> void:
	.draw_move(position)


func draw_end(position: Vector2) -> void:
	.draw_end(position)
	Global.camera.drag = false
	Global.camera2.drag = false
