extends ConfirmationDialog


enum {CEL, FRAME, ALL_FRAMES, ALL_PROJECTS}

var affect : int = CEL
var pixels := []
var current_cel : Image
var preview_image : Image
var preview_texture : ImageTexture

onready var preview : TextureRect = $VBoxContainer/Preview
onready var flip_h : CheckBox = $VBoxContainer/OptionsContainer/FlipHorizontal
onready var flip_v : CheckBox = $VBoxContainer/OptionsContainer/FlipVertical
onready var selection_checkbox : CheckBox = $VBoxContainer/OptionsContainer/SelectionCheckBox


func _ready() -> void:
	current_cel = Image.new()
	preview_image = Image.new()
	preview_texture = ImageTexture.new()


func _on_FlipImageDialog_about_to_show() -> void:
	current_cel = Global.current_project.frames[Global.current_project.current_frame].cels[Global.current_project.current_layer].image
	_on_SelectionCheckBox_toggled(selection_checkbox.pressed)


func _on_FlipImageDialog_confirmed() -> void:
	if affect == CEL:
		Global.canvas.handle_undo("Draw")
		flip_image(current_cel, pixels)
		Global.canvas.handle_redo("Draw")
	elif affect == FRAME:
		Global.canvas.handle_undo("Draw", Global.current_project, -1)
		for cel in Global.current_project.frames[Global.current_project.current_frame].cels:
			flip_image(cel.image, pixels)
		Global.canvas.handle_redo("Draw", Global.current_project, -1)

	elif affect == ALL_FRAMES:
		Global.canvas.handle_undo("Draw", Global.current_project, -1, -1)
		for frame in Global.current_project.frames:
			for cel in frame.cels:
				flip_image(cel.image, pixels)
		Global.canvas.handle_redo("Draw", Global.current_project, -1, -1)

	elif affect == ALL_PROJECTS:
		for project in Global.projects:
			var _pixels := []
			if selection_checkbox.pressed:
				_pixels = project.selected_pixels.duplicate()
			else:
				for x in project.size.x:
					for y in project.size.y:
						_pixels.append(Vector2(x, y))

			Global.canvas.handle_undo("Draw", project, -1, -1)
			for frame in project.frames:
				for cel in frame.cels:
					flip_image(cel.image, _pixels, project)
			Global.canvas.handle_redo("Draw", project, -1, -1)


func _on_FlipHorizontal_toggled(_button_pressed : bool) -> void:
	update_preview()


func _on_FlipVertical_toggled(_button_pressed : bool) -> void:
	update_preview()


func _on_SelectionCheckBox_toggled(button_pressed : bool) -> void:
	pixels.clear()
	if button_pressed:
		pixels = Global.current_project.selected_pixels.duplicate()
	else:
		for x in Global.current_project.size.x:
			for y in Global.current_project.size.y:
				pixels.append(Vector2(x, y))

	update_preview()


func _on_AffectOptionButton_item_selected(index : int) -> void:
	affect = index


func update_preview() -> void:
	preview_image.copy_from(current_cel)
	flip_image(preview_image, pixels)
	preview_texture.create_from_image(preview_image, 0)
	preview.texture = preview_texture


func flip_image(image : Image, _pixels : Array, project : Project = Global.current_project) -> void:
	var entire_image_selected : bool = _pixels.size() == project.size.x * project.size.y
	if entire_image_selected:
		if flip_h.pressed:
			image.flip_x()
		if flip_v.pressed:
			image.flip_y()
	else:
		# Create a temporary image that only has the selected pixels in it
		var selected_image := Image.new()
		selected_image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
		selected_image.lock()
		image.lock()
		for i in _pixels:
			var color : Color = image.get_pixelv(i)
			selected_image.set_pixelv(i, color)
			image.set_pixelv(i, Color(0, 0, 0, 0))

		if flip_h.pressed:
			selected_image.flip_x()
		if flip_v.pressed:
			selected_image.flip_y()

		image.blit_rect_mask(selected_image, selected_image, Rect2(Vector2.ZERO, selected_image.get_size()), Vector2.ZERO)


func _on_FlipImageDialog_popup_hide() -> void:
	Global.dialog_open(false)

