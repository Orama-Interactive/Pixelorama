extends Node2D


func _ready() -> void:
	Global.pixel_grid_updated.connect(queue_redraw)
	Global.project_about_to_switch.connect(_on_project_about_to_switch)
	Global.project_switched.connect(_on_project_switched)
	Global.camera.zoom_changed.connect(queue_redraw)


func _draw() -> void:
	if not Global.draw_pixel_grid:
		return

	var zoom_percentage := 100.0 * Global.camera.zoom.x
	if zoom_percentage < Global.pixel_grid_show_at_zoom:
		return

	var target_rect := Global.current_project.tiles.get_bounding_rect()
	if not target_rect.has_area():
		return

	var grid_multiline_points := PackedVector2Array()
	for x in range(ceili(target_rect.position.x), floori(target_rect.end.x) + 1):
		grid_multiline_points.push_back(Vector2(x, target_rect.position.y))
		grid_multiline_points.push_back(Vector2(x, target_rect.end.y))

	for y in range(ceili(target_rect.position.y), floori(target_rect.end.y) + 1):
		grid_multiline_points.push_back(Vector2(target_rect.position.x, y))
		grid_multiline_points.push_back(Vector2(target_rect.end.x, y))

	if not grid_multiline_points.is_empty():
		draw_multiline(grid_multiline_points, Global.pixel_grid_color)


func _on_project_about_to_switch() -> void:
	var project := Global.current_project
	project.resized.disconnect(queue_redraw)


func _on_project_switched() -> void:
	var project := Global.current_project
	if not project.resized.is_connected(queue_redraw):
		project.resized.connect(queue_redraw)
