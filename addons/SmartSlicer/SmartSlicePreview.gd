extends Control

var _sliced_rects: Array
var _stretch_ratio: Vector2

func show_preview(sliced_rects: Array, stretch_ratio: Vector2) -> void:
	_sliced_rects = sliced_rects
	_stretch_ratio = stretch_ratio
	update()


func _draw() -> void:
	for i in _sliced_rects.size():
		var rect = _sliced_rects[i]
		var updated_rect: Rect2 = rect
		updated_rect.position = updated_rect.position * _stretch_ratio
		updated_rect.size *= _stretch_ratio
		draw_rect(updated_rect, Color("6680ff"), false)
		draw_set_transform(updated_rect.position, 0, Vector2.ONE)
		var font: Font = Global.control.theme.default_font
		var font_height := font.get_height()
		draw_string(font, Vector2(1, font_height), str(i))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
