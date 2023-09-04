@tool
extends Control

const SPLIT_THEME_CLASS: PackedStringArray = [
	"HSplitContainer",  # SPLIT_THEME_CLASS[DockableLayoutSplit.Direction.HORIZONTAL]
	"VSplitContainer",  # SPLIT_THEME_CLASS[DockableLayoutSplit.Direction.VERTICAL]
]

const SPLIT_MOUSE_CURSOR_SHAPE: Array[Control.CursorShape] = [
	Control.CURSOR_HSPLIT,  # SPLIT_MOUSE_CURSOR_SHAPE[DockableLayoutSplit.Direction.HORIZONTAL]
	Control.CURSOR_VSPLIT,  # SPLIT_MOUSE_CURSOR_SHAPE[DockableLayoutSplit.Direction.VERTICAL]
]

var layout_split: DockableLayoutSplit
var first_minimum_size: Vector2
var second_minimum_size: Vector2

var _parent_rect: Rect2
var _mouse_hovering := false
var _dragging := false


func _draw() -> void:
	var theme_class := SPLIT_THEME_CLASS[layout_split.direction]
	var icon := get_theme_icon("grabber", theme_class)
	var autohide := bool(get_theme_constant("autohide", theme_class))
	if not icon or (autohide and not _mouse_hovering):
		return

	draw_texture(icon, (size - icon.get_size()) * 0.5)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.is_pressed()
		if event.double_click:
			layout_split.percent = 0.5
	elif _dragging and event is InputEventMouseMotion:
		var mouse_in_parent := get_parent_control().get_local_mouse_position()
		if layout_split.is_horizontal():
			layout_split.percent = (
				(mouse_in_parent.x - _parent_rect.position.x) / _parent_rect.size.x
			)
		else:
			layout_split.percent = (
				(mouse_in_parent.y - _parent_rect.position.y) / _parent_rect.size.y
			)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_mouse_hovering = true
		set_split_cursor(true)
		if bool(get_theme_constant("autohide", SPLIT_THEME_CLASS[layout_split.direction])):
			queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_mouse_hovering = false
		set_split_cursor(false)
		if bool(get_theme_constant("autohide", SPLIT_THEME_CLASS[layout_split.direction])):
			queue_redraw()
	elif what == NOTIFICATION_FOCUS_EXIT:
		_dragging = false


func get_layout_minimum_size() -> Vector2:
	if not layout_split:
		return Vector2.ZERO
	var separation := get_theme_constant("separation", SPLIT_THEME_CLASS[layout_split.direction])
	if layout_split.is_horizontal():
		return Vector2(
			first_minimum_size.x + separation + second_minimum_size.x,
			maxf(first_minimum_size.y, second_minimum_size.y)
		)
	else:
		return Vector2(
			maxf(first_minimum_size.x, second_minimum_size.x),
			first_minimum_size.y + separation + second_minimum_size.y
		)


func set_split_cursor(value: bool) -> void:
	if value:
		mouse_default_cursor_shape = SPLIT_MOUSE_CURSOR_SHAPE[layout_split.direction]
	else:
		mouse_default_cursor_shape = CURSOR_ARROW


func get_split_rects(rect: Rect2) -> Dictionary:
	_parent_rect = rect
	var separation := get_theme_constant("separation", SPLIT_THEME_CLASS[layout_split.direction])
	var origin := rect.position
	var percent := layout_split.percent
	if layout_split.is_horizontal():
		var split_offset := clampf(
			rect.size.x * percent - separation * 0.5,
			first_minimum_size.x,
			rect.size.x - second_minimum_size.x - separation
		)
		var second_width := rect.size.x - split_offset - separation

		return {
			"first": Rect2(origin.x, origin.y, split_offset, rect.size.y),
			"self": Rect2(origin.x + split_offset, origin.y, separation, rect.size.y),
			"second":
			Rect2(origin.x + split_offset + separation, origin.y, second_width, rect.size.y),
		}
	else:
		var split_offset := clampf(
			rect.size.y * percent - separation * 0.5,
			first_minimum_size.y,
			rect.size.y - second_minimum_size.y - separation
		)
		var second_height := rect.size.y - split_offset - separation

		return {
			"first": Rect2(origin.x, origin.y, rect.size.x, split_offset),
			"self": Rect2(origin.x, origin.y + split_offset, rect.size.x, separation),
			"second":
			Rect2(origin.x, origin.y + split_offset + separation, rect.size.x, second_height),
		}
