class_name PixelCel
extends BaseCel
## A class for the properties of cels in PixelLayers.
## The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).

## This variable is where the image data of the cel are.
var image: ImageExtended:
	set = image_changed


func _init(_image := ImageExtended.new(), _opacity := 1.0) -> void:
	image_texture = ImageTexture.new()
	image = _image  # Set image and call setter
	opacity = _opacity


func image_changed(value: ImageExtended) -> void:
	image = value
	if not image.is_empty() and is_instance_valid(image_texture):
		image_texture.set_image(image)


func set_indexed_mode(indexed: bool) -> void:
	image.is_indexed = indexed
	if image.is_indexed:
		image.resize_indices()
		image.select_palette("", false)
		image.convert_rgb_to_indexed()


func get_content() -> Variant:
	return image


func set_content(content, texture: ImageTexture = null) -> void:
	var proper_content: ImageExtended
	if content is not ImageExtended:
		proper_content = ImageExtended.new()
		proper_content.copy_from_custom(content, image.is_indexed)
	else:
		proper_content = content
	image = proper_content
	if is_instance_valid(texture) and is_instance_valid(texture.get_image()):
		image_texture = texture
		if image_texture.get_image().get_size() != image.get_size():
			image_texture.set_image(image)
	else:
		image_texture.update(image)


func create_empty_content() -> ImageExtended:
	var empty := Image.create(image.get_width(), image.get_height(), false, image.get_format())
	var new_image := ImageExtended.new()
	new_image.copy_from_custom(empty, image.is_indexed)
	return new_image


func copy_content() -> Variant:
	var tmp_image := Image.create_from_data(
		image.get_width(), image.get_height(), false, image.get_format(), image.get_data()
	)
	var copy_image := ImageExtended.new()
	copy_image.copy_from_custom(tmp_image, image.is_indexed)
	return copy_image


func get_image() -> ImageExtended:
	return image


func duplicate_cel() -> PixelCel:
	var new_cel := PixelCel.new()
	new_cel.opacity = opacity
	new_cel.z_index = z_index
	new_cel.user_data = user_data
	new_cel.ui_color = ui_color
	return new_cel


func update_texture(undo := false) -> void:
	image_texture.set_image(image)
	super.update_texture(undo)


func get_class_name() -> String:
	return "PixelCel"
