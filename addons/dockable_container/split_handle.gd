tool
extends Control

const Layout = preload("layout.gd")

const SPLIT_THEME_CLASS = [
	"HSplitContainer",  # SPLIT_THEME_CLASS[LayoutSplit.Direction.HORIZONTAL]
	"VSplitContainer",  # SPLIT_THEME_CLASS[LayoutSplit.Direction.VERTICAL]
]

const SPLIT_MOUSE_CURSOR_SHAPE = [
	Control.CURSOR_HSPLIT,  # SPLIT_MOUSE_CURSOR_SHAPE[LayoutSplit.Direction.HORIZONTAL]
	Control.CURSOR_VSPLIT,  # SPLIT_MOUSE_CURSOR_SHAPE[LayoutSplit.Direction.VERTICAL]
]

var layout_split: Layout.LayoutSplit
var first_minimum_size: Vector2
var second_minimum_size: Vector2

var _parent_rect
var _mouse_hovering = false
var _dragging = false


func _draw() -> void:
	var theme_class = SPLIT_THEME_CLASS[layout_split.direction]
	var icon = get_icon("grabber", theme_class)
	var autohide = bool(get_constant("autohide", theme_class))
	if not icon or (autohide and not _mouse_hovering):
		return

	draw_texture(icon, (rect_size - icon.get_size()) * 0.5)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		_dragging = event.is_pressed()
		if event.doubleclick:
			layout_split.percent = 0.5
	elif _dragging and event is InputEventMouseMotion:
		var mouse_in_parent = get_parent_control().get_local_mouse_position()
		if layout_split.is_horizontal():
			layout_split.percent = (
				(mouse_in_parent.x - _parent_rect.position.x)
				/ _parent_rect.size.x
			)
		else:
			layout_split.percent = (
				(mouse_in_parent.y - _parent_rect.position.y)
				/ _parent_rect.size.y
			)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_mouse_hovering = true
		set_split_cursor(true)
		if bool(get_constant("autohide", SPLIT_THEME_CLASS[layout_split.direction])):
			update()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_mouse_hovering = false
		set_split_cursor(false)
		if bool(get_constant("autohide", SPLIT_THEME_CLASS[layout_split.direction])):
			update()
	elif what == NOTIFICATION_FOCUS_EXIT:
		_dragging = false


func get_layout_minimum_size() -> Vector2:
	if not layout_split:
		return Vector2.ZERO
	var separation = get_constant("separation", SPLIT_THEME_CLASS[layout_split.direction])
	if layout_split.is_horizontal():
		return Vector2(
			first_minimum_size.x + separation + second_minimum_size.x,
			max(first_minimum_size.y, second_minimum_size.y)
		)
	else:
		return Vector2(
			max(first_minimum_size.x, second_minimum_size.x),
			first_minimum_size.y + separation + second_minimum_size.y
		)


func set_split_cursor(value: bool) -> void:
	if value:
		mouse_default_cursor_shape = SPLIT_MOUSE_CURSOR_SHAPE[layout_split.direction]
	else:
		mouse_default_cursor_shape = CURSOR_ARROW


func get_split_rects(rect: Rect2) -> Dictionary:
	_parent_rect = rect
	var separation = get_constant("separation", SPLIT_THEME_CLASS[layout_split.direction])
	var origin = rect.position
	var size = rect.size
	var percent = layout_split.percent
	if layout_split.is_horizontal():
		var first_width = max((size.x - separation) * percent, first_minimum_size.x)
		var split_offset = clamp(
			size.x * percent - separation * 0.5,
			first_minimum_size.x,
			size.x - second_minimum_size.x - separation
		)
		var second_width = size.x - split_offset - separation

		return {
			"first": Rect2(origin.x, origin.y, split_offset, size.y),
			"self": Rect2(origin.x + split_offset, origin.y, separation, size.y),
			"second": Rect2(origin.x + split_offset + separation, origin.y, second_width, size.y),
		}
	else:
		var first_height = max((size.y - separation) * percent, first_minimum_size.y)
		var split_offset = clamp(
			size.y * percent - separation * 0.5,
			first_minimum_size.y,
			size.y - second_minimum_size.y - separation
		)
		var second_height = size.y - split_offset - separation

		return {
			"first": Rect2(origin.x, origin.y, size.x, split_offset),
			"self": Rect2(origin.x, origin.y + split_offset, size.x, separation),
			"second": Rect2(origin.x, origin.y + split_offset + separation, size.x, second_height),
		}


static func get_separation_with_control(control: Control) -> Vector2:
	var hseparation = control.get_constant("separation", "HSplitContainer")
	var vseparation = control.get_constant("separation", "VSplitContainer")
	return Vector2(hseparation, vseparation)
