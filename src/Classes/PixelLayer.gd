class_name PixelLayer
extends BaseLayer
# A class for standard pixel layer properties.


func _init(_project, _name := "") -> void:
	project = _project
	name = _name


# Overridden Methods:


func serialize() -> Dictionary:
	var dict = .serialize()
	dict["type"] = Global.LayerTypes.PIXEL
	dict["new_cels_linked"] = new_cels_linked
	return dict


func deserialize(dict: Dictionary) -> void:
	.deserialize(dict)
	new_cels_linked = dict.new_cels_linked


func new_empty_cel() -> BaseCel:
	var image := Image.new()
	image.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
	return PixelCel.new(image)


func can_layer_get_drawn() -> bool:
	return is_visible_in_hierarchy() && !is_locked_in_hierarchy()


func instantiate_layer_button() -> Node:
	return Global.pixel_layer_button_node.instance()
