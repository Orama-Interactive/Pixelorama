extends ConfirmationDialog


enum {CEL, FRAME, ALL_FRAMES, ALL_PROJECTS}

var affect : int = CEL
var pixels := []
var current_cel : Image
var preview_image : Image
var preview_texture : ImageTexture

var red := true
var green := true
var blue := true
var alpha := false

onready var preview : TextureRect = $VBoxContainer/Preview
onready var selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox


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
		DrawingAlgos.invert_image_colors(current_cel, pixels, red, green, blue, alpha)
		Global.canvas.handle_redo("Draw")
	elif affect == FRAME:
		Global.canvas.handle_undo("Draw", Global.current_project, -1)
		for cel in Global.current_project.frames[Global.current_project.current_frame].cels:
			DrawingAlgos.invert_image_colors(cel.image, pixels, red, green, blue, alpha)
		Global.canvas.handle_redo("Draw", Global.current_project, -1)

	elif affect == ALL_FRAMES:
		Global.canvas.handle_undo("Draw", Global.current_project, -1, -1)
		for frame in Global.current_project.frames:
			for cel in frame.cels:
				DrawingAlgos.invert_image_colors(cel.image, pixels, red, green, blue, alpha)
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
					DrawingAlgos.invert_image_colors(cel.image, _pixels, red, green, blue, alpha)
			Global.canvas.handle_redo("Draw", project, -1, -1)


func _on_RButton_toggled(button_pressed : bool) -> void:
	red = button_pressed
	update_preview()


func _on_GButton_toggled(button_pressed : bool) -> void:
	green = button_pressed
	update_preview()


func _on_BButton_toggled(button_pressed : bool) -> void:
	blue = button_pressed
	update_preview()


func _on_AButton_toggled(button_pressed : bool) -> void:
	alpha = button_pressed
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
	DrawingAlgos.invert_image_colors(preview_image, pixels, red, green, blue, alpha)
	preview_image.unlock()
	preview_texture.create_from_image(preview_image, 0)
	preview.texture = preview_texture


func _on_FlipImageDialog_popup_hide() -> void:
	Global.dialog_open(false)
