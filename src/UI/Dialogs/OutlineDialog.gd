extends ConfirmationDialog


var pixels := []

onready var outline_color = $OptionsContainer/OutlineColor
onready var thick_value = $OptionsContainer/ThickValue
onready var diagonal_checkbox = $OptionsContainer/DiagonalCheckBox
onready var inside_image_checkbox = $OptionsContainer/InsideImageCheckBox
onready var selection_checkbox = $OptionsContainer/SelectionCheckBox


func _ready() -> void:
	outline_color.get_picker().presets_visible = false


func _on_OutlineDialog_about_to_show() -> void:
	_on_SelectionCheckBox_toggled(selection_checkbox.pressed)


func _on_OutlineDialog_confirmed() -> void:
	var color : Color = outline_color.color
	var thickness : int = thick_value.value
	var diagonal : bool = diagonal_checkbox.pressed
	var inside_image : bool = inside_image_checkbox.pressed

	var image : Image = Global.current_project.frames[Global.current_project.current_frame].cels[Global.current_project.current_layer].image
	DrawingAlgos.generate_outline(image, pixels, color, thickness, diagonal, inside_image)


func _on_SelectionCheckBox_toggled(button_pressed : bool) -> void:
	pixels.clear()
	if button_pressed:
		pixels = Global.current_project.selected_pixels.duplicate()
	else:
		for x in Global.current_project.size.x:
			for y in Global.current_project.size.y:
				pixels.append(Vector2(x, y))
