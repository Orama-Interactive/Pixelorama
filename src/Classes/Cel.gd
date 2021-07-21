class_name Cel extends Reference
# A class for cel properties.
# The term "cel" comes from "celluloid" (https://en.wikipedia.org/wiki/Cel).
# The "image" variable is where the image data of each cel are.


var image : Image
var image_texture : ImageTexture
var opacity : float


func _init(_image := Image.new(), _opacity := 1.0, _image_texture : ImageTexture = null) -> void:
	if _image_texture:
		image_texture = _image_texture
	else:
		image_texture = ImageTexture.new()
	image = _image
	opacity = _opacity
