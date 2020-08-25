extends ImageEffect


var color := Color.red
var thickness := 1
var diagonal := false
var inside_image := false

onready var outline_color = $VBoxContainer/OptionsContainer/OutlineColor


func _ready() -> void:
	outline_color.get_picker().presets_visible = false
	color = outline_color.color


func set_nodes() -> void:
	preview = $VBoxContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func _confirmed() -> void:
	if affect == CEL:
		Global.canvas.handle_undo("Draw")
		DrawingAlgos.generate_outline(current_cel, pixels, color, thickness, diagonal, inside_image)
		Global.canvas.handle_redo("Draw")
	elif affect == FRAME:
		Global.canvas.handle_undo("Draw", Global.current_project, -1)
		for cel in Global.current_project.frames[Global.current_project.current_frame].cels:
			DrawingAlgos.generate_outline(cel.image, pixels, color, thickness, diagonal, inside_image)
		Global.canvas.handle_redo("Draw", Global.current_project, -1)

	elif affect == ALL_FRAMES:
		Global.canvas.handle_undo("Draw", Global.current_project, -1, -1)
		for frame in Global.current_project.frames:
			for cel in frame.cels:
				DrawingAlgos.generate_outline(cel.image, pixels, color, thickness, diagonal, inside_image)
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
					DrawingAlgos.generate_outline(cel.image, _pixels, color, thickness, diagonal, inside_image)
			Global.canvas.handle_redo("Draw", project, -1, -1)


func _on_ThickValue_value_changed(value : int) -> void:
	thickness = value
	update_preview()


func _on_OutlineColor_color_changed(_color : Color) -> void:
	color = _color
	update_preview()


func _on_DiagonalCheckBox_toggled(button_pressed : bool) -> void:
	diagonal = button_pressed
	update_preview()


func _on_InsideImageCheckBox_toggled(button_pressed : bool) -> void:
	inside_image = button_pressed
	update_preview()


func update_preview() -> void:
	preview_image.copy_from(current_cel)
	DrawingAlgos.generate_outline(preview_image, pixels, color, thickness, diagonal, inside_image)
	preview_texture.create_from_image(preview_image, 0)
	preview.texture = preview_texture
