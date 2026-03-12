extends Node2D


func _input(event: InputEvent) -> void:
	if event.is_action("ctrl"):
		queue_redraw()


func _draw() -> void:
	var current_cel := Global.current_project.get_current_cel()
	if not current_cel is CelTileMap:
		return
	var tilemap_cel := current_cel as CelTileMap
	var tileset := tilemap_cel.tileset
	@warning_ignore("integer_division")
	var half_size := tilemap_cel.tile_size / 2
	for cell_coords: Vector2i in tilemap_cel.cells:
		var cell := tilemap_cel.get_cell_at(cell_coords)
		var tile_index := cell.index
		var tile := tileset.tiles[tile_index]
		if tile_index == 0:
			continue
		var pos := tilemap_cel.get_pixel_coords(cell_coords)
		if tile.terrain_center_bit > -1:
			var terrain_id := tile.terrain_center_bit
			var terrain_color := tileset.godot_tileset.get_terrain_color(0, terrain_id)
			terrain_color.a = 0.5
			var polygon := tileset.get_terrain_polygon()
			draw_set_transform(pos + half_size, rotation, scale)
			draw_colored_polygon(polygon, terrain_color)
		for i in range(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER + 1):
			var terrain_id := tile.terrain_peering_bits[i]
			if terrain_id == -1:
				continue
			var terrain_color := tileset.godot_tileset.get_terrain_color(0, terrain_id)
			terrain_color.a = 0.5
			#if tileset.godot_tileset_atlas_source.is_va
			var polygon := tileset.get_terrain_peering_bit_polygon(0, i)
			if polygon.size() < 3:
				continue
			var uvs := PackedVector2Array()
			uvs.resize(polygon.size())
			draw_set_transform(pos + half_size, rotation, scale)
			draw_colored_polygon(polygon, terrain_color)
		#draw_polygon()
	draw_set_transform(position, rotation, scale)
