extends ColorRect
class_name PaletteSwatch

# Required by grid sliders
const SWATCH_SIZE := Vector2(26, 26)

signal pressed(mouse_button)
signal double_clicked(mouse_button, position)
signal dropped(source_index, new_index)

const DEFAULT_COLOR := Color(0.0, 0.0, 0.0, 0.0)

var index := -1
var show_left_highlight := false
var show_right_highlight := false
var empty := true setget set_empty


func _ready():
	rect_min_size = SWATCH_SIZE
	rect_size = SWATCH_SIZE


func _draw() -> void:
	if not empty:
		# Black border around swatches with a color
		draw_rect(Rect2(Vector2.ZERO, SWATCH_SIZE), Color.black, false, 1)

	if show_left_highlight:
		# Display outer border highlight
		draw_rect(Rect2(Vector2.ZERO, SWATCH_SIZE), Color.white, false, 1)
		draw_rect(Rect2(Vector2.ONE, SWATCH_SIZE - Vector2(2, 2)), Color.black, false, 1)

	if show_right_highlight:
		# Display inner border highlight
		var margin := SWATCH_SIZE / 4
		draw_rect(Rect2(margin, SWATCH_SIZE - margin * 2), Color.black, false, 1)
		draw_rect(Rect2(margin - Vector2.ONE, SWATCH_SIZE - margin * 2 + Vector2(2, 2)), Color.white, false, 1)


# Enables drawing of highlights which indicate selected swatches
func show_selected_highlight(new_value: bool, mouse_button: int) -> void:
	if not empty:
		match mouse_button:
			BUTTON_LEFT:
				show_left_highlight = new_value
			BUTTON_RIGHT:
				show_right_highlight = new_value
		update()


# Empties the swatch and displays disabled color from theme
func set_empty(new_value: bool) -> void:
	empty = new_value
	if empty:
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		color = Global.control.theme.get_stylebox("disabled", "Button").bg_color
	else:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func get_drag_data(_position):
	var data = null
	if not empty:
		var drag_icon: PaletteSwatch = self.duplicate()
		drag_icon.show_left_highlight = false
		drag_icon.show_right_highlight = false
		drag_icon.empty = false
		set_drag_preview(drag_icon)
		data = {source_index = index}
	return data


func can_drop_data(_position, _data) -> bool:
	return true


func drop_data(_position, data) -> void:
	emit_signal("dropped", data.source_index, index)


func _on_PaletteSlot_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and not empty:
		if event.doubleclick:
			emit_signal("double_clicked", event.button_index, get_global_rect().position)
		else:
			emit_signal("pressed", event.button_index)
