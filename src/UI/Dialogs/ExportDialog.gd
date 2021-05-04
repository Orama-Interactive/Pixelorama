extends AcceptDialog

# called when user resumes export after filename collision
signal resume_export_function()

var animated_preview_current_frame := 0
var animated_preview_frames = []

onready var tabs = $VBoxContainer/Tabs
onready var popups = $Popups
onready var file_exists_alert_popup = $Popups/FileExistsAlert
onready var path_validation_alert_popup = $Popups/PathValidationAlert
onready var path_dialog_popup = $Popups/PathDialog
onready var export_progress_popup = $Popups/ExportProgressBar
onready var export_progress_bar = $Popups/ExportProgressBar/MarginContainer/ProgressBar

onready var animation_options_multiple_animations_directories = $VBoxContainer/AnimationOptions/MultipleAnimationsDirectories
onready var previews = $VBoxContainer/PreviewPanel/PreviewScroll/Previews
onready var frame_timer = $FrameTimer

onready var frame_options = $VBoxContainer/FrameOptions
onready var frame_options_frame_number = $VBoxContainer/FrameOptions/FrameNumber/FrameNumber

onready var spritesheet_options = $VBoxContainer/SpritesheetOptions
onready var spritesheet_options_frames = $VBoxContainer/SpritesheetOptions/Frames/Frames
onready var spritesheet_options_orientation = $VBoxContainer/SpritesheetOptions/Orientation/Orientation
onready var spritesheet_options_lines_count = $VBoxContainer/SpritesheetOptions/Orientation/LinesCount
onready var spritesheet_options_lines_count_label = $VBoxContainer/SpritesheetOptions/Orientation/LinesCountLabel

onready var animation_options = $VBoxContainer/AnimationOptions
onready var animation_options_animation_type = $VBoxContainer/AnimationOptions/AnimationType
onready var animation_options_animation_options = $VBoxContainer/AnimationOptions/AnimatedOptions
onready var animation_options_direction = $VBoxContainer/AnimationOptions/AnimatedOptions/Direction


onready var options_resize = $VBoxContainer/Options/Resize
onready var options_interpolation = $VBoxContainer/Options/Interpolation
onready var path_container = $VBoxContainer/Path
onready var path_line_edit = $VBoxContainer/Path/PathLineEdit
onready var file_line_edit = $VBoxContainer/File/FileLineEdit
onready var file_file_format = $VBoxContainer/File/FileFormat


func _ready() -> void:
	tabs.add_tab("Frame")
	tabs.add_tab("Spritesheet")
	tabs.add_tab("Animation")
	if OS.get_name() == "Windows":
		add_button("Cancel", true, "cancel")
		file_exists_alert_popup.add_button("Cancel Export", true, "cancel")
	else:
		add_button("Cancel", false, "cancel")
		file_exists_alert_popup.add_button("Cancel Export", false, "cancel")

	# Remove close button from export progress bar
	export_progress_popup.get_close_button().hide()


func show_tab() -> void:
	frame_options.hide()
	spritesheet_options.hide()
	animation_options.hide()

	match Export.current_tab:
		Export.ExportTab.FRAME:
			Export.file_format = Export.FileFormat.PNG
			file_file_format.selected = Export.FileFormat.PNG
			frame_timer.stop()
			if not Export.was_exported:
				Export.frame_number = Global.current_project.current_frame + 1
			frame_options_frame_number.max_value = Global.current_project.frames.size() + 1
			var prev_frame_number = frame_options_frame_number.value
			frame_options_frame_number.value = Export.frame_number
			if prev_frame_number == Export.frame_number:
				Export.process_frame()
			frame_options.show()
		Export.ExportTab.SPRITESHEET:
			create_frame_tag_list()
			Export.file_format = Export.FileFormat.PNG
			if not Export.was_exported:
				Export.orientation = Export.Orientation.ROWS
				Export.lines_count = int(ceil(sqrt(Export.number_of_frames)))
			Export.process_spritesheet()
			file_file_format.selected = Export.FileFormat.PNG
			spritesheet_options_frames.select(Export.frame_current_tag)
			frame_timer.stop()
			spritesheet_options_orientation.selected = Export.orientation
			spritesheet_options_lines_count.max_value = Export.number_of_frames
			spritesheet_options_lines_count.value = Export.lines_count
			spritesheet_options_lines_count_label.text = "Columns:"
			spritesheet_options.show()
		Export.ExportTab.ANIMATION:
			set_file_format_selector()
			Export.process_animation()
			animation_options_animation_type.selected = Export.animation_type
			animation_options_direction.selected = Export.direction
			animation_options.show()
	set_preview()
	tabs.current_tab = Export.current_tab


func set_preview() -> void:
	remove_previews()
	if Export.processed_images.size() == 1 and Export.current_tab != Export.ExportTab.ANIMATION:
		previews.columns = 1
		add_image_preview(Export.processed_images[0])
	else:
		match Export.animation_type:
			Export.AnimationType.MULTIPLE_FILES:
				previews.columns = ceil(sqrt(Export.processed_images.size()))
				for i in range(Export.processed_images.size()):
					add_image_preview(Export.processed_images[i], i + 1)
			Export.AnimationType.ANIMATED:
				previews.columns = 1
				add_animated_preview()


func add_image_preview(image: Image, canvas_number: int = -1) -> void:
	var container = create_preview_container()
	var preview = create_preview_rect()
	preview.texture = ImageTexture.new()
	preview.texture.create_from_image(image, 0)
	container.add_child(preview)

	if canvas_number != -1:
		var label = Label.new()
		label.align = Label.ALIGN_CENTER
		label.text = String(canvas_number)
		container.add_child(label)

	previews.add_child(container)


func add_animated_preview() -> void:
	animated_preview_current_frame = Export.processed_images.size() - 1 if Export.direction == Export.AnimationDirection.BACKWARDS else 0
	animated_preview_frames = []

	for processed_image in Export.processed_images:
		var texture = ImageTexture.new()
		texture.create_from_image(processed_image, 0)
		animated_preview_frames.push_back(texture)

	var container = create_preview_container()
	container.name = "PreviewContainer"
	var preview = create_preview_rect()
	preview.name = "Preview"
	preview.texture = animated_preview_frames[animated_preview_current_frame]
	container.add_child(preview)

	previews.add_child(container)
	frame_timer.set_one_shot(true) #The wait_time it can't change correctly if it is playing
	frame_timer.wait_time = Global.current_project.frames[animated_preview_current_frame].duration * (1 / Global.current_project.fps)
	frame_timer.start()


func create_preview_container() -> VBoxContainer:
	var container = VBoxContainer.new()
	container.size_flags_horizontal = SIZE_EXPAND_FILL
	container.size_flags_vertical = SIZE_EXPAND_FILL
	container.rect_min_size = Vector2(0, 128)
	return container


func create_preview_rect() -> TextureRect:
	var preview = TextureRect.new()
	preview.expand = true
	preview.size_flags_horizontal = SIZE_EXPAND_FILL
	preview.size_flags_vertical = SIZE_EXPAND_FILL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return preview


func remove_previews() -> void:
	for child in previews.get_children():
		child.free()


func set_file_format_selector() -> void:
	animation_options_multiple_animations_directories.visible = false
	match Export.animation_type:
		Export.AnimationType.MULTIPLE_FILES:
			Export.file_format = Export.FileFormat.PNG
			file_file_format.selected = Export.FileFormat.PNG
			frame_timer.stop()
			animation_options_animation_options.hide()
			animation_options_multiple_animations_directories.pressed = Export.new_dir_for_each_frame_tag
			animation_options_multiple_animations_directories.visible = true
		Export.AnimationType.ANIMATED:
			Export.file_format = Export.FileFormat.GIF
			file_file_format.selected = Export.FileFormat.GIF
			animation_options_animation_options.show()


func create_frame_tag_list() -> void:
	# Clear existing tag list from entry if it exists
	spritesheet_options_frames.clear()
	spritesheet_options_frames.add_item("All Frames", 0) # Re-add removed 'All Frames' item

	# Repopulate list with current tag list
	for item in Global.current_project.animation_tags:
		spritesheet_options_frames.add_item(item.name)


func open_path_validation_alert_popup() -> void:
	path_validation_alert_popup.popup_centered()


func open_file_exists_alert_popup(dialog_text: String) -> void:
	file_exists_alert_popup.dialog_text = dialog_text
	file_exists_alert_popup.popup_centered()


func toggle_export_progress_popup(open: bool) -> void:
	if open:
		export_progress_popup.popup_centered()
	else:
		export_progress_popup.hide()


func set_export_progress_bar(value: float) -> void:
	export_progress_bar.value = value


func _on_ExportDialog_about_to_show() -> void:
	Global.canvas.selection.transform_content_confirm()
	# If we're on HTML5, don't let the user change the directory path
	if OS.get_name() == "HTML5":
		path_container.visible = false
		Export.directory_path = "user://"

	if Export.directory_path.empty():
		Export.directory_path = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)

	# If export already occured - sets gui to show previous settings
	options_resize.value = Export.resize
	options_interpolation.selected = Export.interpolation
	path_line_edit.text = Export.directory_path
	path_dialog_popup.current_dir = Export.directory_path
	file_line_edit.text = Export.file_name
	file_file_format.selected = Export.file_format
	show_tab()

	for child in popups.get_children(): # Set the theme for the popups
		child.theme = Global.control.theme

	Export.file_exists_alert = tr("File %s already exists. Overwrite?") # Update translation

	# Set the size of the preview checker
	var checker = $VBoxContainer/PreviewPanel/TransparentChecker
	checker.rect_size = checker.get_parent().rect_size

func _on_Tabs_tab_clicked(tab : int) -> void:
	Export.current_tab = tab
	show_tab()


func _on_Frame_value_changed(value: float) -> void:
	Export.frame_number = value
	Export.process_frame()
	set_preview()


func _on_Orientation_item_selected(id : int) -> void:
	Export.orientation = id
	if Export.orientation == Export.Orientation.ROWS:
		spritesheet_options_lines_count_label.text = "Columns:"
	else:
		spritesheet_options_lines_count_label.text = "Rows:"
	spritesheet_options_lines_count.value = Export.frames_divided_by_spritesheet_lines()
	Export.process_spritesheet()
	set_preview()


func _on_LinesCount_value_changed(value : float) -> void:
	Export.lines_count = value
	Export.process_spritesheet()
	set_preview()


func _on_AnimationType_item_selected(id : int) -> void:
	Export.animation_type = id
	set_file_format_selector()
	set_preview()


func _on_Direction_item_selected(id : int) -> void:
	Export.direction = id
	match id:
		Export.AnimationDirection.FORWARD:
			animated_preview_current_frame = 0
		Export.AnimationDirection.BACKWARDS:
			animated_preview_current_frame = Export.processed_images.size() - 1
		Export.AnimationDirection.PING_PONG:
			animated_preview_current_frame = 0
			pingpong_direction = Export.AnimationDirection.FORWARD


func _on_Resize_value_changed(value : float) -> void:
	Export.resize = value


func _on_Interpolation_item_selected(id: int) -> void:
	Export.interpolation = id


func _on_ExportDialog_confirmed() -> void:
	if Export.export_processed_images(false, self):
		hide()


func _on_ExportDialog_custom_action(action : String) -> void:
	if action == "cancel":
		hide()


func _on_PathButton_pressed() -> void:
	path_dialog_popup.popup_centered()


func _on_PathLineEdit_text_changed(new_text : String) -> void:
	Global.current_project.directory_path = new_text
	Export.directory_path = new_text


func _on_FileLineEdit_text_changed(new_text : String) -> void:
	Global.current_project.file_name = new_text
	Export.file_name = new_text


func _on_FileDialog_dir_selected(dir : String) -> void:
	path_line_edit.text = dir
	Global.current_project.directory_path = dir
	Export.directory_path = dir


func _on_FileFormat_item_selected(id : int) -> void:
	Global.current_project.file_format = id
	Export.file_format = id


func _on_FileExistsAlert_confirmed() -> void:
	# Overwrite existing file
	file_exists_alert_popup.dialog_text = Export.file_exists_alert
	Export.stop_export = false
	emit_signal("resume_export_function")


func _on_FileExistsAlert_custom_action(action : String) -> void:
	if action == "cancel":
		# Cancel export
		file_exists_alert_popup.dialog_text = Export.file_exists_alert
		Export.stop_export = true
		emit_signal("resume_export_function")
		file_exists_alert_popup.hide()


var pingpong_direction = Export.AnimationDirection.FORWARD
func _on_FrameTimer_timeout() -> void:
	$VBoxContainer/PreviewPanel/PreviewScroll/Previews/PreviewContainer/Preview.texture = animated_preview_frames[animated_preview_current_frame]

	match Export.direction:
		Export.AnimationDirection.FORWARD:
			if animated_preview_current_frame == animated_preview_frames.size() - 1:
				animated_preview_current_frame = 0
			else:
				animated_preview_current_frame += 1
			frame_timer.wait_time = Global.current_project.frames[(animated_preview_current_frame - 1) % (animated_preview_frames.size())].duration * (1 / Global.current_project.fps)
			frame_timer.start()
		Export.AnimationDirection.BACKWARDS:
			if animated_preview_current_frame == 0:
				animated_preview_current_frame = Export.processed_images.size() - 1
			else:
				animated_preview_current_frame -= 1
			frame_timer.wait_time = Global.current_project.frames[(animated_preview_current_frame + 1) % (animated_preview_frames.size())].duration * (1 / Global.current_project.fps)
			frame_timer.start()
		Export.AnimationDirection.PING_PONG:
			match pingpong_direction:
				Export.AnimationDirection.FORWARD:
					if animated_preview_current_frame == animated_preview_frames.size() - 1:
						pingpong_direction = Export.AnimationDirection.BACKWARDS
						animated_preview_current_frame -= 1
						if animated_preview_current_frame <= 0:
							animated_preview_current_frame = 0
					else:
						animated_preview_current_frame += 1
					frame_timer.wait_time = Global.current_project.frames[(animated_preview_current_frame - 1) % (animated_preview_frames.size())].duration * (1 / Global.current_project.fps)
					frame_timer.start()
				Export.AnimationDirection.BACKWARDS:
					if animated_preview_current_frame == 0:
						animated_preview_current_frame += 1
						if animated_preview_current_frame >= animated_preview_frames.size() - 1:
							animated_preview_current_frame = 0
						pingpong_direction = Export.AnimationDirection.FORWARD
					else:
						animated_preview_current_frame -= 1
					frame_timer.wait_time = Global.current_project.frames[(animated_preview_current_frame + 1) % (animated_preview_frames.size())].duration * (1 / Global.current_project.fps)
					frame_timer.start()



func _on_ExportDialog_popup_hide() -> void:
	frame_timer.stop()


func _on_MultipleAnimationsDirectories_toggled(button_pressed : bool) -> void:
	Export.new_dir_for_each_frame_tag = button_pressed


func _on_Frames_item_selected(id : int) -> void:
	Export.frame_current_tag = id
	Export.process_spritesheet()
	set_preview()
	spritesheet_options_lines_count.max_value = Export.number_of_frames
	spritesheet_options_lines_count.value = Export.lines_count
