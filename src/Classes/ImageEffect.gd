class_name ImageEffect extends AcceptDialog
# Parent class for all image effects
# Methods that have "pass" are meant to be replaced by the inherited Scripts


enum {CEL, FRAME, ALL_FRAMES, ALL_PROJECTS}

var affect : int = CEL
var current_cel : Image
var current_frame : Image
var preview_image : Image
var preview_texture : ImageTexture
var preview : TextureRect
var selection_checkbox : CheckBox
var affect_option_button : OptionButton


func _ready() -> void:
	set_nodes()
	current_cel = Image.new()
	current_frame = Image.new()
	current_frame.create(Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_RGBA8)
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
	Global.canvas.selection.transform_content_confirm()
	current_cel = Global.current_project.frames[Global.current_project.current_frame].cels[Global.current_project.current_layer].image
	current_frame.resize(Global.current_project.size.x, Global.current_project.size.y)
	current_frame.fill(Color(0, 0, 0, 0))
	var frame = Global.current_project.frames[Global.current_project.current_frame]
	Export.blend_layers(current_frame, frame)
	if selection_checkbox:
		_on_SelectionCheckBox_toggled(selection_checkbox.pressed)
	else:
		update_preview()
	update_transparent_background_size()


func _confirmed() -> void:
	if affect == CEL:
		if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn(): # No changes if the layer is locked or invisible
			return
		Global.canvas.handle_undo("Draw")
		commit_action(current_cel)
		Global.canvas.handle_redo("Draw")
	elif affect == FRAME:
		Global.canvas.handle_undo("Draw", Global.current_project, -1)
		var i := 0
		for cel in Global.current_project.frames[Global.current_project.current_frame].cels:
			if Global.current_project.layers[i].can_layer_get_drawn():
				commit_action(cel.image)
			i += 1
		Global.canvas.handle_redo("Draw", Global.current_project, -1)

	elif affect == ALL_FRAMES:
		Global.canvas.handle_undo("Draw", Global.current_project, -1, -1)
		for frame in Global.current_project.frames:
			var i := 0
			for cel in frame.cels:
				if Global.current_project.layers[i].can_layer_get_drawn():
					commit_action(cel.image)
				i += 1
		Global.canvas.handle_redo("Draw", Global.current_project, -1, -1)

	elif affect == ALL_PROJECTS:
		for project in Global.projects:
			Global.canvas.handle_undo("Draw", project, -1, -1)
			for frame in project.frames:
				var i := 0
				for cel in frame.cels:
					if project.layers[i].can_layer_get_drawn():
						commit_action(cel.image, project)
					i += 1
			Global.canvas.handle_redo("Draw", project, -1, -1)


func commit_action(_cel : Image, _project : Project = Global.current_project) -> void:
	pass


func set_nodes() -> void:
	pass


func _on_SelectionCheckBox_toggled(_button_pressed : bool) -> void:
	update_preview()


func _on_AffectOptionButton_item_selected(index : int) -> void:
	affect = index
	update_preview()


func update_preview() -> void:
	match affect:
		CEL:
			preview_image.copy_from(current_cel)
		_:
			preview_image.copy_from(current_frame)
	commit_action(preview_image)
	preview_image.unlock()
	preview_texture.create_from_image(preview_image, 0)
	preview.texture = preview_texture


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
