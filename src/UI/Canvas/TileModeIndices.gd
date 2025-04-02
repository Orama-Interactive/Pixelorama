extends Node2D

const FONT_SIZE := 16


func _input(event: InputEvent) -> void:
	if event.is_action("ctrl"):
		queue_redraw()


func _draw() -> void:
	var current_cel := Global.current_project.get_current_cel()
	var scale_factor := 0.25
	draw_set_transform(position, rotation, Vector2(scale_factor, scale_factor))
	if current_cel is CelTileMap and Input.is_action_pressed("ctrl"):
		var tilemap_cel := current_cel as CelTileMap
		var tile_size := tilemap_cel.get_tile_size()
		var font := Themes.get_font()
		for cell_coords: Vector2i in tilemap_cel.cells:
			var cell := tilemap_cel.get_cell_at(cell_coords)
			if cell.index == 0:
				continue
			var text := cell.to_string()
			var pos := tilemap_cel.get_pixel_coords(cell_coords)
			pos.y += tile_size.y - font.get_ascent(FONT_SIZE * 0.5) * 0.5
			draw_string(
				font,
				pos / scale_factor,
				text,
				HORIZONTAL_ALIGNMENT_CENTER,
				tile_size.x / scale_factor,
				FONT_SIZE
			)
	draw_set_transform(position, rotation, scale)
