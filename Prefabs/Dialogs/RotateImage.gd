extends ConfirmationDialog

var texture : ImageTexture
var aux_img : Image
var layer : Image

func _ready():
	texture = ImageTexture.new()
	texture.flags = 0
	aux_img = Image.new()
	$VBoxContainer/HBoxContainer2/OptionButton.add_item("Rotxel")
	pass

func set_sprite(sprite : Image):
	aux_img.copy_from(sprite)
	layer = sprite
	texture.create_from_image(aux_img, 0)
	$VBoxContainer/TextureRect.texture = texture


func _on_HSlider_value_changed(value):
	var sprite : Image = Image.new()
	sprite.copy_from(aux_img)
	Global.rotxel(sprite,value*PI/180)
	texture.create_from_image(sprite, 0)
	$VBoxContainer/HBoxContainer/SpinBox.value = $VBoxContainer/HBoxContainer/HSlider.value


func _on_SpinBox_value_changed(value):
	$VBoxContainer/HBoxContainer/HSlider.value = $VBoxContainer/HBoxContainer/SpinBox.value


func _on_RotateImage_confirmed():
	Global.canvas.handle_undo("Draw")
	Global.rotxel(layer,$VBoxContainer/HBoxContainer/HSlider.value*PI/180)
	Global.canvas.handle_redo("Draw")
	$VBoxContainer/HBoxContainer/HSlider.value = 0
