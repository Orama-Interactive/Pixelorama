# gdlint: ignore=max-public-methods
class_name CelTileMap
extends PixelCel

## A cel type for 2D tile-based maps.
## A Tilemap cel uses a [TileSetCustom], which it inherits from its [LayerTileMap].
## Extending from [PixelCel], it contains an internal [Image], which is divided in
## grid cells, the size of which comes from [member TileSetCustom.tile_size].
## Each cell contains an index, which is an integer used to map that portion of the
## internal [member PixelCel.image] to a tile in [member tileset], as well as
## information that specifies if that cell has a transformation applied to it,
## such as horizontal flipping, vertical flipping, or if it's transposed.

## The [TileSetCustom] that this cel uses, passed down from the cel's [LayerTileMap].
var tileset: TileSetCustom

## The [Array] of type [CelTileMap.Cell] that contains data for each cell of the tilemap.
## The array's size is equal to [member horizontal_cells] * [member vertical_cells].
var cells: Array[Cell]
## The amount of horizontal cells.
var horizontal_cells: int
## The amount of vertical cells.
var vertical_cells: int
## Dictionary of [int] and [Array].
## The key is the index of the tile in the tileset,
## and the value is the index of the tilemap tile that changed first, along with
## its image that is being changed when manual mode is enabled.
## Gets reset on [method update_tilemap].
var editing_images := {}


## An internal class of [CelTIleMap], which contains data used by individual cells of the tilemap.
class Cell:
	## The index of the [TileSetCustom] tile that the cell is mapped to.
	var index := 0
	## If [code]true[/code], the tile is flipped horizontally in this cell.
	var flip_h := false
	## If [code]true[/code], the tile is flipped vertically in this cell.
	var flip_v := false
	## If [code]true[/code], the tile is rotated 90 degrees counter-clockwise,
	## and then flipped vertically in this cell.
	var transpose := false

	func _to_string() -> String:
		var text := str(index)
		if flip_h:
			text += "H"
		if flip_v:
			text += "V"
		if transpose:
			text += "T"
		return text

	func remove_transformations() -> void:
		flip_h = false
		flip_v = false
		transpose = false

	func serialize() -> Dictionary:
		return {"index": index, "flip_h": flip_h, "flip_v": flip_v, "transpose": transpose}

	func deserialize(dict: Dictionary) -> void:
		index = dict.get("index", index)
		flip_h = dict.get("flip_h", flip_h)
		flip_v = dict.get("flip_v", flip_v)
		transpose = dict.get("transpose", transpose)


func _init(_tileset: TileSetCustom, _image := ImageExtended.new(), _opacity := 1.0) -> void:
	super._init(_image, _opacity)
	set_tileset(_tileset)


func set_tileset(new_tileset: TileSetCustom, reset_indices := true) -> void:
	if tileset == new_tileset:
		return
	if is_instance_valid(tileset):
		if tileset.updated.is_connected(_on_tileset_updated):
			tileset.updated.disconnect(_on_tileset_updated)
	tileset = new_tileset
	if is_instance_valid(tileset):
		_resize_cells(get_image().get_size(), reset_indices)
		if not tileset.updated.is_connected(_on_tileset_updated):
			tileset.updated.connect(_on_tileset_updated)


## Maps the cell at position [param cell_position] to
## the [member tileset]'s tile of index [param index].
func set_index(cell_position: int, index: int) -> void:
	index = clampi(index, 0, tileset.tiles.size() - 1)
	var previous_index := cells[cell_position].index

	if previous_index != index:
		if previous_index > 0 and previous_index < tileset.tiles.size():
			tileset.tiles[previous_index].times_used -= 1
		tileset.tiles[index].times_used += 1
		cells[cell_position].index = index
	cells[cell_position].flip_h = TileSetPanel.is_flipped_h
	cells[cell_position].flip_v = TileSetPanel.is_flipped_v
	cells[cell_position].transpose = TileSetPanel.is_transposed
	_update_cell(cell_position)
	Global.canvas.queue_redraw()


## Returns the pixel coordinates of the tilemap's cell
## at position [cell_position] in the cel's image.
## The reverse of [method get_cell_position].
func get_cell_coords_in_image(cell_position: int) -> Vector2i:
	var x_coord := float(tileset.tile_size.x) * (cell_position % horizontal_cells)
	@warning_ignore("integer_division")
	var y_coord := float(tileset.tile_size.y) * (cell_position / horizontal_cells)
	return Vector2i(x_coord, y_coord)


## Returns the position of a cell in the tilemap
## at pixel coordinates [param coords] in the cel's image.
## The reverse of [method get_cell_coords_in_image].
func get_cell_position(coords: Vector2i) -> int:
	@warning_ignore("integer_division")
	var x := coords.x / tileset.tile_size.x
	x = clampi(x, 0, horizontal_cells - 1)
	@warning_ignore("integer_division")
	var y := coords.y / tileset.tile_size.y
	y = clampi(y, 0, vertical_cells - 1)
	y *= horizontal_cells
	return x + y


## Returns the position of a cell in the tilemap
## at tilemap coordinates [param coords] in the cel's image.
func get_cell_position_in_tilemap_space(coords: Vector2i) -> int:
	var x := coords.x
	x = clampi(x, 0, horizontal_cells - 1)
	var y := coords.y
	y = clampi(y, 0, vertical_cells - 1)
	y *= horizontal_cells
	return x + y


## Returns the index of a cell in the tilemap
## at pixel coordinates [param coords] in the cel's image.
func get_cell_index_at_coords(coords: Vector2i) -> int:
	return cells[get_cell_position(coords)].index


## Returns the index of a cell in the tilemap
## at tilemap coordinates [param coords] in the cel's image.
func get_cell_index_at_coords_in_tilemap_space(coords: Vector2i) -> int:
	return cells[get_cell_position_in_tilemap_space(coords)].index


## Returns [code]true[/code] if the tile at cell position [param cell_position]
## with image [param image_portion] is equal to [param tile_image].
func _tiles_equal(cell_position: int, image_portion: Image, tile_image: Image) -> bool:
	var cell_data := cells[cell_position]
	var final_image_portion := transform_tile(
		tile_image, cell_data.flip_h, cell_data.flip_v, cell_data.transpose
	)
	return image_portion.get_data() == final_image_portion.get_data()


## Applies transformations to [param tile_image] based on [param flip_h],
## [param flip_v] and [param transpose], and returns the transformed image.
## If [param reverse] is [code]true[/code], the transposition is applied the reverse way.
func transform_tile(
	tile_image: Image, flip_h: bool, flip_v: bool, transpose: bool, reverse := false
) -> Image:
	var transformed_tile := Image.new()
	transformed_tile.copy_from(tile_image)
	if transpose:
		var tmp_image := Image.new()
		tmp_image.copy_from(transformed_tile)
		if reverse:
			tmp_image.rotate_90(CLOCKWISE)
		else:
			tmp_image.rotate_90(COUNTERCLOCKWISE)
		transformed_tile.blit_rect(
			tmp_image, Rect2i(Vector2i.ZERO, transformed_tile.get_size()), Vector2i.ZERO
		)
		if reverse and not (flip_h != flip_v):
			transformed_tile.flip_x()
		else:
			transformed_tile.flip_y()
	if flip_h:
		transformed_tile.flip_x()
	if flip_v:
		transformed_tile.flip_y()
	return transformed_tile


## Given a [param selection_map] and a [param selection_rect],
## the method finds the cells that are currently selected and returns them
## in the form of a 2D array that contains the serialiazed data
##of the selected cells in the form of [Dictionary].
func get_selected_cells(selection_map: SelectionMap, selection_rect: Rect2i) -> Array[Array]:
	var selected_cells: Array[Array] = []
	for x in range(0, selection_rect.size.x, tileset.tile_size.x):
		selected_cells.append([])
		for y in range(0, selection_rect.size.y, tileset.tile_size.y):
			var pos := Vector2i(x, y) + selection_rect.position
			var x_index := x / tileset.tile_size.x
			if selection_map.is_pixel_selected(pos):
				var cell_pos := get_cell_position(pos)
				selected_cells[x_index].append(cells[cell_pos].serialize())
			else:
				# If it's not selected, append the transparent tile 0.
				selected_cells[x_index].append(
					{"index": 0, "flip_h": false, "flip_v": false, "transpose": false}
				)
	return selected_cells


## Resizes [param selected_indices], which is an array of arrays of [Dictionary],
## to [param horizontal_size] and [param vertical_size].
## This method is used when resizing a selection and draw tiles mode is enabled.
func resize_selection(
	selected_cells: Array[Array], horizontal_size: int, vertical_size: int
) -> Array[Array]:
	var resized_cells: Array[Array] = []
	var current_columns := selected_cells.size()
	if current_columns == 0:
		return resized_cells
	var current_rows := selected_cells[0].size()
	if current_rows == 0:
		return resized_cells
	resized_cells.resize(horizontal_size)
	for x in horizontal_size:
		resized_cells[x] = []
		resized_cells[x].resize(vertical_size)
	var column_middles := current_columns - 2
	if current_columns == 1:
		for x in horizontal_size:
			_resize_rows(selected_cells[0], resized_cells[x], current_rows, vertical_size)
	else:
		for x in horizontal_size:
			if x == 0:
				_resize_rows(selected_cells[0], resized_cells[x], current_rows, vertical_size)
			elif x == horizontal_size - 1:
				_resize_rows(selected_cells[-1], resized_cells[x], current_rows, vertical_size)
			else:
				if x < current_columns - 1:
					_resize_rows(selected_cells[x], resized_cells[x], current_rows, vertical_size)
				else:
					if column_middles == 0:
						_resize_rows(
							selected_cells[-1], resized_cells[x], current_rows, vertical_size
						)
					else:
						var x_index := x - (column_middles * ((x - 1) / column_middles))
						_resize_rows(
							selected_cells[x_index], resized_cells[x], current_rows, vertical_size
						)
	return resized_cells


## Helper method of [method resize_selection].
func _resize_rows(
	selected_cells: Array, resized_cells: Array, current_rows: int, vertical_size: int
) -> void:
	var row_middles := current_rows - 2
	if current_rows == 1:
		for y in vertical_size:
			resized_cells[y] = selected_cells[0]
	else:
		for y in vertical_size:
			if y == 0:
				resized_cells[y] = selected_cells[0]
			elif y == vertical_size - 1:
				resized_cells[y] = selected_cells[-1]
			else:
				if y < current_rows - 1:
					resized_cells[y] = selected_cells[y]
				else:
					if row_middles == 0:
						resized_cells[y] = selected_cells[-1]
					else:
						var y_index := y - (row_middles * ((y - 1) / row_middles))
						resized_cells[y] = selected_cells[y_index]


## Applies the [param selected_cells] data to [param target_image] data,
## offset by [param selection_rect]. The target image needs to be resized first.
## This method is used when resizing a selection and draw tiles mode is enabled.
func apply_resizing_to_image(
	target_image: Image, selected_cells: Array[Array], selection_rect: Rect2i
) -> void:
	for x in selected_cells.size():
		for y in selected_cells[x].size():
			var pos := Vector2i(x, y) * tileset.tile_size + selection_rect.position
			var cell_pos := get_cell_position(pos)
			var coords := get_cell_coords_in_image(cell_pos) - selection_rect.position
			var rect := Rect2i(coords, tileset.tile_size)
			var image_portion := target_image.get_region(rect)
			var cell_data := Cell.new()
			cell_data.deserialize(selected_cells[x][y])
			var index := cell_data.index
			if index >= tileset.tiles.size():
				index = 0
			var current_tile := tileset.tiles[index].image
			var transformed_tile := transform_tile(
				current_tile, cell_data.flip_h, cell_data.flip_v, cell_data.transpose
			)
			if image_portion.get_data() != transformed_tile.get_data():
				var tile_size := transformed_tile.get_size()
				target_image.blit_rect(transformed_tile, Rect2i(Vector2i.ZERO, tile_size), coords)
				if target_image is ImageExtended:
					target_image.convert_rgb_to_indexed()


## Appends data to a [Dictionary] to be used for undo/redo.
func serialize_undo_data() -> Dictionary:
	var dict := {}
	var cell_indices := []
	cell_indices.resize(cells.size())
	for i in cell_indices.size():
		cell_indices[i] = cells[i].serialize()
	dict["cell_indices"] = cell_indices
	dict["tileset"] = tileset.serialize_undo_data()
	dict["resize"] = false
	return dict


## Same purpose as [method serialize_undo_data], but for when the image resource
## ([param source_image]) we want to store to the undo/redo stack
## is not the same as [member image]. This method also handles the resizing logic for undo/redo.
func serialize_undo_data_source_image(
	source_image: ImageExtended, redo_data: Dictionary, undo_data: Dictionary
) -> void:
	undo_data[self] = serialize_undo_data()
	if source_image.get_size() != image.get_size():
		undo_data[self]["resize"] = true
		_resize_cells(source_image.get_size())
		tileset.handle_project_resize(self)
	var tile_editing_mode := TileSetPanel.tile_editing_mode
	if tile_editing_mode == TileSetPanel.TileEditingMode.MANUAL:
		tile_editing_mode = TileSetPanel.TileEditingMode.AUTO
	update_tilemap(tile_editing_mode, source_image)
	redo_data[self] = serialize_undo_data()
	redo_data[self]["resize"] = undo_data[self]["resize"]


## Reads data from a [param dict] [Dictionary], and uses them to add methods to [param undo_redo].
func deserialize_undo_data(dict: Dictionary, undo_redo: UndoRedo, undo: bool) -> void:
	var cell_indices = dict.cell_indices
	if undo:
		undo_redo.add_undo_method(_deserialize_cell_data.bind(cell_indices, dict.resize))
		if dict.has("tileset"):
			undo_redo.add_undo_method(tileset.deserialize_undo_data.bind(dict.tileset, self))
	else:
		undo_redo.add_do_method(_deserialize_cell_data.bind(cell_indices, dict.resize))
		if dict.has("tileset"):
			undo_redo.add_do_method(tileset.deserialize_undo_data.bind(dict.tileset, self))


## Called when loading a new project. Loops through all [member cells]
## and finds the amount of times each tile from the [member tileset] is being used.
func find_times_used_of_tiles() -> void:
	for cell in cells:
		tileset.tiles[cell.index].times_used += 1


## Gets called every time a change is being applied to the [param image],
## such as when finishing drawing with a draw tool, or when applying an image effect.
## This method responsible for updating the indices of the [member cells], as well as
## updating the [member tileset] with the incoming changes.
## The updating behavior depends on the current tile editing mode
## by [member TileSetPanel.tile_editing_mode].
## If a [param source_image] is provided, that image is being used instead of [member image].
func update_tilemap(
	tile_editing_mode := TileSetPanel.tile_editing_mode, source_image := image
) -> void:
	editing_images.clear()
	var tileset_size_before_update := tileset.tiles.size()
	for i in cells.size():
		var coords := get_cell_coords_in_image(i)
		var rect := Rect2i(coords, tileset.tile_size)
		var image_portion := source_image.get_region(rect)
		var index := cells[i].index
		if index >= tileset.tiles.size():
			index = 0
		var current_tile := tileset.tiles[index]
		if tile_editing_mode == TileSetPanel.TileEditingMode.MANUAL:
			if image_portion.is_invisible():
				continue
			if index == 0:
				# If the tileset is empty, only then add a new tile.
				if tileset.tiles.size() <= 1:
					tileset.add_tile(image_portion, self)
					cells[i].index = tileset.tiles.size() - 1
				continue
			if not _tiles_equal(i, image_portion, current_tile.image):
				tileset.replace_tile_at(image_portion, index, self)
		elif tile_editing_mode == TileSetPanel.TileEditingMode.AUTO:
			_handle_auto_editing_mode(i, image_portion, tileset_size_before_update)
		else:  # Stack
			if image_portion.is_invisible():
				continue
			var found_tile := false
			for j in range(1, tileset.tiles.size()):
				var tile := tileset.tiles[j]
				if _tiles_equal(i, image_portion, tile.image):
					if cells[i].index != j:
						tileset.tiles[cells[i].index].times_used -= 1
						cells[i].index = j
						tileset.tiles[j].times_used += 1
						cells[i].remove_transformations()
					found_tile = true
					break
			if not found_tile:
				if cells[i].index > 0:
					tileset.tiles[cells[i].index].times_used -= 1
				tileset.add_tile(image_portion, self)
				cells[i].index = tileset.tiles.size() - 1
				cells[i].remove_transformations()
	# Updates transparent cells that have indices higher than 0.
	# This can happen when switching to another tileset which has less tiles
	# than the previous one.
	for i in cells.size():
		var coords := get_cell_coords_in_image(i)
		var rect := Rect2i(coords, tileset.tile_size)
		var image_portion := source_image.get_region(rect)
		if not image_portion.is_invisible():
			continue
		var index := cells[i].index
		if index == 0:
			continue
		if index >= tileset.tiles.size():
			index = 0
		var current_tile := tileset.tiles[index]
		if not _tiles_equal(i, image_portion, current_tile.image):
			set_index(i, cells[i].index)


## Gets called by [method update_tilemap]. This method is responsible for handling
## the tilemap updating behavior for the auto tile editing mode.[br]
## Cases:[br]
## 0) Cell is transparent. Set its index to 0.
## [br]
## 0.5) Cell is transparent and mapped.
## Set its index to 0 and unuse the mapped tile.
## If the mapped tile is removed, reduce the index of all cells that have
## indices greater or equal than the existing tile's index.
## [br]
## 1) Cell not mapped, exists in the tileset.
## Map the cell to the existing tile and increase its times_used by one.
## [br]
## 2) Cell not mapped, does not exist in the tileset.
## Add the cell as a tile in the tileset, set its index to be the tileset's tile size - 1.
## [br]
## 3) Cell mapped, tile did not change. Do nothing.
## [br]
## 4) Cell mapped, exists in the tileset.
## The mapped tile still exists in the tileset.
## Map the cell to the existing tile, increase its times_used by one,
## and reduce the previously mapped tile's times_used by 1.
## [br]
## 5) Cell mapped, exists in the tileset.
## The mapped tile does not exist in the tileset anymore.
## Map the cell to the existing tile and increase its times_used by one.
## Remove the previously mapped tile,
## and reduce the index of all cells that have indices greater or equal
## than the existing tile's index.
## [br]
## 6) Cell mapped, does not exist in the tileset.
## The mapped tile still exists in the tileset.
## Add the cell as a tile in the tileset, set its index to be the tileset's tile size - 1.
## Reduce the previously mapped tile's times_used by 1.
## [br]
## 7) Cell mapped, does not exist in the tileset.
## The mapped tile does not exist in the tileset anymore.
## Simply replace the old tile with the new one, do not change its index.
func _handle_auto_editing_mode(
	i: int, image_portion: Image, tileset_size_before_update: int
) -> void:
	var index := cells[i].index
	if index >= tileset.tiles.size():
		index = 0
	var current_tile := tileset.tiles[index]
	if image_portion.is_invisible():
		# Case 0: The cell is transparent.
		if cells[i].index >= tileset_size_before_update:
			return
		cells[i].index = 0
		cells[i].remove_transformations()
		if index > 0:
			# Case 0.5: The cell is transparent and mapped to a tile.
			var is_removed := tileset.unuse_tile_at_index(index, self)
			if is_removed:
				# Re-index all indices that are after the deleted one.
				_re_index_cells_after_index(index)
		return
	var index_in_tileset := tileset.find_tile(image_portion)
	if index == 0:  # If the cell is not mapped to a tile.
		if index_in_tileset > -1:
			# Case 1: The cell is not mapped already,
			# and it exists in the tileset as a tile.
			tileset.tiles[index_in_tileset].times_used += 1
			cells[i].index = index_in_tileset
		else:
			# Case 2: The cell is not mapped already,
			# and it does not exist in the tileset.
			tileset.add_tile(image_portion, self)
			cells[i].index = tileset.tiles.size() - 1
	else:  # If the cell is already mapped.
		if _tiles_equal(i, image_portion, current_tile.image):
			# Case 3: The cell is mapped and it did not change.
			# Do nothing and move on to the next cell.
			return
		if index_in_tileset > -1:  # If the cell exists in the tileset as a tile.
			if current_tile.times_used > 1:
				# Case 4: The cell is mapped and it exists in the tileset as a tile,
				# and the currently mapped tile still exists in the tileset.
				tileset.tiles[index_in_tileset].times_used += 1
				cells[i].index = index_in_tileset
				tileset.unuse_tile_at_index(index, self)
			else:
				# Case 5: The cell is mapped and it exists in the tileset as a tile,
				# and the currently mapped tile no longer exists in the tileset.
				tileset.tiles[index_in_tileset].times_used += 1
				cells[i].index = index_in_tileset
				tileset.remove_tile_at_index(index, self)
				# Re-index all indices that are after the deleted one.
				_re_index_cells_after_index(index)
		else:  # If the cell does not exist in the tileset as a tile.
			if current_tile.times_used > 1:
				# Case 6: The cell is mapped and it does not
				# exist in the tileset as a tile,
				# and the currently mapped tile still exists in the tileset.
				tileset.unuse_tile_at_index(index, self)
				tileset.add_tile(image_portion, self)
				cells[i].index = tileset.tiles.size() - 1
			else:
				# Case 7: The cell is mapped and it does not
				# exist in the tileset as a tile,
				# and the currently mapped tile no longer exists in the tileset.
				tileset.replace_tile_at(image_portion, index, self)
	cells[i].remove_transformations()


## Re-indexes all [member cells] that are larger or equal to [param index],
## by reducing their value by one.
func _re_index_cells_after_index(index: int) -> void:
	for i in cells.size():
		var tmp_index := cells[i].index
		if tmp_index >= index:
			cells[i].index -= 1


## Updates the [member image] data of the cell of the tilemap in [param cell_position],
## to ensure that it is the same as its mapped tile in the [member tileset].
func _update_cell(cell_position: int) -> void:
	var coords := get_cell_coords_in_image(cell_position)
	var rect := Rect2i(coords, tileset.tile_size)
	var image_portion := image.get_region(rect)
	var cell_data := cells[cell_position]
	var index := cell_data.index
	if index >= tileset.tiles.size():
		index = 0
	var current_tile := tileset.tiles[index].image
	var transformed_tile := transform_tile(
		current_tile, cell_data.flip_h, cell_data.flip_v, cell_data.transpose
	)
	if image_portion.get_data() != transformed_tile.get_data():
		var tile_size := transformed_tile.get_size()
		image.blit_rect(transformed_tile, Rect2i(Vector2i.ZERO, tile_size), coords)
		image.convert_rgb_to_indexed()


## Calls [method _update_cell] for all [member cells].
func update_cel_portions() -> void:
	for i in cells.size():
		_update_cell(i)


## Loops through all [member cells] of the tilemap and updates their indices,
## so they can remain mapped to the [member tileset]'s tiles.
func _re_index_all_cells() -> void:
	for i in cells.size():
		var coords := get_cell_coords_in_image(i)
		var rect := Rect2i(coords, tileset.tile_size)
		var image_portion := image.get_region(rect)
		if image_portion.is_invisible():
			var index := cells[i].index
			if index > 0 and index < tileset.tiles.size():
				var current_tile := tileset.tiles[index]
				if not _tiles_equal(i, image_portion, current_tile.image):
					set_index(i, cells[i].index)
			continue
		for j in range(1, tileset.tiles.size()):
			var tile := tileset.tiles[j]
			if _tiles_equal(i, image_portion, tile.image):
				cells[i].index = j
				break


## Resizes the [member cells] array based on [param new_size].
func _resize_cells(new_size: Vector2i, reset_indices := true) -> void:
	horizontal_cells = ceili(float(new_size.x) / tileset.tile_size.x)
	vertical_cells = ceili(float(new_size.y) / tileset.tile_size.y)
	cells.resize(horizontal_cells * vertical_cells)
	for i in cells.size():
		if reset_indices:
			cells[i] = Cell.new()
		else:
			if not is_instance_valid(cells[i]):
				cells[i] = Cell.new()


## Returns [code]true[/code] if the user just did a Redo.
func _is_redo() -> bool:
	return Global.control.redone


## If the tileset has been modified by another [param cel],
## make sure to also update it here.
## If [param replace_index] is larger than -1, it means that manual mode
## has been used to replace a tile in the tileset in another cel,
## so call [method update_cel_portions] to update it in this cel as well.
## Otherwise, call [method _re_index_all_cells] to ensure that the cells have correct indices.
func _on_tileset_updated(cel: CelTileMap, replace_index: int) -> void:
	if cel == self:
		return
	if link_set != null and cel in link_set["cels"]:
		return
	if replace_index > -1:  # Manual mode
		update_cel_portions()
	else:
		_re_index_all_cells()
	Global.canvas.update_all_layers = true
	Global.canvas.queue_redraw()


func _deserialize_cell_data(cell_indices: Array, resize: bool) -> void:
	if resize:
		_resize_cells(image.get_size())
	for i in cell_indices.size():
		var cell_data: Dictionary = cell_indices[i]
		cells[i].deserialize(cell_data)


# Overridden Methods:
func set_content(content, texture: ImageTexture = null) -> void:
	super.set_content(content, texture)
	_resize_cells(image.get_size())
	_re_index_all_cells()


func update_texture(undo := false) -> void:
	var tile_editing_mode := TileSetPanel.tile_editing_mode
	if undo or _is_redo() or tile_editing_mode != TileSetPanel.TileEditingMode.MANUAL:
		super.update_texture(undo)
		editing_images.clear()
		return

	for i in cells.size():
		var cell_data := cells[i]
		var index := cell_data.index
		if index >= tileset.tiles.size():
			index = 0
		var coords := get_cell_coords_in_image(i)
		var rect := Rect2i(coords, tileset.tile_size)
		var image_portion := image.get_region(rect)
		var current_tile := tileset.tiles[index]
		if index == 0:
			if tileset.tiles.size() > 1:
				# Prevent from drawing on empty image portions.
				var tile_size := current_tile.image.get_size()
				image.blit_rect(current_tile.image, Rect2i(Vector2i.ZERO, tile_size), coords)
			continue
		if not editing_images.has(index):
			if not _tiles_equal(i, image_portion, current_tile.image):
				var transformed_image := transform_tile(
					image_portion, cell_data.flip_h, cell_data.flip_v, cell_data.transpose, true
				)
				editing_images[index] = [i, transformed_image]

	for i in cells.size():
		var cell_data := cells[i]
		var index := cell_data.index
		if index >= tileset.tiles.size():
			index = 0
		var coords := get_cell_coords_in_image(i)
		var rect := Rect2i(coords, tileset.tile_size)
		var image_portion := image.get_region(rect)
		if editing_images.has(index):
			var editing_portion := editing_images[index][0] as int
			if i == editing_portion:
				var transformed_image := transform_tile(
					image_portion, cell_data.flip_h, cell_data.flip_v, cell_data.transpose, true
				)
				editing_images[index] = [i, transformed_image]
			var editing_image := editing_images[index][1] as Image
			var transformed_editing_image := transform_tile(
				editing_image, cell_data.flip_h, cell_data.flip_v, cell_data.transpose
			)
			if not image_portion.get_data() == transformed_editing_image.get_data():
				var tile_size := image_portion.get_size()
				image.blit_rect(transformed_editing_image, Rect2i(Vector2i.ZERO, tile_size), coords)
	super.update_texture(undo)


func serialize() -> Dictionary:
	var dict := super.serialize()
	var cell_indices := []
	cell_indices.resize(cells.size())
	for i in cell_indices.size():
		cell_indices[i] = cells[i].serialize()
	dict["cell_indices"] = cell_indices
	return dict


func deserialize(dict: Dictionary) -> void:
	super.deserialize(dict)
	var cell_indices = dict.get("cell_indices")
	for i in cell_indices.size():
		cells[i].deserialize(cell_indices[i])


func get_class_name() -> String:
	return "CelTileMap"
