extends ImageEffect


var red := true
var green := true
var blue := true
var alpha := false


func set_nodes() -> void:
	preview = $VBoxContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func _confirmed() -> void:
	if affect == CEL:
		Global.canvas.handle_undo("Draw")
		DrawingAlgos.invert_image_colors(current_cel, pixels, red, green, blue, alpha)
		Global.canvas.handle_redo("Draw")
	elif affect == FRAME:
		Global.canvas.handle_undo("Draw", Global.current_project, -1)
		for cel in Global.current_project.frames[Global.current_project.current_frame].cels:
			DrawingAlgos.invert_image_colors(cel.image, pixels, red, green, blue, alpha)
		Global.canvas.handle_redo("Draw", Global.current_project, -1)

	elif affect == ALL_FRAMES:
		Global.canvas.handle_undo("Draw", Global.current_project, -1, -1)
		for frame in Global.current_project.frames:
			for cel in frame.cels:
				DrawingAlgos.invert_image_colors(cel.image, pixels, red, green, blue, alpha)
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
					DrawingAlgos.invert_image_colors(cel.image, _pixels, red, green, blue, alpha)
			Global.canvas.handle_redo("Draw", project, -1, -1)


func _on_RButton_toggled(button_pressed : bool) -> void:
	red = button_pressed
	update_preview()


func _on_GButton_toggled(button_pressed : bool) -> void:
	green = button_pressed
	update_preview()


func _on_BButton_toggled(button_pressed : bool) -> void:
	blue = button_pressed
	update_preview()


func _on_AButton_toggled(button_pressed : bool) -> void:
	alpha = button_pressed
	update_preview()


func update_preview() -> void:
	match affect:
		CEL:
			preview_image.copy_from(current_cel)
		_:
			preview_image.copy_from(current_frame)
	DrawingAlgos.invert_image_colors(preview_image, pixels, red, green, blue, alpha)
	preview_image.unlock()
	preview_texture.create_from_image(preview_image, 0)
	preview.texture = preview_texture
