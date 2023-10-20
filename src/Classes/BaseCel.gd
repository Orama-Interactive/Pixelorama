class_name BaseCel
extends RefCounted
## Base class for cel properties.
## The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).

signal texture_changed  ## Emitted whenever cel's tecture is changed

var opacity := 1.0  ## Opacity/Transparency of the cel.
## The image stored in the cel.
var image_texture: Texture2D:
	get = _get_image_texture
## If the cel is linked then this contains a reference to the link set [Dictionary] this cel is in:
## [param { "cels": Array, "hue": float }].
## [br] If the cel is not linked then it is [code]null[/code].
var link_set = null  # { "cels": Array, "hue": float } or null
var transformed_content: Image  ## Used in transformations (moving, scaling etc with selections).

# Methods to Override:


func _get_image_texture() -> Texture2D:
	return image_texture


## The content methods deal with the unique content of each cel type. For example, an Image for
## PixelCel, or a Dictionary of settings for a procedural layer type, and null for Groups.
## Can be used for linking/unlinking cels, copying, and deleting content
func get_content() -> Variant:
	return null


## The content methods deal with the unique content of each cel type. For example, an Image for
## PixelCel, or a Dictionary of settings for a procedural layer type, and null for Groups.
## Can be used for linking/unlinking cels, copying, and deleting content.
func set_content(_content, _texture: ImageTexture = null) -> void:
	return


## The content methods deal with the unique content of each cel type. For example, an Image for
## PixelCel, or a Dictionary of settings for a procedural layer type, and null for Groups.
## Can be used to delete the content of the cel with [method set_content]
## (using the old content from get_content as undo data).
func create_empty_content() -> Variant:
	return []


## The content methods deal with the unique content of each cel type. For example, an Image for
## PixelCel, or a Dictionary of settings for a procedural layer type, and null for Groups.
## Can be used for creating copy content for copying cels or unlinking cels.
func copy_content() -> Variant:
	return []


## Returns the image of image based cel types, or a render for procedural types.
## It's meant for read-only usage of image data, such as copying selections or color picking.
func get_image() -> Image:
	return null


## Used to update the texture of the cel.
func update_texture() -> void:
	texture_changed.emit()
	if link_set != null:
		var frame := Global.current_project.current_frame
		# This check is needed in case the user has selected multiple cels that are also linked
		if self in Global.current_project.frames[frame].cels:
			for cel in link_set["cels"]:
				cel.texture_changed.emit()


## Returns a curated [Dictionary] from the cel data.
func serialize() -> Dictionary:
	return {"opacity": opacity}


## Set the cel data according to a curated [Dictionary] obtained from [method serialize].
func deserialize(dict: Dictionary) -> void:
	opacity = dict["opacity"]


## Used to save cel image/thumbnail during saving of a pxo file.
func save_image_data_to_pxo(_file: FileAccess) -> void:
	return


## Used to load cel image/thumbnail during loading of a pxo file.
func load_image_data_from_pxo(_file: FileAccess, _project_size: Vector2i) -> void:
	return


## Used to perform cleanup after a cel is removed.
func on_remove() -> void:
	pass


## Returns an instance of the cel button that will be added to the timeline.
func instantiate_cel_button() -> Node:
	return null


## Returns to get the type of the cel class.
func get_class_name() -> String:
	return "BaseCel"
