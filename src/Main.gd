extends Control

const SPLASH_DIALOG_SCENE_PATH := "res://src/UI/Dialogs/SplashDialog.tscn"

var opensprite_file_selected := false
var redone := false
var is_quitting_on_save := false
var is_writing_text := false
var changed_projects_on_quit: Array[Project]
var cursor_image := preload("res://assets/graphics/cursor.png")
## Used to download an image when dragged and dropped directly from a browser into Pixelorama
var url_to_download := ""
var splash_dialog: AcceptDialog:
	get:
		if not is_instance_valid(splash_dialog):
			splash_dialog = load(SPLASH_DIALOG_SCENE_PATH).instantiate()
			add_child(splash_dialog)
		return splash_dialog

@onready var main_ui := $MenuAndUI/UI/DockableContainer as DockableContainer
@onready var backup_confirmation: ConfirmationDialog = $Dialogs/BackupConfirmation
## Dialog used to open images and project (.pxo) files.
@onready var open_sprite_dialog := $Dialogs/OpenSprite as FileDialog
## Dialog used to save project (.pxo) files.
@onready var save_sprite_dialog := $Dialogs/SaveSprite as FileDialog
@onready var save_sprite_html5: ConfirmationDialog = $Dialogs/SaveSpriteHTML5
@onready var tile_mode_offsets_dialog: ConfirmationDialog = $Dialogs/TileModeOffsetsDialog
@onready var quit_dialog: ConfirmationDialog = $Dialogs/QuitDialog
@onready var quit_and_save_dialog: ConfirmationDialog = $Dialogs/QuitAndSaveDialog
@onready var download_confirmation := $Dialogs/DownloadImageConfirmationDialog as ConfirmationDialog
@onready var left_cursor: Sprite2D = $LeftCursor
@onready var right_cursor: Sprite2D = $RightCursor
@onready var image_request := $ImageRequest as HTTPRequest


class CLI:
	static var args_list := {
		["--version", "--pixelorama-version"]:
		[CLI.print_version, "Prints current Pixelorama version"],
		["--size"]: [CLI.print_project_size, "Prints size of the given project"],
		["--framecount"]: [CLI.print_frame_count, "Prints total frames in the current project"],
		["--export", "-e"]: [CLI.enable_export, "Indicates given project should be exported"],
		["--spritesheet", "-s"]:
		[CLI.enable_spritesheet, "Indicates given project should be exported as spritesheet"],
		["--output", "-o"]: [CLI.set_output, "[path] Name of output file (with extension)"],
		["--scale"]: [CLI.set_export_scale, "[integer] Scales up the export image by a number"],
		["--frames", "-f"]: [CLI.set_frames, "[integer-integer] Used to specify frame range"],
		["--direction", "-d"]: [CLI.set_direction, "[0, 1, 2] Specifies direction"],
		["--json"]: [CLI.set_json, "Export the JSON data of the project"],
		["--split-layers"]: [CLI.set_split_layers, "Each layer exports separately"],
		["--help", "-h", "-?"]: [CLI.generate_help, "Displays this help page"]
	}

	static func generate_help(_project: Project, _next_arg: String):
		var help := str(
			(
				"""
 =========================================================================\n
Help for Pixelorama's CLI.

Usage:
\t%s [SYSTEM OPTIONS] -- [USER OPTIONS] [FILES]...

Use -h in place of [SYSTEM OPTIONS] to see [SYSTEM OPTIONS].
Or use -h in place of [USER OPTIONS] to see [USER OPTIONS].

some useful [SYSTEM OPTIONS] are:
--headless     Run in headless mode.
--quit         Close pixelorama after current command.


[USER OPTIONS]:\n
(The terms in [ ] reflect the valid type for corresponding argument).

"""
				% OS.get_executable_path().get_file()
			)
		)
		for command_group: Array in args_list.keys():
			help += str(
				var_to_str(command_group).replace("[", "").replace("]", "").replace('"', ""),
				"\t\t".c_unescape(),
				args_list[command_group][1],
				"\n".c_unescape()
			)
		help += "========================================================================="
		print(help)

	## Dedicated place for command line args callables
	static func print_version(_project: Project, _next_arg: String) -> void:
		print(Global.current_version)

	static func print_project_size(project: Project, _next_arg: String) -> void:
		print(project.size)

	static func print_frame_count(project: Project, _next_arg: String) -> void:
		print(project.frames.size())

	static func enable_export(_project: Project, _next_arg: String):
		return true

	static func enable_spritesheet(_project: Project, _next_arg: String):
		Export.current_tab = Export.ExportTab.SPRITESHEET
		return true

	static func set_output(project: Project, next_arg: String) -> void:
		if not next_arg.is_empty():
			project.file_name = next_arg.get_file().get_basename()
			var directory_path = next_arg.get_base_dir()
			if directory_path != ".":
				project.export_directory_path = directory_path
			var extension := next_arg.get_extension()
			project.file_format = Export.get_file_format_from_extension(extension)

	static func set_export_scale(_project: Project, next_arg: String) -> void:
		if not next_arg.is_empty():
			if next_arg.is_valid_float():
				Export.resize = next_arg.to_float() * 100

	static func set_frames(project: Project, next_arg: String) -> void:
		if not next_arg.is_empty():
			if next_arg.contains("-"):
				var frame_numbers := next_arg.split("-")
				if frame_numbers.size() > 1:
					project.selected_cels.clear()
					var frame_number_1 := 0
					if frame_numbers[0].is_valid_int():
						frame_number_1 = frame_numbers[0].to_int() - 1
					frame_number_1 = clampi(frame_number_1, 0, project.frames.size() - 1)
					var frame_number_2 := project.frames.size() - 1
					if frame_numbers[1].is_valid_int():
						frame_number_2 = frame_numbers[1].to_int() - 1
					frame_number_2 = clampi(frame_number_2, 0, project.frames.size() - 1)
					for frame in range(frame_number_1, frame_number_2 + 1):
						project.selected_cels.append([frame, project.current_layer])
						project.change_cel(frame)
						Export.frame_current_tag = Export.ExportFrames.SELECTED_FRAMES
			elif next_arg.is_valid_int():
				var frame_number := next_arg.to_int() - 1
				frame_number = clampi(frame_number, 0, project.frames.size() - 1)
				project.selected_cels = [[frame_number, project.current_layer]]
				project.change_cel(frame_number)
				Export.frame_current_tag = Export.ExportFrames.SELECTED_FRAMES

	static func set_direction(_project: Project, next_arg: String) -> void:
		if not next_arg.is_empty():
			next_arg = next_arg.to_lower()
			if next_arg == "0" or next_arg.contains("forward"):
				Export.direction = Export.AnimationDirection.FORWARD
			elif next_arg == "1" or next_arg.contains("backward"):
				Export.direction = Export.AnimationDirection.BACKWARDS
			elif next_arg == "2" or next_arg.contains("ping"):
				Export.direction = Export.AnimationDirection.PING_PONG
			else:
				print(Export.AnimationDirection.keys()[Export.direction])
		else:
			print(Export.AnimationDirection.keys()[Export.direction])

	static func set_json(_project: Project, _next_arg: String) -> void:
		Export.export_json = true

	static func set_split_layers(_project: Project, _next_arg: String) -> void:
		Export.split_layers = true


func _init() -> void:
	Global.project_switched.connect(_project_switched)
	if not DirAccess.dir_exists_absolute("user://backups"):
		DirAccess.make_dir_recursive_absolute("user://backups")
	Global.shrink = _get_auto_display_scale()
	_handle_layout_files()


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)

	get_window().title = tr("untitled") + " - Pixelorama " + Global.current_version

	Global.current_project.layers.append(PixelLayer.new(Global.current_project))
	Global.current_project.frames.append(Global.current_project.new_empty_frame())
	Global.animation_timeline.project_changed()

	Import.import_brushes(Global.path_join_array(Global.data_directories, "Brushes"))
	Import.import_patterns(Global.path_join_array(Global.data_directories, "Patterns"))

	quit_and_save_dialog.add_button("Exit without saving", false, "ExitWithoutSaving")
	_handle_cmdline_arguments()
	get_tree().root.files_dropped.connect(_on_files_dropped)
	if OS.get_name() == "Android":
		OS.request_permissions()
	_handle_backup()
	await get_tree().process_frame
	_setup_application_window_size()
	_show_splash_screen()
	Global.pixelorama_opened.emit()


func _input(event: InputEvent) -> void:
	if is_writing_text and event is InputEventKey and is_instance_valid(Global.main_viewport):
		Global.main_viewport.get_child(0).push_input(event)
	left_cursor.position = get_global_mouse_position() + Vector2(-32, 32)
	right_cursor.position = get_global_mouse_position() + Vector2(32, 32)

	if event is InputEventKey and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		if get_viewport().gui_get_focus_owner() is LineEdit:
			get_viewport().gui_get_focus_owner().release_focus()


func _project_switched() -> void:
	if Global.current_project.export_directory_path != "":
		open_sprite_dialog.current_dir = Global.current_project.export_directory_path
		save_sprite_dialog.current_dir = Global.current_project.export_directory_path


# Taken from https://github.com/godotengine/godot/blob/3.x/editor/editor_settings.cpp#L1474
func _get_auto_display_scale() -> float:
	if OS.get_name() == "macOS":
		return DisplayServer.screen_get_max_scale()

	var dpi := DisplayServer.screen_get_dpi()
	var smallest_dimension := mini(
		DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y
	)
	if dpi >= 192 && smallest_dimension >= 1400:
		return 2.0  # hiDPI display.
	elif smallest_dimension >= 1700:
		return 1.5  # Likely a hiDPI display, but we aren't certain due to the returned DPI.
	return 1.0


func _handle_layout_files() -> void:
	if not DirAccess.dir_exists_absolute(Global.LAYOUT_DIR):
		DirAccess.make_dir_absolute(Global.LAYOUT_DIR)
	var dir := DirAccess.open(Global.LAYOUT_DIR)
	var files := dir.get_files()
	if files.size() == 0:
		for layout in Global.default_layouts:
			var file_name := layout.resource_path.get_basename().get_file() + ".tres"
			var new_layout := layout.clone()
			new_layout.layout_reset_path = layout.resource_path
			ResourceSaver.save(new_layout, Global.LAYOUT_DIR.path_join(file_name))
		files = dir.get_files()
	for file in files:
		var layout := ResourceLoader.load(Global.LAYOUT_DIR.path_join(file))
		if layout is DockableLayout:
			if layout.layout_reset_path.is_empty():
				if file == "Default.tres":
					layout.layout_reset_path = Global.default_layouts[0].resource_path
				elif file == "Tallscreen.tres":
					layout.layout_reset_path = Global.default_layouts[1].resource_path
			Global.layouts.append(layout)
			# Save the layout every time it changes
			layout.save_on_change = true


func _setup_application_window_size() -> void:
	if DisplayServer.get_name() == "headless":
		return
	set_display_scale()
	if Global.font_size != theme.default_font_size:
		theme.default_font_size = Global.font_size
		theme.set_font_size("font_size", "HeaderSmall", Global.font_size + 2)

	if OS.get_name() == "Web":
		return
	# Restore the window position/size if values are present in the configuration cache
	if Global.config_cache.has_section_key("window", "screen"):
		get_window().current_screen = Global.config_cache.get_value("window", "screen")
	if Global.config_cache.has_section_key("window", "maximized"):
		get_window().mode = (
			Window.MODE_MAXIMIZED
			if (Global.config_cache.get_value("window", "maximized"))
			else Window.MODE_WINDOWED
		)

	if !(get_window().mode == Window.MODE_MAXIMIZED):
		if Global.config_cache.has_section_key("window", "position"):
			get_window().position = Global.config_cache.get_value("window", "position")
		if Global.config_cache.has_section_key("window", "size"):
			get_window().size = Global.config_cache.get_value("window", "size")


func set_display_scale() -> void:
	var root := get_window()
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	# Set a minimum window size to prevent UI elements from collapsing on each other.
	root.min_size = Vector2(1024, 576)
	root.content_scale_factor = Global.shrink
	set_custom_cursor()


func set_custom_cursor() -> void:
	if Global.native_cursors:
		return
	if Global.shrink == 1.0:
		Input.set_custom_mouse_cursor(cursor_image, Input.CURSOR_CROSS, Vector2(15, 15))
	else:
		var cursor_data := cursor_image.get_image()
		var cursor_size := cursor_data.get_size() * Global.shrink
		cursor_data.resize(cursor_size.x, cursor_size.y, Image.INTERPOLATE_NEAREST)
		var cursor_tex := ImageTexture.create_from_image(cursor_data)
		Input.set_custom_mouse_cursor(
			cursor_tex, Input.CURSOR_CROSS, Vector2(15, 15) * Global.shrink
		)


func _show_splash_screen() -> void:
	if not Global.config_cache.has_section_key("preferences", "startup"):
		Global.config_cache.set_value("preferences", "startup", true)

	if Global.config_cache.get_value("preferences", "startup"):
		# Wait for the window to adjust itself, so the popup is correctly centered
		await get_tree().process_frame

		splash_dialog.popup_centered()  # Splash screen
		modulate = Color(0.5, 0.5, 0.5)


func _handle_backup() -> void:
	# If backup file exists, Pixelorama was not closed properly (probably crashed) - reopen backup
	backup_confirmation.add_button("Discard All", false, "discard")
	var backup_dir := DirAccess.open("user://backups")
	if backup_dir.get_files().size() > 0:
		# Temporatily stop autosave until user confirms backup
		OpenSave.autosave_timer.stop()
		backup_confirmation.confirmed.connect(_on_BackupConfirmation_confirmed)
		backup_confirmation.custom_action.connect(_on_BackupConfirmation_custom_action)
		backup_confirmation.popup_centered()
		modulate = Color(0.5, 0.5, 0.5)
	else:
		if Global.open_last_project:
			load_last_project()


func _handle_cmdline_arguments() -> void:
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	if args.is_empty():
		return
	# Load the files first
	for arg in args:
		var file_path := arg
		if file_path.is_relative_path():
			file_path = OS.get_executable_path().get_base_dir().path_join(arg)
		OpenSave.handle_loading_file(file_path)

	var project := Global.current_project
	# True when exporting from the CLI.
	# Exporting should be done last, this variable helps with that
	var should_export := false

	var parse_dic := {}
	for command_group: Array in CLI.args_list.keys():
		for command: String in command_group:
			parse_dic[command] = CLI.args_list[command_group][0]
	for i in args.size():  # Handle the rest of the CLI arguments
		var arg := args[i]
		var next_argument := ""
		if i + 1 < args.size():
			next_argument = args[i + 1]
		if arg.begins_with("-") or arg.begins_with("--"):
			if arg in parse_dic.keys():
				var callable: Callable = parse_dic[arg]
				var output = callable.call(project, next_argument)
				if typeof(output) == TYPE_BOOL:
					should_export = output
			else:
				print("==========")
				print("Unknown option: %s" % arg)
				for compare_arg in parse_dic.keys():
					if arg.similarity(compare_arg) >= 0.4:
						print("Similar option: %s" % compare_arg)
				print("==========")
				should_export = false
				get_tree().quit()
				break
	if should_export:
		Export.external_export(project)


func _notification(what: int) -> void:
	if not is_inside_tree():
		return
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			show_quit_dialog()
		# If the mouse exits the window and another application has the focus,
		# pause the application
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if Global.pause_when_unfocused:
				get_tree().paused = true
		NOTIFICATION_WM_MOUSE_EXIT:
			# Do not pause the application if the mouse leaves the main window
			# but there are child subwindows opened, because that makes them unresponsive.
			var window_count := DisplayServer.get_window_list().size()
			if not get_window().has_focus() and window_count == 1 and Global.pause_when_unfocused:
				get_tree().paused = true
		# Unpause it when the mouse enters the window or when it gains focus
		NOTIFICATION_WM_MOUSE_ENTER:
			get_tree().paused = false
		NOTIFICATION_APPLICATION_FOCUS_IN:
			get_tree().paused = false


func _on_files_dropped(files: PackedStringArray) -> void:
	for file in files:
		if not FileAccess.file_exists(file):
			# If the file doesn't exist, it could be a URL. This can occur when dragging
			# and dropping an image directly from the browser into Pixelorama.
			# For security reasons, ask the user if they want to confirm the image download.
			download_confirmation.dialog_text = (
				tr("Do you want to download the image from %s?") % file
			)
			download_confirmation.popup_centered()
			url_to_download = file
		OpenSave.handle_loading_file(file)
	if splash_dialog.visible:
		splash_dialog.hide()


func load_last_project() -> void:
	if OS.get_name() == "Web":
		return
	# Check if any project was saved or opened last time
	if Global.config_cache.has_section_key("data", "last_project_path"):
		# Check if file still exists on disk
		var file_path = Global.config_cache.get_value("data", "last_project_path")
		load_recent_project_file(file_path)
		(func(): Global.cel_switched.emit()).call_deferred()


func load_recent_project_file(path: String) -> void:
	if OS.get_name() == "Web":
		return
	# Check if file still exists on disk
	if FileAccess.file_exists(path):  # If yes then load the file
		OpenSave.handle_loading_file(path)
	else:
		# If file doesn't exist on disk then warn user about this
		Global.popup_error("Cannot find project file.")


func _on_OpenSprite_files_selected(paths: PackedStringArray) -> void:
	for path in paths:
		OpenSave.handle_loading_file(path)
	save_sprite_dialog.current_dir = paths[0].get_base_dir()


func show_save_dialog(project := Global.current_project) -> void:
	Global.dialog_open(true, true)
	if OS.get_name() == "Web":
		var save_filename := save_sprite_html5.get_node("%FileNameLineEdit")
		save_sprite_html5.popup_centered()
		save_filename.text = project.name
	else:
		save_sprite_dialog.popup_centered()
		save_sprite_dialog.get_line_edit().text = project.name


func _on_SaveSprite_file_selected(path: String) -> void:
	save_project(path)


func _on_save_sprite_visibility_changed() -> void:
	if not save_sprite_dialog.visible:
		is_quitting_on_save = false


func save_project(path: String) -> void:
	var project_to_save := Global.current_project
	if is_quitting_on_save:
		project_to_save = changed_projects_on_quit[0]
	var include_blended := false
	if OS.get_name() == "Web":
		var file_name := project_to_save.name + ".pxo"
		path = "user://".path_join(file_name)
		include_blended = save_sprite_html5.get_node("%IncludeBlended").button_pressed
	else:
		if save_sprite_dialog.get_selected_options().size() > 0:
			include_blended = save_sprite_dialog.get_selected_options()[
				save_sprite_dialog.get_option_name(0)
			]
	var success := OpenSave.save_pxo_file(path, false, include_blended, project_to_save)
	if success:
		open_sprite_dialog.current_dir = path.get_base_dir()
	if is_quitting_on_save:
		changed_projects_on_quit.pop_front()
		_save_on_quit_confirmation()


func _on_open_sprite_visibility_changed() -> void:
	if !opensprite_file_selected:
		_can_draw_true()


func _can_draw_true() -> void:
	Global.dialog_open(false)


func show_quit_dialog() -> void:
	changed_projects_on_quit = []
	for project in Global.projects:
		if project.has_changed:
			changed_projects_on_quit.append(project)

	if not quit_dialog.visible:
		if changed_projects_on_quit.size() == 0:
			if Global.quit_confirmation:
				quit_dialog.popup_centered()
			else:
				_quit()
		else:
			quit_and_save_dialog.dialog_text = (
				tr("Project %s has unsaved progress. How do you wish to proceed?")
				% changed_projects_on_quit[0].name
			)
			quit_and_save_dialog.popup_centered()

	Global.dialog_open(true)


func _save_on_quit_confirmation() -> void:
	if changed_projects_on_quit.size() == 0:
		_quit()
	else:
		quit_and_save_dialog.dialog_text = (
			tr("Project %s has unsaved progress. How do you wish to proceed?")
			% changed_projects_on_quit[0].name
		)
		quit_and_save_dialog.popup_centered()
		Global.dialog_open(true)


func _on_QuitDialog_confirmed() -> void:
	_quit()


func _on_QuitAndSaveDialog_custom_action(action: String) -> void:
	if action == "ExitWithoutSaving":
		changed_projects_on_quit.pop_front()
		_save_on_quit_confirmation()


func _on_QuitAndSaveDialog_confirmed() -> void:
	is_quitting_on_save = true
	show_save_dialog(changed_projects_on_quit[0])


func _quit() -> void:
	Global.pixelorama_about_to_close.emit()
	# Darken the UI to denote that the application is currently exiting
	# (it won't respond to user input in this state).
	modulate = Color(0.5, 0.5, 0.5)
	get_tree().quit()


func _on_BackupConfirmation_confirmed() -> void:
	OpenSave.reload_backup_file()


func _on_BackupConfirmation_custom_action(action: String) -> void:
	backup_confirmation.hide()
	if action != "discard":
		return
	_clear_backup_files()
	# Reopen last project
	if Global.open_last_project:
		load_last_project()


func _on_backup_confirmation_visibility_changed() -> void:
	if backup_confirmation.visible:
		return
	if Global.enable_autosave:
		OpenSave.autosave_timer.start()
	Global.dialog_open(false)


func _clear_backup_files() -> void:
	for file in DirAccess.get_files_at("user://backups"):
		DirAccess.remove_absolute("user://backups".path_join(file))


func _exit_tree() -> void:
	for project in Global.projects:
		project.remove()
	# For some reason, the above is not enough to remove all backup files
	_clear_backup_files()
	if DisplayServer.get_name() == "headless":
		return
	Global.config_cache.set_value("window", "layout", Global.layouts.find(main_ui.layout))
	Global.config_cache.set_value("window", "screen", get_window().current_screen)
	Global.config_cache.set_value(
		"window",
		"maximized",
		(
			(get_window().mode == Window.MODE_MAXIMIZED)
			|| (
				(get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN)
				or (get_window().mode == Window.MODE_FULLSCREEN)
			)
		)
	)
	Global.config_cache.set_value("window", "position", get_window().position)
	Global.config_cache.set_value("window", "size", get_window().size)
	Global.config_cache.set_value("view_menu", "draw_grid", Global.draw_grid)
	Global.config_cache.set_value("view_menu", "draw_pixel_grid", Global.draw_pixel_grid)
	Global.config_cache.set_value("view_menu", "show_pixel_indices", Global.show_pixel_indices)
	Global.config_cache.set_value("view_menu", "show_rulers", Global.show_rulers)
	Global.config_cache.set_value("view_menu", "show_guides", Global.show_guides)
	Global.config_cache.set_value("view_menu", "show_mouse_guides", Global.show_mouse_guides)
	Global.config_cache.set_value(
		"view_menu", "display_layer_effects", Global.display_layer_effects
	)
	Global.config_cache.set_value(
		"view_menu", "snap_to_rectangular_grid_boundary", Global.snap_to_rectangular_grid_boundary
	)
	Global.config_cache.set_value(
		"view_menu", "snap_to_rectangular_grid_center", Global.snap_to_rectangular_grid_center
	)
	Global.config_cache.set_value("view_menu", "snap_to_guides", Global.snap_to_guides)
	Global.config_cache.set_value(
		"view_menu", "snap_to_perspective_guides", Global.snap_to_perspective_guides
	)
	Global.config_cache.save(Global.CONFIG_PATH)


func _on_download_image_confirmation_dialog_confirmed() -> void:
	image_request.request(url_to_download)


func _on_image_request_request_completed(
	_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	var image := OpenSave.load_image_from_buffer(body)
	if image.is_empty():
		return
	OpenSave.handle_loading_image(OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP), image)
