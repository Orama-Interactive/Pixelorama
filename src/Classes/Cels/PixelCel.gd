class_name PixelCel
extends BaseCel
## A class for the properties of cels in PixelLayers.
## The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).

## This variable is where the image data of the cel are.
var image: PixeloramaImage:
	set = image_changed


func _init(_image: PixeloramaImage, _opacity := 1.0) -> void:
	image_texture = ImageTexture.new()
	image = _image  # Set image and call setter
	opacity = _opacity


func image_changed(value: PixeloramaImage) -> void:
	image = value
	if not image.is_empty() and is_instance_valid(image_texture):
		image_texture.set_image(image)


func get_content():
	return image


func set_content(content, texture: ImageTexture = null) -> void:
	image = content
	if is_instance_valid(texture) and is_instance_valid(texture.get_image()):
		image_texture = texture
		if image_texture.get_image().get_size() != image.get_size():
			image_texture.set_image(image)
	else:
		image_texture.update(image)


func create_empty_content():
	var empty_image := Image.create(
		image.get_size().x, image.get_size().y, false, Image.FORMAT_RGBA8
	)
	return empty_image


func copy_content():
	var copy_image := Image.create_from_data(
		image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, image.get_data()
	)
	return copy_image


func get_image() -> Image:
	return image


func update_texture() -> void:
	image_texture.set_image(image)
	super.update_texture()


func get_class_name() -> String:
	return "PixelCel"
