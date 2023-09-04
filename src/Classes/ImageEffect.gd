class_name ImageEffect
extends ConfirmationDialog
## Parent class for all image effects
## Methods that have "pass" are meant to be replaced by the inherited scripts

enum { SELECTED_CELS, FRAME, ALL_FRAMES, ALL_PROJECTS }

var affect: int = SELECTED_CELS
var selected_cels: Image
var current_frame: Image
var preview_image := Image.new()
var preview_texture := ImageTexture.new()
var preview: TextureRect
var selection_checkbox: CheckBox
var affect_option_button: OptionButton
var animate_panel: AnimatePanel
var commit_idx := -1  ## The current frame the image effect is being applied to
var has_been_confirmed := false
var _preview_idx := 0  ## The current frame being previewed


func _ready() -> void:
	set_nodes()
	get_ok_button().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	get_cancel_button().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	current_frame = Image.create(
		Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_RGBA8
	)
	selected_cels = Image.create(
		Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_RGBA8
	)
	about_to_popup.connect(_about_to_popup)
	visibility_changed.connect(_visibility_changed)
	confirmed.connect(_confirmed)
	if selection_checkbox:
		selection_checkbox.toggled.connect(_on_SelectionCheckBox_toggled)
	if affect_option_button:
		affect_option_button.item_selected.connect(_on_AffectOptionButton_item_selected)
	if animate_panel:
		$"%ShowAnimate".pressed.connect(display_animate_dialog)


func _about_to_popup() -> void:
	has_been_confirmed = false
	Global.canvas.selection.transform_content_confirm()
	prepare_animator(Global.current_project)
	set_and_update_preview_image(Global.current_project.current_frame)
	update_transparent_background_size()


# prepares "animate_panel.frames" according to affect
func prepare_animator(project: Project) -> void:
	var frames: PackedInt32Array = []
	if affect == SELECTED_CELS:
		for frame_layer in project.selected_cels:
			if not frame_layer[0] in frames:
				frames.append(frame_layer[0])
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
	has_been_confirmed = true
	commit_idx = -1
	var project := Global.current_project
	if affect == SELECTED_CELS:
		prepare_animator(project)
		var undo_data := _get_undo_data(project)
		for cel_index in project.selected_cels:
			if !project.layers[cel_index[1]].can_layer_get_drawn():
				continue
			var cel := project.frames[cel_index[0]].cels[cel_index[1]]
			if not cel is PixelCel:
				continue
			commit_idx = cel_index[0]  # frame is cel_index[0] in this mode
			commit_action(cel.image)
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


func commit_action(_cel: Image, _project := Global.current_project) -> void:
	pass


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton
	animate_panel = $"%AnimatePanel"
	animate_panel.image_effect_node = self


func display_animate_dialog():
	var animate_dialog: Popup = animate_panel.get_parent()
	var pos := Vector2(position.x + size.x, position.y)
	var animate_dialog_rect := Rect2(pos, Vector2(animate_dialog.size.x, size.y))
	animate_dialog.popup(animate_dialog_rect)
	animate_panel.re_calibrate_preview_slider()


func _commit_undo(action: String, undo_data: Dictionary, project: Project) -> void:
	var redo_data := _get_undo_data(project)
	project.undos += 1
	project.undo_redo.create_action(action)
	for image in redo_data:
		project.undo_redo.add_do_property(image, "data", redo_data[image])
	for image in undo_data:
		project.undo_redo.add_undo_property(image, "data", undo_data[image])
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false, -1, -1, project))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true, -1, -1, project))
	project.undo_redo.commit_action()


func _get_undo_data(project: Project) -> Dictionary:
	var data := {}
	var images := _get_selected_draw_images(project)
	for image in images:
		data[image] = image.data
	return data


func _get_selected_draw_images(project: Project) -> Array[Image]:
	var images: Array[Image] = []
	if affect == SELECTED_CELS:
		for cel_index in project.selected_cels:
			var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
			if cel is PixelCel:
				images.append(cel.get_image())
	else:
		for frame in project.frames:
			for cel in frame.cels:
				if cel is PixelCel:
					images.append(cel.get_image())
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
	var frame := Global.current_project.frames[frame_idx]
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
	preview_texture = ImageTexture.create_from_image(preview_image)
	preview.texture = preview_texture


func update_transparent_background_size() -> void:
	if !preview:
		return
	var image_size_y := preview.size.y
	var image_size_x := preview.size.x
	if preview_image.get_size().x > preview_image.get_size().y:
		var scale_ratio := preview_image.get_size().x / image_size_x
		image_size_y = preview_image.get_size().y / scale_ratio
	else:
		var scale_ratio := preview_image.get_size().y / image_size_y
		image_size_x = preview_image.get_size().x / scale_ratio

	preview.get_node("TransparentChecker").size.x = image_size_x
	preview.get_node("TransparentChecker").size.y = image_size_y


func _visibility_changed() -> void:
	Global.dialog_open(false)
