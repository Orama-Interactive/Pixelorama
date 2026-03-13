extends BaseTool

var _prev_mode := false
var _erase := false
var _hovering_polygon: PackedVector2Array
var _hovering_polygon_pos: Vector2


func _input(event: InputEvent) -> void:
	var erase_button: CheckBox = $Erase
	if event.is_action_pressed("change_tool_mode"):
		_prev_mode = erase_button.button_pressed
	if event.is_action("change_tool_mode"):
		erase_button.set_pressed_no_signal(!_prev_mode)
		_erase = erase_button.button_pressed
	if event.is_action_released("change_tool_mode"):
		erase_button.set_pressed_no_signal(_prev_mode)
		_erase = erase_button.button_pressed


func set_config(config: Dictionary) -> void:
	super(config)
	_erase = config.get("erase", _erase)


func update_config() -> void:
	super()
	$Erase.button_pressed = _erase


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
	var terrain_id := 0
	if _erase:
		terrain_id = -1
	var half_size := cel.tile_size / 2
	var tileset := cel.tileset
	var cell_position := get_cell_position(pos)
	var cell_position_pixel_coords := cell_position * cel.tile_size
	var final_pos := pos - cell_position_pixel_coords - half_size - cel.offset
	var tile := tileset.tiles[tile_index]
	var polygon := tileset.get_terrain_polygon()
	if Geometry2D.is_point_in_polygon(final_pos, polygon):
		tile.terrain_center_bit = terrain_id
		Global.canvas.tilemap_property_drawing.queue_redraw()
		return
	for i in range(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER + 1):
		polygon = tileset.get_terrain_peering_bit_polygon(0, i)
		if polygon.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(final_pos, polygon):
			tile.terrain_peering_bits[i] = terrain_id
			Global.canvas.tilemap_property_drawing.queue_redraw()
			return


func _on_erase_toggled(toggled_on: bool) -> void:
	_erase = toggled_on
	update_config()
	save_config()
