# Initial version made by MrTriPie, has been modified
tool
class_name ValueSlider
extends TextureProgress

enum { NORMAL, HELD, SLIDING, TYPING }

export var editable := true
export var prefix: String setget _prefix_changed
export var suffix: String setget _suffix_changed
# Size of additional snapping (applied in addition to Range's step).
# This should always be larger than step.
export var snap_step := 1.0
# If snap_by_default is true, snapping is enabled when Control is NOT held (used for sliding in
# larger steps by default, and smaller steps when holding Control).
# If false, snapping is enabled when Control IS held (used for sliding in smaller steps by
# default, and larger steps when holding Control).
export var snap_by_default := false
# If show_progress is true it will show the colored progress bar, good for values with a specific
# range. False will hide it, which is good for values that can be any number.
export var show_progress := true

var state := NORMAL
onready var line_edit: LineEdit = $LineEdit


func _ready() -> void:
	_reset_display()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_TRANSLATION_CHANGED:
		_reset_display()


func _gui_input(event: InputEvent) -> void:
	if not editable:
		return
	if state == NORMAL:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == BUTTON_LEFT:
				state = HELD
				set_meta("mouse_start_position", get_local_mouse_position())
			elif event.button_index == BUTTON_WHEEL_UP:
				if snap_by_default:
					value += step if event.control else snap_step
				else:
					value += snap_step if event.control else step
			elif event.button_index == BUTTON_WHEEL_DOWN:
				if snap_by_default:
					value -= step if event.control else snap_step
				else:
					value -= snap_step if event.control else step
	elif state == HELD:
		if event.is_action_released("left_mouse"):
			state = TYPING
			line_edit.text = str(value)
			line_edit.editable = true
			line_edit.grab_focus()
			line_edit.selecting_enabled = true
			line_edit.select_all()
			line_edit.caret_position = line_edit.text.length()
			tint_progress = Color.transparent
		elif event is InputEventMouseMotion:
			if get_meta("mouse_start_position").distance_to(get_local_mouse_position()) > 2:
				state = SLIDING
				set_meta("shift_pressed", event.shift)
				set_meta("start_ratio", ratio)
				set_meta("start_value", value)
	elif state == SLIDING:
		if event.is_action_released("left_mouse"):
			state = NORMAL
			remove_meta("mouse_start_position")
			remove_meta("start_ratio")
			remove_meta("start_value")
			remove_meta("shift_pressed")
		if event is InputEventMouseMotion:
			# When pressing/releasing Shift, reset starting values to prevent slider jumping around
			if get_meta("shift_pressed") != event.shift:
				set_meta("mouse_start_position", get_local_mouse_position())
				set_meta("start_ratio", ratio)
				set_meta("start_value", value)
				set_meta("shift_pressed", event.shift)
			var x_delta: float = get_local_mouse_position().x - get_meta("mouse_start_position").x
			# Slow down to allow for more precision
			if event.shift:
				x_delta *= 0.1
			if show_progress:
				ratio = get_meta("start_ratio") + x_delta / rect_size.x
			else:
				value = get_meta("start_value") + x_delta * step
			# Snap when snap_by_default is true, do the opposite when Control is pressed
			if snap_by_default:
				if not event.control:
					value = round(value / snap_step) * snap_step
			else:
				if event.control:
					value = round(value / snap_step) * snap_step


func _prefix_changed(v: String) -> void:
	prefix = v
	_reset_display()


func _suffix_changed(v: String) -> void:
	suffix = v
	_reset_display()


func _on_LineEdit_gui_input(event: InputEvent) -> void:
	if state == TYPING:
		if event is InputEventKey and event.scancode == KEY_ESCAPE:
			_confirm_text(false)  # Cancel
			line_edit.release_focus()


func _on_value_changed(_value: float) -> void:
	_reset_display()


func _on_LineEdit_text_entered(_new_text) -> void:
	# When pressing enter, release focus, which will call _confirm_text on focus_exited signal
	line_edit.release_focus()


# Called on LineEdit's focus_exited signal
# If confirm is false it will cancel setting value
func _confirm_text(confirm := true) -> void:
	if state != TYPING:
		return
	state = NORMAL
	if confirm:
		var expression := Expression.new()
		var error := expression.parse(line_edit.text, [])
		if error != OK:
			_reset_display()
			return
		var result = expression.execute([], null, true)
		if expression.has_execute_failed() or not (result is int or result is float):
			_reset_display()
			return
		value = result
	_reset_display()


func _reset_display() -> void:
	if not line_edit:
		return
	line_edit.selecting_enabled = false  # Remove the selection
	line_edit.editable = false
	tint_under = get_color("under_color", "ValueSlider")
	if show_progress:
		tint_progress = get_color("progress_color", "ValueSlider")
	else:
		tint_progress = Color.transparent
	line_edit.text = str(tr(prefix), " ", value, " ", tr(suffix)).strip_edges()
