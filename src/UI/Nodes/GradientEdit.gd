# Code taken and modified from Material Maker, licensed under MIT
# gdlint: ignore=max-line-length
# https://github.com/RodZill4/material-maker/blob/master/material_maker/widgets/gradient_editor/gradient_editor.gd
class_name GradientEditNode
extends Control

signal updated(gradient, cc)

var continuous_change := true
var active_cursor: GradientCursor  # Showing a color picker popup to change a cursor's color

onready var x_offset: float = rect_size.x - GradientCursor.WIDTH
onready var texture_rect: TextureRect = $TextureRect
onready var texture: Texture = $TextureRect.texture
onready var gradient: Gradient = texture.gradient
onready var color_picker: ColorPicker = $Popup.get_node("ColorPicker")
onready var divide_dialog: ConfirmationDialog = $DivideConfirmationDialog
onready var number_of_parts_spin_box: SpinBox = $"%NumberOfPartsSpinBox"
onready var add_point_end_check_box: CheckBox = $"%AddPointEndCheckBox"


class GradientCursor:
	extends Control

	const WIDTH := 10
	var color: Color
	var sliding := false

	onready var parent: TextureRect = get_parent()
	onready var grand_parent: Container = parent.get_parent()
	onready var label: Label = parent.get_node("Value")

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
					grand_parent.select_color(self, ev.global_position)
				elif ev.pressed:
					grand_parent.continuous_change = false
					sliding = true
					label.visible = true
					label.text = "%.03f" % get_cursor_position()
				else:
					sliding = false
					label.visible = false
			elif ev.button_index == BUTTON_RIGHT and grand_parent.get_sorted_cursors().size() > 2:
				parent.remove_child(self)
				grand_parent.continuous_change = false
				grand_parent.update_from_value()
				queue_free()
		elif ev is InputEventMouseMotion and (ev.button_mask & BUTTON_MASK_LEFT) != 0 and sliding:
			rect_position.x += get_local_mouse_position().x
			if ev.control:
				rect_position.x = (
					round(get_cursor_position() * 20.0)
					* 0.05
					* (parent.rect_size.x - WIDTH)
				)
			rect_position.x = min(max(0, rect_position.x), parent.rect_size.x - rect_size.x)
			grand_parent.update_from_value()
			label.text = "%.03f" % get_cursor_position()

	func get_cursor_position() -> float:
		return rect_position.x / (parent.rect_size.x - WIDTH)

	func set_color(c: Color) -> void:
		color = c
		grand_parent.update_from_value()
		update()

	static func sort(a, b) -> bool:
		return a.get_position() < b.get_position()

	func can_drop_data(_position, data) -> bool:
		return typeof(data) == TYPE_COLOR

	func drop_data(_position, data) -> void:
		set_color(data)


func _ready() -> void:
	_create_cursors()


func _create_cursors() -> void:
	for c in texture_rect.get_children():
		if c is GradientCursor:
			texture_rect.remove_child(c)
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
	for c in texture_rect.get_children():
		if c is GradientCursor:
			var point: float = c.rect_position.x / x_offset
			gradient.add_point(point, c.color)
	emit_signal("updated", gradient, continuous_change)
	continuous_change = true


func add_cursor(x: float, color: Color) -> void:
	var cursor := GradientCursor.new()
	texture_rect.add_child(cursor)
	cursor.rect_position.x = x
	cursor.color = color


func select_color(cursor: GradientCursor, position: Vector2) -> void:
	active_cursor = cursor
	color_picker.color = cursor.color
	if position.x > rect_global_position.x + (rect_size.x / 2.0):
		position.x = rect_global_position.x + rect_size.x
	else:
		position.x = rect_global_position.x - $Popup.rect_size.x
	$Popup.rect_position = position
	$Popup.popup()


func get_sorted_cursors() -> Array:
	var array := []
	for c in texture_rect.get_children():
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
	_create_cursors()


func _on_InterpolationOptionButton_item_selected(index: int) -> void:
	gradient.interpolation_mode = index


func _on_DivideButton_pressed() -> void:
	divide_dialog.popup_centered()


func _on_DivideConfirmationDialog_confirmed() -> void:
	var add_point_to_end := add_point_end_check_box.pressed
	var parts := number_of_parts_spin_box.value
	var colors := []
	var end_point = 1 if add_point_to_end else 0
	parts -= end_point

	if not add_point_to_end:
		# Move the final color one part behind, useful for it to be in constant interpolation
		gradient.add_point((parts - 1) / parts, gradient.interpolate(1))
	for i in parts + end_point:
		colors.append(gradient.interpolate(i / parts))
	gradient.offsets = []
	for i in parts + end_point:
		gradient.add_point(i / parts, colors[i])
	_create_cursors()
	emit_signal("updated", gradient, continuous_change)
