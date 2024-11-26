extends Node2D


func _input(event: InputEvent) -> void:
	if event.is_action("ctrl"):
		queue_redraw()


func _draw() -> void:
	var current_cel := Global.current_project.get_current_cel()
	if current_cel is CelTileMap and Input.is_action_pressed("ctrl"):
		var tilemap_cel := current_cel as CelTileMap
		for i in tilemap_cel.indices.size():
			var pos := tilemap_cel.get_tile_coords(i)
			pos.y += tilemap_cel.tileset.tile_size.y
			var tile_data := tilemap_cel.indices[i]
			var text := tile_data.to_string()
			draw_multiline_string(Themes.get_font(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
