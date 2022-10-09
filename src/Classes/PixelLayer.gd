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
	dict["linked_cels"] = []
	return dict


func deserialize(dict: Dictionary) -> void:
	.deserialize(dict)
	new_cels_linked = dict.new_cels_linked

	if dict.has("linked_cel") and not dict["linked_cel"].empty():  # Old linked cel system
		cel_link_sets = [[]]
		for linked_cel_index in dict["linked_cels"]:
			var linked_cel: PixelCel = project.frames[linked_cel_index].cels[index] # TODO 0: Do I have my index at this point?
			cel_link_sets[0].append(linked_cel)
			linked_cel.image = cel_link_sets[0][0].image
			linked_cel.image_texture = cel_link_sets[0][0].image_texture


func new_empty_cel() -> BaseCel:
	var image := Image.new()
	image.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
	return PixelCel.new(image)


func copy_cel(frame_index: int, linked: bool) -> BaseCel:
	if linked and not linked_cels.empty():
		var cel: PixelCel = linked_cels[0].cels[index]
		return PixelCel.new(cel.image, cel.opacity, cel.image_texture)
	else:
		var cel: PixelCel = project.frames[frame_index].cels[index]
		var copy_image := Image.new()
		copy_image.copy_from(cel.image)
		return PixelCel.new(copy_image, cel.opacity)


func copy_all_cels() -> Array:
	var cels := []

	var linked_image: Image
	var linked_texture: ImageTexture
	if not linked_cels.empty():
		var cel: PixelCel = linked_cels[0].cels[index]
		linked_image = Image.new()
		linked_image.copy_from(cel.image)
		linked_texture = ImageTexture.new()

	for frame in project.frames:
		var cel: PixelCel = frame.cels[index]
		if linked_cels.has(frame):
			cels.append(PixelCel.new(linked_image, cel.opacity, linked_texture))
		else:
			var copy_image := Image.new()
			copy_image.copy_from(cel.image)
			cels.append(PixelCel.new(copy_image, cel.opacity))
	return cels


func can_layer_get_drawn() -> bool:
	return is_visible_in_hierarchy() && !is_locked_in_hierarchy()


func instantiate_layer_button() -> Node:
	return Global.pixel_layer_button_node.instance()
