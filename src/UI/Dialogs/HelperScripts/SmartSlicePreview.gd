extends Control

## Add this as a child of the texturerect that contains the main spritesheet
var color := Color("6680ff")  ## Set this to a theme color later
var _sliced_rects: Array[Rect2i]
var _stretch_amount: float
var _offset: Vector2


func show_preview(sliced_rects: Array[Rect2i]) -> void:
	if not is_instance_valid(get_parent().texture):
		return
	var image: Image = get_parent().texture.get_image()
	if image.get_size().x > image.get_size().y:
		_stretch_amount = size.x / image.get_size().x
	else:
		_stretch_amount = size.y / image.get_size().y
	_sliced_rects = sliced_rects.duplicate()
	_offset = (0.5 * (size - (image.get_size() * _stretch_amount))).floor()
	queue_redraw()


func _draw() -> void:
	draw_set_transform(_offset, 0, Vector2.ONE)
	for i in _sliced_rects.size():
		var rect := _sliced_rects[i]
		var scaled_rect: Rect2 = rect
		scaled_rect.position = (scaled_rect.position * _stretch_amount)
		scaled_rect.size *= _stretch_amount
		draw_rect(scaled_rect, color, false)
		# show number
		draw_set_transform(_offset + scaled_rect.position, 0, Vector2.ONE)
#		var font: Font = Control.new().get_font("font")
		# replace with font used by pixelorama
		var font := Themes.get_font()
		var font_height := font.get_height()
		draw_string(font, Vector2(1, font_height), str(i))
		draw_set_transform(_offset, 0, Vector2.ONE)
