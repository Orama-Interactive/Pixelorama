extends ImageEffect


onready var type_option_button : OptionButton = $VBoxContainer/HBoxContainer2/TypeOptionButton
onready var angle_hslider : HSlider = $VBoxContainer/AngleOptions/AngleHSlider
onready var angle_spinbox : SpinBox = $VBoxContainer/AngleOptions/AngleSpinBox


func _ready() -> void:
	type_option_button.add_item("Rotxel")
	type_option_button.add_item("Upscale, Rotate and Downscale")
	type_option_button.add_item("Nearest neighbour")


func set_nodes() -> void:
	preview = $VBoxContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func _about_to_show() -> void:
	._about_to_show()
	angle_hslider.value = 0


func commit_action(_cel : Image, _project : Project = Global.current_project) -> void:
	var angle : float = deg2rad(angle_hslider.value)
# warning-ignore:integer_division
# warning-ignore:integer_division
	var pivot = Vector2(_cel.get_width() / 2, _cel.get_height() / 2)
	var image := Image.new()
	image.copy_from(_cel)
	if _project.has_selection and selection_checkbox.pressed:
		var selection_rectangle : Rect2 = _project.get_selection_rectangle()
		pivot = selection_rectangle.position + ((selection_rectangle.end - selection_rectangle.position) / 2)
		image.lock()
		_cel.lock()
		for x in _project.size.x:
			for y in _project.size.y:
				var pos := Vector2(x, y)
				if !_project.can_pixel_get_drawn(pos):
					image.set_pixelv(pos, Color(0, 0, 0, 0))
				else:
					_cel.set_pixelv(pos, Color(0, 0, 0, 0))
		image.unlock()
		_cel.unlock()
	match type_option_button.text:
		"Rotxel":
			DrawingAlgos.rotxel(image, angle, pivot)
		"Nearest neighbour":
			DrawingAlgos.nn_rotate(image, angle, pivot)
		"Upscale, Rotate and Downscale":
			DrawingAlgos.fake_rotsprite(image, angle, pivot)
	if _project.has_selection and selection_checkbox.pressed:
		_cel.blend_rect(image, Rect2(Vector2.ZERO, image.get_size()), Vector2.ZERO)
	else:
		_cel.blit_rect(image, Rect2(Vector2.ZERO, image.get_size()), Vector2.ZERO)


func _confirmed() -> void:
	._confirmed()
	angle_hslider.value = 0


func _on_HSlider_value_changed(_value : float) -> void:
	update_preview()
	angle_spinbox.value = angle_hslider.value


func _on_SpinBox_value_changed(_value : float) -> void:
	angle_hslider.value = angle_spinbox.value


func _on_TypeOptionButton_item_selected(_id : int) -> void:
	update_preview()
