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
	if is_instance_valid(font):
		var font_size := get_theme_font_size(&"font_size")
		custom_minimum_size = Vector2(32, maxf(32, font.get_height(font_size)))
		size.y = (get_line_count() + 1) * font.get_height(font_size)


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
	if not is_instance_valid(font):
		return
	var font_size := get_theme_font_size(&"font_size")
	var max_line := get_line(_get_max_line())
	var string_size := font.get_string_size(max_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	size.x = font_size + string_size.x
	size.y = (get_line_count() + 1) * font.get_height(font_size)
