class_name GroupCel
extends BaseCel
# A class for the properties of cels in GroupLayers.
# The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).

var material := ShaderMaterial.new()

func _init(_opacity := 1.0) -> void:
	print("group cel added")
	opacity = _opacity


func get_image() -> Image:
	# TODO: render the material as an image and return it
	return Image.new()
