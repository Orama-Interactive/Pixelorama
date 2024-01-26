extends Control

var opensprite_file_selected := false
var redone := false
var is_quitting_on_save := false
var changed_projects_on_quit: Array[Project]
var cursor_image := preload("res://assets/graphics/cursor.png")

@onready var ui := $MenuAndUI/UI/DockableContainer as DockableContainer
@onready var backup_confirmation: ConfirmationDialog = $Dialogs/BackupConfirmation
@onready var save_sprite_html5: ConfirmationDialog = $Dialogs/SaveSpriteHTML5
@onready var quit_dialog: ConfirmationDialog = $Dialogs/QuitDialog
@onready var quit_and_save_dialog: ConfirmationDialog = $Dialogs/QuitAndSaveDialog
@onready var left_cursor: Sprite2D = $LeftCursor
@onready var right_cursor: Sprite2D = $RightCursor


func _init() -> void:
	Global.shrink = _get_auto_display_scale()


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	_setup_application_window_size()

	Global.main_window.title = tr("untitled") + " - Pixelorama " + Global.current_version

	Global.current_project.layers.append(PixelLayer.new(Global.current_project))
	Global.current_project.frames.append(Global.current_project.new_empty_frame())
	Global.animation_timeline.project_changed()

	Import.import_brushes(Global.path_join_array(Global.data_directories, "Brushes"))
	Import.import_patterns(Global.path_join_array(Global.data_directories, "Patterns"))

	quit_and_save_dialog.add_button("Exit without saving", false, "ExitWithoutSaving")

	Global.open_sprites_dialog.current_dir = Global.config_cache.get_value(
		"data", "current_dir", OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	)
	Global.save_sprites_dialog.current_dir = Global.config_cache.get_value(
		"data", "current_dir", OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	)
	var include_blended := CheckBox.new()
	include_blended.name = "IncludeBlended"
	include_blended.text = "Include blended images"
	include_blended.tooltip_text = """
If enabled, the final blended images are also being stored in the pxo, for each frame.
This makes the pxo file larger and is useful for importing by third-party software
or CLI exporting. Loading pxo files in Pixelorama does not need this option to be enabled.
"""
	include_blended.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Global.save_sprites_dialog.get_vbox().add_child(include_blended)
	# FIXME: OS.get_system_dir does not grab the correct directory for Ubuntu Touch.
	# Additionally, AppArmor policies prevent the app from writing to the /home
	# directory. Until the proper AppArmor policies are determined to write to these
	# files accordingly, use the user data folder where cache.ini is stored.
	# Ubuntu Touch users can access these files in the File Manager at the directory
	# ~/.local/pixelorama.orama-interactive/godot/app_userdata/Pixelorama.
	if OS.has_feature("clickable"):
		Global.open_sprites_dialog.current_dir = OS.get_user_data_dir()
		Global.save_sprites_dialog.current_dir = OS.get_user_data_dir()
	_handle_backup()

	_handle_cmdline_arguments()
	get_tree().root.files_dropped.connect(_on_files_dropped)

	if OS.get_name() == "Android":
		OS.request_permissions()

	_show_splash_screen()
	Global.pixelorama_opened.emit()


func _input(event: InputEvent) -> void:
	left_cursor.position = get_global_mouse_position() + Vector2(-32, 32)
	right_cursor.position = get_global_mouse_position() + Vector2(32, 32)

	if event is InputEventKey and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		if get_viewport().gui_get_focus_owner() is LineEdit:
			get_viewport().gui_get_focus_owner().release_focus()


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


func _setup_application_window_size() -> void:
	var root := get_tree().root
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.min_size = Vector2(1024, 576)
	root.content_scale_factor = Global.shrink
	set_custom_cursor()

	if OS.get_name() == "Web":
		return
	# Set a minimum window size to prevent UI elements from collapsing on each other.
	get_window().min_size = Vector2(1024, 576)

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
		await get_tree().process_frame

		$Dialogs/SplashDialog.popup_centered()  # Splash screen
		modulate = Color(0.5, 0.5, 0.5)


func _handle_backup() -> void:
	# If backup file exists, Pixelorama was not closed properly (probably crashed) - reopen backup
	backup_confirmation.add_button("Discard All", false, "discard")
	if Global.config_cache.has_section("backups"):
		var project_paths = Global.config_cache.get_section_keys("backups")
		if project_paths.size() > 0:
			# Get backup paths
			var backup_paths := []
			for p_path in project_paths:
				backup_paths.append(Global.config_cache.get_value("backups", p_path))
			# Temporatily stop autosave until user confirms backup
			OpenSave.autosave_timer.stop()
			backup_confirmation.confirmed.connect(
				_on_BackupConfirmation_confirmed.bind(project_paths, backup_paths)
			)
			backup_confirmation.custom_action.connect(
				_on_BackupConfirmation_custom_action.bind(project_paths, backup_paths)
			)
			backup_confirmation.popup_centered()
			modulate = Color(0.5, 0.5, 0.5)
		else:
			if Global.open_last_project:
				load_last_project()
	else:
		if Global.open_last_project:
			load_last_project()


func _handle_cmdline_arguments() -> void:
	var args := OS.get_cmdline_args()
	if args.is_empty():
		return

	for arg in args:
		if arg.begins_with("-") or arg.begins_with("--"):
			# TODO: Add code to handle custom command line arguments
			continue
		else:
			OpenSave.handle_loading_file(arg)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			show_quit_dialog()
		# If the mouse exits the window and another application has the focus,
		# pause the application
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if Global.pause_when_unfocused:
				get_tree().paused = true
		NOTIFICATION_WM_MOUSE_EXIT:
			if !get_window().has_focus() and Global.pause_when_unfocused:
				get_tree().paused = true
		# Unpause it when the mouse enters the window or when it gains focus
		NOTIFICATION_WM_MOUSE_ENTER:
			get_tree().paused = false
		NOTIFICATION_APPLICATION_FOCUS_IN:
			get_tree().paused = false


func _on_files_dropped(files: PackedStringArray) -> void:
	for file in files:
		OpenSave.handle_loading_file(file)
	var splash_dialog = Global.control.get_node("Dialogs/SplashDialog")
	if splash_dialog.visible:
		splash_dialog.hide()


func load_last_project() -> void:
	if OS.get_name() == "Web":
		return
	# Check if any project was saved or opened last time
	if Global.config_cache.has_section_key("preferences", "last_project_path"):
		# Check if file still exists on disk
		var file_path = Global.config_cache.get_value("preferences", "last_project_path")
		if FileAccess.file_exists(file_path):  # If yes then load the file
			OpenSave.open_pxo_file(file_path)
			# Sync file dialogs
			Global.save_sprites_dialog.current_dir = file_path.get_base_dir()
			Global.open_sprites_dialog.current_dir = file_path.get_base_dir()
			Global.config_cache.set_value("data", "current_dir", file_path.get_base_dir())
		else:
			# If file doesn't exist on disk then warn user about this
			Global.popup_error("Cannot find last project file.")


func load_recent_project_file(path: String) -> void:
	if OS.get_name() == "Web":
		return

	# Check if file still exists on disk
	if FileAccess.file_exists(path):  # If yes then load the file
		OpenSave.handle_loading_file(path)
		# Sync file dialogs
		Global.save_sprites_dialog.current_dir = path.get_base_dir()
		Global.open_sprites_dialog.current_dir = path.get_base_dir()
		Global.config_cache.set_value("data", "current_dir", path.get_base_dir())
	else:
		# If file doesn't exist on disk then warn user about this
		Global.popup_error("Cannot find project file.")


func _on_OpenSprite_files_selected(paths: PackedStringArray) -> void:
	for path in paths:
		OpenSave.handle_loading_file(path)
	Global.save_sprites_dialog.current_dir = paths[0].get_base_dir()
	Global.config_cache.set_value("data", "current_dir", paths[0].get_base_dir())


func show_save_dialog(project := Global.current_project) -> void:
	Global.dialog_open(true)
	if OS.get_name() == "Web":
		var save_filename := save_sprite_html5.get_node("%FileNameLineEdit")
		save_sprite_html5.popup_centered()
		save_filename.text = project.name
	else:
		Global.save_sprites_dialog.popup_centered()
		Global.save_sprites_dialog.get_line_edit().text = project.name


func _on_SaveSprite_file_selected(path: String) -> void:
	save_project(path)


func save_project(path: String) -> void:
	var project_to_save := Global.current_project
	if is_quitting_on_save:
		project_to_save = changed_projects_on_quit[0]
	var include_blended := false
	if OS.get_name() == "Web":
		var file_name: String = save_sprite_html5.get_node("%FileNameLineEdit").text
		file_name += ".pxo"
		path = "user://".path_join(file_name)
		include_blended = save_sprite_html5.get_node("%IncludeBlended").button_pressed
	else:
		include_blended = (
			Global.save_sprites_dialog.get_vbox().get_node("IncludeBlended").button_pressed
		)
	var success := OpenSave.save_pxo_file(path, false, include_blended, project_to_save)
	if success:
		Global.open_sprites_dialog.current_dir = path.get_base_dir()
		Global.config_cache.set_value("data", "current_dir", path.get_base_dir())
	if is_quitting_on_save:
		changed_projects_on_quit.pop_front()
		_save_on_quit_confirmation()
		is_quitting_on_save = false


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


func _on_BackupConfirmation_confirmed(project_paths: Array, backup_paths: Array) -> void:
	OpenSave.reload_backup_file(project_paths, backup_paths)
	Global.current_project.file_name = OpenSave.current_save_paths[0].get_file().trim_suffix(".pxo")
	Global.current_project.directory_path = OpenSave.current_save_paths[0].get_base_dir()
	Global.current_project.was_exported = false
	Global.top_menu_container.file_menu.set_item_text(
		Global.FileMenu.SAVE, tr("Save") + " %s" % OpenSave.current_save_paths[0].get_file()
	)
	Global.top_menu_container.file_menu.set_item_text(Global.FileMenu.EXPORT, tr("Export"))


func _on_BackupConfirmation_custom_action(
	action: String, project_paths: Array, backup_paths: Array
) -> void:
	backup_confirmation.hide()
	if action != "discard":
		return
	for i in range(project_paths.size()):
		OpenSave.remove_backup_by_path(project_paths[i], backup_paths[i])
	# Reopen last project
	if Global.open_last_project:
		load_last_project()


func _on_backup_confirmation_visibility_changed() -> void:
	if backup_confirmation.visible:
		return
	if Global.enable_autosave:
		OpenSave.autosave_timer.start()
	Global.dialog_open(false)


func _exit_tree() -> void:
	Global.config_cache.set_value("window", "layout", Global.top_menu_container.selected_layout)
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
	Global.config_cache.set_value("view_menu", "show_rulers", Global.show_rulers)
	Global.config_cache.set_value("view_menu", "show_guides", Global.show_guides)
	Global.config_cache.set_value("view_menu", "show_mouse_guides", Global.show_mouse_guides)
	Global.config_cache.save("user://cache.ini")

	var i := 0
	for project in Global.projects:
		project.remove()
		OpenSave.remove_backup(i)
		i += 1
