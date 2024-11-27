class_name TileSetCustom
extends RefCounted

## A Tileset is a collection of tiles, used by [LayerTileMap]s and [CelTileMap]s.
## The tileset contains the [Project] that it is being used by, its [member name].
## the size of each individual tile, and the collection of [TileSetCustom.Tile]s itself.
## Not to be confused with [TileSet], which is a Godot class.

## Emitted every time the tileset changes, such as when a tile is added, removed or replaced.
## The [CelTileMap] that the changes are coming from is referenced in the [param cel] parameter.
signal updated(cel: CelTileMap)

## The [Project] the tileset is being used by.
var project: Project
## The tileset's name.
var name := ""
## The size of each individual tile.
var tile_size: Vector2i
## The collection of tiles in the form of an [Array] of type [TileSetCustom.Tile].
var tiles: Array[Tile] = []


## An internal class of [TileSetCustom], which contains data used by individual tiles of a tileset.
class Tile:
	## The [Image] tile itself.
	var image: Image
	## The mode that was used when this tile was added to the tileset.
	var mode_added: TileSetPanel.TileEditingMode
	## The amount of tiles this tile is being used in tilemaps.
	var times_used := 1
	## The step number of undo/redo when this tile was added to the tileset.
	var undo_step_added := 0

	func _init(
		_image: Image, _mode_added: TileSetPanel.TileEditingMode, _undo_step_added := 0
	) -> void:
		image = _image
		mode_added = _mode_added
		undo_step_added = _undo_step_added

	## A method that checks if the tile should be removed from the tileset.
	## Returns [code]true[/code] if the current undo step is less than [member undo_step_added],
	## which essentially means that the tile always gets removed if the user undos to the point
	## the tile was added to the tileset.
	## Otherwise, it returns [code]true[/code] if [member mode_added] is not equal to
	## [enum TileSetPanel.TileEditingMode.STACK] and the amount of [member times_used] is 0.
	func can_be_removed(project: Project) -> bool:
		if project.undos < undo_step_added:
			return true
		return mode_added != TileSetPanel.TileEditingMode.STACK and times_used <= 0


func _init(_tile_size: Vector2i, _project: Project, _name := "") -> void:
	tile_size = _tile_size
	project = _project
	name = _name
	var empty_image := Image.create_empty(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
	tiles.append(Tile.new(empty_image, TileSetPanel.tile_editing_mode))


## Adds a new [param image] as a tile to the tileset.
## The [param cel] parameter references the [CelTileMap] that this change is coming from,
## and the [param edit_mode] parameter contains the tile editing mode at the time of this change.
func add_tile(image: Image, cel: CelTileMap, edit_mode: TileSetPanel.TileEditingMode) -> void:
	var tile := Tile.new(image, edit_mode, project.undos)
	tiles.append(tile)
	updated.emit(cel)


## Adds a new [param image] as a tile in a given [param position] in the tileset.
## The [param cel] parameter references the [CelTileMap] that this change is coming from,
## and the [param edit_mode] parameter contains the tile editing mode at the time of this change.
func insert_tile(
	image: Image, position: int, cel: CelTileMap, edit_mode: TileSetPanel.TileEditingMode
) -> void:
	var tile := Tile.new(image, edit_mode, project.undos)
	tiles.insert(position, tile)
	updated.emit(cel)


## Reduces a tile's [member TileSetCustom.Tile.times_used] by one,
## in a given [param index] in the tileset.
## If the times that tile is used reaches 0 and it can be removed,
## it is being removed from the tileset by calling [method remove_tile_at_index].
## Returns [code]true[/code] if the tile has been removed.
## The [param cel] parameter references the [CelTileMap] that this change is coming from.
func unuse_tile_at_index(index: int, cel: CelTileMap) -> bool:
	tiles[index].times_used -= 1
	if tiles[index].can_be_removed(project):
		remove_tile_at_index(index, cel)
		return true
	return false


## Removes a tile in a given [param index] from the tileset.
## The [param cel] parameter references the [CelTileMap] that this change is coming from.
func remove_tile_at_index(index: int, cel: CelTileMap) -> void:
	tiles.remove_at(index)
	updated.emit(cel)


## Replaces a tile in a given [param index] in the tileset with a [param new_tile].
## The [param cel] parameter references the [CelTileMap] that this change is coming from.
func replace_tile_at(new_tile: Image, index: int, cel: CelTileMap) -> void:
	tiles[index].image.copy_from(new_tile)
	updated.emit(cel)


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
		if tile.can_be_removed(project):
			remove_tile_at_index(i, cel)
			tile_removed = true
	return tile_removed


## Serializes the data of this class into the form of a [Dictionary],
## which is used so the data can be stored in pxo files.
func serialize() -> Dictionary:
	return {"name": name, "tile_size": tile_size, "tile_amount": tiles.size()}


## Deserializes the data of a given [member dict] [Dictionary] into class data,
## which is used so data can be loaded from pxo files.
func deserialize(dict: Dictionary) -> void:
	name = dict.get("name", name)
	tile_size = str_to_var("Vector2i" + dict.get("tile_size"))
