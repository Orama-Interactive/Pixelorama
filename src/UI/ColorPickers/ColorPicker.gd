extends Container

const VALUE_ARROW := preload("res://assets/graphics/misc/value_arrow_right.svg")
const VALUE_ARROW_EXPANDED := preload("res://assets/graphics/misc/value_arrow.svg")

## The internal control node of the HSV Rectangle of the [ColorPicker] node.
var hsv_rectangle_control: Control
## The internal aspect ratio container node of other color shapes of the [ColorPicker] node.
var shape_aspect_ratio: AspectRatioContainer
## The internal swatches button of the [ColorPicker] node.
## Used to ensure that swatches are always invisible.
var swatches_button: Button
## The internal container for the color sliders of the [ColorPicker] node.
var color_sliders_vbox: VBoxContainer
var _skip_color_picker_update := false
@onready var color_picker := %ColorPicker as ColorPicker
@onready var color_buttons := %ColorButtons as HBoxContainer
@onready var left_color_rect := %LeftColorRect as ColorRect
@onready var right_color_rect := %RightColorRect as ColorRect
@onready var average_color := %AverageColor as ColorRect
@onready var expand_button: Button = $ScrollContainer/VerticalContainer/ExpandButton


func _ready() -> void:
	Tools.options_reset.connect(reset_options)
	Tools.color_changed.connect(update_color)
	_average(left_color_rect.color, right_color_rect.color)
	color_picker.color_mode = Global.config_cache.get_value(
		"color_picker", "color_mode", ColorPicker.MODE_RGB
	)
	color_picker.picker_shape = Global.config_cache.get_value(
		"color_picker", "picker_shape", ColorPicker.SHAPE_HSV_RECTANGLE
	)

	# Make changes to the UI of the color picker by modifying its internal children
	await get_tree().process_frame
	# The MarginContainer that contains all of the color picker nodes.
	var picker_margin_container := color_picker.get_child(0, true) as MarginContainer
	picker_margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var picker_vbox_container := picker_margin_container.get_child(0, true) as VBoxContainer
	# The HBoxContainer of the picker shapes.
	var shapes_container := picker_vbox_container.get_child(0, true) as HBoxContainer
	shapes_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The Control of the HSV Rectangle picker shape
	hsv_rectangle_control = shapes_container.get_child(0, true) as Control
	hsv_rectangle_control.custom_minimum_size = Vector2(32, 32)
	# The AspectRatioContainer that holds the rest of the picker shapes
	shape_aspect_ratio = shapes_container.get_child(1, true) as AspectRatioContainer
	shape_aspect_ratio.custom_minimum_size = Vector2(32, 32)
	# The HBoxContainer of the screen color picker, the color preview rectangle and the
	# button that lets users change the picker shape. It is visible because
	# color_picker.sampler_visible is set to true.
	# We are hiding the color preview rectangle, adding the hex LineEdit, the
	# left/right color buttons and the color switch, default and average buttons.
	var sampler_cont := picker_vbox_container.get_child(1, true) as HBoxContainer
	# The color preview rectangle that we're hiding.
	var color_texture_rect := sampler_cont.get_child(1, true) as TextureRect
	color_texture_rect.visible = false
	# The HBoxContainer where we get the hex LineEdit node from, and moving it to sampler_cont
	var hex_cont := picker_vbox_container.get_child(4, true).get_child(1, true) as Container
	var hex_edit := hex_cont.get_child(2, true)
	hex_cont.remove_child(hex_edit)
	sampler_cont.add_child(hex_edit)
	sampler_cont.move_child(hex_edit, 1)
	# Move the color buttons (left, right, switch, default, average) on the sampler container
	color_buttons.get_parent().remove_child(color_buttons)
	sampler_cont.add_child(color_buttons)
	sampler_cont.move_child(color_buttons, 0)

	var empty_vbox_container := picker_vbox_container.get_child(3, true) as VBoxContainer
	empty_vbox_container.visible = false
	color_sliders_vbox = picker_vbox_container.get_child(4, true) as VBoxContainer
	color_sliders_vbox.visible = false
	swatches_button = picker_vbox_container.get_child(5, true) as Button
	swatches_button.visible = false
	# The GridContainer that contains the swatch buttons. These are not visible in our case
	# but for some reason its h_separation needs to be set to a value larger than 4,
	# otherwise a weird bug occurs with the Recent Colors where, adding new colors
	# increases the size of the color buttons.
	var presets_container := picker_vbox_container.get_child(6, true) as GridContainer
	presets_container.add_theme_constant_override("h_separation", 5)
	# Move the expand button above the RGB, HSV etc buttons
	expand_button.get_parent().remove_child(expand_button)
	picker_vbox_container.add_child(expand_button)
	picker_vbox_container.move_child(expand_button, 2)

	expand_button.button_pressed = Global.config_cache.get_value(
		"color_picker", "is_expanded", false
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_instance_valid(hsv_rectangle_control):
		# If there's a theme change, reset the custom minimum sizes of the color shapes
		await get_tree().process_frame
		hsv_rectangle_control.custom_minimum_size = Vector2(32, 32)
		shape_aspect_ratio.custom_minimum_size = Vector2(32, 32)
	elif what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(left_color_rect):
		_average(left_color_rect.color, right_color_rect.color)


func _on_color_picker_color_changed(color: Color) -> void:
	# Due to the decimal nature of the color values, some values get rounded off
	# unintentionally before entering this method.
	# Even though the decimal values change, the HTML code remains the same after the change.
	# So we're using this trick to convert the values back to how they are shown in
	# the color picker's UI.
	color = Color(color.to_html())
	_skip_color_picker_update = true
	Tools.assign_color(color, Tools.picking_color_for)


func _on_left_color_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		Tools.picking_color_for = MOUSE_BUTTON_LEFT
		color_picker.color = left_color_rect.color
	else:
		Tools.picking_color_for = MOUSE_BUTTON_RIGHT
		color_picker.color = right_color_rect.color
	_average(left_color_rect.color, right_color_rect.color)


func reset_options() -> void:
	color_picker.color_mode = ColorPicker.MODE_RGB
	color_picker.picker_shape = ColorPicker.SHAPE_HSV_RECTANGLE
	expand_button.button_pressed = false


func update_color(color_info: Dictionary, button: int) -> void:
	var color = color_info.get("color", Color.WHITE)
	if Tools.picking_color_for == button and not _skip_color_picker_update:
		color_picker.color = color
	if button == MOUSE_BUTTON_RIGHT:
		right_color_rect.color = color
	else:
		left_color_rect.color = color
	_average(left_color_rect.color, right_color_rect.color)
	Global.config_cache.set_value("color_picker", "color_mode", color_picker.color_mode)
	Global.config_cache.set_value("color_picker", "picker_shape", color_picker.picker_shape)
	_skip_color_picker_update = false


func _on_ColorSwitch_pressed() -> void:
	Tools.swap_color()


func _on_ColorDefaults_pressed() -> void:
	Tools.default_color()


func _on_expand_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		expand_button.icon = VALUE_ARROW_EXPANDED
	else:
		expand_button.icon = VALUE_ARROW
	color_picker.color_modes_visible = toggled_on
	color_picker.sliders_visible = toggled_on
	color_picker.presets_visible = toggled_on
	if is_instance_valid(swatches_button):
		swatches_button.visible = false
	if is_instance_valid(color_sliders_vbox):
		color_sliders_vbox.visible = toggled_on
	Global.config_cache.set_value("color_picker", "is_expanded", toggled_on)


func _average(color_1: Color, color_2: Color) -> void:
	var average := (color_1 + color_2) / 2.0
	var copy_button := average_color.get_parent() as Control
	copy_button.tooltip_text = str(tr("Average Color:"), "\n#", average.to_html())
	average_color.color = average


func _on_CopyAverage_button_down() -> void:
	average_color.visible = false


func _on_CopyAverage_button_up() -> void:
	average_color.visible = true


func _on_copy_average_gui_input(event: InputEvent) -> void:
	if event.is_action_released(&"left_mouse"):
		Tools.assign_color(average_color.color, MOUSE_BUTTON_LEFT)
	elif event.is_action_released(&"right_mouse"):
		Tools.assign_color(average_color.color, MOUSE_BUTTON_RIGHT)
