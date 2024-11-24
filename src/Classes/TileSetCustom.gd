class_name TileSetCustom
extends RefCounted

signal updated

var project: Project
var name := ""
var tile_size: Vector2i
var tiles: Array[Tile] = []


class Tile:
	var image: Image
	var mode_added: TileSetPanel.TileEditingMode
	var times_used := 1
	var undo_step_added := 0

	func _init(
		_image: Image, _mode_added: TileSetPanel.TileEditingMode, _undo_step_added := 0
	) -> void:
		image = _image
		mode_added = _mode_added
		undo_step_added = _undo_step_added

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


func add_tile(image: Image, edit_mode: TileSetPanel.TileEditingMode) -> void:
	var tile := Tile.new(image, edit_mode, project.undos)
	tiles.append(tile)
	updated.emit()


func insert_tile(image: Image, position: int, edit_mode: TileSetPanel.TileEditingMode) -> void:
	var tile := Tile.new(image, edit_mode, project.undos)
	tiles.insert(position, tile)
	updated.emit()


func unuse_tile_at_index(index: int) -> bool:
	tiles[index].times_used -= 1
	if tiles[index].can_be_removed(project):
		remove_tile_at_index(index)
		return true
	return false


func remove_tile_at_index(index: int) -> void:
	tiles.remove_at(index)
	updated.emit()


func replace_tile_at(new_tile: Image, index: int) -> void:
	tiles[index].image.copy_from(new_tile)
	updated.emit()


func find_tile(image: Image) -> int:
	for i in tiles.size():
		var tile := tiles[i]
		if image.get_data() == tile.image.get_data():
			return i
	return -1


func remove_unused_tiles() -> bool:
	var tile_removed := false
	for i in range(tiles.size() - 1, 0, -1):
		var tile := tiles[i]
		if tile.can_be_removed(project):
			remove_tile_at_index(i)
			tile_removed = true
	return tile_removed


func serialize() -> Dictionary:
	return {"name": name, "tile_size": tile_size, "tile_amount": tiles.size()}


func deserialize(dict: Dictionary) -> void:
	name = dict.get("name", name)
	tile_size = str_to_var("Vector2i" + dict.get("tile_size"))
