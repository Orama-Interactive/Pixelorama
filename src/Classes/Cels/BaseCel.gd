class_name BaseCel
extends RefCounted
## Base class for cel properties.
## "Cel" is short for the term "celluloid" [url]https://en.wikipedia.org/wiki/Cel[/url].

signal texture_changed  ## Emitted whenever the cel's texture is changed

var opacity := 1.0  ## Opacity/Transparency of the cel.
## The image stored in the cel.
var image_texture: Texture2D:
	get = _get_image_texture
## If the cel is linked then this contains a reference to the link set [Dictionary] this cel is in:
## [param { "cels": Array, "hue": float }].
## [br] If the cel is not linked then it is [code]null[/code].
var link_set = null  # { "cels": Array, "hue": float } or null
var transformed_content: Image  ## Used in transformations (moving, scaling etc with selections).
## Used for individual cel ordering. Used for when cels need to be drawn above or below
## their corresponding layer.
var z_index := 0
var user_data := ""  ## User defined data, set in the cel properties.


func get_final_opacity(layer: BaseLayer) -> float:
	return layer.opacity * opacity


func get_frame(project: Project) -> Frame:
	for frame in project.frames:
		if frame.cels.has(self):
			return frame
	return null


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
func update_texture(_undo := false) -> void:
	texture_changed.emit()
	if link_set != null:
		var frame := Global.current_project.current_frame
		# This check is needed in case the user has selected multiple cels that are also linked
		if self in Global.current_project.frames[frame].cels:
			for cel in link_set["cels"]:
				cel.texture_changed.emit()


## Returns a curated [Dictionary] containing the cel data.
func serialize() -> Dictionary:
	var dict := {"opacity": opacity, "z_index": z_index}
	if not user_data.is_empty():
		dict["user_data"] = user_data
	return dict


## Sets the cel data according to a curated [Dictionary] obtained from [method serialize].
func deserialize(dict: Dictionary) -> void:
	opacity = dict["opacity"]
	z_index = dict.get("z_index", z_index)
	user_data = dict.get("user_data", user_data)


func size_changed(_new_size: Vector2i) -> void:
	pass


## Used to perform cleanup after a cel is removed.
func on_remove() -> void:
	pass


## Returns an instance of the cel button that will be added to the timeline.
func instantiate_cel_button() -> Node:
	return Global.cel_button_scene.instantiate()


## Returns to get the type of the cel class.
func get_class_name() -> String:
	return "BaseCel"
