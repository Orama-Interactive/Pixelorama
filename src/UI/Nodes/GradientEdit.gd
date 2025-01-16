# Code taken and modified from Material Maker, licensed under MIT
# gdlint: ignore=max-line-length
# https://github.com/RodZill4/material-maker/blob/master/material_maker/widgets/gradient_editor/gradient_editor.gd
class_name GradientEditNode
extends Control

signal updated(gradient: Gradient, cc: bool)

var continuous_change := true
var active_cursor: GradientCursor:  ## Showing a color picker popup to change a cursor's color
	set(value):
		active_cursor = value
		if is_instance_valid(active_cursor):
			await get_tree().process_frame
			offset_value_slider.set_value_no_signal_update_display(
				active_cursor.get_cursor_offset()
			)
		for i in texture_rect.get_children():
			i.queue_redraw()
var texture := GradientTexture2D.new()
var gradient := Gradient.new()
var presets: Array[Gradient] = []

@onready var x_offset: float = size.x - GradientCursor.WIDTH
@onready var offset_value_slider := %OffsetValueSlider as ValueSlider
@onready var interpolation_option_button: OptionButton = %InterpolationOptionButton
@onready var color_space_option_button: OptionButton = %ColorSpaceOptionButton
@onready var tools_menu_button: MenuButton = %ToolsMenuButton
@onready var presets_menu_button: MenuButton = %PresetsMenuButton
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
	@onready var grand_parent: GradientEditNode = parent.get_parent()

	func _ready() -> void:
		size = Vector2(WIDTH, get_parent().size.y)

	func _draw() -> void:
		var polygon := PackedVector2Array(
			[
				Vector2(0, size.y * 0.75),
				Vector2(WIDTH * 0.5, size.y * 0.5),
				Vector2(WIDTH, size.y * 0.75),
				Vector2(WIDTH, size.y),
				Vector2(0, size.y),
				Vector2(0, size.y * 0.75)
			]
		)
		var c := color
		c.a = 1.0
		draw_colored_polygon(polygon, c)
		var outline_color := Color.BLACK if (color.get_luminance() > 0.5) else Color.WHITE
		draw_polyline(polygon, outline_color)
		draw_dashed_line(Vector2(WIDTH * 0.5, 0), Vector2(WIDTH * 0.5, size.y * 0.5), outline_color)
		# Draw the TRIANGLE (house roof) shape
		if grand_parent.active_cursor == self:
			var active_polygon: PackedVector2Array = PackedVector2Array(
				[
					Vector2(0, size.y * 0.75),
					Vector2(WIDTH * 0.5, size.y * 0.5),
					Vector2(WIDTH, size.y * 0.75),
					Vector2(0, size.y * 0.75)
				]
			)
			draw_colored_polygon(active_polygon, outline_color)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			if ev.button_index == MOUSE_BUTTON_LEFT:
				if ev.double_click:
					grand_parent.select_color(self, ev.global_position)
				elif ev.pressed:
					grand_parent.active_cursor = self
					grand_parent.continuous_change = false
					sliding = true
				else:
					sliding = false
			elif (
				ev.button_index == MOUSE_BUTTON_RIGHT
				and grand_parent.get_sorted_cursors().size() > 2
			):
				var node_index := get_index()
				parent.remove_child(self)
				queue_free()
				if grand_parent.active_cursor == self:
					if node_index > 0:
						node_index -= 1
					grand_parent.active_cursor = parent.get_child(node_index)
				grand_parent.continuous_change = false
				grand_parent.update_from_value()
		elif (
			ev is InputEventMouseMotion
			and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
			and sliding
		):
			move_to(position.x + get_local_mouse_position().x, true, ev.ctrl_pressed)

	func move_to(pos: float, update_slider: bool, snap := false) -> void:
		position.x = pos
		if snap:
			position.x = (roundi(get_cursor_offset() * 20.0) * 0.05 * (parent.size.x - WIDTH))
		position.x = mini(maxi(0, position.x), parent.size.x - size.x)
		grand_parent.update_from_value()
		if update_slider:
			grand_parent.offset_value_slider.value = get_cursor_offset()

	func get_cursor_offset() -> float:
		return position.x / (parent.size.x - WIDTH)

	func get_cursor_position_from_offset(offset: float) -> float:
		return offset * (parent.size.x - WIDTH)

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
	presets.append(Gradient.new())  # Left to right
	presets.append(Gradient.new())  # Left to transparent
	presets.append(Gradient.new())  # Black to white


func _ready() -> void:
	texture_rect.texture = texture
	_create_cursors()
	interpolation_option_button.select(gradient.interpolation_mode)
	color_space_option_button.select(gradient.interpolation_color_space)
	tools_menu_button.get_popup().index_pressed.connect(_on_tools_menu_button_index_pressed)
	presets_menu_button.get_popup().index_pressed.connect(_on_presets_menu_button_index_pressed)
	for preset in presets:
		var grad_texture := GradientTexture2D.new()
		grad_texture.height = 32
		grad_texture.gradient = preset
		presets_menu_button.get_popup().add_icon_item(grad_texture, "")


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
	active_cursor = cursor
	cursor.position.x = x
	cursor.color = color


func select_color(cursor: GradientCursor, pos: Vector2) -> void:
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


func _on_offset_value_slider_value_changed(value: float) -> void:
	var cursor_pos := active_cursor.get_cursor_position_from_offset(value)
	if cursor_pos != active_cursor.get_cursor_offset():
		active_cursor.move_to(cursor_pos, false)


func _on_InterpolationOptionButton_item_selected(index: Gradient.InterpolationMode) -> void:
	gradient.interpolation_mode = index
	updated.emit(gradient, continuous_change)


func _on_color_space_option_button_item_selected(index: Gradient.ColorSpace) -> void:
	gradient.interpolation_color_space = index
	updated.emit(gradient, continuous_change)


func _on_tools_menu_button_index_pressed(index: int) -> void:
	if index == 0:  # Reverse
		gradient.reverse()
		_create_cursors()
		updated.emit(gradient, continuous_change)
	elif index == 1:  # Evenly distribute points
		var point_count := gradient.get_point_count()
		for i in range(point_count):
			gradient.set_offset(i, 1.0 / (point_count - 1) * i)
		_create_cursors()
		updated.emit(gradient, continuous_change)
	elif index == 2:  # Divide into equal parts
		divide_dialog.popup_centered()


func _on_presets_menu_button_about_to_popup() -> void:
	# Update left to right and left to transparent gradients
	presets[0].set_color(0, Tools.get_assigned_color(MOUSE_BUTTON_LEFT))
	presets[0].set_color(1, Tools.get_assigned_color(MOUSE_BUTTON_RIGHT))
	presets[1].set_color(0, Tools.get_assigned_color(MOUSE_BUTTON_LEFT))
	presets[1].set_color(1, Color(0, 0, 0, 0))


func _on_presets_menu_button_index_pressed(index: int) -> void:
	var item_icon := presets_menu_button.get_popup().get_item_icon(index) as GradientTexture2D
	gradient = item_icon.gradient.duplicate()
	texture.gradient = gradient
	_create_cursors()
	updated.emit(gradient, continuous_change)


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
