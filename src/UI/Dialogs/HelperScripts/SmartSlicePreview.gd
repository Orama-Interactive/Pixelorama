extends Control

# add this as a child of the texturerect that contains the main spritesheet
var _sliced_rects: Array
var _stretch_amount: float
var _offset: Vector2

var color: Color = Color("6680ff")  # Set this to a theme color later

func show_preview(sliced_rects: Array) -> void:
	var image = get_parent().texture.get_data()
	if image.get_size().x > image.get_size().y:
		_stretch_amount = rect_size.x / image.get_size().x
	else:
		_stretch_amount = rect_size.y / image.get_size().y
	_sliced_rects = sliced_rects.duplicate()
	_offset = (0.5 * (rect_size - (image.get_size() * _stretch_amount))).floor()
	update()


func _draw() -> void:
	draw_set_transform(_offset, 0, Vector2.ONE)
	for i in _sliced_rects.size():
		var rect = _sliced_rects[i]
		var scaled_rect: Rect2 = rect
		scaled_rect.position = (scaled_rect.position * _stretch_amount)
		scaled_rect.size *= _stretch_amount
		draw_rect(scaled_rect, color, false)
		# show number
		draw_set_transform(_offset + scaled_rect.position, 0, Vector2.ONE)
#		var font: Font = Control.new().get_font("font")
		# replace with font used by pixelorama
		var font: Font = Global.control.theme.default_font
		var font_height := font.get_height()
		draw_string(font, Vector2(1, font_height), str(i))
		draw_set_transform(_offset, 0, Vector2.ONE)
