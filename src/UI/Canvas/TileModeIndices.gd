extends Node2D

const FONT_SIZE := 16


func _input(event: InputEvent) -> void:
	if event.is_action("ctrl"):
		queue_redraw()


func _draw() -> void:
	var current_cel := Global.current_project.get_current_cel()
	draw_set_transform(position, rotation, Vector2(0.5, 0.5))
	if current_cel is CelTileMap and Input.is_action_pressed("ctrl"):
		var tilemap_cel := current_cel as CelTileMap
		var tile_size := tilemap_cel.tileset.tile_size
		var font := Themes.get_font()
		for cell_coords: Vector2i in tilemap_cel.cells_dict:
			var cell := tilemap_cel.get_cell_at(cell_coords)
			if cell.index == 0:
				continue
			var text := cell.to_string()
			var pos := cell_coords * tilemap_cel.tileset.tile_size
			pos.y += tile_size.y - font.get_ascent(FONT_SIZE * 0.5) * 0.5
			draw_string(
				font, pos * 2, text, HORIZONTAL_ALIGNMENT_CENTER, tile_size.x * 2, FONT_SIZE
			)
	draw_set_transform(position, rotation, scale)
