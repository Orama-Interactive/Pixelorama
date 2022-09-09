class_name GroupCel
extends BaseCel
# A class for the properties of cels in GroupLayers.
# The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).

func _init(_opacity := 1.0) -> void:
	opacity = _opacity


func get_image() -> Image:
	# TODO H: This can be used for copying selections or picking colors... Can maybe make from texture data?
	return Image.new()


func create_cel_button() -> Node:
	return Global.group_cel_button_node.instance()
