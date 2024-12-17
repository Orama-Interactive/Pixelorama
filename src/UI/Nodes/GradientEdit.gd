# Code taken and modified from Material Maker, licensed under MIT
# gdlint: ignore=max-line-length
# https://github.com/RodZill4/material-maker/blob/master/material_maker/widgets/gradient_editor/gradient_editor.gd
class_name GradientEditNode
extends Control

signal updated(gradient: Gradient, cc: bool)

var continuous_change := true
var active_cursor: GradientCursor  ## Showing a color picker popup to change a cursor's color
var texture := GradientTexture2D.new()
var gradient := Gradient.new()

@onready var x_offset: float = size.x - GradientCursor.WIDTH
@onready var texture_rect := $TextureRect as TextureRect
@onready var color_picker := $Popup.get_node("ColorPicker") as ColorPicker
@onready var divide_dialog := $DivideConfirmationDialog as ConfirmationDialog
@onready var number_of_parts_spin_box := $"%NumberOfPartsSpinBox" as SpinBox
@onready var add_point_end_check_box := $"%AddPointEndCheckBox" as CheckBox


class GradientCursor:
	extends Control

	const WIDTH := 10
	var color: Color
	var sliding := false

	@onready var parent: TextureRect = get_parent()
	@onready var grand_parent: Container = parent.get_parent()
	@onready var label: Label = parent.get_node("Value")

	func _ready() -> void:
		position = Vector2(0, 15)
		size = Vector2(WIDTH, 15)

	func _draw() -> void:
		var polygon := PackedVector2Array(
			[
				Vector2(0, 5),
				Vector2(WIDTH / 2.0, 0),
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
			if ev.button_index == MOUSE_BUTTON_LEFT:
				if ev.double_click:
					grand_parent.select_color(self, ev.global_position)
				elif ev.pressed:
					grand_parent.continuous_change = false
					sliding = true
					label.visible = true
					label.text = "%.03f" % get_caret_column()
				else:
					sliding = false
					label.visible = false
			elif (
				ev.button_index == MOUSE_BUTTON_RIGHT
				and grand_parent.get_sorted_cursors().size() > 2
			):
				parent.remove_child(self)
				grand_parent.continuous_change = false
				grand_parent.update_from_value()
				queue_free()
		elif (
			ev is InputEventMouseMotion
			and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
			and sliding
		):
			position.x += get_local_mouse_position().x
			if ev.ctrl_pressed:
				position.x = (roundi(get_caret_column() * 20.0) * 0.05 * (parent.size.x - WIDTH))
			position.x = mini(maxi(0, position.x), parent.size.x - size.x)
			grand_parent.update_from_value()
			label.text = "%.03f" % get_caret_column()

	func get_caret_column() -> float:
		return position.x / (parent.size.x - WIDTH)

	func set_color(c: Color) -> void:
		color = c
		grand_parent.update_from_value()
		queue_redraw()

	func _can_drop_data(_position: Vector2, data) -> bool:
		return typeof(data) == TYPE_COLOR

	func _drop_data(_position: Vector2, data) -> void:
		set_color(data)


func _init() -> void:
	texture.gradient = gradient


func _ready() -> void:
	texture_rect.texture = texture
	_create_cursors()
	%InterpolationOptionButton.select(gradient.interpolation_mode)
	%ColorSpaceOptionButton.select(gradient.interpolation_color_space)


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
		var p := clampf(ev.position.x, 0, x_offset)
		add_cursor(p, get_gradient_color(p))
		continuous_change = false
		update_from_value()


func update_from_value() -> void:
	gradient.offsets = []
	for c in texture_rect.get_children():
		if c is GradientCursor:
			var point: float = c.position.x / x_offset
			gradient.add_point(point, c.color)
	updated.emit(gradient, continuous_change)
	continuous_change = true


func add_cursor(x: float, color: Color) -> void:
	var cursor := GradientCursor.new()
	texture_rect.add_child(cursor)
	cursor.position.x = x
	cursor.color = color


func select_color(cursor: GradientCursor, pos: Vector2) -> void:
	active_cursor = cursor
	color_picker.color = cursor.color
	if pos.x > global_position.x + (size.x / 2.0):
		pos.x = global_position.x + size.x
	else:
		pos.x = global_position.x - $Popup.size.x
	$Popup.popup_on_parent(Rect2i(pos, Vector2.ONE))


func get_sorted_cursors() -> Array:
	var array: Array[GradientCursor] = []
	for c in texture_rect.get_children():
		if c is GradientCursor:
			array.append(c)
	array.sort_custom(
		func(a: GradientCursor, b: GradientCursor): return a.get_position() < b.get_position()
	)
	return array


func get_gradient_color(x: float) -> Color:
	return gradient.sample(x / x_offset)


func set_gradient_texture_1d(new_texture: GradientTexture1D) -> void:
	texture = GradientTexture2D.new()
	texture.gradient = new_texture.gradient
	$TextureRect.texture = texture
	gradient = texture.gradient


func set_gradient_texture(new_texture: GradientTexture2D) -> void:
	$TextureRect.texture = new_texture
	texture = new_texture
	gradient = texture.gradient


func _on_ColorPicker_color_changed(color: Color) -> void:
	active_cursor.set_color(color)


func _on_GradientEdit_resized() -> void:
	if not is_instance_valid(texture_rect):
		return
	x_offset = size.x - GradientCursor.WIDTH
	_create_cursors()


func _on_InterpolationOptionButton_item_selected(index: Gradient.InterpolationMode) -> void:
	gradient.interpolation_mode = index
	updated.emit(gradient, continuous_change)


func _on_color_space_option_button_item_selected(index: Gradient.ColorSpace) -> void:
	gradient.interpolation_color_space = index
	updated.emit(gradient, continuous_change)


func _on_DivideButton_pressed() -> void:
	divide_dialog.popup_centered()


func _on_DivideConfirmationDialog_confirmed() -> void:
	var add_point_to_end := add_point_end_check_box.button_pressed
	var parts := number_of_parts_spin_box.value
	var colors: PackedColorArray = []
	var end_point := 1 if add_point_to_end else 0
	parts -= end_point

	if not add_point_to_end:
		# Move the final color one part behind, useful for it to be in constant interpolation
		gradient.add_point((parts - 1) / parts, gradient.sample(1))
	for i in parts + end_point:
		colors.append(gradient.sample(i / parts))
	gradient.offsets = []
	for i in parts + end_point:
		gradient.add_point(i / parts, colors[i])
	_create_cursors()
	updated.emit(gradient, continuous_change)
