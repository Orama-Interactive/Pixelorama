class_name PixelLayer
extends BaseLayer
# A class for standard pixel layer properties.

var new_cels_linked := false
var linked_cels := []  # Array of Frames

func _init(_name := "") -> void:
	name = _name


func serialize() -> Dictionary:
	var dict = .serialize()
	dict["type"] = PIXEL_LAYER
	dict["new_cels_linked"] = new_cels_linked
	dict["linked_cels"] = []
	for cel in linked_cels:
		dict.linked_cels.append(project.frames.find(cel))
	return dict


func deserialize(dict: Dictionary) -> void:
	.deserialize(dict)
	new_cels_linked = dict.new_cels_linked

	for linked_cel_number in dict.linked_cels:
		linked_cels.append(project.frames[linked_cel_number])
		var linked_cel: PixelCel = project.frames[linked_cel_number].cels[index]
		linked_cel.image = linked_cels[0].cels[index].image
		linked_cel.image_texture = linked_cels[0].cels[index].image_texture


# Overridden Functions:

func can_layer_get_drawn() -> bool:
	return is_visible_in_hierarchy() && !is_locked_in_hierarchy()
