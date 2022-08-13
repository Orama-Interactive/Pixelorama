class_name PixelCel
extends BaseCel
# A class for the properties of cels in PixelLayers.
# The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).
# The "image" variable is where the image data of each cel are.

var image: Image setget image_changed
var image_texture: ImageTexture

func _init(_image := Image.new(), _opacity := 1.0, _image_texture: ImageTexture = null) -> void:
	if _image_texture:
		image_texture = _image_texture
	else:
		image_texture = ImageTexture.new()
	self.image = _image # Set image and call setter
	opacity = _opacity


func image_changed(value: Image) -> void:
	image = value
	if !image.is_empty():
		image_texture.create_from_image(image, 0)


func set_content(content: Array) -> void:
	image = content[0]
	image_texture = content[1]


func get_content() -> Array:
	return [image, image_texture]


func create_empty_content() -> Array:
	var empty_image := Image.new()
	empty_image.create(image.get_size().x, image.get_size().y, false, Image.FORMAT_RGBA8)
	var empty_texture := ImageTexture.new()
	empty_texture.create_from_image(empty_image, 0)
	return [empty_image, empty_texture]


func copy_content() -> Array:
	var copy_image := Image.new()
	copy_image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, image.get_data())
	var copy_texture := ImageTexture.new()
	copy_texture.create_from_image(copy_image, 0)
	return [copy_image, copy_texture]


func get_image() -> Image:
	return image


func save_image_data_to_pxo(file: File) -> void:
	file.store_buffer(image.get_data())


func load_image_data_from_pxo(file: File, project_size: Vector2) -> void:
	var buffer := file.get_buffer(project_size.x * project_size.y * 4)
	image.create_from_data(project_size.x, project_size.y, false, Image.FORMAT_RGBA8, buffer)
	image_changed(image)


func create_cel_button() -> Node:
	var cel_button = Global.pixel_cel_button_node.instance()
	cel_button.get_child(0).texture = image_texture
	return cel_button
