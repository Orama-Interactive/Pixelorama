extends ConfirmationDialog

## Called when user resumes export after filename collision
signal resume_export_function
signal about_to_preview(Dictionary)

var preview_current_frame := 0
var preview_frames: Array[Texture2D] = []

# Allow custom exporters to be added
var image_exports: Array[Export.FileFormat] = [
	Export.FileFormat.PNG,
	Export.FileFormat.WEBP,
	Export.FileFormat.JPEG,
	Export.FileFormat.GIF,
	Export.FileFormat.APNG,
	Export.FileFormat.MP4,
	Export.FileFormat.AVI,
	Export.FileFormat.OGV,
	Export.FileFormat.MKV,
	Export.FileFormat.WEBM,
]
var spritesheet_exports: Array[Export.FileFormat] = [
	Export.FileFormat.PNG, Export.FileFormat.WEBP, Export.FileFormat.JPEG
]

var _preview_images: Array[Image]
var _preview_durations: PackedFloat32Array

@onready var tabs: TabBar = $VBoxContainer/TabBar
@onready var checker: ColorRect = $"%TransparentChecker"
@onready var previews: GridContainer = $"%Previews"

@onready var spritesheet_orientation: OptionButton = $"%Orientation"
@onready var spritesheet_lines_count: SpinBox = $"%LinesCount"
@onready var spritesheet_lines_count_label: Label = $"%LinesCountLabel"

@onready var frames_option_button: OptionButton = $"%Frames"
@onready var layers_option_button: OptionButton = $"%Layers"
@onready var options_resize: ValueSlider = $"%Resize"
@onready var dimension_label: Label = $"%DimensionLabel"

@onready var path_line_edit: LineEdit = $"%PathLineEdit"
@onready var file_line_edit: LineEdit = $"%FileLineEdit"
@onready var file_format_options: OptionButton = $"%FileFormat"

@onready var options_interpolation: OptionButton = $"%Interpolation"

@onready var file_exists_alert_popup: AcceptDialog = $Popups/FileExistsAlert
@onready var path_validation_alert_popup: AcceptDialog = $Popups/PathValidationAlert
@onready var path_dialog_popup: FileDialog = $Popups/PathDialog
@onready var export_progress_popup: Window = $Popups/ExportProgressBar
@onready var export_progress_bar := %ProgressBar as ProgressBar
@onready var frame_timer: Timer = $FrameTimer


func _ready() -> void:
	get_ok_button().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	get_cancel_button().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_tab("Image")
	tabs.add_tab("Spritesheet")
	if OS.get_name() == "Windows":
		file_exists_alert_popup.add_button("Cancel Export", true, "cancel")
	else:
		file_exists_alert_popup.add_button("Cancel Export", false, "cancel")


func show_tab() -> void:
	get_tree().call_group("ExportImageOptions", "hide")
	get_tree().call_group("ExportSpritesheetOptions", "hide")
	set_file_format_selector()
	create_frame_tag_list()
	frames_option_button.select(Export.frame_current_tag)
	create_layer_list()
	layers_option_button.select(Export.export_layers)
	match Export.current_tab:
		Export.ExportTab.IMAGE:
			Export.process_animation()
			get_tree().call_group("ExportImageOptions", "show")
			get_tree().set_group(
				"ExportMultipleFilesOptions", "disabled", Export.is_single_file_format()
			)
			get_tree().set_group(
				"ExportMultipleFilesEditableOptions", "editable", !Export.is_single_file_format()
			)
		Export.ExportTab.SPRITESHEET:
			frame_timer.stop()
			Export.process_spritesheet()
			spritesheet_orientation.selected = Export.orientation
			spritesheet_lines_count.max_value = Export.number_of_frames
			spritesheet_lines_count.value = Export.lines_count
			if Export.orientation == Export.Orientation.ROWS:
				spritesheet_lines_count_label.text = "Columns:"
			else:
				spritesheet_lines_count_label.text = "Rows:"
			get_tree().call_group("ExportSpritesheetOptions", "show")
	set_preview()
	update_dimensions_label()
	tabs.current_tab = Export.current_tab


func set_preview() -> void:
	_preview_images = Export.processed_images.duplicate()
	_preview_durations = Export.durations.duplicate()
	var preview_data = {
		"exporter_id": Global.current_project.file_format,
		"export_tab": Export.current_tab,
		"preview_images": _preview_images,
		"durations": _preview_durations
	}
	about_to_preview.emit(preview_data)
	remove_previews()
	if _preview_images.size() == 1:
		previews.columns = 1
		add_image_preview(_preview_images[0])
	else:
		if Export.is_single_file_format():
			previews.columns = 1
			add_animated_preview()
		else:
			previews.columns = ceili(sqrt(_preview_images.size()))
			for i in range(_preview_images.size()):
				add_image_preview(_preview_images[i], i + 1)

	if Global.current_project.file_format == Export.FileFormat.GIF:
		$"%GifWarning".visible = true
	else:
		$"%GifWarning".visible = false


func _on_GifWarning_meta_clicked(meta) -> void:
	OS.shell_open(meta)


func add_image_preview(image: Image, canvas_number: int = -1) -> void:
	var container := create_preview_container()
	var preview := create_preview_rect()
	preview.texture = ImageTexture.create_from_image(image)
	container.add_child(preview)

	if canvas_number != -1:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = str(canvas_number)
		container.add_child(label)

	previews.add_child(container)


func add_animated_preview() -> void:
	preview_current_frame = 0
	preview_frames = []

	for processed_image in _preview_images:
		var texture := ImageTexture.create_from_image(processed_image)
		preview_frames.push_back(texture)

	var container := create_preview_container()
	container.name = "PreviewContainer"
	var preview := create_preview_rect()
	preview.name = "Preview"
	preview.texture = preview_frames[preview_current_frame]
	container.add_child(preview)

	previews.add_child(container)
	frame_timer.set_one_shot(true)  # wait_time can't change correctly if the timer is playing
	frame_timer.wait_time = _preview_durations[preview_current_frame]
	frame_timer.start()


func create_preview_container() -> VBoxContainer:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(0, 128)
	return container


func create_preview_rect() -> TextureRect:
	var preview := TextureRect.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return preview


func remove_previews() -> void:
	for child in previews.get_children():
		child.free()


func set_file_format_selector() -> void:
	match Export.current_tab:
		Export.ExportTab.IMAGE:
			_set_file_format_selector_suitable_file_formats(image_exports)
			if Export.is_ffmpeg_installed():
				for format in Export.ffmpeg_formats:
					file_format_options.set_item_disabled(format, false)
			else:
				for format in Export.ffmpeg_formats:
					file_format_options.set_item_disabled(format, true)
		Export.ExportTab.SPRITESHEET:
			_set_file_format_selector_suitable_file_formats(spritesheet_exports)


## Updates the suitable list of file formats. First is preferred.
## Note that if the current format is in the list, it stays for consistency.
func _set_file_format_selector_suitable_file_formats(formats: Array[Export.FileFormat]) -> void:
	var project := Global.current_project
	file_format_options.clear()
	var needs_update := true
	for i in formats:
		if project.file_format == i:
			needs_update = false
		var label := Export.file_format_string(i) + "; " + Export.file_format_description(i)
		file_format_options.add_item(label, i)
	if needs_update:
		project.file_format = formats[0]
	file_format_options.selected = file_format_options.get_item_index(project.file_format)


func create_frame_tag_list() -> void:
	# Clear existing tag list from entry if it exists
	frames_option_button.clear()
	# Re-add removed items
	frames_option_button.add_item("All frames", 0)
	frames_option_button.add_item("Selected frames", 1)

	# Repopulate list with current tag list
	for item in Global.current_project.animation_tags:
		frames_option_button.add_item(item.name)


func create_layer_list() -> void:
	# Clear existing tag list from entry if it exists
	layers_option_button.clear()
	# Re-add removed items
	layers_option_button.add_item("Visible layers", 0)
	layers_option_button.add_item("Selected layers", 1)

	# Repopulate list with current tag list
	for layer in Global.current_project.layers:
		var layer_name := tr("Pixel layer:")
		if layer is GroupLayer:
			layer_name = tr("Group layer:")
		elif layer is Layer3D:
			layer_name = tr("3D layer:")
		layer_name += " %s" % layer.get_layer_path()
		layers_option_button.add_item(layer_name)


func update_dimensions_label() -> void:
	if _preview_images.size() > 0:
		var new_size: Vector2 = _preview_images[0].get_size() * (Export.resize / 100.0)
		dimension_label.text = str(new_size.x, "×", new_size.y)


func open_path_validation_alert_popup(path_or_name: int = -1) -> void:
	# 0 is invalid path, 1 is invalid name
	var error_text := "Directory path and file name are not valid!"
	if path_or_name == 0:
		error_text = "Directory path is not valid!"
	elif path_or_name == 1:
		error_text = "File name is not valid!"

	path_validation_alert_popup.dialog_text = error_text
	print(error_text)
	path_validation_alert_popup.popup_centered()


func open_file_exists_alert_popup(text: String) -> void:
	file_exists_alert_popup.dialog_text = text
	file_exists_alert_popup.popup_centered()


func toggle_export_progress_popup(open: bool) -> void:
	if open:
		export_progress_popup.popup_centered()
	else:
		export_progress_popup.hide()


func set_export_progress_bar(value: float) -> void:
	export_progress_bar.value = value


func _on_ExportDialog_about_to_show() -> void:
	get_ok_button().text = "Export"
	Global.canvas.selection.transform_content_confirm()
	var project := Global.current_project
	# If we're on Web, don't let the user change the directory path
	if OS.get_name() == "Web":
		get_tree().call_group("NotHTML5", "hide")
		project.directory_path = "user://"

	if project.directory_path.is_empty():
		project.directory_path = Global.config_cache.get_value(
			"data", "current_dir", OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
		)

	# If export already occurred - sets GUI to show previous settings
	options_resize.value = Export.resize
	options_interpolation.selected = Export.interpolation
	path_line_edit.text = project.directory_path
	path_dialog_popup.current_dir = project.directory_path
	file_line_edit.text = project.file_name
	file_format_options.selected = project.file_format
	show_tab()

	# Set the size of the preview checker
	checker.size = checker.get_parent().size


func _on_Tabs_tab_clicked(tab: Export.ExportTab) -> void:
	Export.current_tab = tab
	show_tab()


func _on_Orientation_item_selected(id: Export.Orientation) -> void:
	Export.orientation = id
	if Export.orientation == Export.Orientation.ROWS:
		spritesheet_lines_count_label.text = "Columns:"
	else:
		spritesheet_lines_count_label.text = "Rows:"
	spritesheet_lines_count.value = Export.frames_divided_by_spritesheet_lines()
	Export.process_spritesheet()
	update_dimensions_label()
	set_preview()


func _on_LinesCount_value_changed(value: float) -> void:
	Export.lines_count = value
	Export.process_spritesheet()
	update_dimensions_label()
	set_preview()


func _on_Direction_item_selected(id: Export.AnimationDirection) -> void:
	Export.direction = id
	preview_current_frame = 0
	Export.process_data()
	set_preview()


func _on_Resize_value_changed(value: float) -> void:
	Export.resize = value
	update_dimensions_label()


func _on_Interpolation_item_selected(id: Image.Interpolation) -> void:
	Export.interpolation = id


func _on_ExportDialog_confirmed() -> void:
	Global.current_project.export_overwrite = false
	if await Export.export_processed_images(false, self, Global.current_project):
		hide()


func _on_PathButton_pressed() -> void:
	path_dialog_popup.popup_centered()


func _on_PathLineEdit_text_changed(new_text: String) -> void:
	Global.current_project.directory_path = new_text


func _on_FileLineEdit_text_changed(new_text: String) -> void:
	Global.current_project.file_name = new_text


func _on_FileDialog_dir_selected(dir: String) -> void:
	path_line_edit.text = dir
	Global.current_project.directory_path = dir


func _on_FileFormat_item_selected(idx: int) -> void:
	var id := file_format_options.get_item_id(idx) as Export.FileFormat
	Global.current_project.file_format = id
	if not Export.is_single_file_format():
		get_tree().set_group("ExportMultipleFilesOptions", "disabled", false)
		get_tree().set_group("ExportMultipleFilesEditableOptions", "editable", true)
		frame_timer.stop()
	else:
		get_tree().set_group("ExportMultipleFilesOptions", "disabled", true)
		get_tree().set_group("ExportMultipleFilesEditableOptions", "editable", false)
	set_preview()


## Overwrite existing file
func _on_FileExistsAlert_confirmed() -> void:
	file_exists_alert_popup.dialog_text = Export.file_exists_alert
	Export.stop_export = false
	resume_export_function.emit()


func _on_FileExistsAlert_custom_action(action: String) -> void:
	if action == "cancel":
		# Cancel export
		file_exists_alert_popup.dialog_text = Export.file_exists_alert
		Export.stop_export = true
		resume_export_function.emit()
		file_exists_alert_popup.hide()


func _on_FrameTimer_timeout() -> void:
	var preview_texture_rect: TextureRect = previews.get_node("PreviewContainer/Preview")
	if not preview_texture_rect:
		return
	preview_texture_rect.texture = preview_frames[preview_current_frame]

	if preview_current_frame == preview_frames.size() - 1:
		preview_current_frame = 0
	else:
		preview_current_frame += 1

	frame_timer.wait_time = _preview_durations[preview_current_frame - 1]
	frame_timer.start()


func _on_ExportDialog_popup_hide() -> void:
	frame_timer.stop()


func _on_IncludeTagsInFilename_toggled(button_pressed: bool) -> void:
	Export.include_tag_in_filename = button_pressed


func _on_MultipleAnimationsDirectories_toggled(button_pressed: bool) -> void:
	Export.new_dir_for_each_frame_tag = button_pressed


func _on_Frames_item_selected(id: int) -> void:
	Export.frame_current_tag = id
	Export.process_data()
	set_preview()
	spritesheet_lines_count.max_value = Export.number_of_frames
	spritesheet_lines_count.value = Export.lines_count


func _on_Layers_item_selected(id: int) -> void:
	Export.export_layers = id
	Export.process_data()
	set_preview()


func _on_SeparatorCharacter_text_changed(new_text: String) -> void:
	Export.separator_character = new_text
