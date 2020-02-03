extends ConfirmationDialog

var texture : ImageTexture
var aux_img : Image
var layer : Image

func _ready():
	texture = ImageTexture.new()
	texture.flags = 0
	aux_img = Image.new()
	$VBoxContainer/HBoxContainer2/OptionButton.add_item("Rotxel")
	$VBoxContainer/HBoxContainer2/OptionButton.add_item("Nearest neighbour")

func set_sprite(sprite : Image):
	aux_img.copy_from(sprite)
	layer = sprite
	texture.create_from_image(aux_img, 0)
	$VBoxContainer/TextureRect.texture = texture


func _on_HSlider_value_changed(value):
	rotate()
	$VBoxContainer/HBoxContainer/SpinBox.value = $VBoxContainer/HBoxContainer/HSlider.value


func _on_SpinBox_value_changed(value):
	$VBoxContainer/HBoxContainer/HSlider.value = $VBoxContainer/HBoxContainer/SpinBox.value


func _on_RotateImage_confirmed():
	Global.canvas.handle_undo("Draw")
	Global.rotxel(layer,$VBoxContainer/HBoxContainer/HSlider.value*PI/180)
	Global.canvas.handle_redo("Draw")
	$VBoxContainer/HBoxContainer/HSlider.value = 0
	
func rotate():
	var sprite : Image = Image.new()
	sprite.copy_from(aux_img)
	match $VBoxContainer/HBoxContainer2/OptionButton.text:
		"Rotxel":
			Global.rotxel(sprite,$VBoxContainer/HBoxContainer/HSlider.value*PI/180)
		"Nearest neighbour":
			Global.nn_rotate(sprite,$VBoxContainer/HBoxContainer/HSlider.value*PI/180)
	texture.create_from_image(sprite, 0)


func _on_OptionButton_item_selected(id):
	rotate()
