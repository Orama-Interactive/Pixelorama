class_name BaseCel
extends Reference
# Base class for cel properties.
# The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).

var opacity: float


# Functions to override:

# TODO H: Should this be the case?
# Each Cel type should have a get_image function, which will either return
# its image data for PixelCels, or return a render of that cel. It's meant
# for read-only usage of image data from any type of cel

func get_image() -> Image:
	return null


func save_image_data_to_pxo(_file: File) -> void:
	return


func load_image_data_from_pxo(_file: File, _project_size: Vector2) -> void:
	return


func copy() -> BaseCel:
	return null


func create_cel_button() -> Button:
	return null
