extends Control

var color := Color("6680ff")  # Set this to a theme color later
var _spritesheet_vertical: int
var _spritesheet_horizontal: int


func show_preview(spritesheet_vertical: int, spritesheet_horizontal: int) -> void:
	_spritesheet_vertical = spritesheet_vertical
	_spritesheet_horizontal = spritesheet_horizontal
	queue_redraw()


func _draw() -> void:
	var texture_rect: TextureRect = get_parent()
	var image := texture_rect.texture.get_image()
	var image_size_y := texture_rect.size.y
	var image_size_x := texture_rect.size.x
	if image.get_size().x > image.get_size().y:
		var scale_ratio := image.get_size().x / image_size_x
		image_size_y = image.get_size().y / scale_ratio
	else:
		var scale_ratio := image.get_size().y / image_size_y
		image_size_x = image.get_size().x / scale_ratio

	var offset_x := (texture_rect.size.x - image_size_x) / 2
	var offset_y := (texture_rect.size.y - image_size_y) / 2

	var line_distance_vertical := image_size_y / _spritesheet_vertical
	var line_distance_horizontal := image_size_x / _spritesheet_horizontal

	for i in range(1, _spritesheet_vertical):
		var from := Vector2(offset_x, i * line_distance_vertical + offset_y)
		var to := Vector2(image_size_x + offset_x, i * line_distance_vertical + offset_y)
		draw_line(from, to, color)
	for i in range(1, _spritesheet_horizontal):
		var from := Vector2(i * line_distance_horizontal + offset_x, offset_y)
		var to := Vector2(i * line_distance_horizontal + offset_x, image_size_y + offset_y)
		draw_line(from, to, color)
