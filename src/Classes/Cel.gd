class_name Cel extends Reference
# A class for cel properties.
# The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).
# The "image" variable is where the image data of each cel are.


var image : Image setget image_changed
var image_texture : ImageTexture
var opacity : float


func _init(_image := Image.new(), _opacity := 1.0) -> void:
	image_texture = ImageTexture.new()
	self.image = _image
	opacity = _opacity


func image_changed(value : Image) -> void:
	image = value
	if !image.is_empty():
		image_texture.create_from_image(image, 0)
