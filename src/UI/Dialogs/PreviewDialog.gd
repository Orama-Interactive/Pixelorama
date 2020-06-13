extends ConfirmationDialog


var path : String
var image : Image


func _on_PreviewDialog_about_to_show() -> void:
	var img_texture := ImageTexture.new()
	img_texture.create_from_image(image)
	get_node("CenterContainer/TextureRect").texture = img_texture


func _on_PreviewDialog_popup_hide() -> void:
	queue_free()


func _on_PreviewDialog_confirmed() -> void:
	OpenSave.open_image_file(path, image)
