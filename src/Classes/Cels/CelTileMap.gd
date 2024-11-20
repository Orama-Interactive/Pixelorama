class_name CelTileMap
extends PixelCel

enum TileEditingMode { MANUAL, AUTO, STACK }

var tileset: TileSetCustom
var tile_editing_mode := TileEditingMode.AUTO
var indices := PackedInt32Array()
var indices_x: int
var indices_y: int


func _init(_tileset: TileSetCustom, _image: ImageExtended, _opacity := 1.0) -> void:
	super._init(_image, _opacity)
	tileset = _tileset
	indices_x = ceili(float(get_image().get_width()) / tileset.tile_size.x)
	indices_y = ceili(float(get_image().get_height()) / tileset.tile_size.y)
	indices.resize(indices_x * indices_y)


func update_tileset() -> void:
	var removed_tile_indices: Array[int] = []
	if tile_editing_mode == TileEditingMode.AUTO:
		for j in range(tileset.tiles.size() - 1, 0, -1):
			var tile := tileset.tiles[j]
			var tile_used := false
			for i in indices.size():
				var x_coord := float(tileset.tile_size.x) * (i % indices_x)
				var y_coord := float(tileset.tile_size.y) * (i / indices_x)
				var rect := Rect2i(Vector2i(x_coord, y_coord), tileset.tile_size)
				var image_portion := image.get_region(rect)
				if image_portion.is_invisible():
					continue
				if image_portion.get_data() == tile.get_data():
					tile_used = true
					break
			if not tile_used:
				removed_tile_indices.append(j)
				tileset.remove_tile_at_index(j)
	for i in indices.size():
		var x_coord := float(tileset.tile_size.x) * (i % indices_x)
		var y_coord := float(tileset.tile_size.y) * (i / indices_x)
		var rect := Rect2i(Vector2i(x_coord, y_coord), tileset.tile_size)
		var image_portion := image.get_region(rect)
		if image_portion.is_invisible():
			continue
		var index := indices[i]
		if tile_editing_mode == TileEditingMode.MANUAL:
			if index == 0 or tileset.tiles.size() <= index:
				continue
			if image_portion.get_data() != tileset.tiles[index].get_data():
				tileset.replace_tile_at(image_portion, index)
				# TODO: Update the rest of the tilemap
		else:
			var found_tile := false
			for j in range(1, tileset.tiles.size()):
				var tile := tileset.tiles[j]
				if image_portion.get_data() == tile.get_data():
					indices[i] = j
					found_tile = true
					break
			if not found_tile:
				if removed_tile_indices.is_empty():
					tileset.add_tile(image_portion)
					indices[i] = tileset.tiles.size()
				else:
					var index_position := removed_tile_indices.pop_back() as int
					tileset.insert_tile(image_portion, index_position)
					indices[i] = index_position


func get_class_name() -> String:
	return "CelTileMap"
