extends Container

const PADDING := 1
# https://github.com/godotengine/godot/blob/master/scene/gui/scroll_bar.h#L113
const PAGE_DIVISOR := 8
# https://github.com/godotengine/godot/pull/111305
const PAN_MULTIPLIER := 5

@export var h_scroll_bar: HScrollBar


func _ready() -> void:
	sort_children.connect(_on_sort_children)
	if is_instance_valid(h_scroll_bar):
		h_scroll_bar.resized.connect(_update_scroll)
		h_scroll_bar.value_changed.connect(_on_scroll_bar_value_changed)


func _gui_input(event: InputEvent) -> void:
	if get_child_count() == 0:
		return
	var vertical_scroll: bool = get_child(0).size.y >= size.y
	var should_h_scroll := not vertical_scroll
	if event is InputEventWithModifiers and not should_h_scroll:
		should_h_scroll = event.shift_pressed
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_RIGHT, MOUSE_BUTTON_WHEEL_LEFT]:
			# This helps/allows two finger scrolling (on Laptops)
			should_h_scroll = true
		if should_h_scroll:
			if is_instance_valid(h_scroll_bar):
				if (
					event.button_index == MOUSE_BUTTON_WHEEL_UP
					or event.button_index == MOUSE_BUTTON_WHEEL_LEFT
				):
					h_scroll_bar.value -= PAGE_DIVISOR * event.factor
					accept_event()
				elif (
					event.button_index == MOUSE_BUTTON_WHEEL_DOWN
					or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT
				):
					h_scroll_bar.value += PAGE_DIVISOR * event.factor
					accept_event()
	# Pan scrolling, used by some MacOS devices
	# (see: https://github.com/Orama-Interactive/Pixelorama/discussions/1218)
	elif event is InputEventPanGesture:
		if event.delta.x != 0:
			h_scroll_bar.value += signf(event.delta.x) * PAN_MULTIPLIER


func _update_scroll() -> void:
	if get_child_count() > 0 and is_instance_valid(h_scroll_bar):
		var cel_margin_container := get_child(0) as Control
		var child_min_size := cel_margin_container.get_combined_minimum_size()
		h_scroll_bar.visible = child_min_size.x > size.x
		h_scroll_bar.max_value = child_min_size.x
		if h_scroll_bar.visible:
			h_scroll_bar.page = size.x - h_scroll_bar.get_combined_minimum_size().x
		else:
			h_scroll_bar.page = size.x
		cel_margin_container.position.x = -h_scroll_bar.value + PADDING


func ensure_control_visible(control: Control) -> void:
	if not is_instance_valid(control):
		return
	# Based on Godot's implementation in ScrollContainer
	var global_rect := get_global_rect()
	var other_rect := control.get_global_rect()
	var diff := maxf(
		minf(other_rect.position.x, global_rect.position.x),
		other_rect.position.x + other_rect.size.x - global_rect.size.x
	)
	h_scroll_bar.value += diff - global_rect.position.x


func _on_sort_children() -> void:
	if get_child_count():
		get_child(0).size = get_child(0).get_combined_minimum_size()
		_update_scroll()


func _on_scroll_bar_value_changed(value: float) -> void:
	if get_child_count() > 0 and is_instance_valid(h_scroll_bar):
		var cel_margin_container := get_child(0) as Control
		cel_margin_container.position.x = -value + PADDING


func _clips_input() -> bool:
	return true
