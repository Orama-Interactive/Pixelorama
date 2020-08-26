extends ImageEffect


func _ready() -> void:
	$VBoxContainer/HBoxContainer2/OptionButton.add_item("Rotxel")
	$VBoxContainer/HBoxContainer2/OptionButton.add_item("Upscale, Rotate and Downscale")
	$VBoxContainer/HBoxContainer2/OptionButton.add_item("Nearest neighbour")


func set_nodes() -> void:
	preview = $VBoxContainer/Preview


func _about_to_show() -> void:
	._about_to_show()
	$VBoxContainer/HBoxContainer/HSlider.value = 0


func _confirmed() -> void:
	Global.canvas.handle_undo("Draw")
	match $VBoxContainer/HBoxContainer2/OptionButton.text:
		"Rotxel":
			DrawingAlgos.rotxel(current_cel,$VBoxContainer/HBoxContainer/HSlider.value*PI/180)
		"Nearest neighbour":
			DrawingAlgos.nn_rotate(current_cel,$VBoxContainer/HBoxContainer/HSlider.value*PI/180)
		"Upscale, Rotate and Downscale":
			DrawingAlgos.fake_rotsprite(current_cel,$VBoxContainer/HBoxContainer/HSlider.value*PI/180)
	Global.canvas.handle_redo("Draw")
	$VBoxContainer/HBoxContainer/HSlider.value = 0


func _on_HSlider_value_changed(_value : float) -> void:
	update_preview()
	$VBoxContainer/HBoxContainer/SpinBox.value = $VBoxContainer/HBoxContainer/HSlider.value


func _on_SpinBox_value_changed(_value : float) -> void:
	$VBoxContainer/HBoxContainer/HSlider.value = $VBoxContainer/HBoxContainer/SpinBox.value


func update_preview() -> void:
	preview_image.copy_from(current_cel)
	match $VBoxContainer/HBoxContainer2/OptionButton.text:
		"Rotxel":
			DrawingAlgos.rotxel(preview_image,$VBoxContainer/HBoxContainer/HSlider.value*PI/180)
		"Nearest neighbour":
			DrawingAlgos.nn_rotate(preview_image,$VBoxContainer/HBoxContainer/HSlider.value*PI/180)
		"Upscale, Rotate and Downscale":
			DrawingAlgos.fake_rotsprite(preview_image,$VBoxContainer/HBoxContainer/HSlider.value*PI/180)
	preview_texture.create_from_image(preview_image, 0)
	preview.texture = preview_texture


func _on_OptionButton_item_selected(_id : int) -> void:
	update_preview()
