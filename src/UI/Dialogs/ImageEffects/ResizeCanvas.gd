extends ConfirmationDialog

var width := 64
var height := 64
var offset_x := 0
var offset_y := 0
var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)

@onready var width_spinbox: SpinBox = $VBoxContainer/OptionsContainer/WidthValue
@onready var height_spinbox: SpinBox = $VBoxContainer/OptionsContainer/HeightValue
@onready var x_offset_spinbox: SpinBox = $VBoxContainer/OptionsContainer/XOffsetSpinBox
@onready var y_offset_spinbox: SpinBox = $VBoxContainer/OptionsContainer/YOffsetSpinBox
@onready var aspect_ratio_container: AspectRatioContainer = $VBoxContainer/AspectRatioContainer
@onready var preview_rect: TextureRect = $VBoxContainer/AspectRatioContainer/Preview


func _on_about_to_popup() -> void:
	Global.canvas.selection.transform_content_confirm()
	image.resize(Global.current_project.size.x, Global.current_project.size.y)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var frame := Global.current_project.frames[Global.current_project.current_frame]
	DrawingAlgos.blend_layers(image, frame)
	if width_spinbox.value == Global.current_project.size.x:
		_on_width_value_changed(width_spinbox.value)
	else:
		width_spinbox.value = Global.current_project.size.x
	if height_spinbox.value == Global.current_project.size.y:
		_on_height_value_changed(height_spinbox.value)
	else:
		height_spinbox.value = Global.current_project.size.y
	update_preview()


func _on_confirmed() -> void:
	DrawingAlgos.resize_canvas(width, height, offset_x, offset_y)


func _on_width_value_changed(value: int) -> void:
	width = value
	x_offset_spinbox.min_value = mini(width - Global.current_project.size.x, 0)
	x_offset_spinbox.max_value = maxi(width - Global.current_project.size.x, 0)
	x_offset_spinbox.value = clampi(
		x_offset_spinbox.value, x_offset_spinbox.min_value, x_offset_spinbox.max_value
	)
	update_preview()


func _on_height_value_changed(value: int) -> void:
	height = value
	y_offset_spinbox.min_value = mini(height - Global.current_project.size.y, 0)
	y_offset_spinbox.max_value = maxi(height - Global.current_project.size.y, 0)
	y_offset_spinbox.value = clampi(
		y_offset_spinbox.value, y_offset_spinbox.min_value, y_offset_spinbox.max_value
	)
	update_preview()


func _on_x_offset_spin_box_value_changed(value: int) -> void:
	offset_x = value
	update_preview()


func _on_y_offset_spin_box_value_changed(value: int) -> void:
	offset_y = value
	update_preview()


func _on_center_button_pressed() -> void:
	x_offset_spinbox.value = (x_offset_spinbox.min_value + x_offset_spinbox.max_value) / 2
	y_offset_spinbox.value = (y_offset_spinbox.min_value + y_offset_spinbox.max_value) / 2


func update_preview() -> void:
	# preview_image is the same as image but offsetted
	var preview_image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	preview_image.blend_rect(
		image, Rect2i(Vector2i.ZERO, Global.current_project.size), Vector2i(offset_x, offset_y)
	)
	preview_rect.texture = ImageTexture.create_from_image(preview_image)
	aspect_ratio_container.ratio = float(preview_image.get_width()) / preview_image.get_height()


func _on_visibility_changed() -> void:
	if visible:
		return
	Global.dialog_open(false)
	# Resize the image to (1, 1) so it does not waste unneeded RAM
	image.resize(1, 1)
