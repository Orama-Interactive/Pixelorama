extends ConfirmationDialog



var image : Image
var spritesheet_horizontal := 1
var spritesheet_vertical := 1

onready var texture_rect : TextureRect = $VBoxContainer/CenterContainer/TextureRect
onready var image_size_label : Label = $VBoxContainer/SizeContainer/ImageSizeLabel
onready var frame_size_label : Label = $VBoxContainer/SizeContainer/FrameSizeLabel
onready var split_image_options = $VBoxContainer/SplitImageOptions


func _on_PreviewDialog_about_to_show() -> void:
	image = Image.new()
	image.create(Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_RGBA8)
	image.lock()
	var layer_i := 0
	for cel in Global.current_project.frames[Global.current_project.current_frame].cels:
		if Global.current_project.layers[layer_i].visible:
			var cel_image := Image.new()
			cel_image.copy_from(cel.image)
			cel_image.lock()
			if cel.opacity < 1: # If we have cel transparency
				for xx in cel_image.get_size().x:
					for yy in cel_image.get_size().y:
						var pixel_color := cel_image.get_pixel(xx, yy)
						var alpha : float = pixel_color.a * cel.opacity
						cel_image.set_pixel(xx, yy, Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha))
			image.blend_rect(cel_image, Rect2(Vector2.ZERO, Global.current_project.size), Vector2.ZERO)
		layer_i += 1
	image.unlock()
	
	var preview_texture := ImageTexture.new()
	preview_texture.create_from_image(image, 0)
	texture_rect.texture = preview_texture
	
	split_image_options.get_node("HorizontalFrames").max_value = min(split_image_options.get_node("HorizontalFrames").max_value, image.get_size().x)
	split_image_options.get_node("VerticalFrames").max_value = min(split_image_options.get_node("VerticalFrames").max_value, image.get_size().y)
	image_size_label.text = tr("Image Size") + ": " + str(image.get_size().x) + "×" + str(image.get_size().y)
	frame_size_label.text = tr("Frame Size") + ": " + str(image.get_size().x / spritesheet_horizontal) + "×" + str(image.get_size().y / spritesheet_vertical)
	for child in texture_rect.get_node("VerticalLines").get_children():
		child.queue_free()
	frame_value_changed(spritesheet_vertical, true)
	for child in texture_rect.get_node("HorizLines").get_children():
		child.queue_free()
	frame_value_changed(spritesheet_horizontal, false)


func _on_PreviewDialog_popup_hide() -> void:
	Global.dialog_open(false)


func _on_PreviewDialog_confirmed() -> void:
	if spritesheet_horizontal == 1 and spritesheet_vertical == 1:
		return
	split_image(image, spritesheet_horizontal, spritesheet_vertical)

func _on_HorizontalFrames_value_changed(value : int) -> void:
	spritesheet_horizontal = value
	for child in texture_rect.get_node("HorizLines").get_children():
		child.queue_free()

	frame_value_changed(value, false)


func _on_VerticalFrames_value_changed(value : int) -> void:
	spritesheet_vertical = value
	for child in texture_rect.get_node("VerticalLines").get_children():
		child.queue_free()

	frame_value_changed(value, true)


func frame_value_changed(value : int, vertical : bool) -> void:
	var image_size_y = texture_rect.rect_size.y
	var image_size_x = texture_rect.rect_size.x
	if image.get_size().x > image.get_size().y:
		var scale_ratio = image.get_size().x / image_size_x
		image_size_y = image.get_size().y / scale_ratio
	else:
		var scale_ratio = image.get_size().y / image_size_y
		image_size_x = image.get_size().x / scale_ratio

	var offset_x = (texture_rect.rect_size.x - image_size_x) / 2
	var offset_y = (texture_rect.rect_size.y - image_size_y) / 2

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


func split_image(image : Image, horizontal : int, vertical : int) -> void:
	# data needed to slice images
	var start_frame = Global.current_project.current_frame
	horizontal = min(horizontal, image.get_size().x)
	vertical = min(vertical, image.get_size().y)
	var frame_width := image.get_size().x / horizontal
	var frame_height := image.get_size().y / vertical

	# resize canvas to if "frame_width" or "frame_height" is too large
	var project_width :int = max(frame_width, Global.current_project.size.x)
	var project_height :int = max(frame_height, Global.current_project.size.y)
	DrawingAlgos.resize_canvas(project_width, project_height,0 ,0) 

	# slice images
	for yy in range(vertical):
		for xx in range(horizontal):
			var cropped_image := Image.new()
			cropped_image.create(Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_RGBA8)
			if split_image_options.get_node("MoveToCorner").pressed:
				cropped_image.blend_rect(image, Rect2(frame_width * xx, frame_height * yy, frame_width, frame_height), Vector2.ZERO)
			else:
				cropped_image.blend_rect(image, Rect2(frame_width * xx, frame_height * yy, frame_width, frame_height), Vector2(frame_width * xx, frame_height * yy))
			OpenSave.open_image_as_new_frame(cropped_image, Global.current_project.layers.size() - 1)
