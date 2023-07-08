extends Container

@onready var left_picker := $ColorPickersHorizontal/LeftColorPickerButton
@onready var right_picker := $ColorPickersHorizontal/RightColorPickerButton
@onready var average_color = $"%AverageColor"
@onready var transparent_checker = $"%TransparentChecker"


func _ready() -> void:
	Tools.connect("color_changed", Callable(self, "update_color"))
	left_picker.get_picker().presets_visible = false
	right_picker.get_picker().presets_visible = false
	_average(left_picker.color, right_picker.color)
	transparent_checker.position = average_color.position
	transparent_checker.size = average_color.size


func _on_ColorSwitch_pressed() -> void:
	Tools.swap_color()


func _on_ColorPickerButton_color_changed(color: Color, right: bool):
	var button := MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
	Tools.assign_color(color, button)
	_average(left_picker.color, right_picker.color)


func _on_ToLeft_pressed():
	Tools.assign_color(average_color.color, MOUSE_BUTTON_LEFT)


func _on_ToRight_pressed():
	Tools.assign_color(average_color.color, MOUSE_BUTTON_RIGHT)


func _on_ColorPickerButton_pressed() -> void:
	Global.can_draw = false
	Tools.disconnect("color_changed", Callable(self, "update_color"))


func _on_ColorPickerButton_popup_closed() -> void:
	Global.can_draw = true
	Tools.connect("color_changed", Callable(self, "update_color"))


func _on_ColorDefaults_pressed() -> void:
	Tools.default_color()


func update_color(color: Color, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		left_picker.color = color
	else:
		right_picker.color = color
	_average(left_picker.color, right_picker.color)


func _average(color_1: Color, color_2: Color) -> void:
	var average_r = (color_1.r + color_2.r) / 2.0
	var average_g = (color_1.g + color_2.g) / 2.0
	var average_b = (color_1.b + color_2.b) / 2.0
	var average_a = (color_1.a + color_2.a) / 2.0
	var average := Color(average_r, average_g, average_b, average_a)

	var copy_button = average_color.get_parent()
	copy_button.tooltip_text = str("Average Color:\n#", average.to_html(), "\n(Press to Copy)")
	average_color.color = average


func _on_CopyAverage_button_down():
	transparent_checker.visible = false
	average_color.visible = false
	OS.clipboard = average_color.color.to_html()


func _on_CopyAverage_button_up():
	transparent_checker.visible = true
	average_color.visible = true
