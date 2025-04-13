class_name PixelLayer
extends BaseLayer
## A class for standard pixel layer properties.


func _init(_project: Project, _name := "") -> void:
	project = _project
	name = _name


# Overridden Methods:


func serialize() -> Dictionary:
	var dict := super.serialize()
	dict["type"] = get_layer_type()
	dict["new_cels_linked"] = new_cels_linked
	return dict


func deserialize(dict: Dictionary) -> void:
	super.deserialize(dict)
	new_cels_linked = dict.new_cels_linked


func get_layer_type() -> int:
	return Global.LayerTypes.PIXEL


func new_empty_cel() -> BaseCel:
	var format := project.get_image_format()
	var is_indexed := project.is_indexed()
	var image := ImageExtended.create_custom(
		project.size.x, project.size.y, false, format, is_indexed
	)
	return PixelCel.new(image)


func new_cel_from_image(image: Image) -> PixelCel:
	var pixelorama_image := ImageExtended.new()
	pixelorama_image.copy_from_custom(image, project.is_indexed())
	return PixelCel.new(pixelorama_image)


func can_layer_get_drawn() -> bool:
	return is_visible_in_hierarchy() && !is_locked_in_hierarchy()
