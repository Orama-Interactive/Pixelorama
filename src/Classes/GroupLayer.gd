class_name GroupLayer
extends BaseLayer
# A class for group layer properties

var expanded := true


func _init(_project, _name := ""):
	project = _project
	name = _name


func blend_children(frame: Frame, origin := Vector2.ZERO) -> Image:
	var image := Image.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
	var children := get_children(false)
	var blend_rect := Rect2(Vector2.ZERO, project.size)
	for layer in children:
		if not layer.is_visible_in_hierarchy():
			continue
		if layer is PixelLayer:
			var cel: PixelCel = frame.cels[layer.index]
			var cel_image := Image.new()
			cel_image.copy_from(cel.image)
			if cel.opacity < 1:  # If we have cel transparency
				for xx in cel_image.get_size().x:
					for yy in cel_image.get_size().y:
						var pixel_color := cel_image.get_pixel(xx, yy)
						var alpha: float = pixel_color.a * cel.opacity
						cel_image.set_pixel(
							xx, yy, Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha)
						)
			image.blend_rect(cel_image, blend_rect, origin)
		else:  # Only if layer is GroupLayer, cannot define this due to cyclic reference error
			image.blend_rect(layer.blend_children(frame, origin), blend_rect, origin)
	return image


# Overridden Methods:


func serialize() -> Dictionary:
	var data = super.serialize()
	data["type"] = Global.LayerTypes.GROUP
	data["expanded"] = expanded
	return data


func deserialize(dict: Dictionary) -> void:
	super.deserialize(dict)
	expanded = dict.expanded


func new_empty_cel() -> BaseCel:
	return GroupCel.new()


func set_name_to_default(number: int) -> void:
	name = tr("Group") + " %s" % number


#func accepts_child(_layer: BaseLayer) -> bool:
func accepts_child(_layer) -> bool:
	return true


func instantiate_layer_button() -> Node:
	return Global.group_layer_button_node.instantiate()
