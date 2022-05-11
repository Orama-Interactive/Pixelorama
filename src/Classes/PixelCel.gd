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
	self.image = _image
	opacity = _opacity


func image_changed(value: Image) -> void:
	image = value
	if !image.is_empty():
		image_texture.create_from_image(image, 0)


func get_image() -> Image:
	return image


func save_image_data_to_pxo(file: File) -> void:
	file.store_buffer(image.get_data())


func load_image_data_from_pxo(file: File, project_size: Vector2) -> void:
	var buffer := file.get_buffer(project_size.x * project_size.y * 4)
	image.create_from_data(project_size.x, project_size.y, false, Image.FORMAT_RGBA8, buffer)
	image_changed(image)
