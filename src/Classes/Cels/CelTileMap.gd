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

var cells: Dictionary[Vector2i, Cell] = {}  ## Dictionary that contains the data of each cell.
## If [code]true[/code], users can only place tiles in the tilemap and not modify the tileset
## in any way, such as by drawing pixels.
## Passed down from the cel's [LayerTileMap].
var place_only_mode := false
## The size of each tile.
## Overwrites the [member tileset]'s tile size if [member place_only_mode] is [code]true[/code].
## Passed down from the cel's [LayerTileMap].
var tile_size := Vector2i(16, 16):
	set(value):
		tile_size = value
		re_order_tilemap()
## The shape of each tile.
## Overwrites the [member tileset]'s tile shape if [member place_only_mode] is [code]true[/code].
## Passed down from the cel's [LayerTileMap].
var tile_shape := TileSet.TILE_SHAPE_SQUARE:
	set(value):
		tile_shape = value
		re_order_tilemap()
## The layout of the tiles. Used when [member place_only_mode] is [code]true[/code].
## Passed down from the cel's [LayerTileMap].
var tile_layout := TileSet.TILE_LAYOUT_DIAMOND_DOWN:
	set(value):
		tile_layout = value
		re_order_tilemap()
## For all half-offset shapes (Isometric & Hexagonal), determines the offset axis.
## Passed down from the cel's [LayerTileMap].
var tile_offset_axis := TileSet.TILE_OFFSET_AXIS_HORIZONTAL:
	set(value):
		tile_offset_axis = value
		re_order_tilemap()
var vertical_cell_min := 0  ## The minimum vertical cell.
var vertical_cell_max := 0  ## The maximum vertical cell.
var offset := Vector2i.ZERO  ## The offset of the tilemap in pixel coordinates.
var prev_offset := offset  ## Used for undo/redo purposes.
## The key is the index of the tile in the tileset,
## and the value is the coords of the tilemap tile that changed first, along with
## its image that is being changed when manual mode is enabled.
## Gets reset on [method update_tilemap].
var editing_images: Dictionary[int, Array] = {}
## When enabled, the tile is defined by content strictly inside it's grid,
## and tile when placed in area smaller than it's size gets assigned a different index.
## useful when drawing (should be disabled when placing tiles instead)
var _should_clip_tiles: bool = true

## Used to ensure [method _queue_update_cel_portions] is only called once.
var _pending_update := false


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
	## Used to ensure that each cell is only being updated once per frame,
	## to avoid rare cases of infinite recursion.
	var updated_this_frame := false

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
		if tileset.tile_added.is_connected(_on_tileset_tile_added):
			tileset.tile_added.disconnect(_on_tileset_tile_added)
			tileset.tile_removed.disconnect(_on_tileset_tile_removed)
			tileset.tile_replaced.disconnect(_on_tileset_tile_replaced)
	tileset = new_tileset
	if is_instance_valid(tileset):
		_resize_cells(get_image().get_size(), reset_indices)
		tile_size = tileset.tile_size
		tile_shape = tileset.tile_shape
		if not tileset.tile_added.is_connected(_on_tileset_tile_added):
			tileset.tile_added.connect(_on_tileset_tile_added)
			tileset.tile_removed.connect(_on_tileset_tile_removed)
			tileset.tile_replaced.connect(_on_tileset_tile_replaced)


## Maps the cell at position [param cell_position] to
## the [member tileset]'s tile of index [param index].
func set_index(
	cell: Cell,
	index: int,
	flip_h := TileSetPanel.is_flipped_h,
	flip_v := TileSetPanel.is_flipped_v,
	transpose := TileSetPanel.is_transposed
) -> void:
	index = clampi(index, 0, tileset.tiles.size() - 1)
	var previous_index := cell.index

	if previous_index != index:
		if previous_index > 0 and previous_index < tileset.tiles.size():
			tileset.tiles[previous_index].times_used -= 1
		tileset.tiles[index].times_used += 1
		cell.index = index
	cell.flip_h = flip_h
	cell.flip_v = flip_v
	cell.transpose = transpose
	if place_only_mode:
		if previous_index != index:  # Remove previous tile to avoid overlapped pixels
			var cell_coords := cells.find_key(cell) as Vector2i
			var coords := get_pixel_coords(cell_coords)
			var prev_tile := tileset.tiles[previous_index].image
			var prev_tile_size := prev_tile.get_size()
			var blank := Image.create_empty(
				prev_tile_size.x, prev_tile_size.y, false, prev_tile.get_format()
			)
			var tile_offset := (prev_tile_size - get_tile_size()) / 2
			image.blit_rect_mask(
				blank, prev_tile, Rect2i(Vector2i.ZERO, prev_tile_size), coords - tile_offset
			)
		_queue_update_cel_portions(true)
	else:
		_update_cell(cell)
	Global.canvas.queue_redraw()


## Changes the [member offset] of the tilemap. Automatically resizes the cells and redraws the grid.
func change_offset(new_offset: Vector2i) -> void:
	offset = new_offset
	_resize_cells(get_image().get_size(), false)
	Global.canvas.grid.queue_redraw()


## Returns the [CelTileMap.Cell] at position [param cell_coords] in tilemap space.
func get_cell_at(cell_coords: Vector2i) -> Cell:
	if not cells.has(cell_coords):
		cells[cell_coords] = Cell.new()
	return cells[cell_coords]


## Returns the position of a cell in the tilemap
## at pixel coordinates [param coords] in the cel's image.
func get_cell_position(pixel_coords: Vector2i) -> Vector2i:
	var offset_coords := pixel_coords - offset
	var cell_coords := Vector2i()
	if get_tile_shape() != TileSet.TILE_SHAPE_SQUARE:
		offset_coords -= get_tile_size() / 2
		var godot_tileset := TileSet.new()
		godot_tileset.tile_size = get_tile_size()
		godot_tileset.tile_shape = get_tile_shape()
		godot_tileset.tile_layout = tile_layout
		godot_tileset.tile_offset_axis = get_tile_offset_axis()
		var godot_tilemap := TileMapLayer.new()
		godot_tilemap.tile_set = godot_tileset
		cell_coords = godot_tilemap.local_to_map(offset_coords)
		godot_tilemap.queue_free()
	else:
		var x_pos := float(offset_coords.x) / get_tile_size().x
		var y_pos := float(offset_coords.y) / get_tile_size().y
		cell_coords = Vector2i(floori(x_pos), floori(y_pos))
	return cell_coords


## Returns the index of a cell in the tilemap
## at pixel coordinates [param coords] in the cel's image.
func get_cell_index_at_coords(coords: Vector2i) -> int:
	return get_cell_at(get_cell_position(coords)).index


func get_pixel_coords(cell_coords: Vector2i) -> Vector2i:
	if get_tile_shape() != TileSet.TILE_SHAPE_SQUARE:
		var godot_tileset := TileSet.new()
		godot_tileset.tile_size = get_tile_size()
		godot_tileset.tile_shape = get_tile_shape()
		godot_tileset.tile_layout = tile_layout
		godot_tileset.tile_offset_axis = get_tile_offset_axis()
		var godot_tilemap := TileMapLayer.new()
		godot_tilemap.tile_set = godot_tileset
		var pixel_coords := godot_tilemap.map_to_local(cell_coords).floor() as Vector2i
		if get_tile_shape() == TileSet.TILE_SHAPE_HEXAGON:
			var quarter_tile_size := get_tile_size() / 4
			if get_tile_offset_axis() == TileSet.TILE_OFFSET_AXIS_HORIZONTAL:
				pixel_coords += Vector2i(0, quarter_tile_size.y)
			else:
				pixel_coords += Vector2i(quarter_tile_size.x, 0)
		godot_tilemap.queue_free()
		return pixel_coords + offset
	return cell_coords * get_tile_size() + offset


func get_image_portion(rect: Rect2i, source_image := image) -> Image:
	if get_tile_shape() != TileSet.TILE_SHAPE_SQUARE:
		var mask := Image.create_empty(
			get_tile_size().x, get_tile_size().y, false, Image.FORMAT_LA8
		)
		mask.fill(Color(0, 0, 0, 0))
		if get_tile_shape() == TileSet.TILE_SHAPE_ISOMETRIC:
			var old_clip := _should_clip_tiles
			# Disable _should_clip_tiles when placing tiles (it's only useful in drawing)
			if (
				Tools.is_placing_tiles()
				or TileSetPanel.tile_editing_mode == TileSetPanel.TileEditingMode.MANUAL
			):
				_should_clip_tiles = false
			var grid_coord = (Vector2(rect.position - offset) * 2 / Vector2(get_tile_size())).round()
			var is_smaller_tile = int(grid_coord.y) % 2 != 0
			DrawingAlgos.generate_isometric_rectangle(mask, is_smaller_tile and _should_clip_tiles)
			_should_clip_tiles = old_clip
		elif get_tile_shape() == TileSet.TILE_SHAPE_HEXAGON:
			if get_tile_offset_axis() == TileSet.TILE_OFFSET_AXIS_HORIZONTAL:
				DrawingAlgos.generate_hexagonal_pointy_top(mask)
			else:
				DrawingAlgos.generate_hexagonal_flat_top(mask)
		var to_return := Image.create_empty(
			get_tile_size().x, get_tile_size().y, false, source_image.get_format()
		)
		var portion := source_image.get_region(rect)
		to_return.blit_rect_mask(
			portion, mask, Rect2i(Vector2i.ZERO, portion.get_size()), Vector2i.ZERO
		)
		return to_return
	return source_image.get_region(rect)


func get_tile_size() -> Vector2i:
	if place_only_mode:
		return tile_size
	return tileset.tile_size


func get_tile_shape() -> TileSet.TileShape:
	if place_only_mode:
		return tile_shape
	return tileset.tile_shape


func get_tile_offset_axis() -> TileSet.TileOffsetAxis:
	if place_only_mode:
		return tile_offset_axis
	return tileset.tile_offset_axis


func bucket_fill(cell_coords: Vector2i, index: int, callable: Callable) -> void:
	var godot_tileset := TileSet.new()
	godot_tileset.tile_size = get_tile_size()
	godot_tileset.tile_shape = get_tile_shape()
	godot_tileset.tile_layout = tile_layout
	godot_tileset.tile_offset_axis = get_tile_offset_axis()
	var godot_tilemap := TileMapLayer.new()
	godot_tilemap.tile_set = godot_tileset
	var source_cell := get_cell_at(cell_coords)
	var source_index := source_cell.index
	var already_checked: Array[Vector2i]
	var to_check: Array[Vector2i]
	to_check.push_back(cell_coords)
	while not to_check.is_empty():
		var coords := to_check.pop_back() as Vector2i
		if not already_checked.has(coords):
			if not cells.has(coords):
				already_checked.append(coords)
				continue
			var current_cell := cells[coords]
			if source_index == current_cell.index:
				callable.call(coords, index)
				# Get surrounding tiles (handles different tile shapes).
				var around := godot_tilemap.get_surrounding_cells(coords)
				for i in around.size():
					to_check.push_back(around[i])
			already_checked.append(coords)
	godot_tilemap.queue_free()


func re_order_tilemap() -> void:
	if not place_only_mode:
		return
	image.fill(Color(0, 0, 0, 0))
	update_cel_portions(true)


## Returns [code]true[/code] if the tile at cell position [param cell_position]
## with image [param image_portion] is equal to [param tile_image].
func _tiles_equal(cell: Cell, image_portion: Image, tile_image: Image) -> bool:
	var final_image_portion := transform_tile(tile_image, cell.flip_h, cell.flip_v, cell.transpose)
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
## of the selected cells in the form of [Dictionary].
func get_selected_cells(selection_map: SelectionMap, selection_rect: Rect2i) -> Array[Array]:
	var selected_cells: Array[Array] = []
	for x in range(0, selection_rect.size.x, get_tile_size().x):
		selected_cells.append([])
		for y in range(0, selection_rect.size.y, get_tile_size().y):
			var pos := Vector2i(x, y) + selection_rect.position
			var x_index := x / get_tile_size().x
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


## Applies the [param selected_cells] data to [param target_image] data.
## The target image needs to be resized first.
## This method is used when resizing a selection and draw tiles mode is enabled.
func apply_resizing_to_image(
	target_image: Image,
	selected_cells: Array[Array],
	selection_rect: Rect2i,
	transform_confirmed: bool
) -> void:
	for x in selected_cells.size():
		for y in selected_cells[x].size():
			var coords := Vector2i(x, y) * get_tile_size()
			var rect := Rect2i(coords, get_tile_size())
			var image_portion := get_image_portion(rect)
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
				var transformed_tile_size := transformed_tile.get_size()
				target_image.blit_rect(
					transformed_tile, Rect2i(Vector2i.ZERO, transformed_tile_size), coords
				)
				if target_image is ImageExtended:
					target_image.convert_rgb_to_indexed()
			if transform_confirmed:
				var cell_coords := Vector2i(x, y) + (selection_rect.position / get_tile_size())
				get_cell_at(cell_coords).deserialize(cell_data.serialize())


## Appends data to a [Dictionary] to be used for undo/redo.
## [param skip_tileset_undo] is used to avoid getting undo/redo data from the same tileset twice
## by other tilemap cels sharing that exact tileset.
func serialize_undo_data(skip_tileset_undo := false) -> Dictionary:
	var dict := {}
	var cell_data := {}
	for cell_coords: Vector2i in cells:
		var cell := cells[cell_coords]
		cell_data[cell_coords] = cell.serialize()
	dict["cell_data"] = cell_data
	if not skip_tileset_undo:
		dict["tileset"] = tileset.serialize_undo_data()
	dict["resize"] = false
	return dict


## Same purpose as [method serialize_undo_data], but for when the image resource
## ([param source_image]) we want to store to the undo/redo stack
## is not the same as [member image]. This method also handles the resizing logic for undo/redo.
func serialize_undo_data_source_image(
	source_image: ImageExtended,
	redo_data: Dictionary,
	undo_data: Dictionary,
	new_offset := Vector2i.ZERO,
	affect_tileset := false,
	resize_interpolation := Image.INTERPOLATE_NEAREST
) -> void:
	undo_data[self] = serialize_undo_data(not affect_tileset)
	undo_data[self]["tile_size"] = tile_size
	var resize_factor := Vector2(source_image.get_size()) / Vector2(image.get_size())
	if source_image.get_size() != image.get_size():
		undo_data[self]["resize"] = true
		_resize_cells(source_image.get_size(), false)
		if affect_tileset:  # Happens only when scaling image
			tileset.handle_project_resize(resize_factor, resize_interpolation)
	var tile_editing_mode := TileSetPanel.tile_editing_mode
	if tile_editing_mode == TileSetPanel.TileEditingMode.MANUAL:
		tile_editing_mode = TileSetPanel.TileEditingMode.AUTO
	if affect_tileset and source_image.get_size() == image.get_size():
		update_tilemap(tile_editing_mode, source_image)
	redo_data[self] = serialize_undo_data(not affect_tileset)
	redo_data[self]["tile_size"] = Vector2(tile_size) * resize_factor
	redo_data[self]["resize"] = undo_data[self]["resize"]
	if new_offset != Vector2i.ZERO:
		undo_data[self]["offset"] = offset
		redo_data[self]["offset"] = offset + new_offset


## Reads data from a [param dict] [Dictionary], and uses them to add methods to [param undo_redo].
func deserialize_undo_data(dict: Dictionary, undo_redo: UndoRedo, undo: bool) -> void:
	var cell_data = dict.cell_data
	if undo:
		if dict.has("tile_size"):
			undo_redo.add_undo_property(self, "tile_size", dict.tile_size)
		if dict.has("offset"):
			undo_redo.add_undo_method(change_offset.bind(dict.offset))
		undo_redo.add_undo_method(_deserialize_cell_data.bind(cell_data, dict.resize))
		if dict.has("tileset"):
			undo_redo.add_undo_method(tileset.deserialize_undo_data.bind(dict.tileset, self))
	else:
		if dict.has("tile_size"):
			undo_redo.add_do_property(self, "tile_size", dict.tile_size)
		if dict.has("offset"):
			undo_redo.add_do_method(change_offset.bind(dict.offset))
		undo_redo.add_do_method(_deserialize_cell_data.bind(cell_data, dict.resize))
		if dict.has("tileset"):
			undo_redo.add_do_method(tileset.deserialize_undo_data.bind(dict.tileset, self))


## Called when loading a new project, or when [method set_content] is called.
## Loops through all [member cells] and finds the amount of times
## each tile from the [member tileset] is being used.
func find_times_used_of_tiles() -> void:
	for cell_coords in cells:
		var cell := cells[cell_coords]
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
	if place_only_mode:
		return
	var tileset_size_before_update := tileset.tiles.size()
	for cell_coords in cells:
		var cell := get_cell_at(cell_coords)
		var coords := get_pixel_coords(cell_coords)
		var rect := Rect2i(coords, get_tile_size())
		var image_portion := get_image_portion(rect, source_image)
		var index := cell.index
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
					cell.index = tileset.tiles.size() - 1
				continue
			if not _tiles_equal(cell, image_portion, current_tile.image):
				tileset.replace_tile_at(image_portion, index, self)
		elif tile_editing_mode == TileSetPanel.TileEditingMode.AUTO:
			_handle_auto_editing_mode(cell, image_portion, tileset_size_before_update)
		else:  # Stack
			if image_portion.is_invisible():
				continue
			var found_tile := false
			for j in range(1, tileset.tiles.size()):
				var tile := tileset.tiles[j]
				if _tiles_equal(cell, image_portion, tile.image):
					if cell.index != j:
						tileset.tiles[cell.index].times_used -= 1
						cell.index = j
						tileset.tiles[j].times_used += 1
						cell.remove_transformations()
					found_tile = true
					break
			if not found_tile:
				if cell.index > 0:
					tileset.tiles[cell.index].times_used -= 1
				tileset.add_tile(image_portion, self)
				cell.index = tileset.tiles.size() - 1
				cell.remove_transformations()
	# Updates transparent cells that have indices higher than 0.
	# This can happen when switching to another tileset which has less tiles
	# than the previous one.
	for cell_coords in cells:
		var cell := cells[cell_coords]
		var coords := get_pixel_coords(cell_coords)
		var rect := Rect2i(coords, get_tile_size())
		var image_portion := get_image_portion(rect, source_image)
		if not image_portion.is_invisible():
			continue
		var index := cell.index
		if index == 0:
			continue
		if index >= tileset.tiles.size():
			index = 0
		var current_tile := tileset.tiles[index]
		if not _tiles_equal(cell, image_portion, current_tile.image):
			set_index(cell, cell.index)


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
	cell: Cell, image_portion: Image, tileset_size_before_update: int
) -> void:
	var index := cell.index
	if index >= tileset.tiles.size():
		index = 0
	var current_tile := tileset.tiles[index]
	if image_portion.is_invisible():
		# Case 0: The cell is transparent.
		if cell.index >= tileset_size_before_update:
			return
		cell.index = 0
		cell.remove_transformations()
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
			cell.index = index_in_tileset
		else:
			# Case 2: The cell is not mapped already,
			# and it does not exist in the tileset.
			tileset.add_tile(image_portion, self)
			cell.index = tileset.tiles.size() - 1
	else:  # If the cell is already mapped.
		if _tiles_equal(cell, image_portion, current_tile.image):
			# Case 3: The cell is mapped and it did not change.
			# Do nothing and move on to the next cell.
			return
		if index_in_tileset > -1:  # If the cell exists in the tileset as a tile.
			if current_tile.times_used > 1:
				# Case 4: The cell is mapped and it exists in the tileset as a tile,
				# and the currently mapped tile still exists in the tileset.
				tileset.tiles[index_in_tileset].times_used += 1
				cell.index = index_in_tileset
				tileset.unuse_tile_at_index(index, self)
			else:
				# Case 5: The cell is mapped and it exists in the tileset as a tile,
				# and the currently mapped tile no longer exists in the tileset.
				tileset.tiles[index_in_tileset].times_used += 1
				cell.index = index_in_tileset
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
				cell.index = tileset.tiles.size() - 1
			else:
				# Case 7: The cell is mapped and it does not
				# exist in the tileset as a tile,
				# and the currently mapped tile no longer exists in the tileset.
				tileset.replace_tile_at(image_portion, index, self)
	cell.remove_transformations()


## Re-indexes all [member cells] that are larger or equal to [param index],
## by either reducing or increasing their value by one, whether [param decrease]
## is [code]true[/code] or not.
func _re_index_cells_after_index(index: int, decrease := true) -> void:
	for cell_coords in cells:
		var cell := cells[cell_coords]
		var tmp_index := cell.index
		if tmp_index >= index:
			if decrease:
				cell.index -= 1
			else:
				cell.index += 1


## Updates the [param source_image] data of the cell of the tilemap in [param cell_position],
## to ensure that it is the same as its mapped tile in the [member tileset].
func _update_cell(cell: Cell) -> void:
	if cell.updated_this_frame:
		return
	cell.updated_this_frame = true
	cell.set_deferred("updated_this_frame", false)
	var cell_coords := cells.find_key(cell) as Vector2i
	var coords := get_pixel_coords(cell_coords)
	var rect := Rect2i(coords, get_tile_size())
	var image_portion := get_image_portion(rect)
	var index := cell.index
	if index >= tileset.tiles.size():
		index = 0
	var current_tile := tileset.tiles[index].image
	var transformed_tile := transform_tile(current_tile, cell.flip_h, cell.flip_v, cell.transpose)
	if image_portion.get_data() != transformed_tile.get_data():
		_draw_cell(image, transformed_tile, coords, index == 0)
		image.convert_rgb_to_indexed()


func _draw_cell(
	source_image: Image, tile_image: Image, coords: Vector2i, force_square_blit: bool
) -> void:
	var transformed_tile_size := tile_image.get_size()
	var tile_offset := (transformed_tile_size - get_tile_size()) / 2
	coords -= tile_offset
	if force_square_blit or get_tile_shape() == TileSet.TILE_SHAPE_SQUARE:
		source_image.blit_rect(tile_image, Rect2i(Vector2i.ZERO, transformed_tile_size), coords)
		if get_tile_shape() != TileSet.TILE_SHAPE_SQUARE and not place_only_mode:
			update_cel_portions()
	else:
		var mask: Image
		if place_only_mode:
			mask = tile_image
		else:
			mask = Image.create_empty(
				transformed_tile_size.x, transformed_tile_size.y, false, Image.FORMAT_LA8
			)
			mask.fill(Color(0, 0, 0, 0))
			if get_tile_shape() == TileSet.TILE_SHAPE_ISOMETRIC:
				var grid_coord = (Vector2(coords - offset) * 2 / Vector2(get_tile_size())).round()
				var is_smaller_tile = int(grid_coord.y) % 2 != 0
				var old_clip := _should_clip_tiles
				# Disable _should_clip_tiles when placing tiles (it's only useful in drawing)
				if Tools.is_placing_tiles():
					_should_clip_tiles = false
				DrawingAlgos.generate_isometric_rectangle(
					mask, is_smaller_tile and _should_clip_tiles
				)
				_should_clip_tiles = old_clip
			elif get_tile_shape() == TileSet.TILE_SHAPE_HEXAGON:
				if get_tile_offset_axis() == TileSet.TILE_OFFSET_AXIS_HORIZONTAL:
					DrawingAlgos.generate_hexagonal_pointy_top(mask)
				else:
					DrawingAlgos.generate_hexagonal_flat_top(mask)
		source_image.blit_rect_mask(
			tile_image, mask, Rect2i(Vector2i.ZERO, transformed_tile_size), coords
		)


## Calls [method _update_cell] for all [member cells].
func update_cel_portions(skip_zeros := false) -> void:
	_pending_update = false
	var cell_keys := cells.keys()
	cell_keys.sort()
	for cell_coords in cell_keys:
		var cell := cells[cell_coords]
		if cell.index == 0 and skip_zeros:
			continue
		_update_cell(cell)


## Loops through all [member cells] of the tilemap and updates their indices,
## so they can remain mapped to the [member tileset]'s tiles.
func re_index_all_cells(set_invisible_to_zero := false, source_image := image) -> void:
	for cell_coords in cells:
		var cell := cells[cell_coords]
		var coords := get_pixel_coords(cell_coords)
		var rect := Rect2i(coords, get_tile_size())
		var image_portion := get_image_portion(rect, source_image)
		if image_portion.is_invisible():
			if set_invisible_to_zero:
				cell.index = 0
				continue
			var index := cell.index
			if index > 0 and index < tileset.tiles.size():
				var current_tile := tileset.tiles[index]
				if not _tiles_equal(cell, image_portion, current_tile.image):
					set_index(cell, cell.index)
			continue
		for j in range(1, tileset.tiles.size()):
			var tile := tileset.tiles[j]
			if _tiles_equal(cell, image_portion, tile.image):
				cell.index = j
				break


func _queue_update_cel_portions(skip_zeroes := false) -> void:
	if _pending_update:
		return
	_pending_update = true
	update_cel_portions.call_deferred(skip_zeroes)


## Resizes the [member cells] array based on [param new_size].
func _resize_cells(new_size: Vector2i, reset_indices := true) -> void:
	if get_tile_shape() != TileSet.TILE_SHAPE_SQUARE:
		var half_size := get_tile_size() / 2
		for x in range(0, new_size.x + 1, half_size.x):
			for y in range(0, new_size.y + 1, half_size.y):
				var pixel_coords := Vector2i(x, y)
				var cell_coords := get_cell_position(pixel_coords)
				if not cells.has(cell_coords):
					cells[cell_coords] = Cell.new()
	else:
		var horizontal_cells := ceili(float(new_size.x) / get_tile_size().x)
		var vertical_cells := ceili(float(new_size.y) / get_tile_size().y)
		if offset.x % get_tile_size().x != 0:
			horizontal_cells += 1
		if offset.y % get_tile_size().y != 0:
			vertical_cells += 1
		var offset_in_tiles := Vector2i((Vector2(offset) / Vector2(get_tile_size())).ceil())
		for x in horizontal_cells:
			for y in vertical_cells:
				var cell_coords := Vector2i(x, y) - offset_in_tiles
				if not cells.has(cell_coords):
					cells[cell_coords] = Cell.new()
	for cell_coords in cells:
		if cell_coords.y < vertical_cell_min:
			vertical_cell_min = cell_coords.y
		if cell_coords.y > vertical_cell_max:
			vertical_cell_max = cell_coords.y + 1
	for cell_coords in cells:
		if reset_indices:
			cells[cell_coords] = Cell.new()
		else:
			if not is_instance_valid(cells[cell_coords]):
				cells[cell_coords] = Cell.new()


## Returns [code]true[/code] if the user just did a Redo.
func _is_redo() -> bool:
	return Global.control.redone


## If a tile has been added to the tileset by another [param cel], also update the indices here.
func _on_tileset_tile_added(cel: CelTileMap, index: int) -> void:
	if cel == self:
		return
	if link_set != null and cel in link_set["cels"]:
		return
	_re_index_cells_after_index(index, false)
	Global.canvas.update_all_layers = true
	Global.canvas.queue_redraw.call_deferred()


## If a tile has been removed from the tileset by another [param cel], also update the indices here.
func _on_tileset_tile_removed(cel: CelTileMap, index: int) -> void:
	if cel == self:
		return
	if link_set != null and cel in link_set["cels"]:
		return
	_re_index_cells_after_index(index, true)
	Global.canvas.update_all_layers = true
	Global.canvas.queue_redraw.call_deferred()


## If a tile has been replaced in the tileset by another [param cel]
## when using manual mode, also update its image.
func _on_tileset_tile_replaced(cel: CelTileMap, _index: int) -> void:
	if cel == self:
		return
	if link_set != null and cel in link_set["cels"]:
		return
	update_cel_portions(true)
	Global.canvas.update_all_layers = true
	Global.canvas.queue_redraw.call_deferred()


func _deserialize_cell_data(cell_data: Dictionary, resize: bool) -> void:
	if resize:
		_resize_cells(image.get_size())
	for cell_coords in cells:
		if cell_coords in cell_data:
			var cell_data_serialized: Dictionary = cell_data[cell_coords]
			get_cell_at(cell_coords).deserialize(cell_data_serialized)
		else:
			# For cells not found in the undo's cell data.
			# Happens when placing tiles on cells that had not been created before.
			var default_dict := {"index": 0, "flip_h": false, "flip_v": false, "transpose": false}
			get_cell_at(cell_coords).deserialize(default_dict)
	if resize:
		image.fill(Color(0, 0, 0, 0))
		update_cel_portions.call_deferred(true)


# Overridden Methods:
func get_content() -> Variant:
	return [image, cells]


func set_content(content, texture: ImageTexture = null) -> void:
	for cell_coords in cells:
		var cell := cells[cell_coords]
		if cell.index > 0:
			tileset.tiles[cell.index].times_used -= 1
	super.set_content(content[0], texture)
	cells = content[1]
	find_times_used_of_tiles()


func copy_content() -> Array:
	var tmp_image := Image.create_from_data(
		image.get_width(), image.get_height(), false, image.get_format(), image.get_data()
	)
	var copy_image := ImageExtended.new()
	copy_image.copy_from_custom(tmp_image, image.is_indexed)
	var copied_cells: Dictionary[Vector2i, Cell] = {}
	for cell in cells:
		copied_cells[cell] = Cell.new()
		copied_cells[cell].deserialize(cells[cell].serialize())
	return [copy_image, copied_cells.duplicate(true)]


func update_texture(undo := false) -> void:
	var tile_editing_mode := TileSetPanel.tile_editing_mode
	if (
		undo
		or _is_redo()
		or tile_editing_mode != TileSetPanel.TileEditingMode.MANUAL
		or Tools.is_placing_tiles()
		or place_only_mode
	):
		super.update_texture(undo)
		editing_images.clear()
		return

	for cell_coords in cells:
		var cell := cells[cell_coords]
		var coords := get_pixel_coords(cell_coords)
		var index := cell.index
		if index >= tileset.tiles.size():
			index = 0
		var rect := Rect2i(coords, get_tile_size())
		var image_portion := get_image_portion(rect)
		var current_tile := tileset.tiles[index]
		if index == 0:
			if tileset.tiles.size() > 1:
				# Prevent from drawing on empty image portions.
				_draw_cell(image, current_tile.image, coords, false)
			continue
		if not editing_images.has(index):
			if not _tiles_equal(cell, image_portion, current_tile.image):
				var transformed_image := transform_tile(
					image_portion, cell.flip_h, cell.flip_v, cell.transpose, true
				)
				editing_images[index] = [cell_coords, transformed_image]

	for cell_coords in cells:
		var cell := cells[cell_coords]
		var coords := get_pixel_coords(cell_coords)
		var index := cell.index
		if index >= tileset.tiles.size():
			index = 0
		var rect := Rect2i(coords, get_tile_size())
		var image_portion := get_image_portion(rect)
		if editing_images.has(index):
			var editing_portion := editing_images[index][0] as Vector2i
			if cell_coords == editing_portion:
				var transformed_image := transform_tile(
					image_portion, cell.flip_h, cell.flip_v, cell.transpose, true
				)
				editing_images[index] = [cell_coords, transformed_image]
			var editing_image := editing_images[index][1] as Image
			var transformed_editing_image := transform_tile(
				editing_image, cell.flip_h, cell.flip_v, cell.transpose
			)
			if not image_portion.get_data() == transformed_editing_image.get_data():
				_draw_cell(image, transformed_editing_image, coords, index == 0)
	super.update_texture(undo)


func serialize() -> Dictionary:
	var dict := super.serialize()
	var cell_data := {}
	for cell_coords in cells:
		var cell := cells[cell_coords]
		cell_data[cell_coords] = cell.serialize()
	dict["cell_data"] = cell_data
	dict["offset"] = offset
	return dict


func deserialize(dict: Dictionary) -> void:
	super.deserialize(dict)
	var cell_data = dict.get("cell_data", [])
	for cell_coords_str in cell_data:
		var cell_data_serialized: Dictionary = cell_data[cell_coords_str]
		var cell_coords := str_to_var("Vector2i" + cell_coords_str) as Vector2i
		get_cell_at(cell_coords).deserialize(cell_data_serialized)
	var new_offset_str = dict.get("offset", "(0, 0)")
	var new_offset := str_to_var("Vector2i" + new_offset_str) as Vector2i
	if new_offset != offset:
		change_offset(new_offset)


func get_class_name() -> String:
	return "CelTileMap"
