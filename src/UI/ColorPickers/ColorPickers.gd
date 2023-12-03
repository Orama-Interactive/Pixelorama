extends Container

var picking_color := MOUSE_BUTTON_LEFT

@onready var average_color := %AverageColor as ColorRect
@onready var color_picker := %ColorPicker as ColorPicker
@onready var right_color_rect := %RightColorRect as ColorRect
@onready var left_color_rect := %LeftColorRect as ColorRect


func _ready() -> void:
	Tools.color_changed.connect(update_color)
	_average(left_color_rect.color, right_color_rect.color)

	# Make changes to the UI of the color picker by modifying its internal children
	await get_tree().process_frame
	var picker_margin_container := color_picker.get_child(0, true) as MarginContainer
	picker_margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var picker_vbox_container := picker_margin_container.get_child(0, true) as VBoxContainer
	var shapes_container := picker_vbox_container.get_child(0, true) as HBoxContainer
	shapes_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var square_picker := shapes_container.get_child(0, true) as Control
	var shape_aspect_ratio := shapes_container.get_child(1, true) as AspectRatioContainer
	square_picker.custom_minimum_size = Vector2(32, 32)
	shape_aspect_ratio.custom_minimum_size = Vector2(32, 32)
	var sampler_cont := picker_vbox_container.get_child(1, true) as HBoxContainer
	var color_texture_rect := sampler_cont.get_child(1, true) as TextureRect
	color_texture_rect.visible = false
	var hex_cont := picker_vbox_container.get_child(4, true).get_child(1, true) as Container
	var hex_edit := hex_cont.get_child(2, true)
	hex_cont.remove_child(hex_edit)
	sampler_cont.add_child(hex_edit)
	sampler_cont.move_child(hex_edit, 1)


func _on_color_picker_color_changed(color: Color) -> void:
	if picking_color == MOUSE_BUTTON_RIGHT:
		right_color_rect.color = color
	else:
		left_color_rect.color = color
	Tools.assign_color(color, picking_color)


func _on_left_color_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		picking_color = MOUSE_BUTTON_LEFT
		color_picker.color = left_color_rect.color
	else:
		picking_color = MOUSE_BUTTON_RIGHT
		color_picker.color = right_color_rect.color
	_average(left_color_rect.color, right_color_rect.color)


func update_color(color: Color, button: int) -> void:
	if picking_color == button:
		color_picker.color = color
	if button == MOUSE_BUTTON_RIGHT:
		right_color_rect.color = color
	else:
		left_color_rect.color = color
	_average(left_color_rect.color, right_color_rect.color)


func _on_ColorSwitch_pressed() -> void:
	Tools.swap_color()


func _on_ColorDefaults_pressed() -> void:
	Tools.default_color()


func _average(color_1: Color, color_2: Color) -> void:
	var average_r := (color_1.r + color_2.r) / 2.0
	var average_g := (color_1.g + color_2.g) / 2.0
	var average_b := (color_1.b + color_2.b) / 2.0
	var average_a := (color_1.a + color_2.a) / 2.0
	var average := Color(average_r, average_g, average_b, average_a)

	var copy_button := average_color.get_parent() as Control
	copy_button.tooltip_text = str("Average Color:\n#", average.to_html())
	average_color.color = average


func _on_CopyAverage_button_down():
	average_color.visible = false


func _on_CopyAverage_button_up():
	average_color.visible = true


func _on_copy_average_gui_input(event: InputEvent) -> void:
	if event.is_action_released(&"left_mouse"):
		Tools.assign_color(average_color.color, MOUSE_BUTTON_LEFT)
	elif event.is_action_released(&"right_mouse"):
		Tools.assign_color(average_color.color, MOUSE_BUTTON_RIGHT)
