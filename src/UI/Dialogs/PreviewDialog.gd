extends ConfirmationDialog


enum ImageImportOptions {NEW_TAB, SPRITESHEET, NEW_FRAME, NEW_LAYER, PALETTE}

var path : String
var image : Image
var current_import_option : int = ImageImportOptions.NEW_TAB
var spritesheet_horizontal := 1
var spritesheet_vertical := 1

onready var texture_rect : TextureRect = $VBoxContainer/CenterContainer/TextureRect
onready var spritesheet_options = $VBoxContainer/HBoxContainer/SpritesheetOptions


func _on_PreviewDialog_about_to_show() -> void:
	var img_texture := ImageTexture.new()
	img_texture.create_from_image(image)
	texture_rect.texture = img_texture


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
		texture_rect.get_child(0).visible = true
		texture_rect.get_child(1).visible = true
	else:
		spritesheet_options.visible = false
		texture_rect.get_child(0).visible = false
		texture_rect.get_child(1).visible = false


func _on_HorizontalFrames_value_changed(value) -> void:
	spritesheet_horizontal = value
	for child in texture_rect.get_node("HorizLines").get_children():
		child.queue_free()
	if value > 1:
		var line_distance = texture_rect.rect_size.x / value
		for i in range(1, value):
			var line_2d := Line2D.new()
			line_2d.width = 1
			line_2d.position = Vector2.ZERO
			line_2d.add_point(Vector2(i * line_distance, 0))
			line_2d.add_point(Vector2(i * line_distance, texture_rect.rect_size.x))
			texture_rect.get_node("HorizLines").add_child(line_2d)


func _on_VerticalFrames_value_changed(value) -> void:
	spritesheet_vertical = value
	for child in texture_rect.get_node("VerticalLines").get_children():
		child.queue_free()
	if value > 1:
		var line_distance = texture_rect.rect_size.y / value
		for i in range(1, value):
			var line_2d := Line2D.new()
			line_2d.width = 1
			line_2d.position = Vector2.ZERO
			line_2d.add_point(Vector2(0, i * line_distance))
			line_2d.add_point(Vector2(texture_rect.rect_size.y, i * line_distance))
			texture_rect.get_node("VerticalLines").add_child(line_2d)
