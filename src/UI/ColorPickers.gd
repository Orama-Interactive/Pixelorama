extends Container

onready var left_picker := $VBoxContainer/ColorPickersHorizontal/LeftColorPickerButton
onready var right_picker := $VBoxContainer/ColorPickersHorizontal/RightColorPickerButton


func _ready() -> void:
	Tools.connect("color_changed", self, "update_color")
	left_picker.get_picker().presets_visible = false
	right_picker.get_picker().presets_visible = false
	$VBoxContainer/Mirror/Horizontal.pressed = Tools.horizontal_mirror
	$VBoxContainer/Mirror/Vertical.pressed = Tools.vertical_mirror


func _on_ColorSwitch_pressed() -> void:
	Tools.swap_color()


func _on_ColorPickerButton_color_changed(color: Color, right: bool):
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


func update_color(color: Color, button: int) -> void:
	if button == BUTTON_LEFT:
		left_picker.color = color
	else:
		right_picker.color = color


func _on_Horizontal_toggled(button_pressed: bool) -> void:
	Tools.horizontal_mirror = button_pressed
	Global.config_cache.set_value("preferences", "horizontal_mirror", button_pressed)
	Global.show_y_symmetry_axis = button_pressed
	Global.current_project.y_symmetry_axis.visible = (
		Global.show_y_symmetry_axis
		and Global.show_guides
	)

	var texture_button: TextureRect = $VBoxContainer/Mirror/Horizontal/TextureRect
	var file_name := "horizontal_mirror_on.png"
	if !button_pressed:
		file_name = "horizontal_mirror_off.png"
	Global.change_button_texturerect(texture_button, file_name)


func _on_Vertical_toggled(button_pressed: bool) -> void:
	Tools.vertical_mirror = button_pressed
	Global.config_cache.set_value("preferences", "vertical_mirror", button_pressed)
	Global.show_x_symmetry_axis = button_pressed
	# If the button is not pressed but another button is, keep the symmetry guide visible
	Global.current_project.x_symmetry_axis.visible = (
		Global.show_x_symmetry_axis
		and Global.show_guides
	)

	var texture_button: TextureRect = $VBoxContainer/Mirror/Vertical/TextureRect
	var file_name := "vertical_mirror_on.png"
	if !button_pressed:
		file_name = "vertical_mirror_off.png"
	Global.change_button_texturerect(texture_button, file_name)
