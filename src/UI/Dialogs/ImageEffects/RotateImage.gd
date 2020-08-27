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


func _about_to_show() -> void:
	._about_to_show()
	angle_hslider.value = 0


func commit_action(_cel : Image, _pixels : Array, _project : Project = Global.current_project) -> void:
	match type_option_button.text:
		"Rotxel":
			DrawingAlgos.rotxel(_cel,angle_hslider.value*PI/180)
		"Nearest neighbour":
			DrawingAlgos.nn_rotate(_cel,angle_hslider.value*PI/180)
		"Upscale, Rotate and Downscale":
			DrawingAlgos.fake_rotsprite(_cel,angle_hslider.value*PI/180)


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
