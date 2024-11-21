class_name TileSetCustom
extends RefCounted

signal updated

var name := ""
var tile_size: Vector2i
var tiles: Array[Tile] = []


class Tile:
	var image: Image
	var mode_added: TileSetPanel.TileEditingMode

	func _init(_image: Image, _mode_added: TileSetPanel.TileEditingMode) -> void:
		image = _image
		mode_added = _mode_added


func _init(_tile_size: Vector2i, _name := "") -> void:
	tile_size = _tile_size
	name = _name
	#var indices_x := ceili(float(_project_size.x) / tile_size.x)
	#var indices_y := ceili(float(_project_size.y) / tile_size.y)
	#tiles.resize(indices_x * indices_y + 1)
	var empty_image := Image.create_empty(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
	tiles.append(Tile.new(empty_image, TileSetPanel.tile_editing_mode))


func add_tile(image: Image, edit_mode: TileSetPanel.TileEditingMode) -> void:
	var tile := Tile.new(image, edit_mode)
	tiles.append(tile)
	updated.emit()


func insert_tile(image: Image, position: int, edit_mode: TileSetPanel.TileEditingMode) -> void:
	var tile := Tile.new(image, edit_mode)
	tiles.insert(position, tile)
	updated.emit()


func remove_tile_at_index(index: int) -> void:
	tiles.remove_at(index)
	updated.emit()


func replace_tile_at(new_tile: Image, index: int) -> void:
	tiles[index].image.copy_from(new_tile)
	updated.emit()
