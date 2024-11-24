class_name CelTileMap
extends PixelCel

var tileset: TileSetCustom
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
	for i in indices.size():
		var x_coord := float(tileset.tile_size.x) * (i % indices_x)
		var y_coord := float(tileset.tile_size.y) * (i / indices_x)
		var rect := Rect2i(Vector2i(x_coord, y_coord), tileset.tile_size)
		var image_portion := image.get_region(rect)
		var index := indices[i]
		var current_tile := tileset.tiles[index]
		if TileSetPanel.tile_editing_mode == TileSetPanel.TileEditingMode.MANUAL:
			if index == 0 or tileset.tiles.size() <= index:
				if tileset.tiles.size() <= 1:
					tileset.add_tile(image_portion, TileSetPanel.tile_editing_mode)
					indices[i] = tileset.tiles.size() - 1
				continue
			if image_portion.get_data() != tileset.tiles[index].image.get_data():
				tileset.replace_tile_at(image_portion, index)
				# TODO: Update the rest of the tilemap
		elif TileSetPanel.tile_editing_mode == TileSetPanel.TileEditingMode.AUTO:
			handle_auto_editing_mode(i, image_portion)
		else:  # Stack
			var found_tile := false
			for j in range(1, tileset.tiles.size()):
				var tile := tileset.tiles[j]
				if image_portion.get_data() == tile.image.get_data():
					indices[i] = j
					found_tile = true
					break
			if not found_tile:
				tileset.add_tile(image_portion, TileSetPanel.tile_editing_mode)
				indices[i] = tileset.tiles.size() - 1


## Cases:[br]
## 0) Portion is transparent. Set its index to 0.
## [br]
## 0.5) Portion is transparent and mapped.
## Set its index to 0 and unuse the mapped tile.
## If the mapped tile is removed, educe the index of all portions that have indices greater or equal
## than the existing tile's index.
## [br]
## 1) Portion not mapped, exists in the tileset.
## Map the portion to the existing tile and increase its times_used by one.
## [br]
## 2) Portion not mapped, does not exist in the tileset.
## Add the portion as a tile in the tileset, set its index to be the tileset's tile size - 1.
## [br]
## 3) Portion mapped, tile did not change. Do nothing.
## [br]
## 4) Portion mapped, exists in the tileset.
## The mapped tile still exists in the tileset.
## Map the portion to the existing tile, increase its times_used by one,
## and reduce the previously mapped tile's times_used by 1.
## [br]
## 5) Portion mapped, exists in the tileset.
## The mapped tile does not exist in the tileset anymore.
## Map the portion to the existing tile and increase its times_used by one.
## Remove the previously mapped tile,
## and reduce the index of all portions that have indices greater or equal
## than the existing tile's index.
## [br]
## 6) Portion mapped, does not exist in the tileset.
## The mapped tile still exists in the tileset.
## Add the portion as a tile in the tileset, set its index to be the tileset's tile size - 1.
## Reduce the previously mapped tile's times_used by 1.
## [br]
## 7) Portion mapped, does not exist in the tileset.
## The mapped tile does not exist in the tileset anymore.
## Simply replace the old tile with the new one, do not change its index.
func handle_auto_editing_mode(i: int, image_portion: Image) -> void:
	var index := indices[i]
	var current_tile := tileset.tiles[index]
	if image_portion.is_invisible():
		# Case 0: The portion is transparent.
		indices[i] = 0
		if index > 0:
			# Case 0.5: The portion is transparent and mapped to a tile.
			var is_removed := tileset.unuse_tile_at_index(index)
			if is_removed:
				# Re-index all indices that are after the deleted one.
				re_index_tiles_after_index(index)
		return
	var index_in_tileset := tileset.find_tile(image_portion)
	if index == 0:  # If the portion is not mapped to a tile.
		if index_in_tileset > -1:
			# Case 1: The portion is not mapped already,
			# and it exists in the tileset as a tile.
			tileset.tiles[index_in_tileset].times_used += 1
			indices[i] = index_in_tileset
		else:
			# Case 2: The portion is not mapped already,
			# and it does not exist in the tileset.
			tileset.add_tile(image_portion, TileSetPanel.tile_editing_mode)
			indices[i] = tileset.tiles.size() - 1
	else:  # If the portion is already mapped.
		if image_portion.get_data() == current_tile.image.get_data():
			# Case 3: The portion is mapped and it did not change.
			# Do nothing and move on to the next portion.
			return
		var previous_tile_index_in_tileset := tileset.find_tile(current_tile.image)
		if index_in_tileset > -1:  # If the portion exists in the tileset as a tile.
			if current_tile.times_used > 1:
				# Case 4: The portion is mapped and it exists in the tileset as a tile,
				# and the currently mapped tile still exists in the tileset.
				tileset.tiles[index_in_tileset].times_used += 1
				indices[i] = index_in_tileset
				tileset.unuse_tile_at_index(index)
			else:
				# Case 5: The portion is mapped and it exists in the tileset as a tile,
				# and the currently mapped tile no longer exists in the tileset.
				tileset.tiles[index_in_tileset].times_used += 1
				indices[i] = index_in_tileset
				tileset.remove_tile_at_index(index)
				# Re-index all indices that are after the deleted one.
				re_index_tiles_after_index(index)
		else:  # If the portion does not exist in the tileset as a tile.
			if current_tile.times_used > 1:
				# Case 6: The portion is mapped and it does not
				# exist in the tileset as a tile,
				# and the currently mapped tile still exists in the tileset.
				tileset.unuse_tile_at_index(index)
				tileset.add_tile(image_portion, TileSetPanel.tile_editing_mode)
				indices[i] = tileset.tiles.size() - 1
			else:
				# Case 7: The portion is mapped and it does not
				# exist in the tileset as a tile,
				# and the currently mapped tile no longer exists in the tileset.
				tileset.replace_tile_at(image_portion, index)


## Re-indexes all [member indices] that are larger or equal to [param index],
## by reducing their value by one.
func re_index_tiles_after_index(index: int) -> void:
	for i in indices.size():
		var tmp_index := indices[i]
		if tmp_index >= index:
			indices[i] -= 1


## Unused, should delete.
func re_index_tiles() -> void:
	for i in indices.size():
		var x_coord := float(tileset.tile_size.x) * (i % indices_x)
		var y_coord := float(tileset.tile_size.y) * (i / indices_x)
		var rect := Rect2i(Vector2i(x_coord, y_coord), tileset.tile_size)
		var image_portion := image.get_region(rect)
		if image_portion.is_invisible():
			indices[i] = 0
			continue
		for j in range(1, tileset.tiles.size()):
			var tile := tileset.tiles[j]
			if image_portion.get_data() == tile.image.get_data():
				indices[i] = j
				break


func get_class_name() -> String:
	return "CelTileMap"
