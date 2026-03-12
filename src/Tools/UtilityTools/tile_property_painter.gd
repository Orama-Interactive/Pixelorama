extends BaseTool

var _hovering_polygon: PackedVector2Array
var _hovering_polygon_pos: Vector2


func draw_start(pos: Vector2i) -> void:
	super(pos)
	_draw_cache.append(pos)
	set_tile_bit(pos)


func draw_move(pos: Vector2i) -> void:
	super(pos)
	if pos in _draw_cache:
		return
	set_tile_bit(pos)
	_draw_cache.append(pos)


func draw_end(pos: Vector2i) -> void:
	super(pos)
	set_tile_bit(pos)


func cursor_move(pos: Vector2i) -> void:
	super(pos)
	_hovering_polygon = []
	if Global.current_project.get_current_cel() is not CelTileMap:
		return
	var cel := Global.current_project.get_current_cel() as CelTileMap
	var tile_index := cel.get_cell_index_at_coords(pos)
	if tile_index == 0:
		return
	var half_size := cel.tile_size / 2
	var tileset := cel.tileset
	var cell_position := get_cell_position(pos)
	var cell_position_pixel_coords := cell_position * cel.tile_size
	var final_pos := pos - cell_position_pixel_coords - half_size - cel.offset
	var polygon := tileset.get_terrain_polygon()
	if Geometry2D.is_point_in_polygon(final_pos, polygon):
		_hovering_polygon = polygon
		_hovering_polygon_pos = cell_position_pixel_coords + half_size - cel.offset
		return
	for i in range(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER + 1):
		polygon = tileset.get_terrain_peering_bit_polygon(0, i)
		if polygon.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(final_pos, polygon):
			_hovering_polygon = polygon
			_hovering_polygon_pos = cell_position_pixel_coords + half_size - cel.offset
			break


func draw_indicator(_left: bool) -> void:
	if _hovering_polygon.size() < 3:
		return
	Global.canvas.indicators.draw_set_transform(_hovering_polygon_pos, Global.canvas.indicators.rotation, Global.canvas.indicators.scale)
	Global.canvas.indicators.draw_colored_polygon(_hovering_polygon, Color.WHITE)
	Global.canvas.indicators.draw_set_transform(Global.canvas.indicators.position, Global.canvas.indicators.rotation, Global.canvas.indicators.scale)


func set_tile_bit(pos: Vector2i) -> void:
	if Global.current_project.get_current_cel() is not CelTileMap:
		return
	var cel := Global.current_project.get_current_cel() as CelTileMap
	var tile_index := cel.get_cell_index_at_coords(pos)
	if tile_index == 0:
		return
	var half_size := cel.tile_size / 2
	var tileset := cel.tileset
	var cell_position := get_cell_position(pos)
	var cell_position_pixel_coords := cell_position * cel.tile_size
	var final_pos := pos - cell_position_pixel_coords - half_size - cel.offset
	var tile := tileset.tiles[tile_index]
	var polygon := tileset.get_terrain_polygon()
	if Geometry2D.is_point_in_polygon(final_pos, polygon):
		tile.terrain_center_bit = 0
		return
	for i in range(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER + 1):
		#var terrain_id := tile.terrain_peering_bits[i]
		polygon = tileset.get_terrain_peering_bit_polygon(0, i)
		if polygon.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(final_pos, polygon):
			tile.terrain_peering_bits[i] = 0
			break
