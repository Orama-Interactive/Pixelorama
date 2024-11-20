class_name TileSetCustom
extends RefCounted

signal updated

var name := ""
var tile_size: Vector2i
var tiles: Array[Image] = []


func _init(_tile_size: Vector2i, _name := "") -> void:
	tile_size = _tile_size
	name = _name
	#var indices_x := ceili(float(_project_size.x) / tile_size.x)
	#var indices_y := ceili(float(_project_size.y) / tile_size.y)
	#tiles.resize(indices_x * indices_y + 1)
	var empty_image := Image.create_empty(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
	tiles.append(empty_image)


func add_tile(tile: Image) -> void:
	tiles.append(tile)
	updated.emit()


func insert_tile(tile: Image, position: int) -> void:
	tiles.insert(position, tile)
	updated.emit()


func remove_tile_at_index(index: int) -> void:
	tiles.remove_at(index)
	updated.emit()


func replace_tile_at(new_tile: Image, index: int) -> void:
	tiles[index].copy_from(new_tile)
	updated.emit()
