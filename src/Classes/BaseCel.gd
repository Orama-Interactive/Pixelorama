class_name BaseCel
extends RefCounted
## Base class for cel properties.
## The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).

signal texture_changed

var opacity := 1.0
var image_texture: Texture2D:
	get = _get_image_texture
# If the cel is linked a ref to the link set Dictionary this cel is in, or null if not linked:
var link_set = null  # { "cels": Array, "hue": float } or null
var transformed_content: Image  # Used in transformations (moving, scaling etc with selections)

# Methods to Override:


func _get_image_texture() -> Texture2D:
	return image_texture


# The content methods deal with the unique content of each cel type. For example, an Image for
# PixelLayers, or a Dictionary of settings for a procedural layer type, and null for Groups.
# Can be used for linking/unlinking cels, copying, and deleting content
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
# It's meant for read-only usage of image data, such as copying selections or color picking.
func get_image() -> Image:
	return null


func update_texture() -> void:
	texture_changed.emit()
	if link_set != null:
		var frame: int = Global.current_project.current_frame
		# This check is needed in case the user has selected multiple cels that are also linked
		if self in Global.current_project.frames[frame].cels:
			for cel in link_set["cels"]:
				cel.texture_changed.emit()


func serialize() -> Dictionary:
	return {"opacity": opacity}


func deserialize(dict: Dictionary) -> void:
	opacity = dict["opacity"]


func save_image_data_to_pxo(_file: FileAccess) -> void:
	return


func load_image_data_from_pxo(_file: FileAccess, _project_size: Vector2) -> void:
	return


func on_remove() -> void:
	pass


func instantiate_cel_button() -> Node:
	return null


func get_class_name() -> String:
	return "BaseCel"
