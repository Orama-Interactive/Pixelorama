class_name TextToolEdit
extends TextEdit

const VALUE_ARROW := preload("res://assets/graphics/misc/value_arrow.svg")
const VALUE_ARROW_HOVER := preload("res://assets/graphics/misc/value_arrow_hover.svg")
const VALUE_ARROW_PRESS := preload("res://assets/graphics/misc/value_arrow_press.svg")

var font: Font:
	set(value):
		font = value
		add_theme_font_override("font", font)
var drag := false


func _ready() -> void:
	var drag_button := TextureButton.new()
	drag_button.anchor_left = 0.5
	drag_button.anchor_right = 0.5
	drag_button.offset_left = -5.0
	drag_button.offset_right = 5.0
	drag_button.offset_bottom = 6.0
	drag_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	drag_button.texture_normal = VALUE_ARROW
	drag_button.texture_hover = VALUE_ARROW_HOVER
	drag_button.texture_pressed = VALUE_ARROW_PRESS
	drag_button.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	add_child(drag_button)
	text_changed.connect(_on_text_changed)
	drag_button.gui_input.connect(_on_drag_gui_input)
	drag_button.button_down.connect(_on_drag_button_down)
	drag_button.button_up.connect(_on_drag_button_up)
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


func _on_drag_gui_input(event: InputEvent) -> void:
	if not drag or not event is InputEventMouseMotion:
		return
	position += event.relative


func _on_text_changed() -> void:
	if not font:
		return
	size.x = 16 + font.get_string_size(get_line(_get_max_line())).x
	size.y = get_line_count() * font.get_height() + 16


func _on_drag_button_down() -> void:
	drag = true


func _on_drag_button_up() -> void:
	drag = false
	grab_focus()
