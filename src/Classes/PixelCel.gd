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

# TODO R3: A copy_image bool parameter could be useful for places such as the merging layers function
# 		where the copied cels don't need the image to be copied (at least not yet in that case)
#		Alternatively, keep it as is, and maybe put a comment on the copy function mentioning that it
# 		copies the image data too...
func copy() -> BaseCel:
	var copy_image := Image.new()
	copy_image.copy_from(image)
	var copy_texture := ImageTexture.new()
	copy_texture.create_from_image(copy_image, 0)
	# Using get_script over the class name prevents a cyclic reference:
	return get_script().new(copy_image, opacity, copy_texture)


func create_cel_button() -> Node:
	var cel_button = Global.pixel_cel_button_node.instance()
	cel_button.get_child(0).texture = image_texture
	return cel_button
