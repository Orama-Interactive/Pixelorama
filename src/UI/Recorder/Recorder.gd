extends PanelContainer

signal frame_saved

enum Mode { CANVAS, PIXELORAMA }

var mode: int = Mode.CANVAS
var chosen_dir := ""
var save_dir := ""
var project: Project
var cache := []  # Array of images stored during recording
var frame_captured := 0  # A variable used to visualize frames captured
var skip_amount := 1  # No of "do" actions after which a frame can be captured
var current_frame_no := 0  # used to compare with skip_amount to see if it can be captured

var resize := 100

@onready var project_list := $"%TargetProjectOption" as OptionButton
@onready var folder_button := $"%Folder" as Button
@onready var start_button := $"%Start" as Button
@onready var size_label := $"%Size" as Label
@onready var path_field := $"%Path3D" as LineEdit


func _ready() -> void:
	refresh_projects_list()
	project = Global.current_project
	frame_saved.connect(_on_frame_saved)
	# Make a recordings folder if there isn't one
	var dir := DirAccess.open(chosen_dir)
	chosen_dir = Global.directory_module.xdg_data_home.path_join("Recordings")
	dir.make_dir_recursive(chosen_dir)
	path_field.text = chosen_dir
	size_label.text = str("(", project.size.x, "×", project.size.y, ")")


func initialize_recording() -> void:
	connect_undo()  # connect to detect changes in project
	cache.clear()  # clear the cache array to store new images
	frame_captured = 0
	current_frame_no = skip_amount - 1

	# disable some options that are not required during recording
	folder_button.visible = true
	project_list.visible = false
	$ScrollContainer/CenterContainer/GridContainer/Captured.visible = true
	for child in $Dialogs/Options/PanelContainer/VBoxContainer.get_children():
		if !child.is_in_group("visible during recording"):
			child.visible = false

	save_dir = chosen_dir
	# Remove end back-slashes if present
	if save_dir.ends_with("/"):
		save_dir[-1] = ""

	# Create a new directory based on time
	var time_dict := Time.get_time_dict_from_system()
	var folder := str(
		project.name, time_dict.hour, "_", time_dict.minute, "_", time_dict.second
	)
	save_dir = save_dir.path_join(folder)
	var dir := DirAccess.open(save_dir)
	dir.make_dir_recursive(save_dir)

	capture_frame()  # capture first frame
	$Timer.start()


func capture_frame() -> void:
	current_frame_no += 1
	if current_frame_no != skip_amount:
		return
	current_frame_no = 0
	var image: Image
	if mode == Mode.PIXELORAMA:
		image = get_tree().root.get_viewport().get_texture().get_data()
		image.flip_y()
	else:
		var frame = project.frames[project.current_frame]
		image = Image.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
		Export.blend_all_layers(image, frame, Vector2(0, 0), project)

	if mode == Mode.CANVAS:
		if resize != 100:
			image.resize(image.get_size().x * resize / 100, image.get_size().y * resize / 100, Image.INTERPOLATE_NEAREST)

	cache.append(image)


func _on_Timer_timeout() -> void:
	# Saves frames little by little during recording
	if cache.size() > 0:
		save_frame(cache[0])
		cache.remove_at(0)


func save_frame(img: Image) -> void:
	var save_file := str(project.name, "_", frame_captured, ".png")
	img.save_png(save_dir.path_join(save_file))
	frame_saved.emit()


func _on_frame_saved() -> void:
	frame_captured += 1
	$ScrollContainer/CenterContainer/GridContainer/Captured.text = str("Saved: ", frame_captured)


func finalize_recording() -> void:
	$Timer.stop()
	for img in cache:
		save_frame(img)
	cache.clear()
	disconnect_undo()
	folder_button.visible = false
	project_list.visible = true
	$ScrollContainer/CenterContainer/GridContainer/Captured.visible = false
	for child in $Dialogs/Options/PanelContainer/VBoxContainer.get_children():
		child.visible = true
	if mode == Mode.PIXELORAMA:
		size_label.get_parent().visible = false


func disconnect_undo() -> void:
	project.undo_redo.version_changed.disconnect(capture_frame)


func connect_undo() -> void:
	project.undo_redo.version_changed.connect(capture_frame)


func _on_TargetProjectOption_item_selected(index: int) -> void:
	project = Global.projects[index]


func _on_TargetProjectOption_pressed() -> void:
	refresh_projects_list()


func refresh_projects_list() -> void:
	project_list.clear()
	for proj in Global.projects:
		project_list.add_item(proj.name)


func _on_Start_toggled(button_pressed: bool) -> void:
	if button_pressed:
		initialize_recording()
		Global.change_button_texturerect(start_button.get_child(0), "stop.png")
	else:
		finalize_recording()
		Global.change_button_texturerect(start_button.get_child(0), "start.png")


func _on_Settings_pressed() -> void:
	var settings := $Dialogs/Options as Window
	var pos := position
	settings.popup(Rect2(pos, settings.size))


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
	resize = value
	var new_size: Vector2 = project.size * (resize / 100.0)
	size_label.text = str("(", new_size.x, "×", new_size.y, ")")


func _on_Choose_pressed() -> void:
	$Dialogs/Path3D.popup_centered()
	$Dialogs/Path3D.current_dir = chosen_dir


func _on_Open_pressed() -> void:
	OS.shell_open(path_field.text)


func _on_Path_dir_selected(dir: String) -> void:
	chosen_dir = dir
	path_field.text = chosen_dir
	start_button.disabled = false


func _on_Fps_value_changed(value: float) -> void:
	var dur_label := $Dialogs/Options/PanelContainer/VBoxContainer/Fps/Duration as Label
	var duration := snappedf(1.0 / value, 0.0001)
	dur_label.text = str("= ", duration, " sec")
