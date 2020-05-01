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
	if Global.pattern_window_position == "left":
		Global.pattern_left_image = image
		Global.left_fill_pattern_container.get_child(0).get_child(0).texture = texture
		Global.left_fill_pattern_container.get_child(2).get_child(1).max_value = image_size.x - 1
		Global.left_fill_pattern_container.get_child(3).get_child(1).max_value = image_size.y - 1

	elif Global.pattern_window_position == "right":
		Global.pattern_right_image = image
		Global.right_fill_pattern_container.get_child(0).get_child(0).texture = texture
		Global.right_fill_pattern_container.get_child(2).get_child(1).max_value = image_size.x - 1
		Global.right_fill_pattern_container.get_child(3).get_child(1).max_value = image_size.y - 1

	Global.patterns_popup.hide()
