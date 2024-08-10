class_name GroupLayer
extends BaseLayer
## A class for group layer properties

var expanded := true


func _init(_project: Project, _name := "") -> void:
	project = _project
	name = _name


## Blends all of the images of children layer of the group layer into a single image.
func blend_children(frame: Frame, origin := Vector2i.ZERO) -> Image:
	var image := Image.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
	var children := get_children(false)
	if children.size() <= 0:
		return image
	var blend_rect := Rect2i(Vector2i.ZERO, project.size)
	var textures: Array[Image] = []
	var metadata_image := Image.create(children.size(), 4, false, Image.FORMAT_R8)
	for i in children.size():
		var layer := children[i]
		if not layer.is_visible_in_hierarchy():
			continue
		if layer is GroupLayer:
			var blended_children: Image = layer.blend_children(frame, origin)
			if DisplayServer.get_name() == "headless":
				image.blend_rect(blended_children, blend_rect, origin)
			else:
				textures.append(blended_children)
		else:
			var cel := frame.cels[layer.index]
			if DisplayServer.get_name() == "headless":
				DrawingAlgos.blend_layers_headless(image, project, layer, cel, origin)
			else:
				textures.append(display_effects(cel))
				DrawingAlgos.set_layer_metadata_image(layer, cel, metadata_image, i)

	if DisplayServer.get_name() != "headless":
		var texture_array := Texture2DArray.new()
		texture_array.create_from_images(textures)
		var params := {
			"layers": texture_array, "metadata": ImageTexture.create_from_image(metadata_image)
		}
		var gen := ShaderImageEffect.new()
		gen.generate_image(image, DrawingAlgos.blend_layers_shader, params, project.size)
	return image


# Overridden Methods:


func serialize() -> Dictionary:
	var data := super.serialize()
	data["type"] = get_layer_type()
	data["expanded"] = expanded
	return data


func deserialize(dict: Dictionary) -> void:
	super.deserialize(dict)
	expanded = dict.expanded


func get_layer_type() -> int:
	return Global.LayerTypes.GROUP


func new_empty_cel() -> BaseCel:
	return GroupCel.new()


func set_name_to_default(number: int) -> void:
	name = tr("Group") + " %s" % number


func accepts_child(_layer: BaseLayer) -> bool:
	return true
