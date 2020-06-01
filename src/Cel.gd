class_name Cel
extends Reference
# A class for cel properties


var image : Image setget image_changed
var image_texture : ImageTexture
var opacity : float


func _init(_image := Image.new(), _opacity := 1.0) -> void:
	self.image = _image
	opacity = _opacity


func image_changed(value : Image) -> void:
	image = value
	image_texture = ImageTexture.new()
	image_texture.create_from_image(image, 0)
