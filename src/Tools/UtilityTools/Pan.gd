extends BaseTool

var _tool_active := false
var _last_position := Vector2.INF

func draw_start(pos: Vector2i) -> void:
	super.draw_start(pos)
	for camera: CanvasCamera in get_tree().get_nodes_in_group("CanvasCameras"):
		camera.drag = true
	_last_position = Global.canvas.current_pixel
	_tool_active = true


func _input(event: InputEvent) -> void:
	if _tool_active:
		if (
			Input.is_action_pressed(&"change_tool_mode") and event is InputEventMouseMotion
		):
			var new_rel = (
				Global.canvas.get_local_mouse_position()
				- Vector2(Global.current_project.size) / 2.0
			)
			var old_rel = _last_position - (Vector2(Global.current_project.size) / 2.0)
			var angle_delta := old_rel.angle_to(new_rel)
			for camera: CanvasCamera in get_tree().get_nodes_in_group("CanvasCameras"):
				camera.rotate_camera_radians(camera.camera_angle - angle_delta)
				get_viewport().set_input_as_handled()
		_last_position = Global.canvas.get_local_mouse_position()


func draw_move(pos: Vector2i) -> void:
	super.draw_move(pos)


func draw_end(pos: Vector2i) -> void:
	_tool_active = false
	super.draw_end(pos)
	for camera: CanvasCamera in get_tree().get_nodes_in_group("CanvasCameras"):
		camera.drag = false
