class_name GroupCel
extends BaseCel
## A class for the properties of cels in GroupLayers.
## The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).


func _init(_opacity := 1.0) -> void:
	opacity = _opacity
	image_texture = ImageTexture.new()


func get_image() -> Image:
	var image := Image.create(
		Global.current_project.size.x,
		Global.current_project.size.y,
		false,
		Global.current_project.get_image_format()
	)
	return image


func get_class_name() -> String:
	return "GroupCel"
