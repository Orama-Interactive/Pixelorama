extends TextureButton


var image : Image
var image_size : Vector2
var texture : ImageTexture


func _ready() -> void:
	if image:
		image_size = image.get_size()
		texture = ImageTexture.new()
		texture.create_from_image(image, 0)


func _on_PatternButton_pressed() -> void:
	Global.pattern_images[Global.pattern_window_position] = image
	Global.fill_pattern_containers[Global.pattern_window_position].get_child(0).get_child(0).texture = texture
	Global.fill_pattern_containers[Global.pattern_window_position].get_child(2).get_child(1).max_value = image_size.x - 1
	Global.fill_pattern_containers[Global.pattern_window_position].get_child(3).get_child(1).max_value = image_size.y - 1

	Global.patterns_popup.hide()
