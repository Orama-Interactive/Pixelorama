extends Node2D


func _input(event: InputEvent) -> void:
	queue_redraw()


func _draw() -> void:
	var current_cel := Global.current_project.get_current_cel()
	if current_cel is CelTileMap:
		var tilemap_cel := current_cel as CelTileMap
		for i in tilemap_cel.indices.size():
			var x := float(tilemap_cel.tileset.tile_size.x) * (i % tilemap_cel.indices_x)
			var y := float(tilemap_cel.tileset.tile_size.y) * (i / tilemap_cel.indices_x)
			var pos := Vector2i(x, y + tilemap_cel.tileset.tile_size.y)
			draw_string(Themes.get_font(), pos, str(tilemap_cel.indices[i]), 0, -1, 12)
