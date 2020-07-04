extends ConfirmationDialog


enum ImageImportOptions {NEW_TAB, SPRITESHEET, NEW_FRAME, NEW_LAYER, PALETTE, BRUSH, PATTERN}

var path : String
var image : Image
var current_import_option : int = ImageImportOptions.NEW_TAB
var spritesheet_horizontal := 1
var spritesheet_vertical := 1

onready var texture_rect : TextureRect = $VBoxContainer/CenterContainer/TextureRect
onready var image_size_label : Label = $VBoxContainer/SizeContainer/ImageSizeLabel
onready var frame_size_label : Label = $VBoxContainer/SizeContainer/FrameSizeLabel
onready var spritesheet_options = $VBoxContainer/HBoxContainer/SpritesheetOptions
onready var new_frame_options = $VBoxContainer/HBoxContainer/NewFrameOptions
onready var new_layer_options = $VBoxContainer/HBoxContainer/NewLayerOptions


func _on_PreviewDialog_about_to_show() -> void:
	var img_texture := ImageTexture.new()
	img_texture.create_from_image(image)
	texture_rect.texture = img_texture
	spritesheet_options.get_node("HorizontalFrames").max_value = min(spritesheet_options.get_node("HorizontalFrames").max_value, image.get_size().x)
	spritesheet_options.get_node("VerticalFrames").max_value = min(spritesheet_options.get_node("VerticalFrames").max_value, image.get_size().y)
	image_size_label.text = tr("Image Size") + ": " + str(image.get_size().x) + "×" + str(image.get_size().y)
	frame_size_label.text = tr("Frame Size") + ": " + str(image.get_size().x) + "×" + str(image.get_size().y)


func _on_PreviewDialog_popup_hide() -> void:
	queue_free()
	# Call Global.dialog_open() only if it's the only preview dialog opened
	for child in Global.control.get_children():
		if child != self and "PreviewDialog" in child.name:
			return
	Global.dialog_open(false)


func _on_PreviewDialog_confirmed() -> void:
	if current_import_option == ImageImportOptions.NEW_TAB:
		OpenSave.open_image_as_new_tab(path, image)

	elif current_import_option == ImageImportOptions.SPRITESHEET:
		OpenSave.open_image_as_spritesheet(path, image, spritesheet_horizontal, spritesheet_vertical)

	elif current_import_option == ImageImportOptions.NEW_FRAME:
		var layer_index : int = new_frame_options.get_node("AtLayerSpinbox").value
		OpenSave.open_image_as_new_frame(image, layer_index)

	elif current_import_option == ImageImportOptions.NEW_LAYER:
		var frame_index : int = new_layer_options.get_node("AtFrameSpinbox").value - 1
		OpenSave.open_image_as_new_layer(image, path.get_basename().get_file(), frame_index)

	elif current_import_option == ImageImportOptions.PALETTE:
		Global.palette_container.import_image_palette(path, image)

	elif current_import_option == ImageImportOptions.BRUSH:
		var file_name : String = path.get_basename().get_file()
		image.convert(Image.FORMAT_RGBA8)
		Global.file_brushes.append(image)
		Global.create_brush_button(image, Global.Brush_Types.FILE, file_name)

		# Copy the image file into the "pixelorama/Brushes" directory
		var location := "Brushes".plus_file(path.get_file())
		var dir = Directory.new()
		dir.copy(path, Global.directory_module.xdg_data_home.plus_file(location))

	elif current_import_option == ImageImportOptions.PATTERN:
		var file_name : String = path.get_basename().get_file()
		image.convert(Image.FORMAT_RGBA8)
		Global.patterns.append(image)
		Global.create_pattern_button(image, file_name)

		# Copy the image file into the "pixelorama/Patterns" directory
		var location := "Patterns".plus_file(path.get_file())
		var dir = Directory.new()
		dir.copy(path, Global.directory_module.xdg_data_home.plus_file(location))


func _on_ImportOption_item_selected(id : int) -> void:
	current_import_option = id
	frame_size_label.visible = false
	spritesheet_options.visible = false
	new_frame_options.visible = false
	new_layer_options.visible = false
	texture_rect.get_child(0).visible = false
	texture_rect.get_child(1).visible = false

	if id == ImageImportOptions.SPRITESHEET:
		frame_size_label.visible = true
		spritesheet_options.visible = true
		texture_rect.get_child(0).visible = true
		texture_rect.get_child(1).visible = true

	elif id == ImageImportOptions.NEW_FRAME:
		new_frame_options.visible = true
		new_frame_options.get_node("AtLayerSpinbox").max_value = Global.current_project.layers.size() - 1

	elif id == ImageImportOptions.NEW_LAYER:
		new_layer_options.visible = true
		new_layer_options.get_node("AtFrameSpinbox").max_value = Global.current_project.frames.size()


func _on_HorizontalFrames_value_changed(value : int) -> void:
	spritesheet_horizontal = value
	for child in texture_rect.get_node("HorizLines").get_children():
		child.queue_free()

	spritesheet_frame_value_changed(value, false)


func _on_VerticalFrames_value_changed(value : int) -> void:
	spritesheet_vertical = value
	for child in texture_rect.get_node("VerticalLines").get_children():
		child.queue_free()

	spritesheet_frame_value_changed(value, true)


func spritesheet_frame_value_changed(value : int, vertical : bool) -> void:
	var image_size_y = texture_rect.rect_size.y
	var image_size_x = texture_rect.rect_size.x
	if image.get_size().x > image.get_size().y:
		var scale_ratio = image.get_size().x / image_size_x
		image_size_y = image.get_size().y / scale_ratio
	else:
		var scale_ratio = image.get_size().y / image_size_y
		image_size_x = image.get_size().x / scale_ratio

	var offset_x = (300 - image_size_x) / 2
	var offset_y = (300 - image_size_y) / 2

	if value > 1:
		var line_distance
		if vertical:
			line_distance = image_size_y / value
		else:
			line_distance = image_size_x / value

		for i in range(1, value):
			var line_2d := Line2D.new()
			line_2d.width = 1
			line_2d.position = Vector2.ZERO
			if vertical:
				line_2d.add_point(Vector2(offset_x, i * line_distance + offset_y))
				line_2d.add_point(Vector2(image_size_x + offset_x, i * line_distance + offset_y))
				texture_rect.get_node("VerticalLines").add_child(line_2d)
			else:
				line_2d.add_point(Vector2(i * line_distance + offset_x, offset_y))
				line_2d.add_point(Vector2(i * line_distance + offset_x, image_size_y + offset_y))
				texture_rect.get_node("HorizLines").add_child(line_2d)

	var frame_width = floor(image.get_size().x / spritesheet_horizontal)
	var frame_height = floor(image.get_size().y / spritesheet_vertical)
	frame_size_label.text = tr("Frame Size") + ": " + str(frame_width) + "×" + str(frame_height)
