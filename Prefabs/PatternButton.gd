extends TextureButton


var image : Image
var texture : ImageTexture


func _ready():
	if image:
		texture = ImageTexture.new()
		texture.create_from_image(image, 0)


func _on_PatternButton_pressed() -> void:
	if Global.pattern_window_position == "left":
		Global.pattern_left_image = image
		Global.left_fill_pattern_container.get_child(0).get_child(0).texture = texture

	elif Global.pattern_window_position == "right":
		Global.pattern_right_image = image
		Global.right_fill_pattern_container.get_child(0).get_child(0).texture = texture
	Global.patterns_popup.hide()
