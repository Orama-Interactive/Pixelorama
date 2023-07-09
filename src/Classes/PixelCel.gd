class_name PixelCel
extends BaseCel
# A class for the properties of cels in PixelLayers.
# The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).
# The "image" variable is where the image data of each cel are.

var image: Image: set = image_changed


func _init(_image := Image.new(), _opacity := 1.0, _image_texture: ImageTexture = null) -> void:
	if _image_texture:
		image_texture = _image_texture
	else:
		image_texture = ImageTexture.new()
	image = _image  # Set image and call setter
	opacity = _opacity


func image_changed(value: Image) -> void:
	image = value
	if !image.is_empty():
		image_texture = ImageTexture.create_from_image(image)


func get_content():
	return image


func set_content(content, texture: ImageTexture = null) -> void:
	image = content
	if is_instance_valid(texture):
		image_texture = texture
		if image_texture.get_image().get_size() != image.get_size():
			image_texture = ImageTexture.create_from_image(image)
	else:
		image_texture = ImageTexture.create_from_image(image)


func create_empty_content():
	var empty_image := Image.create(image.get_size().x, image.get_size().y, false, Image.FORMAT_RGBA8)
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


func save_image_data_to_pxo(file: FileAccess) -> void:
	file.store_buffer(image.get_data())


func load_image_data_from_pxo(file: FileAccess, project_size: Vector2) -> void:
	var buffer := file.get_buffer(project_size.x * project_size.y * 4)
	image = Image.create_from_data(project_size.x, project_size.y, false, Image.FORMAT_RGBA8, buffer)
	image_changed(image)


func instantiate_cel_button() -> Node:
	return Global.pixel_cel_button_node.instantiate()


func get_class_name() -> String:
	return "PixelCel"
