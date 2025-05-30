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
## If [code]true[/code], users can only place tiles in the tilemap and not modify the tileset
## in any way, such as by drawing pixels.
var place_only_mode := false
## The size of each tile.
## Overwrites the [member tileset]'s tile size if [member place_only_mode] is [code]true[/code].
var tile_size := Vector2i(16, 16)
## The shape of each tile.
## Overwrites the [member tileset]'s tile shape if [member place_only_mode] is [code]true[/code].
var tile_shape := TileSet.TILE_SHAPE_SQUARE
## The layout of the tiles. Used when [member place_only_mode] is [code]true[/code].
var tile_layout := TileSet.TILE_LAYOUT_DIAMOND_DOWN
## For all half-offset shapes (Isometric & Hexagonal), determines the offset axis.
var tile_offset_axis := TileSet.TILE_OFFSET_AXIS_HORIZONTAL


func _init(_project: Project, _tileset: TileSetCustom, _name := "") -> void:
	super._init(_project, _name)
	set_tileset(_tileset)
	if not project.tilesets.has(tileset) and is_instance_valid(tileset):
		project.add_tileset(tileset)


func set_tileset(new_tileset: TileSetCustom) -> void:
	if tileset == new_tileset:
		return
	tileset = new_tileset
	if is_instance_valid(tileset):
		tile_size = tileset.tile_size
		tile_shape = tileset.tile_shape


func pass_variables_to_cel(cel: CelTileMap) -> void:
	cel.place_only_mode = place_only_mode
	cel.tile_size = tile_size
	cel.tile_shape = tile_shape
	cel.tile_layout = tile_layout
	cel.tile_offset_axis = tile_offset_axis
	if cel.place_only_mode:
		cel.queue_update_cel_portions(true)


# Overridden Methods:
func serialize() -> Dictionary:
	var dict := super.serialize()
	dict["tileset_index"] = project.tilesets.find(tileset)
	dict["place_only_mode"] = place_only_mode
	dict["tile_size"] = tile_size
	dict["tile_shape"] = tile_shape
	dict["tile_layout"] = tile_layout
	dict["tile_offset_axis"] = tile_offset_axis
	return dict


func deserialize(dict: Dictionary) -> void:
	super.deserialize(dict)
	new_cels_linked = dict.new_cels_linked
	var tileset_index = dict.get("tileset_index")
	tileset = project.tilesets[tileset_index]
	place_only_mode = dict.get("place_only_mode", place_only_mode)
	if dict.has("tile_size"):
		var tile_size_from_dict = dict.get("tile_size")
		if typeof(tile_size_from_dict) == TYPE_VECTOR2I:
			tile_size = tile_size_from_dict
		else:
			tile_size = str_to_var("Vector2i" + tile_size_from_dict)
	tile_shape = dict.get("tile_shape", tile_shape)
	tile_layout = dict.get("tile_layout", tile_layout)
	tile_offset_axis = dict.get("tile_offset_axis", tile_offset_axis)


func get_layer_type() -> int:
	return Global.LayerTypes.TILEMAP


func new_empty_cel() -> BaseCel:
	var format := project.get_image_format()
	var is_indexed := project.is_indexed()
	var image := ImageExtended.create_custom(
		project.size.x, project.size.y, false, format, is_indexed
	)
	var cel_tilemap := CelTileMap.new(tileset, image)
	pass_variables_to_cel(cel_tilemap)
	return cel_tilemap


func new_cel_from_image(image: Image) -> PixelCel:
	var image_extended := ImageExtended.new()
	image_extended.copy_from_custom(image, project.is_indexed())
	var cel_tilemap := CelTileMap.new(tileset, image_extended)
	pass_variables_to_cel(cel_tilemap)
	return cel_tilemap


func set_name_to_default(number: int) -> void:
	name = tr("Tilemap") + " %s" % number
