# Code taken and modified from Material Maker, licensed under MIT
# gdlint: ignore=max-line-length
# https://github.com/RodZill4/material-maker/blob/master/material_maker/widgets/gradient_editor/gradient_editor.gd
class_name GradientEditNode
extends TextureRect

signal updated(gradient, cc)

var continuous_change := true
var active_cursor: GradientCursor  # Showing a color picker popup to change a cursor's color

onready var x_offset: float = rect_size.x - GradientCursor.WIDTH
onready var gradient: Gradient = texture.gradient


class GradientCursor:
	extends Control

	const WIDTH := 10
	var color: Color
	var sliding := false
	onready var label: Label = get_parent().get_node("Value")

	func _ready() -> void:
		rect_position = Vector2(0, 15)
		rect_size = Vector2(WIDTH, 15)

	func _draw() -> void:
# warning-ignore:integer_division
		var polygon := PoolVector2Array(
			[
				Vector2(0, 5),
				Vector2(WIDTH / 2, 0),
				Vector2(WIDTH, 5),
				Vector2(WIDTH, 15),
				Vector2(0, 15),
				Vector2(0, 5)
			]
		)
		var c := color
		c.a = 1.0
		draw_colored_polygon(polygon, c)
		draw_polyline(polygon, Color(0.0, 0.0, 0.0) if color.v > 0.5 else Color(1.0, 1.0, 1.0))

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			if ev.button_index == BUTTON_LEFT:
				if ev.doubleclick:
					get_parent().select_color(self, ev.global_position)
				elif ev.pressed:
					get_parent().continuous_change = false
					sliding = true
					label.visible = true
					label.text = "%.03f" % get_cursor_position()
				else:
					sliding = false
					label.visible = false
			elif ev.button_index == BUTTON_RIGHT and get_parent().get_sorted_cursors().size() > 2:
				var parent = get_parent()
				parent.remove_child(self)
				parent.continuous_change = false
				parent.update_from_value()
				queue_free()
		elif ev is InputEventMouseMotion and (ev.button_mask & BUTTON_MASK_LEFT) != 0 and sliding:
			rect_position.x += get_local_mouse_position().x
			if ev.control:
				rect_position.x = (
					round(get_cursor_position() * 20.0)
					* 0.05
					* (get_parent().rect_size.x - WIDTH)
				)
			rect_position.x = min(max(0, rect_position.x), get_parent().rect_size.x - rect_size.x)
			get_parent().update_from_value()
			label.text = "%.03f" % get_cursor_position()

	func get_cursor_position() -> float:
		return rect_position.x / (get_parent().rect_size.x - WIDTH)

	func set_color(c: Color) -> void:
		color = c
		get_parent().update_from_value()
		update()

	static func sort(a, b) -> bool:
		return a.get_position() < b.get_position()

	func can_drop_data(_position, data) -> bool:
		return typeof(data) == TYPE_COLOR

	func drop_data(_position, data) -> void:
		set_color(data)


func _ready() -> void:
	create_cursors()


func create_cursors() -> void:
	for c in get_children():
		if c is GradientCursor:
			remove_child(c)
			c.queue_free()
	for i in gradient.get_point_count():
		var p: float = gradient.get_offset(i)
		add_cursor(p * x_offset, gradient.get_color(i))


func _gui_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("left_mouse"):
		var p = clamp(ev.position.x, 0, x_offset)
		add_cursor(p, get_gradient_color(p))
		continuous_change = false
		update_from_value()


func update_from_value() -> void:
	gradient.offsets = []
	for c in get_children():
		if c is GradientCursor:
			var point: float = c.rect_position.x / x_offset
			gradient.add_point(point, c.color)
	emit_signal("updated", gradient, continuous_change)
	continuous_change = true


func add_cursor(x: float, color: Color) -> void:
	var cursor := GradientCursor.new()
	add_child(cursor)
	cursor.rect_position.x = x
	cursor.color = color


func select_color(cursor: GradientCursor, position: Vector2) -> void:
	active_cursor = cursor
	var color_picker = $Popup.get_node("ColorPicker")
	color_picker.color = cursor.color
	$Popup.rect_position = position
	$Popup.popup()


func get_sorted_cursors() -> Array:
	var array := []
	for c in get_children():
		if c is GradientCursor:
			array.append(c)
	array.sort_custom(GradientCursor, "sort")
	return array


func get_gradient_color(x: float) -> Color:
	return gradient.interpolate(x / x_offset)


func _on_ColorPicker_color_changed(color: Color) -> void:
	active_cursor.set_color(color)


func _on_GradientEdit_resized() -> void:
	if not gradient:
		return
	x_offset = rect_size.x - GradientCursor.WIDTH
	create_cursors()
