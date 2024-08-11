class_name GroupLayer
extends BaseLayer
## A class for group layer properties

var expanded := true


func _init(_project: Project, _name := "") -> void:
	project = _project
	name = _name


## Blends all of the images of children layer of the group layer into a single image.
func blend_children(frame: Frame, origin := Vector2i.ZERO, apply_effects := true) -> Image:
	var image := Image.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
	var children := get_children(false)
	if children.size() <= 0:
		return image
	var blend_rect := Rect2i(Vector2i.ZERO, project.size)
	var textures: Array[Image] = []
	var metadata_image := Image.create(children.size(), 4, false, Image.FORMAT_RG8)
	for i in children.size():
		var layer := children[i]
		if not layer.is_visible_in_hierarchy():
			continue
		var cel := frame.cels[layer.index]
		if layer is GroupLayer:
			var blended_children: Image = layer.blend_children(frame, origin)
			if DisplayServer.get_name() == "headless":
				image.blend_rect(blended_children, blend_rect, origin)
			else:
				textures.append(blended_children)
				DrawingAlgos.set_layer_metadata_image(layer, cel, metadata_image, i)
		else:
			if DisplayServer.get_name() == "headless":
				DrawingAlgos.blend_layers_headless(image, project, layer, cel, origin)
			else:
				var cel_image: Image
				if apply_effects:
					cel_image = layer.display_effects(cel)
				else:
					cel_image = cel.get_image()
				textures.append(cel_image)
				DrawingAlgos.set_layer_metadata_image(layer, cel, metadata_image, i)
				if origin != Vector2i.ZERO:
					# Only used as a preview for the move tool, when used on a group's children
					var test_array := [project.frames.find(frame), project.layers.find(layer)]
					if test_array in project.selected_cels:
						var origin_fixed := Vector2(origin).abs() / Vector2(cel_image.get_size())
						metadata_image.set_pixel(
							i, 2, Color(origin_fixed.x, origin_fixed.y, 0.0, 0.0)
						)

	if DisplayServer.get_name() != "headless" and textures.size() > 0:
		var texture_array := Texture2DArray.new()
		texture_array.create_from_images(textures)
		var params := {
			"layers": texture_array,
			"metadata": ImageTexture.create_from_image(metadata_image),
			"origin_x_positive": origin.x > 0,
			"origin_y_positive": origin.y > 0,
		}
		var gen := ShaderImageEffect.new()
		gen.generate_image(image, DrawingAlgos.blend_layers_shader, params, project.size)
		if apply_effects:
			image = display_effects(frame.cels[index], image)
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
