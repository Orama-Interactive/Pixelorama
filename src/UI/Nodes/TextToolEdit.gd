class_name TextToolEdit
extends TextEdit

var font: Font:
	set(value):
		font = value
		add_theme_font_override(&"font", font)


func _ready() -> void:
	var stylebox := StyleBoxFlat.new()
	stylebox.draw_center = false
	stylebox.border_width_left = 1
	stylebox.border_width_top = 1
	stylebox.border_width_right = 1
	stylebox.border_width_bottom = 1
	add_theme_stylebox_override(&"normal", stylebox)
	add_theme_stylebox_override(&"focus", stylebox)
	add_theme_constant_override(&"line_spacing", 0)
	text_changed.connect(_on_text_changed)
	theme = Global.control.theme
	if font:
		custom_minimum_size = Vector2(32, maxf(32, font.get_height()))
		size.y = get_line_count() * font.get_height() + 16


func _get_max_line() -> int:
	var max_line := 0
	var max_string := get_line(0).length()
	for i in get_line_count():
		var line := get_line(i)
		if line.length() > max_string:
			max_string = line.length()
			max_line = i
	return max_line


func _on_text_changed() -> void:
	if not font:
		return
	size.x = get_theme_font_size(&"font_size") + font.get_string_size(get_line(_get_max_line())).x
	size.y = get_line_count() * font.get_height() + get_theme_font_size(&"font_size")
