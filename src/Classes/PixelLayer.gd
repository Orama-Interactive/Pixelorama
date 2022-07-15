class_name PixelLayer
extends BaseLayer
# A class for standard pixel layer properties.

var new_cels_linked := false
var linked_cels := []  # Array of Frames
# TODO H: Should _init include project as a parameter? (for all Layer types)
func _init(_name := "") -> void:
	name = _name


# Overridden Functions:

func serialize() -> Dictionary:
	var dict = .serialize()
	dict["type"] = Global.LayerTypes.PIXEL
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


func copy_cel(frame_index: int, new_content: bool) -> BaseCel:
	var cel: PixelCel = project.frames[frame_index].cels[index]
	if new_content:
		var copy_image := Image.new()
		copy_image.copy_from(cel.image)
		return PixelCel.new(copy_image, cel.opacity)
	else:
		return PixelCel.new(cel.image, cel.opacity, cel.image_texture)


func copy_all_cels(new_content: bool) -> Array:
	var cels := []

	var linked_image: Image
	var linked_texture: ImageTexture
	if not linked_cels.empty():
		var cel: PixelCel = linked_cels[0].cels[index]
		if new_content:
			linked_image = Image.new()
			linked_image.copy_from(cel.image)
			linked_texture = ImageTexture.new()
		else:
			linked_image = cel.image
			linked_texture = cel.image_texture

	for frame in project.frames:
		var cel: PixelCel = frame.cels[index]
		if linked_cels.has(frame):
			cels.append(PixelCel.new(linked_image, cel.opacity, linked_texture))
		elif new_content:
			var copy_image := Image.new()
			copy_image.copy_from(cel.image)
			cels.append(PixelCel.new(copy_image, cel.opacity))
		else:
			cels.append(PixelCel.new(cel.image, cel.opacity, cel.image_texture))
	return cels


func can_layer_get_drawn() -> bool:
	return is_visible_in_hierarchy() && !is_locked_in_hierarchy()


func create_layer_button() -> Node:
	return Global.pixel_layer_button_node.instance()
