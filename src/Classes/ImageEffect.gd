class_name ImageEffect
extends ConfirmationDialog
# Parent class for all image effects
# Methods that have "pass" are meant to be replaced by the inherited Scripts

enum { SELECTED_CELS, FRAME, ALL_FRAMES, ALL_PROJECTS }

var affect: int = SELECTED_CELS
var selected_cels := Image.new()
var current_frame := Image.new()
var preview_image := Image.new()
var preview_texture := ImageTexture.new()
var preview: TextureRect
var selection_checkbox: CheckBox
var affect_option_button: OptionButton
var animate_options_container: Node
var animate_menu: PopupMenu
var initial_button: Button
var animate_bool = []
var initial_values: PoolRealArray = []
var selected_idx: int = 0  # the current selected cel to apply animation to
var confirmed := false


func _ready() -> void:
	set_nodes()
	get_ok().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	get_cancel().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	current_frame.create(
		Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_RGBA8
	)
	selected_cels.create(
		Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_RGBA8
	)
	connect("about_to_show", self, "_about_to_show")
	connect("popup_hide", self, "_popup_hide")
	connect("confirmed", self, "_confirmed")
	if selection_checkbox:
		selection_checkbox.connect("toggled", self, "_on_SelectionCheckBox_toggled")
	if affect_option_button:
		affect_option_button.connect("item_selected", self, "_on_AffectOptionButton_item_selected")
	if animate_menu:
		set_animate_menu(0)
		animate_menu.connect("id_pressed", self, "_update_animate_flags")
	if initial_button:
		initial_button.connect("pressed", self, "set_initial_values")


func _about_to_show() -> void:
	confirmed = false
	Global.canvas.selection.transform_content_confirm()
	var frame: Frame = Global.current_project.frames[Global.current_project.current_frame]
	selected_cels.resize(Global.current_project.size.x, Global.current_project.size.y)
	selected_cels.fill(Color(0, 0, 0, 0))
	Export.blend_selected_cels(selected_cels, frame)
	current_frame.resize(Global.current_project.size.x, Global.current_project.size.y)
	current_frame.fill(Color(0, 0, 0, 0))
	Export.blend_all_layers(current_frame, frame)
	update_preview()
	update_transparent_background_size()


func _confirmed() -> void:
	selected_idx = 0
	confirmed = true
	var project: Project = Global.current_project
	if affect == SELECTED_CELS:
		var undo_data := _get_undo_data(project)
		for cel_index in project.selected_cels:
			if !project.layers[cel_index[1]].can_layer_get_drawn():
				continue
			var cel: PixelCel = project.frames[cel_index[0]].cels[cel_index[1]]
			var cel_image: Image = cel.image
			commit_action(cel_image)
		_commit_undo("Draw", undo_data, project)

	elif affect == FRAME:
		var undo_data := _get_undo_data(project)
		var i := 0
		for cel in project.frames[project.current_frame].cels:
			if project.layers[i].can_layer_get_drawn():
				commit_action(cel.image)
			i += 1
		_commit_undo("Draw", undo_data, project)

	elif affect == ALL_FRAMES:
		var undo_data := _get_undo_data(project)
		for frame in project.frames:
			var i := 0
			for cel in frame.cels:
				if project.layers[i].can_layer_get_drawn():
					commit_action(cel.image)
				i += 1
		_commit_undo("Draw", undo_data, project)

	elif affect == ALL_PROJECTS:
		for _project in Global.projects:
			var undo_data := _get_undo_data(_project)
			for frame in _project.frames:
				var i := 0
				for cel in frame.cels:
					if _project.layers[i].can_layer_get_drawn():
						commit_action(cel.image, _project)
					i += 1
			_commit_undo("Draw", undo_data, _project)


func commit_action(_cel: Image, _project: Project = Global.current_project) -> void:
	if confirmed and affect == SELECTED_CELS:
		selected_idx += 1


func set_nodes() -> void:
	pass


func set_animate_menu(elements: int) -> void:
	initial_values.resize(elements)
	initial_values.fill(0)
	animate_bool.resize(elements)
	animate_bool.fill(false)


func set_initial_values() -> void:
	pass


func get_animated_value(project: Project, final: float, property_idx: int):
	if animate_bool[property_idx] == true and confirmed:
		var first: Vector2 = Vector2(initial_values[property_idx], 0)
		var second: Vector2 = Vector2(final, 0)
		var interpolation = float(selected_idx) / project.selected_cels.size()
		return first.linear_interpolate(second, interpolation).x
	else:
		return final


func _update_animate_flags(id: int) -> void:
	animate_bool[id] = !animate_bool[id]
	animate_menu.set_item_checked(id, animate_bool[id])


func _commit_undo(action: String, undo_data: Dictionary, project: Project) -> void:
	var redo_data := _get_undo_data(project)

	project.undos += 1
	project.undo_redo.create_action(action)
	for image in redo_data:
		project.undo_redo.add_do_property(image, "data", redo_data[image])
	for image in undo_data:
		project.undo_redo.add_undo_property(image, "data", undo_data[image])
	project.undo_redo.add_do_method(Global, "undo_or_redo", false, -1, -1, project)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true, -1, -1, project)
	project.undo_redo.commit_action()


func _get_undo_data(project: Project) -> Dictionary:
	var data := {}
	var images := _get_selected_draw_images(project)
	for image in images:
		image.unlock()
		data[image] = image.data
	return data


func _get_selected_draw_images(project: Project) -> Array:  # Array of Images
	var images := []
	if affect == SELECTED_CELS:
		for cel_index in project.selected_cels:
			var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
			if cel is PixelCel:
				images.append(cel.image)
	else:
		for frame in project.frames:
			for cel in frame.cels:
				if cel is PixelCel:
					images.append(cel.image)
	return images


func _on_SelectionCheckBox_toggled(_button_pressed: bool) -> void:
	update_preview()


func _on_AffectOptionButton_item_selected(index: int) -> void:
	affect = index
	animate_options_container.visible = bool(affect == SELECTED_CELS)
	update_preview()


func update_preview() -> void:
	match affect:
		SELECTED_CELS:
			preview_image.copy_from(selected_cels)
		_:
			preview_image.copy_from(current_frame)
	commit_action(preview_image)
	preview_image.unlock()
	preview_texture.create_from_image(preview_image, 0)
	preview.texture = preview_texture


func update_transparent_background_size() -> void:
	if !preview:
		return
	var image_size_y := preview.rect_size.y
	var image_size_x := preview.rect_size.x
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


func _is_webgl1() -> bool:
	return OS.get_name() == "HTML5" and OS.get_current_video_driver() == OS.VIDEO_DRIVER_GLES2
