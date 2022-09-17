class_name GroupCel
extends BaseCel
# A class for the properties of cels in GroupLayers.
# The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).


func _init(_opacity := 1.0) -> void:
	opacity = _opacity
	image_texture = ImageTexture.new()


func get_image() -> Image:
	var image = Image.new()
	image.create(
		Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_RGBA8
	)
	return image


func instantiate_cel_button() -> Node:
	return Global.group_cel_button_node.instance()
