extends ImageEffect


onready var flip_h : CheckBox = $VBoxContainer/OptionsContainer/FlipHorizontal
onready var flip_v : CheckBox = $VBoxContainer/OptionsContainer/FlipVertical


func set_nodes() -> void:
	preview = $VBoxContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func commit_action(_cel : Image, _pixels : Array, project : Project = Global.current_project) -> void:
	flip_image(_cel, _pixels, project)


func _on_FlipHorizontal_toggled(_button_pressed : bool) -> void:
	update_preview()


func _on_FlipVertical_toggled(_button_pressed : bool) -> void:
	update_preview()


func _on_SelectionCheckBox_toggled(button_pressed : bool) -> void:
	._on_SelectionCheckBox_toggled(button_pressed)
	update_preview()


func flip_image(image : Image, _pixels : Array, project : Project = Global.current_project) -> void:
	var entire_image_selected : bool = _pixels.size() == project.size.x * project.size.y
	if entire_image_selected:
		if flip_h.pressed:
			image.flip_x()
		if flip_v.pressed:
			image.flip_y()
	else:
		# Create a temporary image that only has the selected pixels in it
		var selected_image := Image.new()
		selected_image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
		selected_image.lock()
		image.lock()
		for i in _pixels:
			var color : Color = image.get_pixelv(i)
			selected_image.set_pixelv(i, color)
			image.set_pixelv(i, Color(0, 0, 0, 0))

		if flip_h.pressed:
			selected_image.flip_x()
		if flip_v.pressed:
			selected_image.flip_y()

		image.blit_rect_mask(selected_image, selected_image, Rect2(Vector2.ZERO, selected_image.get_size()), Vector2.ZERO)
