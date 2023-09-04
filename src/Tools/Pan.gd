extends BaseTool


func draw_start(pos: Vector2i) -> void:
	super.draw_start(pos)
	Global.camera.drag = true
	Global.camera2.drag = true


func draw_move(pos: Vector2i) -> void:
	super.draw_move(pos)


func draw_end(pos: Vector2i) -> void:
	super.draw_end(pos)
	Global.camera.drag = false
	Global.camera2.drag = false
