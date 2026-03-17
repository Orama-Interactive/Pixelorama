extends BaseTool

var _prev_mode := false
var _erase := false
var _hovering_polygon: PackedVector2Array
var _hovering_polygon_pos: Vector2
var _undo_data := {}


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
	_undo_data = _get_undo_data()
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
	commit_undo()


func cursor_move(pos: Vector2i) -> void:
	super(pos)
	_hovering_polygon = []
	if Global.current_project.get_current_cel() is not CelTileMap:
		return
	var cel := Global.current_project.get_current_cel() as CelTileMap
	var tile_index := cel.get_cell_index_at_coords(pos)
	if tile_index == 0:
		return
	@warning_ignore("integer_division")
	var half_size := cel.tile_size / 2
	var tileset := cel.tileset
	var cell_position := get_cell_position(pos)
	var cell_position_pixel_coords := cel.get_pixel_coords(cell_position)
	var final_pos := pos - cell_position_pixel_coords - half_size
	var polygon := tileset.get_terrain_polygon()
	if Geometry2D.is_point_in_polygon(final_pos, polygon):
		_hovering_polygon = polygon
		_hovering_polygon_pos = cell_position_pixel_coords + half_size
		return
	for i in range(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER + 1):
		if not tileset.is_valid_terrain_peering_bit_for_mode(i):
			continue
		polygon = tileset.get_terrain_peering_bit_polygon(0, i)
		if polygon.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(final_pos, polygon):
			_hovering_polygon = polygon
			_hovering_polygon_pos = cell_position_pixel_coords + half_size
			break


func draw_indicator(_left: bool) -> void:
	if _hovering_polygon.size() < 3:
		return
	Global.canvas.indicators.draw_set_transform(
		_hovering_polygon_pos, Global.canvas.indicators.rotation, Global.canvas.indicators.scale
	)
	Global.canvas.indicators.draw_colored_polygon(_hovering_polygon, Color.WHITE)
	Global.canvas.indicators.draw_set_transform(
		Global.canvas.indicators.position,
		Global.canvas.indicators.rotation,
		Global.canvas.indicators.scale
	)


func set_tile_bit(pos: Vector2i) -> void:
	if Global.current_project.get_current_cel() is not CelTileMap:
		return
	var cel := Global.current_project.get_current_cel() as CelTileMap
	var tile_index := cel.get_cell_index_at_coords(pos)
	if tile_index == 0:
		return
	var terrain_id := TileSetPanel.current_terrain_index
	if _erase:
		terrain_id = -1
	@warning_ignore("integer_division")
	var half_size := cel.tile_size / 2
	var tileset := cel.tileset
	var cell_position := get_cell_position(pos)
	var cell_position_pixel_coords := cel.get_pixel_coords(cell_position)
	var final_pos := pos - cell_position_pixel_coords - half_size
	var tile := tileset.tiles[tile_index]
	var polygon := tileset.get_terrain_polygon()
	if Geometry2D.is_point_in_polygon(final_pos, polygon):
		tile.terrain_center_bit = terrain_id
		Global.canvas.tilemap_property_drawing.queue_redraw()
		return
	for i in tile.terrain_peering_bits.size():
		if not tileset.is_valid_terrain_peering_bit_for_mode(i):
			continue
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


func _get_undo_data() -> Dictionary:
	if Global.current_project.get_current_cel() is not CelTileMap:
		return {}
	var cel := Global.current_project.get_current_cel() as CelTileMap
	var tileset := cel.tileset
	var data := {}
	data[tileset] = tileset.serialize_undo_data()
	return data


func commit_undo(action := "Set tile terrain bits") -> void:
	var redo_data := _get_undo_data()
	var undo_redo := Global.current_project.undo_redo
	undo_redo.create_action(action)
	for tileset: TileSetCustom in redo_data:
		if tileset not in _undo_data:
			printerr("Tileset not found in undo data! This should never happen.")
			continue
		var tileset_undo_data: Dictionary = _undo_data[tileset]
		var tileset_redo_data: Dictionary = redo_data[tileset]
		undo_redo.add_do_method(tileset.deserialize_undo_data.bind(tileset_redo_data, null))
		undo_redo.add_undo_method(tileset.deserialize_undo_data.bind(tileset_undo_data, null))
	undo_redo.add_do_method(Global.canvas.tilemap_property_drawing.queue_redraw)
	undo_redo.add_undo_method(Global.canvas.tilemap_property_drawing.queue_redraw)
	undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	undo_redo.commit_action()
