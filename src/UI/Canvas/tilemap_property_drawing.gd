extends Node2D


func _ready() -> void:
	Global.cel_switched.connect(queue_redraw)
	Tools.tool_changed.connect(_on_tool_changed)


func _input(event: InputEvent) -> void:
	if event.is_action("ctrl"):
		queue_redraw()


func _draw() -> void:
	if not _has_tile_property_painter_tool():
		return
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
		for i in tile.terrain_peering_bits.size():
			if not tileset.is_valid_terrain_peering_bit_for_mode(i):
				continue
			var terrain_id := tile.terrain_peering_bits[i]
			if terrain_id == -1:
				continue
			var terrain_color := tileset.godot_tileset.get_terrain_color(0, terrain_id)
			terrain_color.a = 0.5
			var polygon := tileset.get_terrain_peering_bit_polygon(0, i)
			if polygon.size() < 3:
				continue
			var uvs := PackedVector2Array()
			uvs.resize(polygon.size())
			draw_set_transform(pos + half_size, rotation, scale)
			draw_colored_polygon(polygon, terrain_color)
	draw_set_transform(position, rotation, scale)


func _has_tile_property_painter_tool() -> bool:
	for button in Tools._slots:
		var slot := Tools._slots[button]
		if slot.tool_node.kname == "tilespropertypainter":
			return true
	return false


func _on_tool_changed(_tool_name: String, _button: int) -> void:
	queue_redraw()
