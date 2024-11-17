class_name LayerTileMap
extends PixelLayer

var tileset: TileSetCustom


func _init(_project: Project, _tileset: TileSetCustom, _name := "") -> void:
	super._init(_project, _name)
	tileset = _tileset
	if not project.tilesets.has(tileset):
		project.add_tileset(tileset)


# Overridden Methods:
func get_layer_type() -> int:
	return Global.LayerTypes.TILEMAP


func new_empty_cel() -> BaseCel:
	var image := Image.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
	return CelTileMap.new(tileset, image)
