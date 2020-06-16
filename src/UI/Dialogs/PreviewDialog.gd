extends ConfirmationDialog


enum ImageImportOptions {NEW_TAB, SPRITESHEET, NEW_FRAME, NEW_LAYER, PALETTE}

var path : String
var image : Image
var current_import_option : int = ImageImportOptions.NEW_TAB
var spritesheet_horizontal := 1
var spritesheet_vertical := 1

onready var spritesheet_options = $VBoxContainer/HBoxContainer/SpritesheetOptions


func _on_PreviewDialog_about_to_show() -> void:
	var img_texture := ImageTexture.new()
	img_texture.create_from_image(image)
	get_node("VBoxContainer/CenterContainer/TextureRect").texture = img_texture


func _on_PreviewDialog_popup_hide() -> void:
	queue_free()


func _on_PreviewDialog_confirmed() -> void:
	if current_import_option == ImageImportOptions.NEW_TAB:
		OpenSave.open_image_as_new_tab(path, image)
	elif current_import_option == ImageImportOptions.SPRITESHEET:
		OpenSave.open_image_as_spritesheet(path, image, spritesheet_horizontal, spritesheet_vertical)


func _on_ImportOption_item_selected(id : int) -> void:
	current_import_option = id
	if id == ImageImportOptions.SPRITESHEET:
		spritesheet_options.visible = true
	else:
		spritesheet_options.visible = false


func _on_HorizontalFrames_value_changed(value) -> void:
	spritesheet_horizontal = value


func _on_VerticalFrames_value_changed(value) -> void:
	spritesheet_vertical = value
