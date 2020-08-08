extends ConfirmationDialog


enum {CEL, FRAME, ALL_FRAMES, ALL_PROJECTS}

var affect : int = CEL
var pixels := []
var current_cel : Image
var preview_image : Image
var preview_texture : ImageTexture

onready var preview : TextureRect = $VBoxContainer/Preview
onready var color1 : ColorPickerButton = $VBoxContainer/OptionsContainer/ColorsContainer/ColorPickerButton
onready var color2 : ColorPickerButton = $VBoxContainer/OptionsContainer/ColorsContainer/ColorPickerButton2
onready var steps : SpinBox = $VBoxContainer/OptionsContainer/StepSpinBox
onready var direction : OptionButton = $VBoxContainer/OptionsContainer/DirectionOptionButton
onready var selection_checkbox : CheckBox = $VBoxContainer/OptionsContainer/SelectionCheckBox


func _ready() -> void:
	preview_image = Image.new()
	preview_texture = ImageTexture.new()
	color1.get_picker().presets_visible = false
	color2.get_picker().presets_visible = false


func _on_GradientDialog_about_to_show() -> void:
	current_cel = Global.current_project.frames[Global.current_project.current_frame].cels[Global.current_project.current_layer].image
	_on_SelectionCheckBox_toggled(selection_checkbox.pressed)


func update_preview() -> void:
	preview_image.copy_from(current_cel)
	DrawingAlgos.generate_gradient(preview_image, [color1.color, color2.color], steps.value, direction.selected, pixels)
	preview_texture.create_from_image(preview_image, 0)
	preview.texture = preview_texture


func _on_ColorPickerButton_color_changed(_color : Color) -> void:
	update_preview()


func _on_ColorPickerButton2_color_changed(_color : Color) -> void:
	update_preview()


func _on_StepSpinBox_value_changed(_value : int) -> void:
	update_preview()


func _on_OptionButton_item_selected(_index : int) -> void:
	update_preview()


func _on_SelectionCheckBox_toggled(button_pressed : bool) -> void:
	pixels.clear()
	if button_pressed:
		pixels = Global.current_project.selected_pixels.duplicate()
	else:
		for x in Global.current_project.size.x:
			for y in Global.current_project.size.y:
				pixels.append(Vector2(x, y))

	update_preview()


func _on_AffectOptionButton_item_selected(index : int) -> void:
	affect = index


func _on_GradientDialog_confirmed() -> void:
	if affect == CEL:
		Global.canvas.handle_undo("Draw")
		DrawingAlgos.generate_gradient(current_cel, [color1.color, color2.color], steps.value, direction.selected, pixels)
		Global.canvas.handle_redo("Draw")
	elif affect == FRAME:
		Global.canvas.handle_undo("Draw", Global.current_project, -1)
		for cel in Global.current_project.frames[Global.current_project.current_frame].cels:
			DrawingAlgos.generate_gradient(cel.image, [color1.color, color2.color], steps.value, direction.selected, pixels)
		Global.canvas.handle_redo("Draw", Global.current_project, -1)

	elif affect == ALL_FRAMES:
		Global.canvas.handle_undo("Draw", Global.current_project, -1, -1)
		for frame in Global.current_project.frames:
			for cel in frame.cels:
				DrawingAlgos.generate_gradient(cel.image, [color1.color, color2.color], steps.value, direction.selected, pixels)
		Global.canvas.handle_redo("Draw", Global.current_project, -1, -1)

	elif affect == ALL_PROJECTS:
		for project in Global.projects:
			var _pixels := []
			if selection_checkbox.pressed:
				_pixels = project.selected_pixels.duplicate()
			else:
				for x in project.size.x:
					for y in project.size.y:
						_pixels.append(Vector2(x, y))

			Global.canvas.handle_undo("Draw", project, -1, -1)
			for frame in project.frames:
				for cel in frame.cels:
					DrawingAlgos.generate_gradient(cel.image, [color1.color, color2.color], steps.value, direction.selected, _pixels)
			Global.canvas.handle_redo("Draw", project, -1, -1)


func _on_GradientDialog_popup_hide() -> void:
	Global.dialog_open(false)
