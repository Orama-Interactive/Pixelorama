extends ConfirmationDialog

var width := 64
var height := 64
var offset_x := 0
var offset_y := 0
var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)

@onready var width_spinbox: SpinBox = $VBoxContainer/OptionsContainer/WidthValue
@onready var height_spinbox: SpinBox = $VBoxContainer/OptionsContainer/HeightValue
@onready var x_spinbox: SpinBox = $VBoxContainer/OptionsContainer/XSpinBox
@onready var y_spinbox: SpinBox = $VBoxContainer/OptionsContainer/YSpinBox
@onready var preview_rect: TextureRect = $VBoxContainer/AspectRatioContainer/Preview


func _on_ResizeCanvas_about_to_show() -> void:
	Global.canvas.selection.transform_content_confirm()
	image.resize(Global.current_project.size.x, Global.current_project.size.y)

	var layer_i := 0
	for cel in Global.current_project.frames[Global.current_project.current_frame].cels:
		if cel is PixelCel and Global.current_project.layers[layer_i].is_visible_in_hierarchy():
			var cel_image := Image.new()
			cel_image.copy_from(cel.get_image())
			if cel.opacity < 1:  # If we have cel transparency
				for xx in cel_image.get_size().x:
					for yy in cel_image.get_size().y:
						var pixel_color := cel_image.get_pixel(xx, yy)
						pixel_color.a *= cel.opacity
						cel_image.set_pixel(xx, yy, pixel_color)
			image.blend_rect(
				cel_image, Rect2i(Vector2i.ZERO, Global.current_project.size), Vector2i.ZERO
			)
		layer_i += 1

	width_spinbox.value = Global.current_project.size.x
	height_spinbox.value = Global.current_project.size.y
	update_preview()


func _on_ResizeCanvas_confirmed() -> void:
	DrawingAlgos.resize_canvas(width, height, offset_x, offset_y)


func _on_WidthValue_value_changed(value: int) -> void:
	width = value
	x_spinbox.min_value = mini(width - Global.current_project.size.x, 0)
	x_spinbox.max_value = maxi(width - Global.current_project.size.x, 0)
	x_spinbox.value = clampi(x_spinbox.value, x_spinbox.min_value, x_spinbox.max_value)
	update_preview()


func _on_HeightValue_value_changed(value: int) -> void:
	height = value
	y_spinbox.min_value = mini(height - Global.current_project.size.y, 0)
	y_spinbox.max_value = maxi(height - Global.current_project.size.y, 0)
	y_spinbox.value = clampi(y_spinbox.value, y_spinbox.min_value, y_spinbox.max_value)
	update_preview()


func _on_XSpinBox_value_changed(value: int) -> void:
	offset_x = value
	update_preview()


func _on_YSpinBox_value_changed(value: int) -> void:
	offset_y = value
	update_preview()


func _on_CenterButton_pressed() -> void:
	x_spinbox.value = (x_spinbox.min_value + x_spinbox.max_value) / 2
	y_spinbox.value = (y_spinbox.min_value + y_spinbox.max_value) / 2


func update_preview() -> void:
	# preview_image is the same as image but offsetted
	var preview_image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	preview_image.blend_rect(
		image, Rect2i(Vector2i.ZERO, Global.current_project.size), Vector2i(offset_x, offset_y)
	)
	preview_rect.texture = ImageTexture.create_from_image(preview_image)
	update_transparent_background_size(preview_image)


func update_transparent_background_size(preview_image: Image) -> void:
	var image_size_y := preview_rect.size.y
	var image_size_x := preview_rect.size.x
	if preview_image.get_size().x > preview_image.get_size().y:
		var scale_ratio := preview_image.get_size().x / image_size_x
		image_size_y = preview_image.get_size().y / scale_ratio
	else:
		var scale_ratio := preview_image.get_size().y / image_size_y
		image_size_x = preview_image.get_size().x / scale_ratio

	preview_rect.get_node("TransparentChecker").size.x = image_size_x
	preview_rect.get_node("TransparentChecker").size.y = image_size_y


func _on_visibility_changed() -> void:
	if visible:
		return
	Global.dialog_open(false)
	# Resize the image to (1, 1) so it does not waste unneeded RAM
	image.resize(1, 1)
