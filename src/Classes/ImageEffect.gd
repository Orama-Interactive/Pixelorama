class_name ImageEffect
extends ConfirmationDialog
## Parent class for all image effects
## Methods that have "pass" are meant to be replaced by the inherited scripts

enum { SELECTED_CELS, FRAME, ALL_FRAMES, ALL_PROJECTS }

var affect: int = SELECTED_CELS
var selected_cels := Image.create(1, 1, false, Image.FORMAT_RGBA8)
var current_frame := Image.create(1, 1, false, Image.FORMAT_RGBA8)
var preview_image := Image.new()
var aspect_ratio_container: AspectRatioContainer
var preview: TextureRect
var live_checkbox: CheckBox
var wait_time_slider: ValueSlider
var wait_apply_timer: Timer
var selection_checkbox: CheckBox
var affect_option_button: OptionButton
var animate_panel: AnimatePanel
var commit_idx := -1  ## The current frame the image effect is being applied to
var has_been_confirmed := false
var live_preview := true
var _preview_idx := 0  ## The current frame being previewed


func _ready() -> void:
	set_nodes()
	get_ok_button().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	get_cancel_button().size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	aspect_ratio_container.ratio = float(preview_image.get_width()) / preview_image.get_height()


# prepares "animate_panel.frames" according to affect
func prepare_animator(project: Project) -> void:
	if not is_instance_valid(animate_panel):
		return
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
	aspect_ratio_container = $VBoxContainer/AspectRatioContainer
	preview = $VBoxContainer/AspectRatioContainer/Preview
	live_checkbox = $VBoxContainer/LiveSettings/LiveCheckbox
	wait_time_slider = $VBoxContainer/LiveSettings/WaitTime
	wait_apply_timer = $VBoxContainer/LiveSettings/WaitApply
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton
	animate_panel = $"%AnimatePanel"
	if is_instance_valid(animate_panel):
		animate_panel.image_effect_node = self
	if is_instance_valid(live_checkbox):
		live_checkbox.button_pressed = live_preview


func display_animate_dialog() -> void:
	var animate_dialog: Popup = animate_panel.get_parent()
	var pos := Vector2(position.x + size.x, position.y)
	var animate_dialog_rect := Rect2(pos, Vector2(animate_dialog.size.x, size.y))
	animate_dialog.popup(animate_dialog_rect)
	animate_panel.re_calibrate_preview_slider()


func _commit_undo(action: String, undo_data: Dictionary, project: Project) -> void:
	var tile_editing_mode := TileSetPanel.tile_editing_mode
	if tile_editing_mode == TileSetPanel.TileEditingMode.MANUAL:
		tile_editing_mode = TileSetPanel.TileEditingMode.AUTO
	project.update_tilemaps(undo_data, tile_editing_mode)
	var redo_data := _get_undo_data(project)
	project.undos += 1
	project.undo_redo.create_action(action)
	project.deserialize_cel_undo_data(redo_data, undo_data)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false, -1, -1, project))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true, -1, -1, project))
	project.undo_redo.commit_action()


func _get_undo_data(project: Project) -> Dictionary:
	var data := {}
	project.serialize_cel_undo_data(_get_selected_draw_cels(project), data)
	return data


func _get_selected_draw_cels(project: Project) -> Array[BaseCel]:
	var images: Array[BaseCel] = []
	if affect == SELECTED_CELS:
		for cel_index in project.selected_cels:
			var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
			if cel is PixelCel:
				images.append(cel)
	else:
		for frame in project.frames:
			for cel in frame.cels:
				if cel is PixelCel:
					images.append(cel)
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
	DrawingAlgos.blend_layers(selected_cels, frame, Vector2i.ZERO, Global.current_project, true)
	current_frame.resize(Global.current_project.size.x, Global.current_project.size.y)
	current_frame.fill(Color(0, 0, 0, 0))
	DrawingAlgos.blend_layers(current_frame, frame)
	update_preview()


func update_preview(using_timer := false) -> void:
	if !live_preview and !using_timer:
		wait_apply_timer.start()
		return

	match affect:
		SELECTED_CELS:
			preview_image.copy_from(selected_cels)
		_:
			preview_image.copy_from(current_frame)
	commit_idx = _preview_idx
	commit_action(preview_image)
	preview.texture = ImageTexture.create_from_image(preview_image)


func _visibility_changed() -> void:
	if visible:
		return
	Global.dialog_open(false)
	# Resize the images to (1, 1) so they do not waste unneeded RAM
	selected_cels.resize(1, 1)
	current_frame.resize(1, 1)
	preview_image = Image.new()


func _on_live_checkbox_toggled(toggled_on: bool) -> void:
	live_preview = toggled_on
	wait_time_slider.editable = !live_preview
	wait_time_slider.visible = !live_preview
	if !toggled_on:
		size.y += 1  # Reset size of dialog


func _on_wait_apply_timeout() -> void:
	update_preview(true)


func _on_wait_time_value_changed(value: float) -> void:
	wait_apply_timer.wait_time = value / 1000.0
