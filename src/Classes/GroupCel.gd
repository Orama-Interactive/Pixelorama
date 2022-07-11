class_name GroupCel
extends BaseCel
# A class for the properties of cels in GroupLayers.
# The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).

func _init(_opacity := 1.0) -> void:
	opacity = _opacity


func get_image() -> Image:
	# TODO H: render the material as an image and return it
	return Image.new()


func copy() -> BaseCel:
	# Using get_script over the class name prevents a cyclic reference:
	return get_script().new(opacity)


func create_cel_button() -> Node:
	return Global.group_cel_button_node.instance()
