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
		for i in tilemap_cel.cells.size():
			var tile_data := tilemap_cel.cells[i]
			if tile_data.index == 0:
				continue
			var pos := tilemap_cel.get_cell_coords_in_image(i)
			pos.y += tilemap_cel.tileset.tile_size.y
			var text := tile_data.to_string()
			draw_multiline_string(
				Themes.get_font(), pos * 2, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE
			)
	draw_set_transform(position, rotation, scale)
