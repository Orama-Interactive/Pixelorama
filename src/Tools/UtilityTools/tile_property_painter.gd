extends BaseTool


func draw_start(pos: Vector2i) -> void:
	super.draw_start(pos)
	_draw_cache.append(pos)
	set_tile_bit(pos)


func draw_move(pos: Vector2i) -> void:
	super.draw_move(pos)
	if pos in _draw_cache:
		return
	set_tile_bit(pos)
	_draw_cache.append(pos)


func draw_end(pos: Vector2i) -> void:
	super.draw_end(pos)
	set_tile_bit(pos)


func set_tile_bit(pos: Vector2i) -> void:
	if Global.current_project.get_current_cel() is not CelTileMap:
		return
	var cel := Global.current_project.get_current_cel() as CelTileMap
	var half_size := cel.tile_size / 2
	var tileset := cel.tileset
	#var cell_position := get_cell_position(pos)
	var final_pos := pos - cel.tile_size
	var tile_index := cel.get_cell_index_at_coords(pos)
	var tile := tileset.tiles[tile_index]
	var polygon := tileset.get_terrain_polygon()
	if Geometry2D.is_point_in_polygon(final_pos, polygon):
		tile.terrain_center_bit = 0
	for i in range(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER + 1):
		#var terrain_id := tile.terrain_peering_bits[i]
		polygon = tileset.get_terrain_peering_bit_polygon(0, i)
		if polygon.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(final_pos, polygon):
			tile.terrain_peering_bits[i] = 0
	prints(final_pos, tile.terrain_peering_bits)
