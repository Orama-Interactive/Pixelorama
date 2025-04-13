class_name AudioCel
extends BaseCel
## A class for the properties of cels in AudioLayers.
## The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).


func _init(_opacity := 1.0) -> void:
	opacity = _opacity
	image_texture = ImageTexture.new()


func get_image() -> Image:
	var image := Global.current_project.new_empty_image()
	return image


func get_class_name() -> String:
	return "AudioCel"
