class_name BaseCel
extends Reference
# Base class for cel properties.
# The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).

var opacity: float
var image_texture: ImageTexture
# If the cel is linked a ref to the link set Dictionary this cel is in, or null if not linked:
var link_set = null  # { "cels": Array, "hue": float } or null

# Methods to Override:


# The content methods deal with the unique content of each cel type. For example, an
# Image for PixelCels, an Array of VectorShapes for VectorCels, and null for GroupCels.
# Can be used fo linking/unlinking cels, copying, and deleting content
func get_content():
	return null


func set_content(_content, _texture: ImageTexture = null) -> void:
	return


# Can be used to delete the content of the cel with set_content
# (using the old content from get_content as undo data)
func create_empty_content():
	return []


# Can be used for creating copy content for copying cels or unlinking cels
func copy_content():
	return []


# Returns the image var for image based cel types, or a render for procedural types.
# Good for reading image data of procedural cels, such as copying selections or color picking.
func get_image() -> Image:
	return null


func update_texture() -> void:
	return


func save_image_data_to_pxo(_file: File) -> void:
	return


func load_image_data_from_pxo(_file: File, _project_size: Vector2) -> void:
	return


func instantiate_cel_button() -> Node:
	return null
