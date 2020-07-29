extends ConfirmationDialog

var texture : ImageTexture
var aux_img : Image
var layer : Image

func _ready() -> void:
	texture = ImageTexture.new()
	aux_img = Image.new()
	$VBoxContainer/HBoxContainer2/OptionButton.add_item("Rotxel")
	$VBoxContainer/HBoxContainer2/OptionButton.add_item("Upscale, Rotate and Downscale")
	$VBoxContainer/HBoxContainer2/OptionButton.add_item("Nearest neighbour")

func set_sprite(sprite : Image) -> void:
	aux_img.copy_from(sprite)
	layer = sprite
	texture.create_from_image(aux_img, 0)
	$VBoxContainer/TextureRect.texture = texture


func _on_HSlider_value_changed(_value) -> void:
	rotate()
	$VBoxContainer/HBoxContainer/SpinBox.value = $VBoxContainer/HBoxContainer/HSlider.value


func _on_SpinBox_value_changed(_value):
	$VBoxContainer/HBoxContainer/HSlider.value = $VBoxContainer/HBoxContainer/SpinBox.value


func _on_RotateImage_confirmed() -> void:
	Global.canvas.handle_undo("Draw")
	match $VBoxContainer/HBoxContainer2/OptionButton.text:
		"Rotxel":
			DrawingAlgos.rotxel(layer,$VBoxContainer/HBoxContainer/HSlider.value*PI/180)
		"Nearest neighbour":
			DrawingAlgos.nn_rotate(layer,$VBoxContainer/HBoxContainer/HSlider.value*PI/180)
		"Upscale, Rotate and Downscale":
			DrawingAlgos.fake_rotsprite(layer,$VBoxContainer/HBoxContainer/HSlider.value*PI/180)
	Global.canvas.handle_redo("Draw")
	$VBoxContainer/HBoxContainer/HSlider.value = 0

func rotate() -> void:
	var sprite : Image = Image.new()
	sprite.copy_from(aux_img)
	match $VBoxContainer/HBoxContainer2/OptionButton.text:
		"Rotxel":
			DrawingAlgos.rotxel(sprite,$VBoxContainer/HBoxContainer/HSlider.value*PI/180)
		"Nearest neighbour":
			DrawingAlgos.nn_rotate(sprite,$VBoxContainer/HBoxContainer/HSlider.value*PI/180)
		"Upscale, Rotate and Downscale":
			DrawingAlgos.fake_rotsprite(sprite,$VBoxContainer/HBoxContainer/HSlider.value*PI/180)
	texture.create_from_image(sprite, 0)


func _on_OptionButton_item_selected(_id) -> void:
	rotate()


func _on_RotateImage_about_to_show() -> void:
	$VBoxContainer/HBoxContainer/HSlider.value = 0


func _on_RotateImage_popup_hide() -> void:
	Global.dialog_open(false)
