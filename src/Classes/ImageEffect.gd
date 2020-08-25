class_name ImageEffect extends AcceptDialog
# Parent class for all image effects
# Methods that have "pass" are meant to be replaced by the inherited Scripts


enum {CEL, FRAME, ALL_FRAMES, ALL_PROJECTS}

var affect : int = CEL
var pixels := []
var current_cel : Image
var preview_image : Image
var preview_texture : ImageTexture
var preview : TextureRect
var selection_checkbox : CheckBox
var affect_option_button : OptionButton


func _ready() -> void:
	set_nodes()
	current_cel = Image.new()
	preview_image = Image.new()
	preview_texture = ImageTexture.new()
	connect("about_to_show", self, "_about_to_show")
	connect("popup_hide", self, "_popup_hide")
	connect("confirmed", self, "_confirmed")
	if selection_checkbox:
		selection_checkbox.connect("toggled", self, "_on_SelectionCheckBox_toggled")
	if affect_option_button:
		affect_option_button.connect("item_selected", self, "_on_AffectOptionButton_item_selected")


func _about_to_show() -> void:
	current_cel = Global.current_project.frames[Global.current_project.current_frame].cels[Global.current_project.current_layer].image
	if selection_checkbox:
		_on_SelectionCheckBox_toggled(selection_checkbox.pressed)
	update_transparent_background_size()


func _confirmed() -> void:
	pass


func set_nodes() -> void:
	pass


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
	pass


func update_transparent_background_size() -> void:
	if !preview:
		return
	var image_size_y = preview.rect_size.y
	var image_size_x = preview.rect_size.x
	if preview_image.get_size().x > preview_image.get_size().y:
		var scale_ratio = preview_image.get_size().x / image_size_x
		image_size_y = preview_image.get_size().y / scale_ratio
	else:
		var scale_ratio = preview_image.get_size().y / image_size_y
		image_size_x = preview_image.get_size().x / scale_ratio

	preview.get_node("TransparentChecker").rect_size.x = image_size_x
	preview.get_node("TransparentChecker").rect_size.y = image_size_y


func _popup_hide() -> void:
	Global.dialog_open(false)
