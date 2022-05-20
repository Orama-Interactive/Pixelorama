extends BaseTool

var _relative: Vector2
var _prev_mode := 0
var _zoom_mode := 0


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


func _on_ModeOptions_item_selected(id: int) -> void:
	_zoom_mode = id
	update_config()
	save_config()


func _on_FitToFrame_pressed() -> void:
	Global.camera.fit_to_frame(Global.current_project.size)


func _on_100_pressed() -> void:
	Global.camera.zoom_100()


func get_config() -> Dictionary:
	return {
		"zoom_mode": _zoom_mode,
	}


func set_config(config: Dictionary) -> void:
	_zoom_mode = config.get("zoom_mode", _zoom_mode)


func update_config() -> void:
	$ModeOptions.selected = _zoom_mode


func draw_start(position: Vector2) -> void:
	.draw_start(position)
	var mouse_pos := get_global_mouse_position()
	var viewport_rect := Rect2(
		Global.main_viewport.rect_global_position, Global.main_viewport.rect_size
	)
	var viewport_rect_2 := Rect2(
		Global.second_viewport.rect_global_position, Global.second_viewport.rect_size
	)

	if viewport_rect.has_point(mouse_pos):
		Global.camera.zoom_camera(_zoom_mode * 2 - 1)
	elif viewport_rect_2.has_point(mouse_pos):
		Global.camera2.zoom_camera(_zoom_mode * 2 - 1)


func draw_move(position: Vector2) -> void:
	.draw_move(position)
	Global.camera.zoom_camera(-_relative.x / 3)


func draw_end(position: Vector2) -> void:
	.draw_end(position)
