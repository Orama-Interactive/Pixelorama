extends Node2D

const FONT_SIZE := 16


func _input(event: InputEvent) -> void:
	if event.is_action("ctrl"):
		queue_redraw()


func _draw() -> void:
	var current_cel := Global.current_project.get_current_cel()
	if not current_cel is CelTileMap:
		return
	var tilemap_cel := current_cel as CelTileMap
	var tileset := tilemap_cel.tileset
	for cell_coords: Vector2i in tilemap_cel.cells:
		var cell := tilemap_cel.get_cell_at(cell_coords)
		var tile_index := cell.index
		var tile := tileset.tiles[tile_index]
		if cell.index == 0:
			continue
		var pos := tilemap_cel.get_pixel_coords(cell_coords)
		if tile.terrain_center_bit > -1:
			var terrain_id := tile.terrain_center_bit
			var terrain_color := tileset.godot_tileset.get_terrain_color(0, terrain_id)
			terrain_color.a = 0.5
			var polygon := PackedVector2Array()
			polygon = tileset.get_terrain_polygon()
			draw_set_transform(pos + (tilemap_cel.tile_size / 2), rotation, scale)
			draw_colored_polygon(polygon, terrain_color)
		for i in range(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER + 1):
			var terrain_id := tile.terrain_peering_bits[i]
			if terrain_id == -1:
				continue
			var terrain_color := tileset.godot_tileset.get_terrain_color(0, terrain_id)
			terrain_color.a = 0.5
			print(terrain_color)
			#if tileset.godot_tileset_atlas_source.is_va
			var polygon := PackedVector2Array()
			polygon = tileset.get_terrain_peering_bit_polygon(tile.terrain_peering_bits[i], i)
			if polygon.size() < 3:
				continue
			var uvs := PackedVector2Array()
			uvs.resize(polygon.size())
			draw_set_transform(pos + (tilemap_cel.tile_size / 2), rotation, scale)
			draw_colored_polygon(polygon, terrain_color)
		#draw_polygon()
	draw_set_transform(position, rotation, scale)
	if Input.is_action_pressed("ctrl"):
		var tile_size := tilemap_cel.get_tile_size()
		var min_axis := mini(tilemap_cel.get_tile_size().x, tilemap_cel.get_tile_size().y)
		var scale_factor := min_axis / 32.0
		draw_set_transform(position, rotation, Vector2(scale_factor, scale_factor))
		var font := Themes.get_font()
		for cell_coords: Vector2i in tilemap_cel.cells:
			var cell := tilemap_cel.get_cell_at(cell_coords)
			if cell.index == 0:
				continue
			var text := cell.to_string()
			var pos := tilemap_cel.get_pixel_coords(cell_coords)
			if Global.mirror_view:
				pos.x = Global.current_project.size.x - pos.x - tilemap_cel.get_tile_size().x
			pos.y += tile_size.y - font.get_ascent(FONT_SIZE * 0.5) * scale_factor
			draw_string(
				font,
				pos / scale_factor,
				text,
				HORIZONTAL_ALIGNMENT_CENTER,
				tile_size.x / scale_factor,
				FONT_SIZE
			)
	draw_set_transform(position, rotation, scale)
