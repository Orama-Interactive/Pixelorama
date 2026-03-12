class_name TileSetCustom
extends RefCounted

## A Tileset is a collection of tiles, used by [LayerTileMap]s and [CelTileMap]s.
## The tileset contains its [member name], the size of each individual tile,
## and the collection of [TileSetCustom.Tile]s itself.
## Not to be confused with [TileSet], which is a Godot class.

## Emitted on undo/redo. Used to update the tiles panel.
signal updated
## Emitted when a new tile is added to the tileset by a [param cel] on [param index].
signal tile_added(cel: CelTileMap, index: int)
## Emitted when a tile is removed from the tileset by a [param cel] on [param index].
signal tile_removed(cel: CelTileMap, index: int)
## Emitted when a new tile is replaced in the tileset by a [param cel] on [param index].
signal tile_replaced(cel: CelTileMap, index)
## Emitted when the size of the tile images changes.
signal resized_content

## The tileset's name.
var name := ""
## The collection of tiles in the form of an [Array] of type [TileSetCustom.Tile].
var tiles: Array[Tile] = []
## The size of each tile.
var tile_size: Vector2i
## The shape of each tile.
var tile_shape := TileSet.TILE_SHAPE_SQUARE
## For all half-offset shapes (Isometric & Hexagonal), determines the offset axis.
var tile_offset_axis := TileSet.TILE_OFFSET_AXIS_HORIZONTAL:
	set(value):
		tile_offset_axis = value
		godot_tileset.tile_offset_axis = tile_offset_axis
var godot_tileset: TileSet
var godot_tileset_atlas_source: TileSetAtlasSource
## If [code]true[/code], the code in [method handle_project_resize] does not execute.
## This variable is used to prevent multiple cels from clearing the tileset at the same time.
## In [method handle_project_resize], the variable is set to [code]true[/code], and then
## immediately set to [code]false[/code] in the next frame using [method Object.set_deferred].
var _tileset_has_been_resized := false


## An internal class of [TileSetCustom], which contains data used by individual tiles of a tileset.
class Tile:
	## The [Image] tile itself.
	var image: Image
	## The amount of tiles this tile is being used in tilemaps.
	var times_used := 1
	## The relative probability of this tile appearing when drawing random tiles.
	var probability := 1.0
	## User defined data for each individual tile.
	var user_data := ""
	var terrain_center_bit := -1
	var terrain_peering_bits: Array[int]

	func _init(_image: Image) -> void:
		image = _image
		terrain_peering_bits.resize(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER + 1)
		terrain_peering_bits.fill(-1)

	## A method that checks if the tile should be removed from the tileset.
	## Returns [code]true[/code] if the amount of [member times_used] is 0.
	func can_be_removed() -> bool:
		return times_used <= 0

	func serialize() -> Dictionary:
		return {
			"times_used": times_used,
			"probability": probability,
			"user_data": user_data,
			"terrain_center_bit": terrain_center_bit,
			"terrain_peering_bits": terrain_peering_bits,
		}

	func deserialize(dict: Dictionary, skip_times_used := false) -> void:
		times_used = 0  # We have just now, created the tile and haven't placed it anywhere yet.
		if not skip_times_used:
			# We are likely loading from a pxo file and would like to re-calculate it for good
			# measure
			times_used = dict.get("times_used", times_used)
		probability = dict.get("probability", probability)
		user_data = dict.get("user_data", user_data)
		terrain_center_bit = dict.get("terrain_center_bit", terrain_center_bit)
		terrain_peering_bits = dict.get("terrain_peering_bits", terrain_peering_bits)
		print(terrain_peering_bits)


func _init(
	_tile_size: Vector2i,
	_name := "",
	_tile_shape := TileSet.TILE_SHAPE_SQUARE,
	add_empty_tile := true
) -> void:
	tile_size = _tile_size
	name = _name
	tile_shape = _tile_shape
	if add_empty_tile:
		var empty_image := Image.create_empty(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
		tiles.append(Tile.new(empty_image))
	create_godot_tileset()


func duplicate() -> TileSetCustom:
	var new_tileset := TileSetCustom.new(tile_size, name, tile_shape)
	new_tileset.tile_offset_axis = tile_offset_axis
	return new_tileset


## Adds a new [param image] as a tile to the tileset.
## The [param cel] parameter references the [CelTileMap] that this change is coming from,
## and the [param edit_mode] parameter contains the tile editing mode at the time of this change.
func add_tile(image: Image, cel: CelTileMap, times_used := 1) -> void:
	var tile := Tile.new(image)
	tile.times_used = times_used
	tiles.append(tile)
	tile_added.emit(cel, tiles.size() - 1)
	fill_godot_tileset_atlas()
	#var tile_atlas_image := godot_tileset_atlas_source.texture.get_image()
	#tile_atlas_image.crop(tile_atlas_image.get_width() + tile_size.x, tile_atlas_image.get_height())
	#var origin := Vector2(tiles.size() * tile_size.x, 0)
	#tile_atlas_image.blit_rect(image, Rect2i(Vector2i.ZERO, tile_size), origin)


## Adds a new [param image] as a tile in a given [param position] in the tileset.
## The [param cel] parameter references the [CelTileMap] that this change is coming from,
## and the [param edit_mode] parameter contains the tile editing mode at the time of this change.
func insert_tile(image: Image, position: int, cel: CelTileMap) -> void:
	var tile := Tile.new(image)
	tiles.insert(position, tile)
	tile_added.emit(cel, position)
	fill_godot_tileset_atlas()


## Reduces a tile's [member TileSetCustom.Tile.times_used] by one,
## in a given [param index] in the tileset.
## If the times that tile is used reaches 0 and it can be removed,
## it is being removed from the tileset by calling [method remove_tile_at_index].
## Returns [code]true[/code] if the tile has been removed.
## The [param cel] parameter references the [CelTileMap] that this change is coming from.
func unuse_tile_at_index(index: int, cel: CelTileMap) -> bool:
	tiles[index].times_used -= 1
	if tiles[index].can_be_removed():
		remove_tile_at_index(index, cel)
		return true
	return false


## Removes a tile in a given [param index] from the tileset.
## The [param cel] parameter references the [CelTileMap] that this change is coming from.
func remove_tile_at_index(index: int, cel: CelTileMap) -> void:
	tiles.remove_at(index)
	tile_removed.emit(cel, index)
	fill_godot_tileset_atlas()


## Replaces a tile in a given [param index] in the tileset with a [param new_tile].
## The [param cel] parameter references the [CelTileMap] that this change is coming from.
func replace_tile_at(new_tile: Image, index: int, cel: CelTileMap) -> void:
	tiles[index].image.copy_from(new_tile)
	tile_replaced.emit(cel, index)
	fill_godot_tileset_atlas()


## Finds and returns the position of a tile [param image] inside the tileset.
func find_tile(image: Image) -> int:
	for i in tiles.size():
		var tile := tiles[i]
		if image.get_data() == tile.image.get_data():
			return i
	return -1


## Loops through the array of tiles, and automatically removes any tile that can be removed.
## Returns [code]true[/code] if at least one tile has been removed.
## The [param cel] parameter references the [CelTileMap] that this change is coming from.
func remove_unused_tiles(cel: CelTileMap) -> bool:
	var has_removed_tile := false
	for i in range(tiles.size() - 1, 0, -1):
		var tile := tiles[i]
		if tile.can_be_removed():
			remove_tile_at_index(i, cel)
			has_removed_tile = true
	return has_removed_tile


## Clears the used tiles of tileset. Called when the project gets resized,
## and tilemap cels are updating their size and clearing the tileset to re-create it.
func handle_project_resize(
	resize_factor: Vector2, resize_interpolation: Image.Interpolation
) -> void:
	if _tileset_has_been_resized:
		return
	tile_size = Vector2(tile_size) * resize_factor
	for i in range(tiles.size() - 1, 0, -1):
		var tile := tiles[i]
		tile.image = DrawingAlgos.resize_image(
			tile.image, tile_size.x, tile_size.y, resize_interpolation
		)
	_tileset_has_been_resized = true
	set_deferred("_tileset_has_been_resized", false)
	resized_content.emit()


## Returns the tilemap's info, such as its name and tile size and with a given
## [param tile_index], in the form of text.
func get_text_info(tileset_index: int) -> String:
	var item_string := " %s (%s×%s)" % [tileset_index, tile_size.x, tile_size.y]
	if not name.is_empty():
		item_string += ": " + name
	return tr("Tileset") + item_string


## Finds and returns all of the [LayerTileMap]s that use this tileset.
func find_using_layers(project: Project) -> Array[LayerTileMap]:
	var tilemaps: Array[LayerTileMap]
	for layer in project.layers:
		if layer is not LayerTileMap:
			continue
		if layer.tileset == self:
			tilemaps.append(layer)
	return tilemaps


func pick_random_tile(selected_tile_indices: Array[int]) -> int:
	if selected_tile_indices.is_empty():
		for i in tiles.size():
			selected_tile_indices.append(i)
	var sum := 0.0
	for i in selected_tile_indices:
		if i < tiles.size():
			sum += tiles[i].probability
	var rand := randf_range(0.0, sum)
	var current := 0.0
	for i in selected_tile_indices:
		if i < tiles.size():
			current += tiles[i].probability
			if current >= rand:
				return i
	if selected_tile_indices[0] < tiles.size():
		return selected_tile_indices[0]
	return 0


func create_image_atlas(rows := 1, skip_first := true) -> Image:
	var tiles_size := tiles.size()
	if skip_first:
		tiles_size -= 1
	if tiles_size == 0:
		return null
	var columns := ceili(tiles_size / float(rows))
	var width := tile_size.x * columns
	var height := tile_size.y * rows
	var image := Image.create_empty(width, height, false, tiles[0].image.get_format())
	var origin := Vector2i.ZERO
	var hh := 0
	var vv := 0
	for tile in tiles:
		if skip_first and tile == tiles[0]:
			continue
		if vv < columns:
			origin.x = tile_size.x * vv
			vv += 1
		else:
			hh += 1
			origin.x = 0
			vv = 1
			origin.y = tile_size.y * hh
		image.blend_rect(tile.image, Rect2i(Vector2i.ZERO, tile_size), origin)
	return image


func create_godot_tileset() -> void:
	godot_tileset = TileSet.new()
	godot_tileset.tile_size = tile_size
	godot_tileset.tile_shape = tile_shape
	godot_tileset.tile_offset_axis = tile_offset_axis
	godot_tileset.add_terrain_set()
	godot_tileset.add_terrain(0)
	#fill_godot_tileset_atlas()


func fill_godot_tileset_atlas() -> void:
	for i in range(godot_tileset.get_source_count() - 1, -1, -1):
		var id := godot_tileset.get_source_id(i)
		godot_tileset.remove_source(id)
	godot_tileset_atlas_source = TileSetAtlasSource.new()
	godot_tileset.add_source(godot_tileset_atlas_source)
	var image_atlas := create_image_atlas()
	godot_tileset_atlas_source.texture = ImageTexture.create_from_image(image_atlas)
	godot_tileset_atlas_source.texture_region_size = tile_size
	var grid_size := godot_tileset_atlas_source.get_atlas_grid_size()
	var tile_index := 0
	for x in grid_size.x:
		for y in grid_size.y:
			var coords := Vector2i(x, y)
			godot_tileset_atlas_source.create_tile(coords)
			var tile_data := godot_tileset_atlas_source.get_tile_data(coords, 0)
			var tile := tiles[tile_index]
			tile_data.terrain_set = 0
			tile_data.terrain = tile.terrain_center_bit
			for i in tile.terrain_peering_bits.size():
				var bit := tile.terrain_peering_bits[i]
				if tile_data.is_valid_terrain_peering_bit(i):
					tile_data.set_terrain_peering_bit(i, bit)
				else:
					tile.terrain_peering_bits[i] = -1
			tile_index += 1
			if tile_index >= tiles.size():
				break


## Serializes the data of this class into the form of a [Dictionary],
## which is used so the data can be stored in pxo files.
func serialize() -> Dictionary:
	var dict := {
		"name": name, "tile_size": tile_size, "tile_amount": tiles.size(), "tile_shape": tile_shape
	}
	var tile_data := {}
	for i in tiles.size():
		tile_data[i] = tiles[i].serialize()
	dict["tile_data"] = tile_data
	return dict


## Deserializes the data of a given [member dict] [Dictionary] into class data,
## which is used so data can be loaded from pxo files.
func deserialize(dict: Dictionary) -> void:
	name = dict.get("name", name)
	tile_size = str_to_var("Vector2i" + dict.get("tile_size"))
	tile_shape = dict.get("tile_shape", tile_shape)
	var tile_data := dict.get("tile_data", {}) as Dictionary
	for i_str in tile_data:
		var i := int(i_str)
		var tile: Tile
		if i > tiles.size() - 1:
			tile = Tile.new(null)
			tiles.append(tile)
		else:
			tile = tiles[i]
		tile.deserialize(tile_data[i_str], true)


## Serializes the data of each tile in [member tiles] into the form of a [Dictionary],
## which is used by the undo/redo system.
func serialize_undo_data() -> Dictionary:
	var dict := {"tile_size": tile_size, "tiles": {}}
	for tile in tiles:
		var image_data := tile.image.get_data()
		dict["tiles"][tile.image] = [
			image_data.compress(), image_data.size(), tile.image.get_size(), tile.serialize()
		]
	return dict


## Deserializes the data of each tile in [param dict], which is used by the undo/redo system.
func deserialize_undo_data(dict: Dictionary, _cel: CelTileMap) -> void:
	tiles.resize(dict["tiles"].size())
	var prev_tile_size := tile_size
	tile_size = dict["tile_size"]
	var i := 0
	for image: Image in dict["tiles"]:
		var tile_data = dict["tiles"][image]
		var buffer_size := tile_data[1] as int
		var image_size := tile_data[2] as Vector2i
		var tile_dictionary := tile_data[3] as Dictionary
		var image_data := (tile_data[0] as PackedByteArray).decompress(buffer_size)
		image.set_data(image_size.x, image_size.y, false, image.get_format(), image_data)
		tiles[i] = Tile.new(image)
		tiles[i].deserialize(tile_dictionary)
		i += 1
	updated.emit()
	if tile_size != prev_tile_size:
		resized_content.emit()


func get_terrain_polygon() -> Array[Vector2]:
	match tile_shape:
		TileSet.TILE_SHAPE_SQUARE:
			return _get_square_terrain_polygon(tile_size)

		TileSet.TILE_SHAPE_ISOMETRIC:
			return _get_isometric_terrain_polygon(tile_size)

		_:
			var overlap := 0.0

			if tile_shape == TileSet.TILE_SHAPE_HEXAGON:
				overlap = 0.25

			return _get_half_offset_terrain_polygon(tile_size, overlap, tile_offset_axis)


func get_terrain_peering_bit_polygon(p_terrain_set: int, p_bit: int) -> Array[Vector2]:
	if p_terrain_set < 0 or p_terrain_set >= godot_tileset.get_terrain_sets_count():
		return []

	var terrain_mode := godot_tileset.get_terrain_set_mode(p_terrain_set)

	match tile_shape:
		TileSet.TILE_SHAPE_SQUARE:
			match terrain_mode:
				TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES:
					return _square_corner_side_polygon(tile_size, p_bit)
				TileSet.TERRAIN_MODE_MATCH_CORNERS:
					return _square_corner_polygon(tile_size, p_bit)
				_:
					return _square_side_polygon(tile_size, p_bit)

		TileSet.TILE_SHAPE_ISOMETRIC:
			match terrain_mode:
				TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES:
					return _iso_corner_side_polygon(tile_size, p_bit)
				TileSet.TERRAIN_MODE_MATCH_CORNERS:
					return _iso_corner_polygon(tile_size, p_bit)
				_:
					return _iso_side_polygon(tile_size, p_bit)

		_:
			var overlap := 0.0
			if tile_shape == TileSet.TILE_SHAPE_HEXAGON:
				overlap = 0.25

			match terrain_mode:
				TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES:
					return _half_offset_corner_side(tile_size, overlap, tile_offset_axis, p_bit)
				TileSet.TERRAIN_MODE_MATCH_CORNERS:
					return _half_offset_corner(tile_size, overlap, tile_offset_axis, p_bit)
				_:
					return _half_offset_side(tile_size, overlap, tile_offset_axis, p_bit)


func _get_square_terrain_polygon(size: Vector2i) -> Array[Vector2]:
	var rect := Rect2(-Vector2(size) / 6.0, Vector2(size) / 3.0)
	return _rect_to_polygon(rect)


func _square_corner_side_polygon(size: Vector2i, bit: int) -> Array[Vector2]:
	var offsets := {
		TileSet.CELL_NEIGHBOR_RIGHT_SIDE: Vector2(1, -1),
		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER: Vector2(1, 1),
		TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: Vector2(-1, 1),
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER: Vector2(-3, 1),
		TileSet.CELL_NEIGHBOR_LEFT_SIDE: Vector2(-3, -1),
		TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER: Vector2(-3, -3),
		TileSet.CELL_NEIGHBOR_TOP_SIDE: Vector2(-1, -3),
		TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER: Vector2(1, -3)
	}

	if not offsets.has(bit):
		return []

	var rect := Rect2()
	rect.size = Vector2(size) / 3
	rect.position = offsets[bit] * Vector2(size) / 6.0

	return _rect_to_polygon(rect)


func _square_corner_polygon(size: Vector2i, bit: int) -> Array[Vector2]:
	var points := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]

	var scale := Vector2(size)

	for i in points.size():
		points[i] *= scale

	match bit:
		TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER:
			return _mirror_inner_polygon([points[0]])

		TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER:
			return _mirror_inner_polygon([points[1]])

		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER:
			return _mirror_inner_polygon([points[2]])

		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER:
			return _mirror_inner_polygon([points[3]])

	return []


func _square_side_polygon(size: Vector2i, bit: int) -> Array[Vector2]:
	var points := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]

	var scale := Vector2(size)

	for i in points.size():
		points[i] *= scale

	match bit:
		TileSet.CELL_NEIGHBOR_TOP_SIDE:
			return _mirror_inner_polygon([points[0], points[1]])

		TileSet.CELL_NEIGHBOR_RIGHT_SIDE:
			return _mirror_inner_polygon([points[1], points[2]])

		TileSet.CELL_NEIGHBOR_BOTTOM_SIDE:
			return _mirror_inner_polygon([points[2], points[3]])

		TileSet.CELL_NEIGHBOR_LEFT_SIDE:
			return _mirror_inner_polygon([points[3], points[0]])

	return []


func _get_isometric_terrain_polygon(size: Vector2i) -> Array[Vector2]:
	var unit := Vector2(size) / 6.0

	return [
		Vector2(1, 0) * unit, Vector2(0, 1) * unit, Vector2(-1, 0) * unit, Vector2(0, -1) * unit
	]


func _iso_corner_side_polygon(size: Vector2i, bit: int) -> Array[Vector2]:
	var points := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]

	var unit := Vector2(size) / 2.0

	for i in points.size():
		points[i] *= unit

	match bit:
		TileSet.CELL_NEIGHBOR_TOP_SIDE:
			return _mirror_inner_polygon([points[0], points[1]])

		TileSet.CELL_NEIGHBOR_RIGHT_SIDE:
			return _mirror_inner_polygon([points[1], points[2]])

		TileSet.CELL_NEIGHBOR_BOTTOM_SIDE:
			return _mirror_inner_polygon([points[2], points[3]])

		TileSet.CELL_NEIGHBOR_LEFT_SIDE:
			return _mirror_inner_polygon([points[3], points[0]])

		TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER:
			return _mirror_inner_polygon([points[0], points[1]])

		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER:
			return _mirror_inner_polygon([points[1], points[2]])

		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER:
			return _mirror_inner_polygon([points[2], points[3]])

		TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER:
			return _mirror_inner_polygon([points[3], points[0]])

	return []


func _iso_corner_polygon(size: Vector2i, bit: int) -> Array[Vector2]:
	var unit := Vector2(size) / 6.0

	var shapes := {
		TileSet.CELL_NEIGHBOR_RIGHT_CORNER:
		[
			Vector2(0.5, -0.5),
			Vector2(1.5, -1.5),
			Vector2(3, 0),
			Vector2(1.5, 1.5),
			Vector2(0.5, 0.5),
			Vector2(1, 0)
		],
		TileSet.CELL_NEIGHBOR_BOTTOM_CORNER:
		[
			Vector2(-0.5, 0.5),
			Vector2(-1.5, 1.5),
			Vector2(0, 3),
			Vector2(1.5, 1.5),
			Vector2(0.5, 0.5),
			Vector2(0, 1)
		],
		TileSet.CELL_NEIGHBOR_LEFT_CORNER:
		[
			Vector2(-0.5, -0.5),
			Vector2(-1.5, -1.5),
			Vector2(-3, 0),
			Vector2(-1.5, 1.5),
			Vector2(-0.5, 0.5),
			Vector2(-1, 0)
		],
		TileSet.CELL_NEIGHBOR_TOP_CORNER:
		[
			Vector2(-0.5, -0.5),
			Vector2(-1.5, -1.5),
			Vector2(0, -3),
			Vector2(1.5, -1.5),
			Vector2(0.5, -0.5),
			Vector2(0, -1)
		]
	}

	if not shapes.has(bit):
		return []

	return _scale_points(shapes[bit], unit)


func _iso_side_polygon(size: Vector2i, bit: int) -> Array[Vector2]:
	var points := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]

	var unit := Vector2(size) / 2.0

	for i in points.size():
		points[i] *= unit

	match bit:
		TileSet.CELL_NEIGHBOR_TOP_SIDE:
			return _mirror_inner_polygon([points[0], points[1]])

		TileSet.CELL_NEIGHBOR_RIGHT_SIDE:
			return _mirror_inner_polygon([points[1], points[2]])

		TileSet.CELL_NEIGHBOR_BOTTOM_SIDE:
			return _mirror_inner_polygon([points[2], points[3]])

		TileSet.CELL_NEIGHBOR_LEFT_SIDE:
			return _mirror_inner_polygon([points[3], points[0]])

	return []


func _get_half_offset_terrain_polygon(size: Vector2i, overlap: float, axis: int) -> Array[Vector2]:
	var unit := Vector2(size) / 6.0

	if axis == TileSet.TILE_OFFSET_AXIS_HORIZONTAL:
		return _scale_points(
			[
				Vector2(1, 1.0 - overlap * 2.0),
				Vector2(0, 1),
				Vector2(-1, 1.0 - overlap * 2.0),
				Vector2(-1, -1.0 + overlap * 2.0),
				Vector2(0, -1),
				Vector2(1, -1.0 + overlap * 2.0)
			],
			unit
		)

	else:
		return _scale_points(
			[
				Vector2(1, 0),
				Vector2(1.0 - overlap * 2.0, -1),
				Vector2(-1.0 + overlap * 2.0, -1),
				Vector2(-1, 0),
				Vector2(-1.0 + overlap * 2.0, 1),
				Vector2(1.0 - overlap * 2.0, 1)
			],
			unit
		)


func _half_offset_corner_side(
	size: Vector2i, overlap: float, axis: int, bit: int
) -> Array[Vector2]:
	var points := [
		Vector2(3, (3 * (1 - overlap * 2)) / 2),
		Vector2(3, 3 * (1 - overlap * 2)),
		Vector2(2, 3 * (1 - (overlap * 2) * 2 / 3)),
		Vector2(1, 3 - overlap * 2),
		Vector2(0, 3),
		Vector2(-1, 3 - overlap * 2),
		Vector2(-2, 3 * (1 - (overlap * 2) * 2 / 3)),
		Vector2(-3, 3 * (1 - overlap * 2)),
		Vector2(-3, (3 * (1 - overlap * 2)) / 2),
		Vector2(-3, -(3 * (1 - overlap * 2)) / 2),
		Vector2(-3, -3 * (1 - overlap * 2)),
		Vector2(-2, -3 * (1 - (overlap * 2) * 2 / 3)),
		Vector2(-1, -(3 - overlap * 2)),
		Vector2(0, -3),
		Vector2(1, -(3 - overlap * 2)),
		Vector2(2, -3 * (1 - (overlap * 2) * 2 / 3)),
		Vector2(3, -3 * (1 - overlap * 2)),
		Vector2(3, -(3 * (1 - overlap * 2)) / 2)
	]

	var unit := Vector2(size) / 6.0

	if axis == TileSet.TILE_OFFSET_AXIS_VERTICAL:
		for i in points.size():
			points[i] = Vector2(points[i].y, points[i].x)

	points = _scale_points(points, unit)

	var map := {
		TileSet.CELL_NEIGHBOR_RIGHT_SIDE: [17, 0],
		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER: [0, 1, 2],
		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: [2, 3],
		TileSet.CELL_NEIGHBOR_BOTTOM_CORNER: [3, 4, 5],
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: [5, 6],
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER: [6, 7, 8],
		TileSet.CELL_NEIGHBOR_LEFT_SIDE: [8, 9],
		TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER: [9, 10, 11],
		TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: [11, 12],
		TileSet.CELL_NEIGHBOR_TOP_CORNER: [12, 13, 14],
		TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: [14, 15],
		TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER: [15, 16, 17]
	}

	if not map.has(bit):
		return []

	var poly: Array[Vector2] = []
	for i in map[bit]:
		poly.append(points[i])

	return _mirror_inner_polygon(poly)


func _half_offset_corner(size: Vector2i, overlap: float, axis: int, bit: int) -> Array[Vector2]:
	var points := [
		Vector2(3, 0),
		Vector2(3, 3 * (1 - overlap * 2)),
		Vector2(1.5, (3 * (1 - overlap * 2) + 3) / 2),
		Vector2(0, 3),
		Vector2(-1.5, (3 * (1 - overlap * 2) + 3) / 2),
		Vector2(-3, 3 * (1 - overlap * 2)),
		Vector2(-3, 0),
		Vector2(-3, -3 * (1 - overlap * 2)),
		Vector2(-1.5, -(3 * (1 - overlap * 2) + 3) / 2),
		Vector2(0, -3),
		Vector2(1.5, -(3 * (1 - overlap * 2) + 3) / 2),
		Vector2(3, -3 * (1 - overlap * 2))
	]

	var unit := Vector2(size) / 6.0

	if axis == TileSet.TILE_OFFSET_AXIS_VERTICAL:
		for i in points.size():
			points[i] = Vector2(points[i].y, points[i].x)

	points = _scale_points(points, unit)

	var map := {
		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER: [0, 1, 2],
		TileSet.CELL_NEIGHBOR_BOTTOM_CORNER: [2, 3, 4],
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER: [4, 5, 6],
		TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER: [6, 7, 8],
		TileSet.CELL_NEIGHBOR_TOP_CORNER: [8, 9, 10],
		TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER: [10, 11, 0]
	}

	if axis == TileSet.TILE_OFFSET_AXIS_VERTICAL:
		map = {
			TileSet.CELL_NEIGHBOR_RIGHT_CORNER: [2, 3, 4],
			TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER: [0, 1, 2],
			TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER: [10, 11, 0],
			TileSet.CELL_NEIGHBOR_LEFT_CORNER: [8, 9, 10],
			TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER: [6, 7, 8],
			TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER: [4, 5, 6]
		}

	if not map.has(bit):
		return []

	var poly: Array[Vector2] = []
	for i in map[bit]:
		poly.append(points[i])

	return _mirror_inner_polygon(poly)


func _half_offset_side(size: Vector2i, overlap: float, axis: int, bit: int) -> Array[Vector2]:
	var points := [
		Vector2(3, 3 * (1 - overlap * 2)),
		Vector2(0, 3),
		Vector2(-3, 3 * (1 - overlap * 2)),
		Vector2(-3, -3 * (1 - overlap * 2)),
		Vector2(0, -3),
		Vector2(3, -3 * (1 - overlap * 2))
	]

	var unit := Vector2(size) / 6.0

	if axis == TileSet.TILE_OFFSET_AXIS_VERTICAL:
		for i in points.size():
			points[i] = Vector2(points[i].y, points[i].x)

	points = _scale_points(points, unit)

	var map := {
		TileSet.CELL_NEIGHBOR_RIGHT_SIDE: [5, 0],
		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: [0, 1],
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: [1, 2],
		TileSet.CELL_NEIGHBOR_LEFT_SIDE: [2, 3],
		TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: [3, 4],
		TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: [4, 5]
	}

	if axis == TileSet.TILE_OFFSET_AXIS_VERTICAL:
		map = {
			TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE: [0, 1],
			TileSet.CELL_NEIGHBOR_BOTTOM_SIDE: [5, 0],
			TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE: [4, 5],
			TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE: [3, 4],
			TileSet.CELL_NEIGHBOR_TOP_SIDE: [2, 3],
			TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE: [1, 2]
		}

	if not map.has(bit):
		return []

	var poly: Array[Vector2] = []
	for i in map[bit]:
		poly.append(points[i])

	return _mirror_inner_polygon(poly)


func _rect_to_polygon(rect: Rect2) -> Array[Vector2]:
	return [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]


func _scale_points(points: Array, scale: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for p in points:
		result.append(p * scale)
	return result


func _mirror_inner_polygon(poly: Array[Vector2]) -> Array[Vector2]:
	var half := poly.size()
	for i in range(half):
		poly.append(poly[half - 1 - i] / 3.0)
	return poly
