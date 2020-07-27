extends ConfirmationDialog


var pixels := []
var current_cel : Image
var preview_image : Image
var preview_texture : ImageTexture

var color := Color.red
var thickness := 1
var diagonal := false
var inside_image := false

onready var preview : TextureRect = $VBoxContainer/Preview
onready var outline_color = $VBoxContainer/OptionsContainer/OutlineColor
#onready var thick_value = $VBoxContainer/OptionsContainer/ThickValue
#onready var diagonal_checkbox = $VBoxContainer/OptionsContainer/DiagonalCheckBox
#onready var inside_image_checkbox = $VBoxContainer/OptionsContainer/InsideImageCheckBox
onready var selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox


func _ready() -> void:
	current_cel = Image.new()
	preview_image = Image.new()
	preview_texture = ImageTexture.new()
	outline_color.get_picker().presets_visible = false
	color = outline_color.color


func _on_OutlineDialog_about_to_show() -> void:
	current_cel = Global.current_project.frames[Global.current_project.current_frame].cels[Global.current_project.current_layer].image
	_on_SelectionCheckBox_toggled(selection_checkbox.pressed)


func _on_OutlineDialog_confirmed() -> void:
	Global.canvas.handle_undo("Draw")
	DrawingAlgos.generate_outline(current_cel, pixels, color, thickness, diagonal, inside_image)
	Global.canvas.handle_redo("Draw")


func _on_SelectionCheckBox_toggled(button_pressed : bool) -> void:
	pixels.clear()
	if button_pressed:
		pixels = Global.current_project.selected_pixels.duplicate()
	else:
		for x in Global.current_project.size.x:
			for y in Global.current_project.size.y:
				pixels.append(Vector2(x, y))

	update_preview()


func _on_ThickValue_value_changed(value : int):
	thickness = value
	update_preview()


func _on_OutlineColor_color_changed(_color : Color):
	color = _color
	update_preview()


func _on_DiagonalCheckBox_toggled(button_pressed : bool):
	diagonal = button_pressed
	update_preview()


func _on_InsideImageCheckBox_toggled(button_pressed : bool):
	inside_image = button_pressed
	update_preview()


func update_preview() -> void:
	preview_image.copy_from(current_cel)
	DrawingAlgos.generate_outline(preview_image, pixels, color, thickness, diagonal, inside_image)
	preview_texture.create_from_image(preview_image, 0)
	preview.texture = preview_texture
