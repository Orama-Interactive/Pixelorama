# Code taken and modified from Material Maker, licensed under MIT
# gdlint: ignore=max-line-length
# https://github.com/RodZill4/material-maker/blob/master/material_maker/widgets/gradient_editor/gradient_editor.gd
class_name GradientEditNode
extends Control

signal updated(gradient: Gradient, cc: bool)

const GRADIENT_DIR := "user://gradients"

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
var presets: Array[Preset] = []

@onready var x_offset: float = size.x - GradientCursor.WIDTH
@onready var offset_value_slider := %OffsetValueSlider as ValueSlider
@onready var interpolation_option_button: OptionButton = %InterpolationOptionButton
@onready var color_space_option_button: OptionButton = %ColorSpaceOptionButton
@onready var tools_menu_button: MenuButton = %ToolsMenuButton
@onready var preset_list_button: Button = %PresetListButton
@onready var presets_container: VBoxContainer = %PresetsContainer
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


class Preset:
	var gradient: Gradient
	var file_name := ""

	func _init(_gradient: Gradient, _file_name := "") -> void:
		gradient = _gradient
		file_name = _file_name


func _init() -> void:
	texture.gradient = gradient


func _ready() -> void:
	texture_rect.texture = texture
	_create_cursors()
	interpolation_option_button.select(gradient.interpolation_mode)
	color_space_option_button.select(gradient.interpolation_color_space)
	tools_menu_button.get_popup().index_pressed.connect(_on_tools_menu_button_index_pressed)


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


func serialize_gradient(grad: Gradient) -> Dictionary:
	var dict := {}
	dict["offsets"] = grad.offsets
	dict["colors"] = var_to_str(grad.colors)
	dict["interpolation_mode"] = grad.interpolation_mode
	dict["interpolation_color_space"] = grad.interpolation_color_space
	return dict


func deserialize_gradient(dict: Dictionary) -> Gradient:
	var new_gradient := Gradient.new()
	new_gradient.offsets = dict.get("offsets", new_gradient.offsets)
	var colors = str_to_var(dict.get("colors"))
	new_gradient.colors = colors
	new_gradient.interpolation_mode = dict.get(
		"interpolation_mode", new_gradient.interpolation_mode
	)
	new_gradient.interpolation_color_space = dict.get(
		"interpolation_color_space", new_gradient.interpolation_color_space
	)
	return new_gradient


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


func _initialize_presets() -> void:
	presets.clear()
	for child in presets_container.get_children():
		child.queue_free()
	presets.append(Preset.new(Gradient.new()))  # Left to right
	presets.append(Preset.new(Gradient.new()))  # Left to transparent
	presets.append(Preset.new(Gradient.new()))  # Black to white
	# Update left to right and left to transparent gradients
	presets[0].gradient.set_color(0, Tools.get_assigned_color(MOUSE_BUTTON_LEFT))
	presets[0].gradient.set_color(1, Tools.get_assigned_color(MOUSE_BUTTON_RIGHT))
	presets[1].gradient.set_color(0, Tools.get_assigned_color(MOUSE_BUTTON_LEFT))
	presets[1].gradient.set_color(1, Color(0, 0, 0, 0))
	for file_name in DirAccess.get_files_at(GRADIENT_DIR):
		var full_file_name := GRADIENT_DIR.path_join(file_name)
		var file := FileAccess.open(full_file_name, FileAccess.READ)
		var json := file.get_as_text()
		var dict = JSON.parse_string(json)
		if typeof(dict) == TYPE_DICTIONARY:
			var preset_gradient := deserialize_gradient(dict)
			presets.append(Preset.new(preset_gradient, full_file_name))
	for preset in presets:
		_create_preset_button(preset)


func _on_save_to_presets_button_pressed() -> void:
	if not DirAccess.dir_exists_absolute(GRADIENT_DIR):
		DirAccess.make_dir_absolute(GRADIENT_DIR)
	var json := JSON.stringify(serialize_gradient(gradient))
	var file_name := GRADIENT_DIR.path_join(str(floori(Time.get_unix_time_from_system())))
	var file := FileAccess.open(file_name, FileAccess.WRITE)
	file.store_string(json)


func _on_preset_list_button_pressed() -> void:
	_initialize_presets()
	var popup_panel := preset_list_button.get_child(0) as PopupPanel
	var popup_position := preset_list_button.get_screen_position()
	popup_position.y += preset_list_button.size.y + 4
	popup_panel.popup(Rect2i(popup_position, Vector2i.ONE))


func _create_preset_button(preset: Preset) -> void:
	var grad_texture := GradientTexture2D.new()
	grad_texture.height = 32
	grad_texture.gradient = preset.gradient
	var gradient_button := Button.new()
	gradient_button.icon = grad_texture
	gradient_button.gui_input.connect(_on_preset_button_gui_input.bind(preset))
	presets_container.add_child(gradient_button)


func _on_preset_button_gui_input(event: InputEvent, preset: Preset) -> void:
	if event is not InputEventMouseButton:
		return
	if event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:  # Select preset
		gradient = preset.gradient.duplicate()
		texture.gradient = gradient
		_create_cursors()
		updated.emit(gradient, continuous_change)
		var popup_panel := preset_list_button.get_child(0) as PopupPanel
		popup_panel.hide()
	elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
		# Remove preset
		if preset.file_name.is_empty():
			return
		DirAccess.remove_absolute(preset.file_name)
		presets.erase(preset)
		var button := presets_container.get_child(presets.find(preset)) as Button
		button.queue_free()


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
