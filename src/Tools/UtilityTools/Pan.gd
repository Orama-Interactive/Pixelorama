extends BaseTool

var _tool_active := false

func draw_start(pos: Vector2i) -> void:
	super.draw_start(pos)
	for camera: CanvasCamera in get_tree().get_nodes_in_group("CanvasCameras"):
		camera.drag = true
	_tool_active = true


func _input(event: InputEvent) -> void:
	if (
		_tool_active
		and Input.is_action_pressed("change_tool_mode")
		and event is InputEventMouseMotion
	):
		for camera: CanvasCamera in get_tree().get_nodes_in_group("CanvasCameras"):
			camera.rotate_camera(event.relative.x)


func draw_move(pos: Vector2i) -> void:
	super.draw_move(pos)


func draw_end(pos: Vector2i) -> void:
	_tool_active = false
	super.draw_end(pos)
	for camera: CanvasCamera in get_tree().get_nodes_in_group("CanvasCameras"):
		camera.drag = false
