extends ImageEffect

onready var flip_h: CheckBox = $VBoxContainer/OptionsContainer/FlipHorizontal
onready var flip_v: CheckBox = $VBoxContainer/OptionsContainer/FlipVertical


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func commit_action(_cel: Image, project: Project = Global.current_project) -> void:
	flip_image(_cel, selection_checkbox.pressed, project)


func _on_FlipHorizontal_toggled(_button_pressed: bool) -> void:
	update_preview()


func _on_FlipVertical_toggled(_button_pressed: bool) -> void:
	update_preview()


func flip_image(img: Image, affect_selection: bool, proj: Project = Global.current_project) -> void:
	if !(affect_selection and proj.has_selection):
		if flip_h.pressed:
			img.flip_x()
		if flip_v.pressed:
			img.flip_y()
	else:
		# Create a temporary image that only has the selected pixels in it
		var selected_image := Image.new()
		selected_image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		selected_image.lock()
		img.lock()
		for x in img.get_width():
			for y in img.get_width():
				var pos := Vector2(x, y)
				if proj.can_pixel_get_drawn(pos):
					var color: Color = img.get_pixelv(pos)
					selected_image.set_pixelv(pos, color)
					img.set_pixelv(pos, Color(0, 0, 0, 0))

		if flip_h.pressed:
			selected_image.flip_x()
		if flip_v.pressed:
			selected_image.flip_y()
		selected_image.unlock()
		img.blit_rect_mask(
			selected_image,
			selected_image,
			Rect2(Vector2.ZERO, selected_image.get_size()),
			Vector2.ZERO
		)
		img.unlock()
