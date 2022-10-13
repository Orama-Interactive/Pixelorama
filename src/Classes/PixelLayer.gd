class_name PixelLayer
extends BaseLayer
# A class for standard pixel layer properties.

var linked_cels := [] # TODO 0: Remove when possible

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

	if dict.has("linked_cels") and not dict["linked_cels"].empty():  # Old linked cel system
		cel_link_sets = [[]]
		for linked_cel_index in dict["linked_cels"]:
			var linked_cel: PixelCel = project.frames[linked_cel_index].cels[index] # TODO 0: Do I have my index at this point?
			cel_link_sets[0].append(linked_cel)
			linked_cel.link_set = cel_link_sets[0]
			linked_cel.image = cel_link_sets[0][0].image
			linked_cel.image_texture = cel_link_sets[0][0].image_texture


func new_empty_cel() -> BaseCel:
	var image := Image.new()
	image.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
	return PixelCel.new(image)


func can_layer_get_drawn() -> bool:
	return is_visible_in_hierarchy() && !is_locked_in_hierarchy()


func instantiate_layer_button() -> Node:
	return Global.pixel_layer_button_node.instance()
