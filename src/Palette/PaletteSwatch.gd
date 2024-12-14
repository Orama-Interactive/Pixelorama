class_name PaletteSwatch
extends ColorRect

signal pressed(mouse_button: int)
signal double_clicked(mouse_button: int, position: Vector2)
signal dropped(source_index: int, new_index: int)

const DEFAULT_COLOR := Color(0.0, 0.0, 0.0, 0.0)

var index := -1
var color_index := -1
var show_left_highlight := false
var show_right_highlight := false
var empty := true:
	set(value):
		empty = value
		if empty:
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			color = Global.control.theme.get_stylebox("disabled", "Button").bg_color
		else:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		if empty:
			empty = true


func set_swatch_size(swatch_size: Vector2) -> void:
	custom_minimum_size = swatch_size
	size = swatch_size


func _draw() -> void:
	if not empty:
		# Black border around swatches with a color
		draw_rect(Rect2(Vector2.ONE, size), Color.BLACK, false, 1)

	if show_left_highlight:
		# Display outer border highlight
		draw_rect(Rect2(Vector2.ONE, size), Color.WHITE, false, 1)
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(2, 2)), Color.BLACK, false, 1)

	if show_right_highlight:
		# Display inner border highlight
		var margin := size / 4
		draw_rect(Rect2(margin, size - margin * 2), Color.BLACK, false, 1)
		draw_rect(
			Rect2(margin - Vector2.ONE, size - margin * 2 + Vector2(2, 2)), Color.WHITE, false, 1
		)
	if Global.show_pixel_indices:
		var font := Themes.get_font()
		var str_pos := Vector2(size.x / 2, size.y - 2)
		var text_color := Global.control.theme.get_color(&"font_color", &"Label")
		draw_string_outline(
			font,
			str_pos,
			str(color_index),
			HORIZONTAL_ALIGNMENT_RIGHT,
			-1,
			size.x / 2,
			1,
			text_color.inverted()
		)
		draw_string(
			font, str_pos, str(color_index), HORIZONTAL_ALIGNMENT_RIGHT, -1, size.x / 2, text_color
		)


## Enables drawing of highlights which indicate selected swatches
func show_selected_highlight(new_value: bool, mouse_button: int) -> void:
	if not empty:
		match mouse_button:
			MOUSE_BUTTON_LEFT:
				show_left_highlight = new_value
			MOUSE_BUTTON_RIGHT:
				show_right_highlight = new_value
		queue_redraw()


func _get_drag_data(_position: Vector2) -> Variant:
	var data = null
	if not empty:
		var drag_icon: PaletteSwatch = self.duplicate()
		drag_icon.show_left_highlight = false
		drag_icon.show_right_highlight = false
		drag_icon.empty = false
		set_drag_preview(drag_icon)
		data = {source_index = index}
	return data


func _can_drop_data(_position: Vector2, _data) -> bool:
	return true


func _drop_data(_position: Vector2, data) -> void:
	dropped.emit(data.source_index, index)


func _on_PaletteSlot_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and not empty:
		if event.double_click:
			double_clicked.emit(event.button_index, get_global_rect().position)
		else:
			pressed.emit(event.button_index)
