class_name TextToolEdit
extends TextEdit

var font: Font:
	set(value):
		font = value
		add_theme_font_override(&"font", font)
var _border_node := Control.new()


func _ready() -> void:
	Global.camera.zoom_changed.connect(func(): _border_node.queue_redraw())
	_border_node.draw.connect(_on_border_redraw)
	_border_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_border_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_border_node)
	caret_blink = true
	var stylebox := StyleBoxFlat.new()
	stylebox.draw_center = false
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
	_border_node.queue_redraw()


func _on_border_redraw() -> void:
	var border_width := (1.0 / Global.camera.zoom.x) * 2.0 + 1.0
	_border_node.draw_rect(_border_node.get_rect(), Color.WHITE, false, border_width)
