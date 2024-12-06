class_name LayerTileMap
extends PixelLayer

## A layer type for 2D tile-based maps.
## A LayerTileMap uses a [TileSetCustom], which is then by all of its [CelTileMap]s.
## This class doesn't hold any actual tilemap data, as they are different in each cel.
## For this reason, that data is being handled by the [CelTileMap] class.
## Not to be confused with [TileMapLayer], which is a Godot node.

## The [TileSetCustom] that this layer uses.
## Internally, this class doesn't make much use of this.
## It's mostly only used to be passed down to the layer's [CelTileMap]s.
var tileset: TileSetCustom


func _init(_project: Project, _tileset: TileSetCustom, _name := "") -> void:
	super._init(_project, _name)
	tileset = _tileset
	if not project.tilesets.has(tileset) and is_instance_valid(tileset):
		project.add_tileset(tileset)


# Overridden Methods:
func serialize() -> Dictionary:
	var dict := super.serialize()
	dict["tileset_index"] = project.tilesets.find(tileset)
	return dict


func deserialize(dict: Dictionary) -> void:
	super.deserialize(dict)
	new_cels_linked = dict.new_cels_linked
	var tileset_index = dict.get("tileset_index")
	tileset = project.tilesets[tileset_index]


func get_layer_type() -> int:
	return Global.LayerTypes.TILEMAP


func new_empty_cel() -> BaseCel:
	var format := project.get_image_format()
	var is_indexed := project.is_indexed()
	var image := ImageExtended.create_custom(
		project.size.x, project.size.y, false, format, is_indexed
	)
	return CelTileMap.new(tileset, image)


func new_cel_from_image(image: Image) -> PixelCel:
	var image_extended := ImageExtended.new()
	image_extended.copy_from_custom(image, project.is_indexed())
	return CelTileMap.new(tileset, image_extended)


func set_name_to_default(number: int) -> void:
	name = tr("Tilemap") + " %s" % number
