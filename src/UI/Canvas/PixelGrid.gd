extends Node2D


func _draw() -> void:
	if not Global.draw_pixel_grid:
		return

	var zoom_percentage := 100.0 / Global.camera.zoom.x
	if zoom_percentage < Global.pixel_grid_show_at_zoom:
		return

	var rect : Rect2 = Global.current_project.get_tile_mode_rect()
	if rect.has_no_area():
		return

	for x in range(ceil(rect.position.x), floor(rect.end.x) + 1):
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Global.pixel_grid_color)
	for y in range(ceil(rect.position.y), floor(rect.end.y) + 1):
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Global.pixel_grid_color)
