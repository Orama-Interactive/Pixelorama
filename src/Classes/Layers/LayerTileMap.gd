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
	var format := project.get_image_format()
	var is_indexed := project.is_indexed()
	var image := ImageExtended.create_custom(
		project.size.x, project.size.y, false, format, is_indexed
	)
	return CelTileMap.new(tileset, image)
