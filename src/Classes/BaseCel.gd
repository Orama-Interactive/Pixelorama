class_name BaseCel
extends Reference
# Base class for cel properties.
# The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).

var opacity: float
var image_texture: ImageTexture

# Methods to Override:

# TODO H: Check if copying cels can use the content methods

# TODO H1: These content methods need good doc comments:
#			COMMENT FROM THE IDEA TODO COMMENT (MAY BE USEFUL FOR WRITING COMMENTS)
#			- get_content will return certain content of the cel (should metadata be included?)
#			- set_content will set the content (same structure as get_content returns)
#			- delete/clear_content will erase it,
#			- using get_content and set_content could become useful for linking/unlinking cels, and will be reversible for undo
#				- this can be used to replace copy_cel and copy_all_cels in layer classes
#			- using all 3 will allow you to delete content, and undo it in cel button
#				= making this generic and should solve issues with combing cel_button scripts into 1
#			- copy_content may also be a useful method to have

func set_content(content) -> void:
	return


func get_content():
	return []


func create_empty_content():
	return []


func copy_content():
	return []


# Returns the image var for image based cel types, or a render for procedural types.
# It's meant for read-only usage of image data, such as copying selections or color picking.
func get_image() -> Image:
	return null


func update_texture() -> void:
	return


func save_image_data_to_pxo(_file: File) -> void:
	return


func load_image_data_from_pxo(_file: File, _project_size: Vector2) -> void:
	return


func create_cel_button() -> Node:
	return null
