extends Control

var opensprite_file_selected := false
var redone := false
var is_quitting_on_save := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	setup_application_window_size()

	Global.window_title = tr("untitled") + " - Pixelorama " + Global.current_version

	Global.current_project.layers[0].name = tr("Layer") + " 0"
	Global.layers_container.get_child(0).label.text = Global.current_project.layers[0].name
	Global.layers_container.get_child(0).line_edit.text = Global.current_project.layers[0].name

	Import.import_brushes(Global.directory_module.get_brushes_search_path_in_order())
	Import.import_patterns(Global.directory_module.get_patterns_search_path_in_order())

	Global.quit_and_save_dialog.add_button("Save & Exit", false, "Save")
	Global.quit_and_save_dialog.get_ok().text = "Exit without saving"

	Global.open_sprites_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	Global.save_sprites_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)

	var zstd_checkbox := CheckBox.new()
	zstd_checkbox.name = "ZSTDCompression"
	zstd_checkbox.pressed = true
	zstd_checkbox.text = "Use ZSTD Compression"
	zstd_checkbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Global.save_sprites_dialog.get_vbox().add_child(zstd_checkbox)

	if not Global.config_cache.has_section_key("preferences", "startup"):
		Global.config_cache.set_value("preferences", "startup", true)
	show_splash_screen()

	handle_backup()

	# If the user wants to run Pixelorama with arguments in terminal mode
	# or open files with Pixelorama directly, then handle that
	if OS.get_cmdline_args():
		OpenSave.handle_loading_files(OS.get_cmdline_args())
	get_tree().connect("files_dropped", self, "_on_files_dropped")


func _input(event : InputEvent) -> void:
	Global.left_cursor.position = get_global_mouse_position() + Vector2(-32, 32)
	Global.left_cursor.texture = Global.left_cursor_tool_texture
	Global.right_cursor.position = get_global_mouse_position() + Vector2(32, 32)
	Global.right_cursor.texture = Global.right_cursor_tool_texture

	if event is InputEventKey and (event.scancode == KEY_ENTER or event.scancode == KEY_KP_ENTER):
		if get_focus_owner() is LineEdit:
			get_focus_owner().release_focus()

	# The section of code below is reserved for Undo and Redo! Do not place code for Input below, but above.
	if !event.is_echo(): # Checks if the action is pressed down
		if event.is_action_pressed("redo_secondary"): # Done, so that "redo_secondary" hasn't
			redone = true # a slight delay before it starts. The "redo" and "undo" action don't have a slight delay,
			Global.current_project.undo_redo.redo() # The "redo" and "undo" action don't have a slight delay,
			redone = false # because they get called as an accelerator once pressed (TopMenuContainer.gd / Line 152).
		return

	if event.is_action("redo"): # Ctrl + Y
		redone = true
		Global.current_project.undo_redo.redo()
		redone = false

	if event.is_action("redo_secondary"): # Shift + Ctrl + Z
		redone = true
		Global.current_project.undo_redo.redo()
		redone = false

	if event.is_action("undo") and !event.shift: # Ctrl + Z and check if shift isn't pressed
		Global.current_project.undo_redo.undo() # so "undo" isn't accidentaly triggered while using "redo_secondary"


func setup_application_window_size() -> void:
	if OS.get_name() == "HTML5":
		return
	# Set a minimum window size to prevent UI elements from collapsing on each other.
	OS.min_window_size = Vector2(1024, 576)

	get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_DISABLED,
		SceneTree.STRETCH_ASPECT_IGNORE, Vector2(1024,576), Global.shrink)

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


func show_splash_screen() -> void:
	# Wait for the window to adjust itself, so the popup is correctly centered
	yield(get_tree().create_timer(0.2), "timeout")
	if Global.config_cache.get_value("preferences", "startup"):
		$Dialogs/SplashDialog.popup_centered() # Splash screen
		modulate = Color(0.5, 0.5, 0.5)
	else:
		Global.can_draw = true


func handle_backup() -> void:
	# If backup file exists then Pixelorama was not closed properly (probably crashed) - reopen backup
	var backup_confirmation : ConfirmationDialog = $Dialogs/BackupConfirmation
	backup_confirmation.get_cancel().text = tr("Delete")
	if Global.config_cache.has_section("backups"):
		var project_paths = Global.config_cache.get_section_keys("backups")
		if project_paths.size() > 0:
			# Get backup paths
			var backup_paths := []
			for p_path in project_paths:
				backup_paths.append(Global.config_cache.get_value("backups", p_path))
			# Temporatily stop autosave until user confirms backup
			OpenSave.autosave_timer.stop()
			backup_confirmation.dialog_text = tr(backup_confirmation.dialog_text) % project_paths
			backup_confirmation.connect("confirmed", self, "_on_BackupConfirmation_confirmed", [project_paths, backup_paths])
			backup_confirmation.get_cancel().connect("pressed", self, "_on_BackupConfirmation_delete", [project_paths, backup_paths])
			backup_confirmation.popup_centered()
			Global.can_draw = false
			modulate = Color(0.5, 0.5, 0.5)
		else:
			if Global.open_last_project:
				load_last_project()
	else:
		if Global.open_last_project:
			load_last_project()


func _notification(what : int) -> void:
	match what:
		MainLoop.NOTIFICATION_WM_QUIT_REQUEST: # Handle exit
			show_quit_dialog()
		MainLoop.NOTIFICATION_WM_FOCUS_OUT: # Called when the mouse isn't in the window anymore
			Engine.set_target_fps(1) # then set the fps to 1 to relieve the cpu
		MainLoop.NOTIFICATION_WM_MOUSE_ENTER: # Opposite of the above
			Engine.set_target_fps(0) # 0 stands for maximum fps


func _on_files_dropped(_files : PoolStringArray, _screen : int) -> void:
	OpenSave.handle_loading_files(_files)


func load_last_project() -> void:
	if OS.get_name() == "HTML5":
		return
	# Check if any project was saved or opened last time
	if Global.config_cache.has_section_key("preferences", "last_project_path"):
		# Check if file still exists on disk
		var file_path = Global.config_cache.get_value("preferences", "last_project_path")
		var file_check := File.new()
		if file_check.file_exists(file_path): # If yes then load the file
			OpenSave.open_pxo_file(file_path)
		else:
			# If file doesn't exist on disk then warn user about this
			Global.error_dialog.set_text("Cannot find last project file.")
			Global.error_dialog.popup_centered()
			Global.dialog_open(true)


func load_recent_project_file(path : String) -> void:
	if OS.get_name() == "HTML5":
		return

	# Check if file still exists on disk
	var file_check := File.new()
	if file_check.file_exists(path): # If yes then load the file
		OpenSave.handle_loading_files([path])
	else:
		# If file doesn't exist on disk then warn user about this
		Global.error_dialog.set_text("Cannot find project file.")
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)


func _on_OpenSprite_file_selected(path : String) -> void:
	OpenSave.handle_loading_files([path])


func _on_SaveSprite_file_selected(path : String) -> void:
	var zstd = Global.save_sprites_dialog.get_vbox().get_node("ZSTDCompression").pressed
	OpenSave.save_pxo_file(path, false, zstd)

	if is_quitting_on_save:
		_on_QuitDialog_confirmed()


func _on_SaveSpriteHTML5_confirmed() -> void:
	var file_name = Global.save_sprites_html5_dialog.get_node("FileNameContainer/FileNameLineEdit").text
	file_name += ".pxo"
	var path = "user://".plus_file(file_name)
	OpenSave.save_pxo_file(path, false, false)


func _on_OpenSprite_popup_hide() -> void:
	if !opensprite_file_selected:
		_can_draw_true()


func _can_draw_true() -> void:
	Global.dialog_open(false)


func show_quit_dialog() -> void:
	if !Global.quit_dialog.visible:
		if !Global.current_project.has_changed:
			Global.quit_dialog.call_deferred("popup_centered")
		else:
			Global.quit_and_save_dialog.call_deferred("popup_centered")

	Global.dialog_open(true)


func _on_QuitAndSaveDialog_custom_action(action : String) -> void:
	if action == "Save":
		is_quitting_on_save = true
		Global.save_sprites_dialog.popup_centered()
		Global.quit_dialog.hide()
		Global.dialog_open(true)


func _on_QuitDialog_confirmed() -> void:
	# Darken the UI to denote that the application is currently exiting
	# (it won't respond to user input in this state).
	modulate = Color(0.5, 0.5, 0.5)
	get_tree().quit()


func _on_BackupConfirmation_confirmed(project_paths : Array, backup_paths : Array) -> void:
	OpenSave.reload_backup_file(project_paths, backup_paths)
	OpenSave.autosave_timer.start()
	Export.file_name = OpenSave.current_save_paths[0].get_file().trim_suffix(".pxo")
	Export.directory_path = OpenSave.current_save_paths[0].get_base_dir()
	Export.was_exported = false
	Global.file_menu.get_popup().set_item_text(4, tr("Save") + " %s" % OpenSave.current_save_paths[0].get_file())
	Global.file_menu.get_popup().set_item_text(6, tr("Export"))


func _on_BackupConfirmation_delete(project_paths : Array, backup_paths : Array) -> void:
	for i in range(project_paths.size()):
		OpenSave.remove_backup_by_path(project_paths[i], backup_paths[i])
	OpenSave.autosave_timer.start()
	# Reopen last project
	if Global.open_last_project:
		load_last_project()
