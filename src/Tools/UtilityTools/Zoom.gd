extends BaseTool

enum ZoomMode { ZOOM_OUT, ZOOM_IN }

var _relative: Vector2
var _prev_mode := ZoomMode.ZOOM_OUT
var _zoom_mode := ZoomMode.ZOOM_OUT


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_relative = event.relative

	if event.is_action_pressed("change_tool_mode"):
		_prev_mode = $ModeOptions.selected
	if event.is_action("change_tool_mode"):
		$ModeOptions.selected = _prev_mode ^ 1
		_zoom_mode = $ModeOptions.selected
	if event.is_action_released("change_tool_mode"):
		$ModeOptions.selected = _prev_mode
		_zoom_mode = $ModeOptions.selected


func _on_ModeOptions_item_selected(id: ZoomMode) -> void:
	_zoom_mode = id
	update_config()
	save_config()


func _on_FitToFrame_pressed() -> void:
	for camera: CanvasCamera in get_tree().get_nodes_in_group("CanvasCameras"):
		camera.fit_to_frame(Global.current_project.size)


func _on_100_pressed() -> void:
	for camera: CanvasCamera in get_tree().get_nodes_in_group("CanvasCameras"):
		camera.zoom_100()


func get_config() -> Dictionary:
	return {"zoom_mode": _zoom_mode}


func set_config(config: Dictionary) -> void:
	_zoom_mode = config.get("zoom_mode", _zoom_mode)


func update_config() -> void:
	$ModeOptions.selected = _zoom_mode


func draw_start(pos: Vector2i) -> void:
	super.draw_start(pos)
	var mouse_pos := get_global_mouse_position()
	for camera: CanvasCamera in get_tree().get_nodes_in_group("CanvasCameras"):
		var viewport_container := camera.get_viewport().get_parent() as SubViewportContainer
		var viewport_rect := Rect2(viewport_container.global_position, viewport_container.size)
		if viewport_rect.has_point(mouse_pos):
			camera.zoom_camera(_zoom_mode * 2 - 1)


func draw_move(pos: Vector2i) -> void:
	super.draw_move(pos)
	var mouse_pos := get_global_mouse_position()
	for camera: CanvasCamera in get_tree().get_nodes_in_group("CanvasCameras"):
		var viewport_container := camera.get_viewport().get_parent() as SubViewportContainer
		var viewport_rect := Rect2(viewport_container.global_position, viewport_container.size)
		if viewport_rect.has_point(mouse_pos):
			camera.zoom_camera(-_relative.x / 3)


func draw_end(pos: Vector2i) -> void:
	super.draw_end(pos)
