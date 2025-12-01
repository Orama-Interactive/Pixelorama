class_name RecorderPanel
extends PanelContainer

enum CaptureMethod { ACTIONS, MOUSE_MOTION, SECONDS }
enum RecordType { CANVAS, REGION }
enum FFmpegExportBy { FPS_DETERMINES_DURATION, DURATION_DETERMINES_FPS }

var capture_method := CaptureMethod.ACTIONS
var record_type := RecordType.CANVAS
var save_dir := ""
var chosen_dir := "":
	set(value):
		chosen_dir = value
		if chosen_dir.ends_with("/"):  # Remove end back-slashes if present
			chosen_dir[-1] = ""
var start_after_delay_seconds: int = 0
var action_interval: int = 1  ## Number of "do" actions after which a frame can be captured.
var mouse_displacement: int = 100  ## Mouse displacement after which a frame can be captured.
var seconds_interval: float = 1  ## Number of seconds after which a frame can be captured.
var record_area := Rect2i(0, 0, 1, 1)
var area_follows_mouse := false
var scaling_enabled := true
var scale_percent := 100
var should_export_gif := false
var export_fps: float = 10
var export_duretion: float = 20
var target_window_idx := 0  # index of
var export_by := FFmpegExportBy.FPS_DETERMINES_DURATION
var recorded_projects: Dictionary[Project, Recorder] = {}

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
var _gif_start_frame: int = 0
var _gif_end_frame: int = -1
## Performance variables
var _old_preview_region: Rect2i
var _old_last_position := Vector2.INF

@onready var start_delay_slider: ValueSlider = %StartDelaySlider
# Interval options
@onready var capture_method_option: OptionButton = %CaptureMethodOption
@onready var capture_actions: ValueSlider = %CaptureActions
@onready var capture_mouse_distance: ValueSlider = %MouseDistance
@onready var capture_seconds: ValueSlider = %CaptureSconds
# Record type options
@onready var record_type_option: OptionButton = %RecordTypeOption
@onready var area_options: VBoxContainer = %AreaOptions
@onready var rect_texture: TextureRect = %RectTexture
@onready var preview_aspect_ratio_container: AspectRatioContainer = %PreviewAspectRatioContainer
@onready var target_screen_option: OptionButton = %TargetScreen
@onready var rect_positon_slider: ValueSliderV2 = %RectPositonSlider
@onready var rect_size_slider: ValueSliderV2 = %RectSizeSlider
@onready var follow_mouse_checkbox: CheckBox = %FollowMouse
# Scaling
@onready var scale_output_checkbox: CheckBox = %ScaleOutputCheckbox
@onready var output_scale_container: HBoxContainer = %OutputScale
@onready var scale_value_slider: ValueSlider = %ScaleValueSlider
@onready var size_label := %SizePreviewLabel as Label
# FFmpeg
@onready var ffmpeg_options: VBoxContainer = %FFmpegOptions
@onready var export_gif_checkbox: CheckBox = %ExportGifCheckbox
@onready var ffmpeg_export_by_option: OptionButton = %FFmpegExportByOption
@onready var fps_value_slider: ValueSlider = %FPSValueSlider
@onready var ffmpeg_sconds_slider: ValueSlider = %FFmpegScondsSlider

# Output
@onready var path_field := %Path as LineEdit
@onready var options_container := %OptionsContainer as VBoxContainer

# Panel elements
@onready var captured_label := %CapturedLabel as Label
@onready var start_button := %Start as Button
@onready var capture_timer: Timer = %CaptureTimer
@onready var preview_timer: Timer = %PreviewTimer
@onready var options_dialog := $OptionsDialog as AcceptDialog


class Recorder:
	var project: Project
	var recorder_panel: RecorderPanel
	var actions_done := -1
	var frames_captured := 0
	var save_directory := ""
	var _last_mouse_position := Vector2i.MAX
	var _start_size := Vector2i.ZERO
	var cursor_image: Image
	var mouse_sprite := preload("res://assets/graphics/cursor.png")

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
		cursor_image = mouse_sprite.get_image()
		update_settings()
		recorder_panel.captured_label.text = ""
		_start_size = recorder_panel.record_area.size

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			# Needed so that the project won't be forever remained in memory because of bind().
			project.removed.disconnect(recorder_panel.finalize_recording)

	func update_settings():
		if project.undo_redo.version_changed.is_connected(capture_frame):
			project.undo_redo.version_changed.disconnect(capture_frame)
		if recorder_panel.capture_timer.timeout.is_connected(capture_frame):
			recorder_panel.capture_timer.timeout.disconnect(capture_frame)
		match recorder_panel.capture_method:
			RecorderPanel.CaptureMethod.ACTIONS:
				project.undo_redo.version_changed.connect(capture_frame)
			RecorderPanel.CaptureMethod.MOUSE_MOTION:
				# _input() won't work properly, so i use wait_time with a low value
				recorder_panel.capture_timer.wait_time = 0.05
				recorder_panel.capture_timer.timeout.connect(capture_frame)
				recorder_panel.capture_timer.start()
			RecorderPanel.CaptureMethod.SECONDS:
				recorder_panel.capture_timer.wait_time = recorder_panel.seconds_interval
				recorder_panel.capture_timer.timeout.connect(capture_frame)
				recorder_panel.capture_timer.start()

	static func get_base_region(target_window_idx: int, screen_optionbutton: OptionButton) -> Array:
		var screen_image: Image
		var screen_idx := DisplayServer.INVALID_SCREEN
		var base_region := Rect2i()
		var screen_offset := Vector2i.ZERO
		if target_window_idx < screen_optionbutton.item_count:
			var metadata = screen_optionbutton.get_item_metadata(target_window_idx)
			if typeof(metadata) == TYPE_ARRAY:
				if metadata.size() == 2:
					var idx: int = metadata[0]
					var is_window: bool = metadata[1]
					if is_window and DisplayServer.get_window_list().has(idx):
						base_region = Rect2i(
							DisplayServer.window_get_position(idx),
							DisplayServer.window_get_size(idx)
						)
						screen_idx = DisplayServer.window_get_current_screen(idx)
					else:
						if idx < DisplayServer.get_screen_count():
							screen_idx = idx
		if screen_idx != DisplayServer.INVALID_SCREEN:
			screen_image = DisplayServer.screen_get_image(screen_idx)
			if base_region.has_area() and screen_image:
				screen_image = screen_image.get_region(base_region)
			else:
				screen_offset = screen_optionbutton.get_tree().root.get_window().position
		return [screen_image, screen_offset]

	func capture_frame() -> void:
		if Global.current_project != project:
			return
		if not recorder_panel.get_window():
			return
		if recorder_panel.options_dialog.visible:
			return
		match recorder_panel.capture_method:
			RecorderPanel.CaptureMethod.ACTIONS:
				actions_done += 1
				if actions_done % recorder_panel.action_interval != 0:
					return
			RecorderPanel.CaptureMethod.MOUSE_MOTION:
				var mouse_pos := recorder_panel.get_global_mouse_position()
				var disp := _last_mouse_position.distance_to(mouse_pos)
				if disp < recorder_panel.mouse_displacement:
					return
				_last_mouse_position = recorder_panel.get_global_mouse_position()
		var image: Image
		match recorder_panel.record_type:
			RecorderPanel.RecordType.REGION:
				var base_area: Array = Recorder.get_base_region(
					recorder_panel.target_window_idx, recorder_panel.target_screen_option
				)
				image = base_area[0]
				if !image:  # Error encountered (Image not found)
					recorder_panel.finalize_recording(project)
					return
				var region = Rect2i(
					recorder_panel.record_area.position, recorder_panel.record_area.size
				)
				# Capture the cursor image
				var mouse_pos: Vector2i = recorder_panel.get_global_mouse_position()
				var mouse_point: Vector2i = mouse_pos - (cursor_image.get_size() / 2) + base_area[1]
				cursor_image.convert(image.get_format())
				image.blend_rect(
					cursor_image, Rect2i(Vector2i.ZERO, cursor_image.get_size()), mouse_point
				)
				if recorder_panel.area_follows_mouse:
					var offset = (region.size / 2) - base_area[1]
					region.position = (mouse_pos - offset).clamp(
						Vector2i.ZERO, image.get_size() - region.size
					)
				if region != Rect2i(Vector2i.ZERO, image.get_size()):
					image = image.get_region(region)
			RecorderPanel.RecordType.CANVAS:
				var frame := project.frames[project.current_frame]
				image = project.new_empty_image()
				DrawingAlgos.blend_layers(image, frame, Vector2i.ZERO, project)
		if image.get_size() != _start_size:  # Resize image if it is different than intended
			image.resize(_start_size.x, _start_size.y, Image.INTERPOLATE_NEAREST)
		if recorder_panel.scaling_enabled:
			@warning_ignore("integer_division")
			var resize := recorder_panel.scale_percent / 100
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
	record_type_option.add_item("Canvas Only", RecordType.CANVAS)
	record_type_option.add_item("Custom Area", RecordType.REGION)
	capture_method_option.add_item("By Actions", CaptureMethod.ACTIONS)
	capture_method_option.add_item("By Mouse Motion", CaptureMethod.MOUSE_MOTION)
	capture_method_option.add_item("By Seconds", CaptureMethod.SECONDS)
	ffmpeg_export_by_option.add_item("FPS decides duration", FFmpegExportBy.FPS_DETERMINES_DURATION)
	ffmpeg_export_by_option.add_item("Duration decides fps", FFmpegExportBy.DURATION_DETERMINES_FPS)
	Global.project_switched.connect(_on_project_switched)
	# Make a recordings folder if there isn't one
	chosen_dir = Global.home_data_directory.path_join("Recordings")
	DirAccess.make_dir_recursive_absolute(chosen_dir)
	path_field.text = chosen_dir
	# Temp assignment (remove later)
	var config = Global.config_cache.get_value("RecorderPanel", "settings", {})
	set_config(config)
	update_config()
	repopulate_screen_options()


func initialize_recording() -> void:
	# disable some options that are not required during recording
	captured_label.visible = true
	captured_label.text = "Initializing"
	var group_nodes := get_tree().get_nodes_in_group("hidden during recording")
	if group_nodes:
		for child: Control in group_nodes:
			child.visible = false


func finalize_recording(project := Global.current_project) -> void:
	if recorded_projects.has(project) and Export.is_ffmpeg_installed() and should_export_gif:
		export_gif(project)
		recorded_projects.erase(project)
	if project == Global.current_project:
		captured_label.visible = false
		if get_tree():
			var group_nodes := get_tree().get_nodes_in_group("hidden during recording")
			if group_nodes:
				for child: Control in group_nodes:
					child.visible = true
			update_config()


func export_gif(project: Project) -> void:
	var recorder := recorded_projects[project]
	var path := recorder.save_directory
	var frame_count: int = recorder.frames_captured - _gif_start_frame
	if _gif_end_frame != -1:
		frame_count = _gif_end_frame - _gif_start_frame
	var palette_generation: PackedStringArray = [
		"-y",
		"-start_number",
		str(_gif_start_frame),
		"-i",
		path.path_join(project.name + "_%d.png"),
		"-frames:v",
		str(frame_count),
		"-filter_complex",
		"[0:v] palettegen",
		path.path_join("palette.png")
	]
	var success := OS.execute(Global.ffmpeg_path, palette_generation, [], true)
	var clip_fps := export_fps
	if export_by == FFmpegExportBy.DURATION_DETERMINES_FPS:
		clip_fps = frame_count / export_duretion
	var ffmpeg_execute: PackedStringArray = [
		"-y",
		"-framerate",
		str(clip_fps),
		"-start_number",
		str(_gif_start_frame),
		"-i",
		path.path_join(project.name + "_%d.png"),
		"-i",
		path.path_join("palette.png"),
		"-filter_complex",
		"paletteuse",
		"-frames:v",
		str(frame_count),
		path.path_join(project.name + ".gif")
	]
	success = OS.execute(Global.ffmpeg_path, ffmpeg_execute, [], true)
	if success < 0 or success > 1:
		var fail_text := """Video failed to export. Make sure you have FFMPEG installed
			and have set the correct path in the preferences."""
		Global.popup_error(tr(fail_text))
	if FileAccess.file_exists(path.path_join("palette.png")):
		DirAccess.remove_absolute(path.path_join("palette.png"))


func _on_settings_pressed() -> void:
	options_dialog.popup_centered_clamped(options_dialog.size)


func _on_open_folder_pressed() -> void:
	OS.shell_open(path_field.text)


func _on_start_recording_toggled(button_pressed: bool) -> void:
	if button_pressed and captured_label.visible == false:
		initialize_recording()
		if start_after_delay_seconds > 0:
			await get_tree().create_timer(start_after_delay_seconds).timeout
		recorded_projects[Global.current_project] = Recorder.new(Global.current_project, self)
		Global.change_button_texturerect(start_button.get_child(0), "stop.png")
	else:
		if recorded_projects.has(Global.current_project):  # prevents reaching here during await
			finalize_recording()
			Global.change_button_texturerect(start_button.get_child(0), "start.png")


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


# Option Dialog methods & Signals


func save_config() -> void:
	Global.config_cache.set_value("RecorderPanel", "settings", get_config())


func get_config() -> Dictionary:
	return {
		"start_after_delay_seconds": start_after_delay_seconds,
		"capture_method": capture_method,
		"action_interval": action_interval,
		"mouse_displacement": mouse_displacement,
		"seconds_interval": seconds_interval,
		"record_type": record_type,
		"target_window_idx": target_window_idx,
		"record_area": record_area,
		"area_follows_mouse": area_follows_mouse,
		"scaling_enabled": scaling_enabled,
		"scale_percent": scale_percent,
		"should_export_gif": should_export_gif,
		"export_by": export_by,
		"export_fps": export_fps,
		"export_duretion": export_duretion,
	}


func set_config(config: Dictionary) -> void:
	record_area.size = get_window().size
	start_after_delay_seconds = config.get("start_after_delay_seconds", start_after_delay_seconds)
	capture_method = config.get("capture_method", capture_method)
	action_interval = config.get("action_interval", action_interval)
	mouse_displacement = config.get("mouse_displacement", mouse_displacement)
	seconds_interval = config.get("seconds_interval", seconds_interval)
	record_type = config.get("record_type", record_type)
	target_window_idx = config.get("target_window_idx", target_window_idx)
	record_area = config.get("record_area", record_area)
	area_follows_mouse = config.get("area_follows_mouse", area_follows_mouse)
	scaling_enabled = config.get("scaling_enabled", scaling_enabled)
	scale_percent = config.get("scale_percent", scale_percent)
	should_export_gif = config.get("should_export_gif", should_export_gif)
	export_by = config.get("export_by", export_by)
	export_fps = config.get("export_fps", export_fps)
	export_duretion = config.get("export_duretion", export_duretion)


func update_config():
	start_delay_slider.set_value_no_signal(start_after_delay_seconds)
	capture_method_option.selected = capture_method_option.get_item_index(capture_method)
	capture_actions.set_value_no_signal(action_interval)
	capture_mouse_distance.set_value_no_signal(mouse_displacement)
	capture_seconds.set_value_no_signal(seconds_interval)

	record_type_option.selected = record_type_option.get_item_index(record_type)
	if target_window_idx < target_screen_option.item_count:  # Fixes if window count suddenly changes
		repopulate_screen_options()
	else:
		target_screen_option.selected = target_window_idx
	follow_mouse_checkbox.set_pressed_no_signal(area_follows_mouse)
	rect_positon_slider.set_value_no_signal(record_area.position)
	rect_size_slider.set_value_no_signal(record_area.size)

	if area_follows_mouse:
		if preview_timer.is_stopped():
			preview_timer.start()
	else:
		if not preview_timer.is_stopped():
			preview_timer.stop()

	scale_output_checkbox.set_pressed_no_signal(scaling_enabled)
	scale_value_slider.set_value_no_signal(scale_percent)
	var new_size: Vector2i = Global.current_project.size * (scale_percent / 100.0)
	size_label.text = str("(", new_size.x, "×", new_size.y, ")")

	export_gif_checkbox.set_pressed_no_signal(should_export_gif)
	ffmpeg_export_by_option.selected = ffmpeg_export_by_option.get_item_index(export_by)
	fps_value_slider.set_value_no_signal(export_fps)
	ffmpeg_sconds_slider.set_value_no_signal(export_duretion)

	capture_actions.visible = capture_method == CaptureMethod.ACTIONS
	capture_mouse_distance.visible = capture_method == CaptureMethod.MOUSE_MOTION
	capture_seconds.visible = capture_method == CaptureMethod.SECONDS
	target_screen_option.visible = record_type == RecordType.REGION
	area_options.visible = record_type == RecordType.REGION
	rect_positon_slider.visible = not follow_mouse_checkbox.button_pressed
	output_scale_container.visible = scaling_enabled
	scale_value_slider.visible = scaling_enabled
	ffmpeg_export_by_option.visible = should_export_gif
	fps_value_slider.visible = (
		should_export_gif and export_by == FFmpegExportBy.FPS_DETERMINES_DURATION
	)
	ffmpeg_sconds_slider.visible = (
		should_export_gif and export_by == FFmpegExportBy.DURATION_DETERMINES_FPS
	)

	for recorder: Recorder in recorded_projects.values():
		recorder.update_settings()


func repopulate_screen_options():
	target_screen_option.clear()
	var entry_id: int = 0
	for i in DisplayServer.get_screen_count():
		target_screen_option.add_item("Screen %s" % str(i), entry_id)
		target_screen_option.set_item_metadata(entry_id, [i, false])
		entry_id += 1
	for i in DisplayServer.get_window_list():
		if options_dialog.get_window_id() == i:
			continue
		target_screen_option.add_item("Window %s" % str(entry_id), entry_id)
		target_screen_option.set_item_metadata(entry_id, [i, true])
		entry_id += 1
	target_screen_option.select(clampi(target_window_idx, 0, target_screen_option.item_count - 1))


func update_preview(reset_region := false):
	if record_type != RecordType.REGION:
		return
	var preview = Recorder.get_base_region(target_window_idx, target_screen_option)
	if preview[0]:
		var mouse_pos: Vector2i = get_global_mouse_position()
		if reset_region:
			record_area = Rect2i(Vector2i.ZERO, preview[0].get_size())
		var region = Rect2i(record_area.position, record_area.size)
		var offset = (region.size / 2) - preview[1]
		region.position = (mouse_pos - offset).clamp(
			Vector2i.ZERO, preview[0].get_size() - region.size
		)
		if _old_preview_region != region:
			_old_preview_region = region
			var texture = ImageTexture.create_from_image(preview[0].get_region(region))
			rect_texture.texture = texture
			preview_aspect_ratio_container.ratio = float(record_area.size.x) / record_area.size.y
	else:
		repopulate_screen_options()


func _on_options_dialog_visibility_changed() -> void:
	if visible:
		ffmpeg_options.visible = Export.is_ffmpeg_installed()
		options_dialog.size.y = 0
		update_preview()
	else:
		if rect_texture:
			rect_texture.texture = null


func _on_start_delay_slider_value_changed(value: int) -> void:
	start_after_delay_seconds = value
	update_config()
	save_config()


func _update_follow_mouse_preview() -> void:
	if area_follows_mouse and options_dialog.visible:
		var mouse_pos := get_global_mouse_position()
		if _old_last_position.distance_to(mouse_pos) < 20:
			return
		_old_last_position = mouse_pos
		if follow_mouse_checkbox and rect_texture.is_visible_in_tree():
			var offset = record_area.size / 2
			var new_position = (Vector2i(get_global_mouse_position()) - offset).clamp(
				Vector2i.ZERO, get_window().size - record_area.size
			)
			if record_area.position != new_position:
				record_area.position = new_position
				update_preview()


func _on_capture_method_option_item_selected(index: int) -> void:
	capture_method = capture_method_option.get_item_id(index) as CaptureMethod
	update_config()
	save_config()


func _on_action_interval_value_changed(value: int) -> void:
	action_interval = value
	update_config()
	save_config()


func _on_mouse_distance_value_changed(value: int) -> void:
	mouse_displacement = value
	update_config()
	save_config()


func _on_seconds_interval_value_changed(value: float) -> void:
	seconds_interval = value
	update_config()
	save_config()


func _on_record_type_option_item_selected(index: int) -> void:
	record_type = record_type_option.get_item_id(index) as RecordType
	update_preview()
	update_config()
	save_config()


func _on_target_screen_item_selected(index: int) -> void:
	target_window_idx = index
	update_preview(true)
	update_config()
	save_config()


func _on_rect_positon_slider_value_changed(value: Vector2i) -> void:
	record_area.position = value
	update_preview()
	update_config()
	save_config()


func _on_full_region_button_pressed() -> void:
	record_area = Rect2i(Vector2i.ZERO, get_window().size)
	update_preview()
	update_config()
	save_config()


func _on_rect_size_slider_value_changed(value: Vector2i) -> void:
	record_area.size = value
	update_preview()
	update_config()
	save_config()


func _on_follow_mouse_toggled(toggled_on: bool) -> void:
	area_follows_mouse = toggled_on
	update_config()
	save_config()


func _on_scale_output_checkbox_toggled(toggled_on: bool) -> void:
	scaling_enabled = toggled_on
	update_config()
	save_config()


func _on_output_scale_value_changed(value: int) -> void:
	scale_percent = value
	update_config()
	save_config()


func _on_export_gif_checkbox_toggled(toggled_on: bool) -> void:
	should_export_gif = toggled_on
	update_config()
	save_config()


func _on_fps_value_value_changed(value: float) -> void:
	export_fps = value
	update_config()
	save_config()


func _on_ffmpeg_sconds_slider_value_changed(value: float) -> void:
	export_duretion = value
	update_config()
	save_config()


func _on_ffmpeg_export_by_option_item_selected(index: int) -> void:
	export_by = ffmpeg_export_by_option.get_item_id(index) as FFmpegExportBy
	update_config()
	save_config()


func _on_Choose_pressed() -> void:
	_path_dialog.popup_centered_clamped()
	_path_dialog.current_dir = chosen_dir


func _on_path_dialog_dir_selected(dir: String) -> void:
	chosen_dir = dir
	path_field.text = chosen_dir
	start_button.disabled = false


func _on_gif_start_frame_value_changed(value: int) -> void:
	_gif_start_frame = value


func _on_gif_end_frame_value_changed(value: int) -> void:
	_gif_end_frame = value
