extends Control

var opensprite_file_selected := false
var file_menu : PopupMenu
var view_menu : PopupMenu
var redone := false
var is_quitting_on_save := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	setup_application_window_size()

	setup_file_menu()
	setup_edit_menu()
	setup_view_menu()
	setup_image_menu()
	setup_help_menu()

	Global.window_title = tr("untitled") + " - Pixelorama " + Global.current_version

	Global.current_project.layers[0].name = tr("Layer") + " 0"
	Global.layers_container.get_child(0).label.text = Global.current_project.layers[0].name
	Global.layers_container.get_child(0).line_edit.text = Global.current_project.layers[0].name

	Import.import_brushes(Global.directory_module.get_brushes_search_path_in_order())
	Import.import_patterns(Global.directory_module.get_patterns_search_path_in_order())

	Global.color_pickers[0].get_picker().presets_visible = false
	Global.color_pickers[1].get_picker().presets_visible = false

	$QuitAndSaveDialog.add_button("Save & Exit", false, "Save")
	$QuitAndSaveDialog.get_ok().text = "Exit without saving"

	if not Global.config_cache.has_section_key("preferences", "startup"):
		Global.config_cache.set_value("preferences", "startup", true)
	show_splash_screen()

	handle_backup()

	# If the user wants to run Pixelorama with arguments in terminal mode
	# or open files with Pixelorama directly, then handle that
	if OS.get_cmdline_args():
		handle_loading_files(OS.get_cmdline_args())
	get_tree().connect("files_dropped", self, "_on_files_dropped")


func _input(event : InputEvent) -> void:
	Global.left_cursor.position = get_global_mouse_position() + Vector2(-32, 32)
	Global.left_cursor.texture = Global.left_cursor_tool_texture
	Global.right_cursor.position = get_global_mouse_position() + Vector2(32, 32)
	Global.right_cursor.texture = Global.right_cursor_tool_texture

	if event is InputEventKey and (event.scancode == KEY_ENTER or event.scancode == KEY_KP_ENTER):
		if get_focus_owner() is LineEdit:
			get_focus_owner().release_focus()

	if event.is_action_pressed("toggle_fullscreen"):
		OS.window_fullscreen = !OS.window_fullscreen

	if event.is_action_pressed("redo_secondary"): # Shift + Ctrl + Z
		redone = true
		Global.current_project.undo_redo.redo()
		redone = false


func setup_application_window_size() -> void:
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


func setup_file_menu() -> void:
	var file_menu_items := {
		"New..." : InputMap.get_action_list("new_file")[0].get_scancode_with_modifiers(),
		"Open..." : InputMap.get_action_list("open_file")[0].get_scancode_with_modifiers(),
		'Open last project...' : 0,
		"Save..." : InputMap.get_action_list("save_file")[0].get_scancode_with_modifiers(),
		"Save as..." : InputMap.get_action_list("save_file_as")[0].get_scancode_with_modifiers(),
		"Import..." : InputMap.get_action_list("import_file")[0].get_scancode_with_modifiers(),
		"Export..." : InputMap.get_action_list("export_file")[0].get_scancode_with_modifiers(),
		"Export as..." : InputMap.get_action_list("export_file_as")[0].get_scancode_with_modifiers(),
		"Quit" : InputMap.get_action_list("quit")[0].get_scancode_with_modifiers(),
		}
	file_menu = Global.file_menu.get_popup()
	var i := 0

	for item in file_menu_items.keys():
		file_menu.add_item(item, i, file_menu_items[item])
		i += 1

	file_menu.connect("id_pressed", self, "file_menu_id_pressed")


func setup_edit_menu() -> void:
	var edit_menu_items := {
		"Undo" : InputMap.get_action_list("undo")[0].get_scancode_with_modifiers(),
		"Redo" : InputMap.get_action_list("redo")[0].get_scancode_with_modifiers(),
		"Clear Selection" : 0,
		"Preferences" : 0
		}
	var edit_menu : PopupMenu = Global.edit_menu.get_popup()
	var i := 0

	for item in edit_menu_items.keys():
		edit_menu.add_item(item, i, edit_menu_items[item])
		i += 1

	edit_menu.connect("id_pressed", self, "edit_menu_id_pressed")


func setup_view_menu() -> void:
	var view_menu_items := {
		"Tile Mode" : InputMap.get_action_list("tile_mode")[0].get_scancode_with_modifiers(),
		"Show Grid" : InputMap.get_action_list("show_grid")[0].get_scancode_with_modifiers(),
		"Show Rulers" : InputMap.get_action_list("show_rulers")[0].get_scancode_with_modifiers(),
		"Show Guides" : InputMap.get_action_list("show_guides")[0].get_scancode_with_modifiers(),
		"Show Animation Timeline" : 0
		}
	view_menu = Global.view_menu.get_popup()

	var i := 0
	for item in view_menu_items.keys():
		view_menu.add_check_item(item, i, view_menu_items[item])
		i += 1

	view_menu.set_item_checked(2, true) # Show Rulers
	view_menu.set_item_checked(3, true) # Show Guides
	view_menu.set_item_checked(4, true) # Show Animation Timeline
	view_menu.hide_on_checkable_item_selection = false
	view_menu.connect("id_pressed", self, "view_menu_id_pressed")


func setup_image_menu() -> void:
	var image_menu_items := {
		"Scale Image" : 0,
		"Crop Image" : 0,
		"Flip Horizontal" : InputMap.get_action_list("image_flip_horizontal")[0].get_scancode_with_modifiers(),
		"Flip Vertical" : InputMap.get_action_list("image_flip_vertical")[0].get_scancode_with_modifiers(),
		"Rotate Image" : 0,
		"Invert colors" : 0,
		"Desaturation" : 0,
		"Outline" : 0,
		"Adjust Hue/Saturation/Value" : 0
		}
	var image_menu : PopupMenu = Global.image_menu.get_popup()

	var i := 0
	for item in image_menu_items.keys():
		image_menu.add_item(item, i, image_menu_items[item])
		if i == 4:
			image_menu.add_separator()
		i += 1

	image_menu.connect("id_pressed", self, "image_menu_id_pressed")


func setup_help_menu() -> void:
	var help_menu_items := {
		"View Splash Screen" : 0,
		"Online Docs" : 0,
		"Issue Tracker" : 0,
		"Changelog" : 0,
		"About Pixelorama" : 0
		}
	var help_menu : PopupMenu = Global.help_menu.get_popup()

	var i := 0
	for item in help_menu_items.keys():
		help_menu.add_item(item, i, help_menu_items[item])
		i += 1

	help_menu.connect("id_pressed", self, "help_menu_id_pressed")


func show_splash_screen() -> void:
	# Wait for the window to adjust itself, so the popup is correctly centered
	yield(get_tree().create_timer(0.01), "timeout")
	if Global.config_cache.get_value("preferences", "startup"):
		$SplashDialog.popup_centered() # Splash screen
		modulate = Color(0.5, 0.5, 0.5)
	else:
		Global.can_draw = true


func handle_backup() -> void:
	# If backup file exists then Pixelorama was not closed properly (probably crashed) - reopen backup
	$BackupConfirmation.get_cancel().text = tr("Delete")
	if Global.config_cache.has_section("backups"):
		var project_paths = Global.config_cache.get_section_keys("backups")
		if project_paths.size() > 0:
			# Get backup path
			var backup_path = Global.config_cache.get_value("backups", project_paths[0])
			# Temporatily stop autosave until user confirms backup
			OpenSave.autosave_timer.stop()
			# For it's only possible to reload the first found backup
			$BackupConfirmation.dialog_text = tr($BackupConfirmation.dialog_text) % project_paths[0]
			$BackupConfirmation.connect("confirmed", self, "_on_BackupConfirmation_confirmed", [project_paths[0], backup_path])
			$BackupConfirmation.get_cancel().connect("pressed", self, "_on_BackupConfirmation_delete", [project_paths[0], backup_path])
			$BackupConfirmation.popup_centered()
			Global.can_draw = false
			modulate = Color(0.5, 0.5, 0.5)
		else:
			if Global.open_last_project:
				load_last_project()
	else:
		if Global.open_last_project:
			load_last_project()


func handle_loading_files(files : PoolStringArray) -> void:
	for file in files:
		if file.get_extension().to_lower() == "pxo":
				_on_OpenSprite_file_selected(file)
		else:
			$ImportSprites._on_ImportSprites_files_selected([file])


func _notification(what : int) -> void:
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST: # Handle exit
		show_quit_dialog()


func _on_files_dropped(_files : PoolStringArray, _screen : int) -> void:
	handle_loading_files(_files)


func on_new_project_file_menu_option_pressed() -> void:
	$CreateNewImage.popup_centered()
	Global.dialog_open(true)


func open_project_file() -> void:
	$OpenSprite.popup_centered()
	Global.dialog_open(true)
	opensprite_file_selected = false


func on_open_last_project_file_menu_option_pressed() -> void:
	# Check if last project path is set and if yes then open
	if Global.config_cache.has_section_key("preferences", "last_project_path"):
		load_last_project()
	else: # if not then warn user that he didn't edit any project yet
		Global.error_dialog.set_text("You haven't saved or opened any project in Pixelorama yet!")
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)


func save_project_file() -> void:
	is_quitting_on_save = false
	if OpenSave.current_save_path == "":
		$SaveSprite.popup_centered()
		Global.dialog_open(true)
	else:
		_on_SaveSprite_file_selected(OpenSave.current_save_path)


func save_project_file_as() -> void:
	is_quitting_on_save = false
	$SaveSprite.popup_centered()
	Global.dialog_open(true)


func import_file() -> void:
	$ImportSprites.popup_centered()
	Global.dialog_open(true)
	opensprite_file_selected = false


func export_file() -> void:
	if $ExportDialog.was_exported == false:
		$ExportDialog.popup_centered()
		Global.dialog_open(true)
	else:
		$ExportDialog.external_export()


func file_menu_id_pressed(id : int) -> void:
	match id:
		0: # New
			on_new_project_file_menu_option_pressed()
		1: # Open
			open_project_file()
		2: # Open last project
			on_open_last_project_file_menu_option_pressed()
		3: # Save
			save_project_file()
		4: # Save as
			save_project_file_as()
		5: # Import
			import_file()
		6: # Export
			export_file()
		7: # Export as
			$ExportDialog.popup_centered()
			Global.dialog_open(true)
		8: # Quit
			show_quit_dialog()


func edit_menu_id_pressed(id : int) -> void:
	match id:
		0: # Undo
			Global.current_project.undo_redo.undo()
		1: # Redo
			redone = true
			Global.current_project.undo_redo.redo()
			redone = false
		2: # Clear selection
			Global.canvas.handle_undo("Rectangle Select")
			Global.selection_rectangle.polygon[0] = Vector2.ZERO
			Global.selection_rectangle.polygon[1] = Vector2.ZERO
			Global.selection_rectangle.polygon[2] = Vector2.ZERO
			Global.selection_rectangle.polygon[3] = Vector2.ZERO
			Global.current_project.selected_pixels.clear()
			Global.canvas.handle_redo("Rectangle Select")
		3: # Preferences
			$PreferencesDialog.popup_centered(Vector2(400, 280))
			Global.dialog_open(true)


func toggle_tile_mode() -> void:
	Global.tile_mode = !Global.tile_mode
	view_menu.set_item_checked(0, Global.tile_mode)


func toggle_show_grid() -> void:
	Global.draw_grid = !Global.draw_grid
	view_menu.set_item_checked(1, Global.draw_grid)


func toggle_show_rulers() -> void:
	Global.show_rulers = !Global.show_rulers
	view_menu.set_item_checked(2, Global.show_rulers)
	Global.horizontal_ruler.visible = Global.show_rulers
	Global.vertical_ruler.visible = Global.show_rulers


func toggle_show_guides() -> void:
	Global.show_guides = !Global.show_guides
	view_menu.set_item_checked(3, Global.show_guides)
	for guide in Global.canvas.get_children():
		if guide is Guide:
			guide.visible = Global.show_guides


func toggle_show_anim_timeline() -> void:
	Global.show_animation_timeline = !Global.show_animation_timeline
	view_menu.set_item_checked(4, Global.show_animation_timeline)
	Global.animation_timeline.visible = Global.show_animation_timeline


func view_menu_id_pressed(id : int) -> void:
	match id:
		0: # Tile mode
			toggle_tile_mode()
		1: # Show grid
			toggle_show_grid()
		2: # Show rulers
			toggle_show_rulers()
		3: # Show guides
			toggle_show_guides()
		4: # Show animation timeline
			toggle_show_anim_timeline()

	Global.canvas.update()


func show_scale_image_popup() -> void:
	$ScaleImage.popup_centered()
	Global.dialog_open(true)


func crop_image() -> void:
	# Use first cel as a starting rectangle
	var used_rect : Rect2 = Global.current_project.frames[0].cels[0].image.get_used_rect()

	for f in Global.current_project.frames:
		# However, if first cel is empty, loop through all cels until we find one that isn't
		for cel in f.cels:
			if used_rect != Rect2(0, 0, 0, 0):
				break
			else:
				if cel.image.get_used_rect() != Rect2(0, 0, 0, 0):
					used_rect = cel.image.get_used_rect()

		# Merge all layers with content
		for cel in f.cels:
				if cel.image.get_used_rect() != Rect2(0, 0, 0, 0):
					used_rect = used_rect.merge(cel.image.get_used_rect())

	# If no layer has any content, just return
	if used_rect == Rect2(0, 0, 0, 0):
		return

	var width := used_rect.size.x
	var height := used_rect.size.y
	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Scale")
	Global.current_project.undo_redo.add_do_property(Global.current_project, "size", Vector2(width, height).floor())
	for f in Global.current_project.frames:
		# Loop through all the layers to crop them
		for j in range(Global.current_project.layers.size() - 1, -1, -1):
			var sprite : Image = f.cels[j].image.get_rect(used_rect)
			Global.current_project.undo_redo.add_do_property(f.cels[j].image, "data", sprite.data)
			Global.current_project.undo_redo.add_undo_property(f.cels[j].image, "data", f.cels[j].image.data)

	Global.current_project.undo_redo.add_undo_property(Global.current_project, "size", Global.current_project.size)
	Global.current_project.undo_redo.add_undo_method(Global, "undo")
	Global.current_project.undo_redo.add_do_method(Global, "redo")
	Global.current_project.undo_redo.commit_action()


func flip_image(horizontal : bool) -> void:
	var image : Image = Global.current_project.frames[Global.current_project.current_frame].cels[Global.current_project.current_layer].image
	Global.canvas.handle_undo("Draw")
	image.unlock()
	if horizontal:
		image.flip_x()
	else:
		image.flip_y()
	image.lock()
	Global.canvas.handle_redo("Draw")


func show_rotate_image_popup() -> void:
	var image : Image = Global.current_project.frames[Global.current_project.current_frame].cels[Global.current_project.current_layer].image
	$RotateImage.set_sprite(image)
	$RotateImage.popup_centered()
	Global.dialog_open(true)


func invert_image_colors() -> void:
	var image : Image = Global.current_project.frames[Global.current_project.current_frame].cels[Global.current_project.current_layer].image
	Global.canvas.handle_undo("Draw")
	for xx in image.get_size().x:
		for yy in image.get_size().y:
			var px_color = image.get_pixel(xx, yy).inverted()
			if px_color.a == 0:
				continue
			image.set_pixel(xx, yy, px_color)
	Global.canvas.handle_redo("Draw")


func desaturate_image() -> void:
	var image : Image = Global.current_project.frames[Global.current_project.current_frame].cels[Global.current_project.current_layer].image
	Global.canvas.handle_undo("Draw")
	for xx in image.get_size().x:
		for yy in image.get_size().y:
			var px_color = image.get_pixel(xx, yy)
			if px_color.a == 0:
				continue
			var gray = image.get_pixel(xx, yy).v
			px_color = Color(gray, gray, gray, px_color.a)
			image.set_pixel(xx, yy, px_color)
	Global.canvas.handle_redo("Draw")


func show_add_outline_popup() -> void:
	$OutlineDialog.popup_centered()
	Global.dialog_open(true)


func show_hsv_configuration_popup() -> void:
	$HSVDialog.popup_centered()
	Global.dialog_open(true)


func image_menu_id_pressed(id : int) -> void:
	if Global.current_project.layers[Global.current_project.current_layer].locked: # No changes if the layer is locked
		return
	match id:
		0: # Scale Image
			show_scale_image_popup()

		1: # Crop Image
			crop_image()

		2: # Flip Horizontal
			flip_image(true)

		3: # Flip Vertical
			flip_image(false)

		4: # Rotate
			show_rotate_image_popup()

		5: # Invert Colors
			invert_image_colors()

		6: # Desaturation
			desaturate_image()

		7: # Outline
			show_add_outline_popup()

		8: # HSV
			show_hsv_configuration_popup()


func help_menu_id_pressed(id : int) -> void:
	match id:
		0: # Splash Screen
			$SplashDialog.popup_centered()
			Global.dialog_open(true)
		1: # Online Docs
			OS.shell_open("https://orama-interactive.github.io/Pixelorama-Docs/")
		2: # Issue Tracker
			OS.shell_open("https://github.com/Orama-Interactive/Pixelorama/issues")
		3: # Changelog
			OS.shell_open("https://github.com/Orama-Interactive/Pixelorama/blob/master/CHANGELOG.md#v07---2020-05-16")
		4: # About Pixelorama
			$AboutDialog.popup_centered()
			Global.dialog_open(true)


func load_last_project() -> void:
	# Check if any project was saved or opened last time
	if Global.config_cache.has_section_key("preferences", "last_project_path"):
		# Check if file still exists on disk
		var file_path = Global.config_cache.get_value("preferences", "last_project_path")
		var file_check := File.new()
		if file_check.file_exists(file_path): # If yes then load the file
			_on_OpenSprite_file_selected(file_path)
		else:
			# If file doesn't exist on disk then warn user about this
			Global.error_dialog.set_text("Cannot find last project file.")
			Global.error_dialog.popup_centered()
			Global.dialog_open(true)


func _on_OpenSprite_file_selected(path : String) -> void:
	OpenSave.open_pxo_file(path)

	$SaveSprite.current_path = path
	# Set last opened project path and save
	Global.config_cache.set_value("preferences", "last_project_path", path)
	Global.config_cache.save("user://cache.ini")
	$ExportDialog.file_name = path.get_file().trim_suffix(".pxo")
	$ExportDialog.directory_path = path.get_base_dir()
	$ExportDialog.was_exported = false
	file_menu.set_item_text(3, tr("Save") + " %s" % path.get_file())
	file_menu.set_item_text(6, tr("Export"))


func _on_SaveSprite_file_selected(path : String) -> void:
	OpenSave.save_pxo_file(path, false)

	# Set last opened project path and save
	Global.config_cache.set_value("preferences", "last_project_path", path)
	Global.config_cache.save("user://cache.ini")
	$ExportDialog.file_name = path.get_file().trim_suffix(".pxo")
	$ExportDialog.directory_path = path.get_base_dir()
	$ExportDialog.was_exported = false
	file_menu.set_item_text(3, tr("Save") + " %s" % path.get_file())

	if is_quitting_on_save:
		_on_QuitDialog_confirmed()


func _on_ImportSprites_popup_hide() -> void:
	if !opensprite_file_selected:
		_can_draw_true()


func _can_draw_true() -> void:
	Global.dialog_open(false)


func show_quit_dialog() -> void:
	if !$QuitDialog.visible:
		if !Global.current_project.has_changed:
			$QuitDialog.call_deferred("popup_centered")
		else:
			$QuitAndSaveDialog.call_deferred("popup_centered")

	Global.dialog_open(true)


func _on_QuitAndSaveDialog_custom_action(action : String) -> void:
	if action == "Save":
		is_quitting_on_save = true
		$SaveSprite.popup_centered()
		$QuitDialog.hide()
		Global.dialog_open(true)
		OpenSave.remove_backup()


func _on_QuitDialog_confirmed() -> void:
	# Darken the UI to denote that the application is currently exiting
	# (it won't respond to user input in this state).
	modulate = Color(0.5, 0.5, 0.5)
	OpenSave.remove_backup()
	get_tree().quit()


func _on_BackupConfirmation_confirmed(project_path : String, backup_path : String) -> void:
	OpenSave.reload_backup_file(project_path, backup_path)
	OpenSave.autosave_timer.start()
	$ExportDialog.file_name = OpenSave.current_save_path.get_file().trim_suffix(".pxo")
	$ExportDialog.directory_path = OpenSave.current_save_path.get_base_dir()
	$ExportDialog.was_exported = false
	file_menu.set_item_text(3, tr("Save") + " %s" % OpenSave.current_save_path.get_file())
	file_menu.set_item_text(6, tr("Export"))


func _on_BackupConfirmation_delete(project_path : String, backup_path : String) -> void:
	OpenSave.remove_backup_by_path(project_path, backup_path)
	OpenSave.autosave_timer.start()
	# Reopen last project
	if Global.open_last_project:
		load_last_project()
