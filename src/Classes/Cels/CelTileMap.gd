class_name CelTileMap
extends PixelCel

var tileset: TileSetCustom:
	set(value):
		if is_instance_valid(tileset):
			if tileset.updated.is_connected(_on_tileset_updated):
				tileset.updated.disconnect(_on_tileset_updated)
		tileset = value
		if is_instance_valid(tileset):
			_resize_indices(get_image().get_size())
			if not tileset.updated.is_connected(_on_tileset_updated):
				tileset.updated.connect(_on_tileset_updated)
var indices: Array[Tile]
var indices_x: int
var indices_y: int
## Dictionary of [int] and an [Array] of [bool] ([member TileSetPanel.placing_tiles])
## and [enum TileSetPanel.TileEditingMode].
var undo_redo_modes := {}
## Dictionary of [int] and [Array].
## The key is the index of the tile in the tileset,
## and the value is the index of the tilemap tile that changed first, along with
## its image that is being changed when manual mode is enabled.
## Gets reset on [method update_tileset].
var editing_images := {}


class Tile:
	var index := 0
	var flip_h := false
	var flip_v := false
	var transpose := false

	func serialize() -> Dictionary:
		return {"index": index, "flip_h": flip_h, "flip_v": flip_v, "transpose": transpose}

	func deserialize(dict: Dictionary) -> void:
		index = dict.get("index", index)
		flip_h = dict.get("flip_h", flip_h)
		flip_v = dict.get("flip_v", flip_v)
		transpose = dict.get("transpose", transpose)


func _init(_tileset: TileSetCustom, _image: ImageExtended, _opacity := 1.0) -> void:
	super._init(_image, _opacity)
	tileset = _tileset


func set_index(tile_position: int, index: int) -> void:
	index = clampi(index, 0, tileset.tiles.size() - 1)
	tileset.tiles[index].times_used += 1
	indices[tile_position].index = index
	update_cel_portion(tile_position)
	Global.canvas.queue_redraw()


func update_tileset(undo: bool) -> void:
	editing_images.clear()
	var undos := tileset.project.undos
	if not undo and not _is_redo():
		undo_redo_modes[undos] = [TileSetPanel.placing_tiles, TileSetPanel.tile_editing_mode]
	if undo:
		undos += 1
	var tile_editing_mode := _get_tile_editing_mode(undos)
	for i in indices.size():
		var coords := get_tile_coords(i)
		var rect := Rect2i(coords, tileset.tile_size)
		var image_portion := image.get_region(rect)
		var index := indices[i].index
		if index >= tileset.tiles.size():
			printerr("Tile at position ", i, ", mapped to ", index, " is out of bounds!")
			index = 0
			indices[i].index = 0
		var current_tile := tileset.tiles[index]
		if tile_editing_mode == TileSetPanel.TileEditingMode.MANUAL:
			if image_portion.is_invisible():
				continue
			if index == 0:
				# If the tileset is empty, only then add a new tile.
				if tileset.tiles.size() <= 1:
					tileset.add_tile(image_portion, self, tile_editing_mode)
					indices[i].index = tileset.tiles.size() - 1
				continue
			if image_portion.get_data() != current_tile.image.get_data():
				tileset.replace_tile_at(image_portion, index, self)
		elif tile_editing_mode == TileSetPanel.TileEditingMode.AUTO:
			handle_auto_editing_mode(i, image_portion)
		else:  # Stack
			if image_portion.is_invisible():
				continue
			var found_tile := false
			for j in range(1, tileset.tiles.size()):
				var tile := tileset.tiles[j]
				if image_portion.get_data() == tile.image.get_data():
					indices[i].index = j
					found_tile = true
					break
			if not found_tile:
				tileset.add_tile(image_portion, self, tile_editing_mode)
				indices[i].index = tileset.tiles.size() - 1
	if undo:
		var tile_removed := tileset.remove_unused_tiles(self)
		if tile_removed:
			re_index_all_tiles()


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
	var index := indices[i].index
	var current_tile := tileset.tiles[index]
	if image_portion.is_invisible():
		# Case 0: The portion is transparent.
		indices[i].index = 0
		if index > 0:
			# Case 0.5: The portion is transparent and mapped to a tile.
			var is_removed := tileset.unuse_tile_at_index(index, self)
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
			indices[i].index = index_in_tileset
		else:
			# Case 2: The portion is not mapped already,
			# and it does not exist in the tileset.
			tileset.add_tile(image_portion, self, TileSetPanel.TileEditingMode.AUTO)
			indices[i].index = tileset.tiles.size() - 1
	else:  # If the portion is already mapped.
		if image_portion.get_data() == current_tile.image.get_data():
			# Case 3: The portion is mapped and it did not change.
			# Do nothing and move on to the next portion.
			return
		if index_in_tileset > -1:  # If the portion exists in the tileset as a tile.
			if current_tile.times_used > 1:
				# Case 4: The portion is mapped and it exists in the tileset as a tile,
				# and the currently mapped tile still exists in the tileset.
				tileset.tiles[index_in_tileset].times_used += 1
				indices[i].index = index_in_tileset
				tileset.unuse_tile_at_index(index, self)
			else:
				# Case 5: The portion is mapped and it exists in the tileset as a tile,
				# and the currently mapped tile no longer exists in the tileset.
				tileset.tiles[index_in_tileset].times_used += 1
				indices[i].index = index_in_tileset
				tileset.remove_tile_at_index(index, self)
				# Re-index all indices that are after the deleted one.
				re_index_tiles_after_index(index)
		else:  # If the portion does not exist in the tileset as a tile.
			if current_tile.times_used > 1:
				# Case 6: The portion is mapped and it does not
				# exist in the tileset as a tile,
				# and the currently mapped tile still exists in the tileset.
				tileset.unuse_tile_at_index(index, self)
				tileset.add_tile(image_portion, self, TileSetPanel.TileEditingMode.AUTO)
				indices[i].index = tileset.tiles.size() - 1
			else:
				# Case 7: The portion is mapped and it does not
				# exist in the tileset as a tile,
				# and the currently mapped tile no longer exists in the tileset.
				tileset.replace_tile_at(image_portion, index, self)


## Re-indexes all [member indices] that are larger or equal to [param index],
## by reducing their value by one.
func re_index_tiles_after_index(index: int) -> void:
	for i in indices.size():
		var tmp_index := indices[i].index
		if tmp_index >= index:
			indices[i].index -= 1


func update_cel_portion(tile_position: int) -> void:
	var coords := get_tile_coords(tile_position)
	var rect := Rect2i(coords, tileset.tile_size)
	var image_portion := image.get_region(rect)
	var index := indices[tile_position].index
	var current_tile := tileset.tiles[index]
	if image_portion.get_data() != current_tile.image.get_data():
		var tile_size := current_tile.image.get_size()
		image.blit_rect(current_tile.image, Rect2i(Vector2i.ZERO, tile_size), coords)


func update_cel_portions() -> void:
	for i in indices.size():
		update_cel_portion(i)


func get_tile_coords(portion_position: int) -> Vector2i:
	var x_coord := float(tileset.tile_size.x) * (portion_position % indices_x)
	@warning_ignore("integer_division")
	var y_coord := float(tileset.tile_size.y) * (portion_position / indices_x)
	return Vector2i(x_coord, y_coord)


func get_tile_position(coords: Vector2i) -> int:
	@warning_ignore("integer_division")
	var x := coords.x / tileset.tile_size.x
	x = clampi(x, 0, indices_x - 1)
	@warning_ignore("integer_division")
	var y := coords.y / tileset.tile_size.y
	y = clampi(y, 0, indices_y - 1)
	y *= indices_x
	return x + y


func re_index_all_tiles() -> void:
	for i in indices.size():
		var coords := get_tile_coords(i)
		var rect := Rect2i(coords, tileset.tile_size)
		var image_portion := image.get_region(rect)
		if image_portion.is_invisible():
			indices[i].index = 0
			continue
		for j in range(1, tileset.tiles.size()):
			var tile := tileset.tiles[j]
			if image_portion.get_data() == tile.image.get_data():
				indices[i].index = j
				break


func _resize_indices(new_size: Vector2i) -> void:
	indices_x = ceili(float(new_size.x) / tileset.tile_size.x)
	indices_y = ceili(float(new_size.y) / tileset.tile_size.y)
	indices.resize(indices_x * indices_y)
	for i in indices.size():
		indices[i] = Tile.new()


func _is_redo() -> bool:
	return Global.control.redone


func _get_tile_editing_mode(undos: int) -> TileSetPanel.TileEditingMode:
	var tile_editing_mode: TileSetPanel.TileEditingMode
	if undo_redo_modes.has(undos):
		tile_editing_mode = undo_redo_modes[undos][1]
	else:
		tile_editing_mode = TileSetPanel.tile_editing_mode
	return tile_editing_mode


## If the tileset has been modified by another tile, make sure to also update it here.
func _on_tileset_updated(cel: CelTileMap) -> void:
	if cel == self or not is_instance_valid(cel):
		return
	update_cel_portions()
	Global.canvas.update_all_layers = true
	Global.canvas.queue_redraw()


# Overridden Methods:
func update_texture(undo := false) -> void:
	var tile_editing_mode := TileSetPanel.tile_editing_mode
	if undo or _is_redo() or tile_editing_mode != TileSetPanel.TileEditingMode.MANUAL:
		super.update_texture(undo)
		return

	for i in indices.size():
		var index := indices[i].index
		var coords := get_tile_coords(i)
		var rect := Rect2i(coords, tileset.tile_size)
		var image_portion := image.get_region(rect)
		var current_tile := tileset.tiles[index]
		if index == 0 and tileset.tiles.size() > 1:
			# Prevent from drawing on empty image portions.
			var tile_size := current_tile.image.get_size()
			image.blit_rect(current_tile.image, Rect2i(Vector2i.ZERO, tile_size), coords)
			continue
		if editing_images.has(index):
			var editing_portion := editing_images[index][0] as int
			if i == editing_portion:
				editing_images[index] = [i, image_portion]
			var editing_image := editing_images[index][1] as Image
			if editing_image.get_data() != image_portion.get_data():
				var tile_size := image_portion.get_size()
				image.blit_rect(editing_image, Rect2i(Vector2i.ZERO, tile_size), coords)
		else:
			if image_portion.get_data() != current_tile.image.get_data():
				editing_images[index] = [i, image_portion]
	super.update_texture(undo)


func size_changed(new_size: Vector2i) -> void:
	_resize_indices(new_size)
	re_index_all_tiles()


func on_undo_redo(undo: bool) -> void:
	var undos := tileset.project.undos
	if undo:
		undos += 1
	if (undo or _is_redo()) and undo_redo_modes.has(undos):
		var placing_tiles: bool = undo_redo_modes[undos][0]
		if placing_tiles:
			re_index_all_tiles()
			return
	update_tileset(undo)


func serialize() -> Dictionary:
	var dict := super.serialize()
	var tile_indices := []
	tile_indices.resize(indices.size())
	for i in tile_indices.size():
		tile_indices[i] = indices[i].serialize()
	dict["tile_indices"] = tile_indices
	return dict


func deserialize(dict: Dictionary) -> void:
	super.deserialize(dict)
	var tile_indices = dict.get("tile_indices")
	for i in tile_indices.size():
		indices[i].deserialize(tile_indices[i])


func get_class_name() -> String:
	return "CelTileMap"
