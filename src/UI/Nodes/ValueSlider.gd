# Initial version made by MrTriPie, has been modified by Overloaded.
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
export var show_arrows := true setget _show_arrows_changed
export var echo_arrow_time := 0.075
# This will be replaced with input action strings in Godot 4.x
# Right now this is only used for changing the brush size with Control + Wheel
# In Godot 4.x, the shortcut will be editable
export var is_global := false

var state := NORMAL
var arrow_is_held := 0  # Used for arrow button echo behavior. Is 1 for ValueUp, -1 for ValueDown.

var _line_edit := LineEdit.new()
var _value_up_button := TextureButton.new()
var _value_down_button := TextureButton.new()
var _timer := Timer.new()


func _init() -> void:
	nine_patch_stretch = true
	stretch_margin_left = 3
	stretch_margin_top = 3
	stretch_margin_right = 3
	stretch_margin_bottom = 3
	theme_type_variation = "ValueSlider"


func _ready() -> void:
	connect("value_changed", self, "_on_value_changed")
	_setup_nodes()
	set_process_input(is_global)
	_reset_display(true)
	if not Engine.editor_hint:  # Pixelorama specific code
		_value_up_button.modulate = Global.modulate_icon_color
		_value_down_button.modulate = Global.modulate_icon_color


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_reset_display(true)
	elif what == NOTIFICATION_TRANSLATION_CHANGED:
		_reset_display(false)


func _input(event: InputEvent) -> void:
	if not editable or not is_visible_in_tree():
		return
	# Hardcode Control + Wheel as a global shortcut, if is_global is true
	# In Godot 4.x this will change into two is_action() checks for incrementing and decrementing
	if not event is InputEventMouseButton:
		return
	if not event.pressed:
		return
	if not event.control:
		return
	if event.button_index == BUTTON_WHEEL_UP:
		if snap_by_default:
			value += step if event.control else snap_step
		else:
			value += snap_step if event.control else step
	elif event.button_index == BUTTON_WHEEL_DOWN:
		if snap_by_default:
			value -= step if event.control else snap_step
		else:
			value -= snap_step if event.control else step


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
			_line_edit.text = str(value)
			_line_edit.editable = true
			_line_edit.grab_focus()
			_line_edit.selecting_enabled = true
			_line_edit.select_all()
			_line_edit.caret_position = _line_edit.text.length()
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


func _setup_nodes() -> void:  # Only called once on _ready()
	_line_edit.align = LineEdit.ALIGN_CENTER
	_line_edit.anchor_right = 1
	_line_edit.anchor_bottom = 1
	_line_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line_edit.add_stylebox_override("read_only", StyleBoxEmpty.new())
	_line_edit.add_stylebox_override("normal", StyleBoxEmpty.new())
	_line_edit.connect("text_entered", self, "_on_LineEdit_text_entered")
	_line_edit.connect("focus_exited", self, "_confirm_text")
	_line_edit.connect("gui_input", self, "_on_LineEdit_gui_input")
	add_child(_line_edit)

	_value_up_button.rect_scale.y = -1
	_value_up_button.anchor_left = 1
	_value_up_button.anchor_right = 1
	_value_up_button.margin_left = -15
	_value_up_button.margin_top = 12
	_value_up_button.margin_right = -3
	_value_up_button.margin_bottom = 24
	_value_up_button.add_to_group("UIButtons")
	_value_up_button.connect("button_down", self, "_on_Value_button_down", [1])
	_value_up_button.connect("button_up", self, "_on_Value_button_up")
	add_child(_value_up_button)

	_value_down_button.anchor_left = 1
	_value_down_button.anchor_top = 1
	_value_down_button.anchor_right = 1
	_value_down_button.anchor_bottom = 1
	_value_down_button.margin_left = -15
	_value_down_button.margin_top = -12
	_value_down_button.margin_right = -3
	_value_down_button.margin_bottom = 0
	_value_down_button.add_to_group("UIButtons")
	_value_down_button.connect("button_down", self, "_on_Value_button_down", [-1])
	_value_down_button.connect("button_up", self, "_on_Value_button_up")
	add_child(_value_down_button)

	_timer.connect("timeout", self, "_on_Timer_timeout")
	add_child(_timer)


func _prefix_changed(v: String) -> void:
	prefix = v
	_reset_display()


func _suffix_changed(v: String) -> void:
	suffix = v
	_reset_display()


func _show_arrows_changed(v: bool) -> void:
	show_arrows = v
	if not _line_edit:
		return
	_value_up_button.visible = v
	_value_down_button.visible = v


func _on_LineEdit_gui_input(event: InputEvent) -> void:
	if state == TYPING:
		if event is InputEventKey and event.scancode == KEY_ESCAPE:
			_confirm_text(false)  # Cancel
			_line_edit.release_focus()


func _on_value_changed(_value: float) -> void:
	_reset_display()


func _on_LineEdit_text_entered(_new_text: String) -> void:
	# When pressing enter, release focus, which will call _confirm_text on focus_exited signal
	_line_edit.release_focus()


# Called on LineEdit's focus_exited signal
# If confirm is false it will cancel setting value
func _confirm_text(confirm := true) -> void:
	if state != TYPING:
		return
	state = NORMAL
	if confirm:
		var expression := Expression.new()
		var error := expression.parse(_line_edit.text, [])
		if error != OK:
			_reset_display(true)
			return
		var result = expression.execute([], null, true)
		if expression.has_execute_failed() or not (result is int or result is float):
			_reset_display(true)
			return
		value = result
	_reset_display(true)


func _reset_display(theme_changed := false) -> void:
	_line_edit.selecting_enabled = false  # Remove the selection
	_line_edit.editable = false
	if theme_changed and not Engine.editor_hint:
		texture_under = get_icon("texture_under", "ValueSlider")
		texture_over = get_icon("texture_over", "ValueSlider")
		texture_progress = get_icon("texture_progress", "ValueSlider")
		_value_up_button.texture_normal = get_icon("arrow_normal", "ValueSlider")
		_value_up_button.texture_pressed = get_icon("arrow_pressed", "ValueSlider")
		_value_up_button.texture_hover = get_icon("arrow_hover", "ValueSlider")

		_value_down_button.texture_normal = get_icon("arrow_normal", "ValueSlider")
		_value_down_button.texture_pressed = get_icon("arrow_pressed", "ValueSlider")
		_value_down_button.texture_hover = get_icon("arrow_hover", "ValueSlider")

		tint_under = get_color("under_color", "ValueSlider")
		if show_progress:
			tint_progress = get_color("progress_color", "ValueSlider")
		else:
			tint_progress = Color.transparent
	_line_edit.text = str(tr(prefix), " ", value, " ", tr(suffix)).strip_edges()
	var line_edit_color := _line_edit.get_color("font_color")
	var line_edit_disabled_col: Color = get_color("read_only", "LineEdit")
	if editable:
		_line_edit.add_color_override("font_color_uneditable", line_edit_color)
	else:
		_line_edit.add_color_override("font_color_uneditable", line_edit_disabled_col)


func _on_Value_button_down(direction: int) -> void:
	if not editable:
		return
	# Direction is either 1 or -1
	value += (snap_step if Input.is_action_pressed("ctrl") else step) * direction
	arrow_is_held = direction
	_timer.wait_time = echo_arrow_time * 8  # 0.6 with the default value
	_timer.one_shot = true
	_timer.start()


func _on_Value_button_up() -> void:
	arrow_is_held = 0
	_timer.stop()


# Echo behavior. If the user keeps pressing the button, the value keeps changing.
func _on_Timer_timeout() -> void:
	if arrow_is_held == 0:
		_timer.stop()
		return
	value += (snap_step if Input.is_action_pressed("ctrl") else step) * arrow_is_held
	if _timer.one_shot:
		_timer.wait_time = echo_arrow_time
		_timer.one_shot = false
		_timer.start()
