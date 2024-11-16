class_name TileSetCustom
extends RefCounted

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
