extends Control

var opensprite_file_selected := false
var redone := false
var is_quitting_on_save := false
var cursor_image: Texture = preload("res://assets/graphics/cursor.png")

onready var ui := $MenuAndUI/UI/DockableContainer
onready var backup_confirmation: ConfirmationDialog = $Dialogs/BackupConfirmation
onready var quit_dialog: ConfirmationDialog = $Dialogs/QuitDialog
onready var quit_and_save_dialog: ConfirmationDialog = $Dialogs/QuitAndSaveDialog
onready var left_cursor: Sprite = $LeftCursor
onready var right_cursor: Sprite = $RightCursor


func _init() -> void:
	Global.shrink = _get_auto_display_scale()
	if OS.get_name() == "OSX":
		_use_osx_shortcuts()


func _ready() -> void:
	randomize()
	get_tree().set_auto_accept_quit(false)
	_setup_application_window_size()

	Global.window_title = tr("untitled") + " - Pixelorama " + Global.current_version

	Global.current_project.layers.append(PixelLayer.new(Global.current_project))
	Global.current_project.frames.append(Global.current_project.new_empty_frame())
	Global.animation_timeline.project_changed()
	Global.current_project.toggle_frame_buttons()

	Import.import_brushes(Global.directory_module.get_brushes_search_path_in_order())
	Import.import_patterns(Global.directory_module.get_patterns_search_path_in_order())

	quit_and_save_dialog.add_button("Exit without saving", false, "ExitWithoutSaving")
	quit_and_save_dialog.get_ok().text = "Save & Exit"

	Global.open_sprites_dialog.current_dir = Global.config_cache.get_value(
		"data", "current_dir", OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	)
	Global.save_sprites_dialog.current_dir = Global.config_cache.get_value(
		"data", "current_dir", OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	)

	# FIXME: OS.get_system_dir does not grab the correct directory for Ubuntu Touch.
	# Additionally, AppArmor policies prevent the app from writing to the /home
	# directory. Until the proper AppArmor policies are determined to write to these
	# files accordingly, use the user data folder where cache.ini is stored.
	# Ubuntu Touch users can access these files in the File Manager at the directory
	# ~/.local/pixelorama.orama-interactive/godot/app_userdata/Pixelorama.
	if OS.has_feature("clickable"):
		Global.open_sprites_dialog.current_dir = OS.get_user_data_dir()
		Global.save_sprites_dialog.current_dir = OS.get_user_data_dir()

	var i := 0
	for camera in Global.cameras:
		camera.index = i
		i += 1

	var zstd_checkbox := CheckBox.new()
	zstd_checkbox.name = "ZSTDCompression"
	zstd_checkbox.pressed = true
	zstd_checkbox.text = "Use ZSTD Compression"
	zstd_checkbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Global.save_sprites_dialog.get_vbox().add_child(zstd_checkbox)

	_handle_backup()

	_handle_cmdline_arguments()
	get_tree().connect("files_dropped", self, "_on_files_dropped")

	if OS.get_name() == "Android":
		OS.request_permissions()

	_show_splash_screen()


func _input(event: InputEvent) -> void:
	left_cursor.position = get_global_mouse_position() + Vector2(-32, 32)
	right_cursor.position = get_global_mouse_position() + Vector2(32, 32)

	if event is InputEventKey and (event.scancode == KEY_ENTER or event.scancode == KEY_KP_ENTER):
		if get_focus_owner() is LineEdit:
			get_focus_owner().release_focus()


# Taken from https://github.com/godotengine/godot/blob/3.x/editor/editor_settings.cpp#L1474
func _get_auto_display_scale() -> float:
	if OS.get_name() == "OSX":
		return OS.get_screen_max_scale()

	var dpi := OS.get_screen_dpi()
	var smallest_dimension: int = min(OS.get_screen_size().x, OS.get_screen_size().y)
	if dpi >= 192 && smallest_dimension >= 1400:
		return 2.0  # hiDPI display.
	elif smallest_dimension >= 1700:
		return 1.5  # Likely a hiDPI display, but we aren't certain due to the returned DPI.
	return 1.0


func _setup_application_window_size() -> void:
	get_tree().set_screen_stretch(
		SceneTree.STRETCH_MODE_DISABLED,
		SceneTree.STRETCH_ASPECT_IGNORE,
		Vector2(1024, 576),
		Global.shrink
	)
	set_custom_cursor()

	if OS.get_name() == "HTML5":
		return
	# Set a minimum window size to prevent UI elements from collapsing on each other.
	OS.min_window_size = Vector2(1024, 576)

	# Restore the window position/size if values are present in the configuration cache
	if Global.config_cache.has_section_key("window", "screen"):
		OS.current_screen = Global.config_cache.get_value("window", "screen")
	if Global.config_cache.has_section_key("window", "maximized"):
		OS.window_maximized = Global.config_cache.get_value("window", "maximized")

	if !OS.window_maximized:
		if Global.config_cache.has_section_key("window", "position"):
			OS.window_position = Global.config_cache.get_value("window", "position")
		if Global.config_cache.has_section_key("window", "size"):
			OS.window_size = Global.config_cache.get_value("window", "size")


func set_custom_cursor() -> void:
	if Global.native_cursors:
		return

	if Global.shrink == 1.0:
		Input.set_custom_mouse_cursor(cursor_image, Input.CURSOR_CROSS, Vector2(15, 15))
	else:
		var cursor_data := cursor_image.get_data()
		cursor_data.resize(
			cursor_data.get_width() * Global.shrink, cursor_data.get_height() * Global.shrink, 0
		)
		var new_cursor_tex := ImageTexture.new()
		new_cursor_tex.create_from_image(cursor_data, 0)
		Input.set_custom_mouse_cursor(
			new_cursor_tex, Input.CURSOR_CROSS, Vector2(15, 15) * Global.shrink
		)


func _show_splash_screen() -> void:
	if not Global.config_cache.has_section_key("preferences", "startup"):
		Global.config_cache.set_value("preferences", "startup", true)

	if Global.config_cache.get_value("preferences", "startup"):
		# Wait for the window to adjust itself, so the popup is correctly centered
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")

		$Dialogs/SplashDialog.popup_centered()  # Splash screen
		modulate = Color(0.5, 0.5, 0.5)
	else:
		Global.can_draw = true


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
			backup_confirmation.connect(
				"confirmed", self, "_on_BackupConfirmation_confirmed", [project_paths, backup_paths]
			)
			backup_confirmation.connect(
				"custom_action",
				self,
				"_on_BackupConfirmation_custom_action",
				[project_paths, backup_paths]
			)
			backup_confirmation.popup_centered()
			Global.can_draw = false
			modulate = Color(0.5, 0.5, 0.5)
		else:
			if Global.open_last_project:
				load_last_project()
	else:
		if Global.open_last_project:
			load_last_project()


func _handle_cmdline_arguments() -> void:
	var args := OS.get_cmdline_args()
	if args.empty():
		return

	for arg in args:
		if arg.begins_with("-") or arg.begins_with("--"):
			# TODO: Add code to handle custom command line arguments
			continue
		else:
			OpenSave.handle_loading_file(arg)


func _notification(what: int) -> void:
	match what:
		MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
			show_quit_dialog()
		# If the mouse exits the window and another application has the focus,
		# pause the application
		MainLoop.NOTIFICATION_WM_FOCUS_OUT:
			Global.has_focus = false
			if Global.pause_when_unfocused:
				get_tree().paused = true
		MainLoop.NOTIFICATION_WM_MOUSE_EXIT:
			if !OS.is_window_focused() and Global.pause_when_unfocused:
				get_tree().paused = true
		# Unpause it when the mouse enters the window or when it gains focus
		MainLoop.NOTIFICATION_WM_MOUSE_ENTER:
			get_tree().paused = false
		MainLoop.NOTIFICATION_WM_FOCUS_IN:
			get_tree().paused = false
			var mouse_pos := get_global_mouse_position()
			var viewport_rect := Rect2(
				Global.main_viewport.rect_global_position, Global.main_viewport.rect_size
			)
			if viewport_rect.has_point(mouse_pos):
				Global.has_focus = true


func _on_files_dropped(files: PoolStringArray, _screen: int) -> void:
	for file in files:
		OpenSave.handle_loading_file(file)
	var splash_dialog = Global.control.get_node("Dialogs/SplashDialog")
	if splash_dialog.visible:
		splash_dialog.hide()


func load_last_project() -> void:
	if OS.get_name() == "HTML5":
		return
	# Check if any project was saved or opened last time
	if Global.config_cache.has_section_key("preferences", "last_project_path"):
		# Check if file still exists on disk
		var file_path = Global.config_cache.get_value("preferences", "last_project_path")
		var file_check := File.new()
		if file_check.file_exists(file_path):  # If yes then load the file
			OpenSave.open_pxo_file(file_path)
			# Sync file dialogs
			Global.save_sprites_dialog.current_dir = file_path.get_base_dir()
			Global.open_sprites_dialog.current_dir = file_path.get_base_dir()
			Global.config_cache.set_value("data", "current_dir", file_path.get_base_dir())
		else:
			# If file doesn't exist on disk then warn user about this
			Global.error_dialog.set_text("Cannot find last project file.")
			Global.error_dialog.popup_centered()
			Global.dialog_open(true)


func load_recent_project_file(path: String) -> void:
	if OS.get_name() == "HTML5":
		return

	# Check if file still exists on disk
	var file_check := File.new()
	if file_check.file_exists(path):  # If yes then load the file
		OpenSave.handle_loading_file(path)
		# Sync file dialogs
		Global.save_sprites_dialog.current_dir = path.get_base_dir()
		Global.open_sprites_dialog.current_dir = path.get_base_dir()
		Global.config_cache.set_value("data", "current_dir", path.get_base_dir())
	else:
		# If file doesn't exist on disk then warn user about this
		Global.error_dialog.set_text("Cannot find project file.")
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)


func _on_OpenSprite_files_selected(paths: PoolStringArray) -> void:
	for path in paths:
		OpenSave.handle_loading_file(path)
	Global.save_sprites_dialog.current_dir = paths[0].get_base_dir()
	Global.config_cache.set_value("data", "current_dir", paths[0].get_base_dir())


func _on_SaveSprite_file_selected(path: String) -> void:
	save_project(path)


func save_project(path: String) -> void:
	var zstd: bool = Global.save_sprites_dialog.get_vbox().get_node("ZSTDCompression").pressed
	OpenSave.save_pxo_file(path, false, zstd)
	Global.open_sprites_dialog.current_dir = path.get_base_dir()
	Global.config_cache.set_value("data", "current_dir", path.get_base_dir())

	if is_quitting_on_save:
		_quit()


func _on_SaveSpriteHTML5_confirmed() -> void:
	var file_name = Global.save_sprites_html5_dialog.get_node(
		"FileNameContainer/FileNameLineEdit"
	).text
	file_name += ".pxo"
	var path = "user://".plus_file(file_name)
	OpenSave.save_pxo_file(path, false, false)


func _on_OpenSprite_popup_hide() -> void:
	if !opensprite_file_selected:
		_can_draw_true()


func _can_draw_true() -> void:
	Global.dialog_open(false)


func show_quit_dialog() -> void:
	var changed_project := false
	for project in Global.projects:
		if project.has_changed:
			changed_project = true
			break

	if !quit_dialog.visible:
		if !changed_project:
			if Global.quit_confirmation:
				quit_dialog.call_deferred("popup_centered")
			else:
				_quit()
		else:
			quit_and_save_dialog.call_deferred("popup_centered")

	Global.dialog_open(true)


func _on_QuitDialog_confirmed() -> void:
	_quit()


func _on_QuitAndSaveDialog_custom_action(action: String) -> void:
	if action == "ExitWithoutSaving":
		_quit()


func _on_QuitAndSaveDialog_confirmed() -> void:
	is_quitting_on_save = true
	Global.save_sprites_dialog.popup_centered()
	quit_dialog.hide()
	Global.dialog_open(true)


func _quit() -> void:
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


func _on_BackupConfirmation_popup_hide() -> void:
	if Global.enable_autosave:
		OpenSave.autosave_timer.start()


func _use_osx_shortcuts() -> void:
	for action in InputMap.get_actions():
		var action_list: Array = InputMap.get_action_list(action)
		if action_list.size() == 0:
			continue
		var event: InputEvent = action_list[0]

		if event.is_action("show_pixel_grid"):
			event.shift = true

		if event.control:
			event.control = false
			event.command = true


func _exit_tree() -> void:
	Global.config_cache.set_value("window", "layout", Global.top_menu_container.selected_layout)
	Global.config_cache.set_value("window", "screen", OS.current_screen)
	Global.config_cache.set_value(
		"window", "maximized", OS.window_maximized || OS.window_fullscreen
	)
	Global.config_cache.set_value("window", "position", OS.window_position)
	Global.config_cache.set_value("window", "size", OS.window_size)
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
