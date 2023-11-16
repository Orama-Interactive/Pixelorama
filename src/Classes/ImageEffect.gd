class_name ImageEffect
extends ConfirmationDialog
## Parent class for all image effects
## Methods that have "pass" are meant to be replaced by the inherited scripts

enum { SELECTED_CELS, FRAME, ALL_FRAMES, ALL_PROJECTS }

var affect := SELECTED_CELS
var selected_cels := Image.new()
var current_frame := Image.new()
var preview_image := Image.new()
var preview_texture := ImageTexture.new()
var preview: TextureRect
var selection_checkbox: CheckBox
var affect_option_button: OptionButton
var animate_panel: AnimatePanel
var commit_idx := -1  # the current frame, image effect is applied to
var confirmed := false
var _preview_idx := 0  # the current frame, being previewed


func _ready() -> void:
	set_nodes()
	get_ok().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	get_cancel().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	current_frame.create(1, 1, false, Image.FORMAT_RGBA8)
	selected_cels.create(1, 1, false, Image.FORMAT_RGBA8)
	connect("about_to_show", self, "_about_to_show")
	connect("popup_hide", self, "_popup_hide")
	connect("confirmed", self, "_confirmed")
	if selection_checkbox:
		selection_checkbox.connect("toggled", self, "_on_SelectionCheckBox_toggled")
	if affect_option_button:
		affect_option_button.connect("item_selected", self, "_on_AffectOptionButton_item_selected")
	if animate_panel:
		$"%ShowAnimate".connect("pressed", self, "display_animate_dialog")


func _about_to_show() -> void:
	confirmed = false
	Global.canvas.selection.transform_content_confirm()
	prepare_animator(Global.current_project)
	set_and_update_preview_image(Global.current_project.current_frame)
	update_transparent_background_size()


# prepares "animate_panel.frames" according to affect
func prepare_animator(project: Project) -> void:
	var frames = []
	if affect == SELECTED_CELS:
		for fram_layer in project.selected_cels:
			if not fram_layer[0] in frames:
				frames.append(fram_layer[0])
		frames.sort()  # To always start animating from left side of the timeline
		animate_panel.frames = frames
	elif affect == FRAME:
		frames.append(project.current_frame)
		animate_panel.frames = frames
	elif (affect == ALL_FRAMES) or (affect == ALL_PROJECTS):
		for i in project.frames.size():
			frames.append(i)
		animate_panel.frames = frames


func _confirmed() -> void:
	confirmed = true
	commit_idx = -1
	var project: Project = Global.current_project
	if affect == SELECTED_CELS:
		prepare_animator(project)
		var undo_data := _get_undo_data(project)
		for cel_index in project.selected_cels:
			if !project.layers[cel_index[1]].can_layer_get_drawn():
				continue
			var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
			if not cel is PixelCel:
				continue
			var cel_image: Image = cel.image
			commit_idx = cel_index[0]  # frame is cel_index[0] in this mode
			commit_action(cel_image)
		_commit_undo("Draw", undo_data, project)

	elif affect == FRAME:
		prepare_animator(project)
		var undo_data := _get_undo_data(project)
		var i := 0
		commit_idx = project.current_frame
		for cel in project.frames[project.current_frame].cels:
			if not cel is PixelCel:
				i += 1
				continue
			if project.layers[i].can_layer_get_drawn():
				commit_action(cel.image)
			i += 1
		_commit_undo("Draw", undo_data, project)

	elif affect == ALL_FRAMES:
		prepare_animator(project)
		var undo_data := _get_undo_data(project)
		for frame in project.frames:
			var i := 0
			commit_idx += 1  # frames are simply increasing by 1 in this mode
			for cel in frame.cels:
				if not cel is PixelCel:
					i += 1
					continue
				if project.layers[i].can_layer_get_drawn():
					commit_action(cel.image)
				i += 1
		_commit_undo("Draw", undo_data, project)

	elif affect == ALL_PROJECTS:
		for _project in Global.projects:
			prepare_animator(_project)
			commit_idx = -1

			var undo_data := _get_undo_data(_project)
			for frame in _project.frames:
				var i := 0
				commit_idx += 1  # frames are simply increasing by 1 in this mode
				for cel in frame.cels:
					if not cel is PixelCel:
						i += 1
						continue
					if _project.layers[i].can_layer_get_drawn():
						commit_action(cel.image, _project)
					i += 1
			_commit_undo("Draw", undo_data, _project)


func commit_action(_cel: Image, _project: Project = Global.current_project) -> void:
	pass


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton
	animate_panel = $"%AnimatePanel"
	animate_panel.image_effect_node = self


func display_animate_dialog():
	var animate_dialog: Popup = animate_panel.get_parent()
	var pos = Vector2(rect_global_position.x + rect_size.x, rect_global_position.y)
	var animate_dialog_rect := Rect2(pos, Vector2(animate_dialog.rect_size.x, rect_size.y))
	animate_dialog.popup(animate_dialog_rect)
	animate_panel.re_calibrate_preview_slider()


func _commit_undo(action: String, undo_data: Dictionary, project: Project) -> void:
	var redo_data := _get_undo_data(project)
	project.undos += 1
	project.undo_redo.create_action(action)
	Global.undo_redo_compress_images(redo_data, undo_data, project)
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
	$"%ShowAnimate".visible = bool(affect != FRAME and animate_panel.properties.size() != 0)
	prepare_animator(Global.current_project)  # for use in preview
	animate_panel.re_calibrate_preview_slider()
	update_preview()


func set_and_update_preview_image(frame_idx: int) -> void:
	_preview_idx = frame_idx
	var frame: Frame = Global.current_project.frames[frame_idx]
	selected_cels.resize(Global.current_project.size.x, Global.current_project.size.y)
	selected_cels.fill(Color(0, 0, 0, 0))
	Export.blend_selected_cels(selected_cels, frame)
	current_frame.resize(Global.current_project.size.x, Global.current_project.size.y)
	current_frame.fill(Color(0, 0, 0, 0))
	Export.blend_all_layers(current_frame, frame)
	update_preview()


func update_preview() -> void:
	match affect:
		SELECTED_CELS:
			preview_image.copy_from(selected_cels)
		_:
			preview_image.copy_from(current_frame)
	commit_idx = _preview_idx
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
	# Resize the images to (1, 1) so they do not waste unneeded RAM
	selected_cels.resize(1, 1)
	current_frame.resize(1, 1)
	preview_image = Image.new()


func _is_webgl1() -> bool:
	return OS.get_name() == "HTML5" and OS.get_current_video_driver() == OS.VIDEO_DRIVER_GLES2
