extends BaseTool


func draw_start(pos: Vector2i) -> void:
	super.draw_start(pos)
	for camera: CanvasCamera in get_tree().get_nodes_in_group("CanvasCameras"):
		camera.drag = true


func draw_move(pos: Vector2i) -> void:
	super.draw_move(pos)


func draw_end(pos: Vector2i) -> void:
	super.draw_end(pos)
	for camera: CanvasCamera in get_tree().get_nodes_in_group("CanvasCameras"):
		camera.drag = false
