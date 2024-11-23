class_name RecorderPanel
extends PanelContainer

enum Mode { CANVAS, PIXELORAMA }

var mode := Mode.CANVAS
var chosen_dir := "":
	set(value):
		chosen_dir = value
		if chosen_dir.ends_with("/"):  # Remove end back-slashes if present
			chosen_dir[-1] = ""
var recorded_projects := {}  ## [Dictionary] of [Project] and [Recorder].
var save_dir := ""
var skip_amount := 1  ## Number of "do" actions after which a frame can be captured.
var resize_percent := 100
var _path_dialog: FileDialog:
	get:
		if not is_instance_valid(_path_dialog):
			_path_dialog = FileDialog.new()
			_path_dialog.exclusive = false
			_path_dialog.popup_window = true
			_path_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
			_path_dialog.access = FileDialog.ACCESS_FILESYSTEM
			_path_dialog.use_native_dialog = Global.use_native_file_dialogs
			_path_dialog.add_to_group(&"FileDialogs")
			_path_dialog.dir_selected.connect(_on_path_dialog_dir_selected)
			add_child(_path_dialog)
		return _path_dialog

@onready var captured_label := %CapturedLabel as Label
@onready var start_button := $"%Start" as Button
@onready var size_label := $"%Size" as Label
@onready var path_field := $"%Path" as LineEdit
@onready var options_dialog := $OptionsDialog as AcceptDialog
@onready var options_container := %OptionsContainer as VBoxContainer


class Recorder:
	var project: Project
	var recorder_panel: RecorderPanel
	var actions_done := -1
	var frames_captured := 0
	var save_directory := ""

	func _init(_project: Project, _recorder_panel: RecorderPanel) -> void:
		project = _project
		recorder_panel = _recorder_panel
		# Create a new directory based on time
		var time_dict := Time.get_time_dict_from_system()
		var folder := str(
			project.name, time_dict.hour, "_", time_dict.minute, "_", time_dict.second
		)
		var dir := DirAccess.open(recorder_panel.chosen_dir)
		save_directory = recorder_panel.chosen_dir.path_join(folder)
		dir.make_dir_recursive(save_directory)
		project.removed.connect(recorder_panel.finalize_recording.bind(project))
		project.undo_redo.version_changed.connect(capture_frame)
		recorder_panel.captured_label.text = ""

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			# Needed so that the project won't be forever remained in memory because of bind().
			project.removed.disconnect(recorder_panel.finalize_recording)

	func capture_frame() -> void:
		actions_done += 1
		if actions_done % recorder_panel.skip_amount != 0:
			return
		var image: Image
		if recorder_panel.mode == RecorderPanel.Mode.PIXELORAMA:
			image = recorder_panel.get_window().get_texture().get_image()
		else:
			var frame := project.frames[project.current_frame]
			image = project.new_empty_image()
			DrawingAlgos.blend_layers(image, frame, Vector2i.ZERO, project)

			if recorder_panel.resize_percent != 100:
				var resize := recorder_panel.resize_percent / 100
				var new_width := image.get_width() * resize
				var new_height := image.get_height() * resize
				image.resize(new_width, new_height, Image.INTERPOLATE_NEAREST)
		var save_file := str(project.name, "_", frames_captured, ".png")
		image.save_png(save_directory.path_join(save_file))
		frames_captured += 1
		recorder_panel.captured_label.text = str("Saved: ", frames_captured)


func _ready() -> void:
	if OS.get_name() == "Web":
		ExtensionsApi.panel.remove_node_from_tab.call_deferred(self)
		return
	Global.project_switched.connect(_on_project_switched)
	# Make a recordings folder if there isn't one
	chosen_dir = Global.home_data_directory.path_join("Recordings")
	DirAccess.make_dir_recursive_absolute(chosen_dir)
	path_field.text = chosen_dir


func _on_project_switched() -> void:
	if recorded_projects.has(Global.current_project):
		initialize_recording()
		start_button.set_pressed_no_signal(true)
		Global.change_button_texturerect(start_button.get_child(0), "stop.png")
		captured_label.text = str(
			"Saved: ", recorded_projects[Global.current_project].frames_captured
		)
	else:
		finalize_recording()
		start_button.set_pressed_no_signal(false)
		Global.change_button_texturerect(start_button.get_child(0), "start.png")


func initialize_recording() -> void:
	# disable some options that are not required during recording
	captured_label.visible = true
	for child in options_container.get_children():
		if !child.is_in_group("visible during recording"):
			child.visible = false


func finalize_recording(project := Global.current_project) -> void:
	if recorded_projects.has(project):
		recorded_projects.erase(project)
	if project == Global.current_project:
		captured_label.visible = false
		for child in options_container.get_children():
			child.visible = true
		if mode == Mode.PIXELORAMA:
			size_label.get_parent().visible = false


func _on_Start_toggled(button_pressed: bool) -> void:
	if button_pressed:
		recorded_projects[Global.current_project] = Recorder.new(Global.current_project, self)
		initialize_recording()
		Global.change_button_texturerect(start_button.get_child(0), "stop.png")
	else:
		finalize_recording()
		Global.change_button_texturerect(start_button.get_child(0), "start.png")


func _on_Settings_pressed() -> void:
	_on_SpinBox_value_changed(resize_percent)
	options_dialog.popup_on_parent(Rect2i(position, options_dialog.size))


func _on_SkipAmount_value_changed(value: float) -> void:
	skip_amount = value


func _on_Mode_toggled(button_pressed: bool) -> void:
	if button_pressed:
		mode = Mode.PIXELORAMA
		size_label.get_parent().visible = false
	else:
		mode = Mode.CANVAS
		size_label.get_parent().visible = true


func _on_SpinBox_value_changed(value: float) -> void:
	resize_percent = value
	var new_size: Vector2 = Global.current_project.size * (resize_percent / 100.0)
	size_label.text = str("(", new_size.x, "×", new_size.y, ")")


func _on_Choose_pressed() -> void:
	_path_dialog.popup_centered()
	_path_dialog.current_dir = chosen_dir


func _on_open_folder_pressed() -> void:
	OS.shell_open(path_field.text)


func _on_path_dialog_dir_selected(dir: String) -> void:
	chosen_dir = dir
	path_field.text = chosen_dir
	start_button.disabled = false
