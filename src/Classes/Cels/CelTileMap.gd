class_name CelTileMap
extends PixelCel

enum TileEditingMode { MANUAL, AUTO, STACK }

var tileset: TileSetCustom
var tile_editing_mode := TileEditingMode.MANUAL
var indices := PackedInt32Array()
var indices_x: int
var indices_y: int


func _init(_tileset: TileSetCustom, _image := Image.new(), _opacity := 1.0) -> void:
	super._init(_image, _opacity)
	tileset = _tileset
	indices_x = ceili(float(get_image().get_width()) / tileset.tile_size.x)
	indices_y = ceili(float(get_image().get_height()) / tileset.tile_size.y)
	indices.resize(indices_x * indices_y)


func update_texture() -> void:
	super.update_texture()
	for i in indices.size():
		var x_coord := float(tileset.tile_size.x) * (i % indices_x)
		var y_coord := float(tileset.tile_size.y) * (i / indices_x)
		var rect := Rect2i(Vector2i(x_coord, y_coord), tileset.tile_size)
		var image_portion := image.get_region(rect)
		var index := indices[i]
		if tile_editing_mode == TileEditingMode.MANUAL:
			if index == 0:
				continue
			if image_portion.get_data() != tileset.tiles[index].get_data():
				tileset.tiles[index].copy_from(image_portion)
		elif tile_editing_mode == TileEditingMode.AUTO:
			if index == 0:
				continue
		else:
			if not image_portion.is_invisible():
				tileset.tiles.append(image_portion)
				indices[i] = tileset.tiles.size()


func get_class_name() -> String:
	return "CelTileMap"
