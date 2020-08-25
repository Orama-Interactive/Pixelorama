extends ImageEffect


onready var color1 : ColorPickerButton = $VBoxContainer/OptionsContainer/ColorsContainer/ColorPickerButton
onready var color2 : ColorPickerButton = $VBoxContainer/OptionsContainer/ColorsContainer/ColorPickerButton2
onready var steps : SpinBox = $VBoxContainer/OptionsContainer/StepSpinBox
onready var direction : OptionButton = $VBoxContainer/OptionsContainer/DirectionOptionButton


func _ready() -> void:
	color1.get_picker().presets_visible = false
	color2.get_picker().presets_visible = false


func set_nodes() -> void:
	preview = $VBoxContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


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


func _on_DirectionOptionButton_item_selected(_index : int) -> void:
	update_preview()


func _confirmed() -> void:
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
