class_name TileSetCustom
extends RefCounted

## A Tileset is a collection of tiles, used by [LayerTileMap]s and [CelTileMap]s.
## The tileset contains its [member name], the size of each individual tile,
## and the collection of [TileSetCustom.Tile]s itself.
## Not to be confused with [TileSet], which is a Godot class.

## Emitted every time the tileset changes, such as when a tile is added, removed or replaced.
## The [CelTileMap] that the changes are coming from is referenced in the [param cel] parameter.
signal updated(cel: CelTileMap, replace_index: int)

## The tileset's name.
var name := ""
## The size of each individual tile.
var tile_size: Vector2i
## The collection of tiles in the form of an [Array] of type [TileSetCustom.Tile].
var tiles: Array[Tile] = []
## If [code]true[/code], the code in [method handle_project_resize] does not execute.
## This variable is used to prevent multiple cels from clearing the tileset at the same time.
## In [method handle_project_resize], the variable is set to [code]true[/code], and then
## immediately set to [code]false[/code] in the next frame using [method Object.set_deferred].
var _tileset_has_been_cleared := false


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

	func _init(_image: Image) -> void:
		image = _image

	## A method that checks if the tile should be removed from the tileset.
	## Returns [code]true[/code] if the amount of [member times_used] is 0.
	func can_be_removed() -> bool:
		return times_used <= 0

	func serialize() -> Dictionary:
		return {"times_used": times_used, "probability": probability, "user_data": user_data}

	func deserialize(dict: Dictionary, skip_times_used := false) -> void:
		if not skip_times_used:
			times_used = dict.get("times_used", times_used)
		probability = dict.get("probability", probability)
		user_data = dict.get("user_data", user_data)


func _init(_tile_size: Vector2i, _name := "", add_empty_tile := true) -> void:
	tile_size = _tile_size
	name = _name
	if add_empty_tile:
		var empty_image := Image.create_empty(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
		tiles.append(Tile.new(empty_image))


## Adds a new [param image] as a tile to the tileset.
## The [param cel] parameter references the [CelTileMap] that this change is coming from,
## and the [param edit_mode] parameter contains the tile editing mode at the time of this change.
func add_tile(image: Image, cel: CelTileMap, times_used := 1) -> void:
	var tile := Tile.new(image)
	tile.times_used = times_used
	tiles.append(tile)
	updated.emit(cel, -1)


## Adds a new [param image] as a tile in a given [param position] in the tileset.
## The [param cel] parameter references the [CelTileMap] that this change is coming from,
## and the [param edit_mode] parameter contains the tile editing mode at the time of this change.
func insert_tile(image: Image, position: int, cel: CelTileMap) -> void:
	var tile := Tile.new(image)
	tiles.insert(position, tile)
	updated.emit(cel, -1)


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
	updated.emit(cel, -1)


## Replaces a tile in a given [param index] in the tileset with a [param new_tile].
## The [param cel] parameter references the [CelTileMap] that this change is coming from.
func replace_tile_at(new_tile: Image, index: int, cel: CelTileMap) -> void:
	tiles[index].image.copy_from(new_tile)
	updated.emit(cel, index)


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
	var tile_removed := false
	for i in range(tiles.size() - 1, 0, -1):
		var tile := tiles[i]
		if tile.can_be_removed():
			remove_tile_at_index(i, cel)
			tile_removed = true
	return tile_removed


## Clears the used tiles of tileset. Called when the project gets resized,
## and tilemap cels are updating their size and clearing the tileset to re-create it.
func handle_project_resize(cel: CelTileMap) -> void:
	if _tileset_has_been_cleared:
		return
	for i in range(tiles.size() - 1, 0, -1):
		var tile := tiles[i]
		if tile.times_used > 0:
			tiles.erase(tile)
	updated.emit(cel, -1)
	_tileset_has_been_cleared = true
	set_deferred("_tileset_has_been_cleared", false)


## Returns the tilemap's info, such as its name and tile size and with a given
## [param tile_index], in the form of text.
func get_text_info(tile_index: int) -> String:
	var item_string := " %s (%s×%s)" % [tile_index, tile_size.x, tile_size.y]
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
		sum += tiles[i].probability
	var rand := randf_range(0.0, sum)
	var current := 0.0
	for i in selected_tile_indices:
		current += tiles[i].probability
		if current >= rand:
			return i
	return selected_tile_indices[0]


## Serializes the data of this class into the form of a [Dictionary],
## which is used so the data can be stored in pxo files.
func serialize() -> Dictionary:
	var dict := {"name": name, "tile_size": tile_size, "tile_amount": tiles.size()}
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
	var dict := {}
	for tile in tiles:
		var image_data := tile.image.get_data()
		dict[tile.image] = [image_data.compress(), image_data.size(), tile.serialize()]
	return dict


## Deserializes the data of each tile in [param dict], which is used by the undo/redo system.
func deserialize_undo_data(dict: Dictionary, cel: CelTileMap) -> void:
	tiles.resize(dict.size())
	var i := 0
	for image: Image in dict:
		var tile_data = dict[image]
		var buffer_size := tile_data[1] as int
		var tile_dictionary := tile_data[2] as Dictionary
		var image_data := (tile_data[0] as PackedByteArray).decompress(buffer_size)
		image.set_data(tile_size.x, tile_size.y, false, image.get_format(), image_data)
		tiles[i] = Tile.new(image)
		tiles[i].deserialize(tile_dictionary)
		i += 1
	updated.emit(cel, -1)
