extends VBoxContainer


onready var left_picker := $ColorButtonsVertical/ColorPickersCenter/ColorPickersHorizontal/LeftColorPickerButton
onready var right_picker := $ColorButtonsVertical/ColorPickersCenter/ColorPickersHorizontal/RightColorPickerButton


func _ready() -> void:
	Tools.connect("color_changed", self, "update_color")
	left_picker.get_picker().presets_visible = false
	right_picker.get_picker().presets_visible = false


func _on_ColorSwitch_pressed() -> void:
	Tools.swap_color()


func _on_ColorPickerButton_color_changed(color : Color, right : bool):
	var button := BUTTON_RIGHT if right else BUTTON_LEFT
	Tools.assign_color(color, button)


func _on_ColorPickerButton_pressed() -> void:
	Global.can_draw = false
	Tools.disconnect("color_changed", self, "update_color")


func _on_ColorPickerButton_popup_closed() -> void:
	Global.can_draw = true
	Tools.connect("color_changed", self, "update_color")


func _on_ColorDefaults_pressed() -> void:
	Tools.default_color()


func update_color(color : Color, button : int) -> void:
	if button == BUTTON_LEFT:
		left_picker.color = color
	else:
		right_picker.color = color
