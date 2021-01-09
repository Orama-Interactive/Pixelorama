extends Node2D


func _draw() -> void:
	if not Global.draw_pixel_grid:
		return

	var zoom_percentage := 100.0 / Global.camera.zoom.x
	if zoom_percentage < Global.pixel_grid_show_at_zoom:
		return

	var rect : Rect2 = get_rect_to_draw()
	if rect.has_no_area():
		return

	for x in range(ceil(rect.position.x), floor(rect.end.x) + 1):
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Global.pixel_grid_color)
	for y in range(ceil(rect.position.y), floor(rect.end.y) + 1):
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Global.pixel_grid_color)


func get_rect_to_draw() -> Rect2:
	var size := Global.current_project.size
	var tiling_rect : Rect2
	match Global.current_project.tile_mode:
		Global.Tile_Mode.NONE:
			tiling_rect = Rect2(Vector2.ZERO, size)
		Global.Tile_Mode.XAXIS:
			tiling_rect = Rect2(Vector2(-1, 0) * size, Vector2(3, 1) * size)
		Global.Tile_Mode.YAXIS:
			tiling_rect = Rect2(Vector2(0, -1) * size, Vector2(1, 3) * size)
		Global.Tile_Mode.BOTH:
			tiling_rect = Rect2(Vector2(-1, -1) * size, Vector2(3, 3) * size)
	return tiling_rect
