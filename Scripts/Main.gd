extends Control

var current_save_path := ""
var opensprite_file_selected := false
var file_menu : PopupMenu
var view_menu : PopupMenu
var tools := []
var redone := false
var is_quitting_on_save := false
var previous_left_color := Color.black
var previous_right_color := Color.white

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	# Set a minimum window size to prevent UI elements from collapsing on each other.
	# This property is only available in 3.2alpha or later, so use `set()` to fail gracefully if it doesn't exist.
	OS.set("min_window_size", Vector2(1152, 648))

	# `TranslationServer.get_loaded_locales()` was added in 3.2beta and in 3.1.2
	# The `has_method()` check and the `else` branch can be removed once 3.2 is released.
	if TranslationServer.has_method("get_loaded_locales"):
		Global.loaded_locales = TranslationServer.get_loaded_locales()
	else:
		# Hardcoded list of locales
		Global.loaded_locales = ["de_DE", "el_GR", "en_US", "eo_UY", "es_ES", "fr_FR", "it_IT", "lv_LV", "pl_PL", "pt_BR", "ru_RU", "zh_CN","zh_TW"]

	# Make sure locales are always sorted, in the same order
	Global.loaded_locales.sort()

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

	var file_menu_items := {
		"New..." : KEY_MASK_CMD + KEY_N,
		"Open..." : KEY_MASK_CMD + KEY_O,
		"Save..." : KEY_MASK_CMD + KEY_S,
		"Save as..." : KEY_MASK_SHIFT + KEY_MASK_CMD + KEY_S,
		"Import..." : KEY_MASK_CMD + KEY_I,
		"Export..." : KEY_MASK_CMD + KEY_E,
		"Export as..." : KEY_MASK_SHIFT + KEY_MASK_CMD + KEY_E,
		"Quit" : KEY_MASK_CMD + KEY_Q
		}
	var edit_menu_items := {
		"Undo" : KEY_MASK_CMD + KEY_Z,
		"Redo" : KEY_MASK_CMD + KEY_Y,
		"Clear Selection" : 0,
		"Preferences" : 0
		}
	var view_menu_items := {
		"Tile Mode" : KEY_MASK_CMD + KEY_T,
		"Show Grid" : KEY_MASK_CMD + KEY_G,
		"Show Rulers" : KEY_MASK_CMD + KEY_R,
		"Show Guides" : KEY_MASK_CMD + KEY_F,
		"Show Animation Timeline" : 0
		}
	var image_menu_items := {
		"Scale Image" : 0,
		"Crop Image" : 0,
		"Flip Horizontal" : KEY_MASK_SHIFT + KEY_H,
		"Flip Vertical" : KEY_MASK_SHIFT + KEY_V,
		"Rotate Image" : 0,
		"Invert colors" : 0,
		"Desaturation" : 0,
		"Outline" : 0
		}
	var help_menu_items := {
		"View Splash Screen" : 0,
		"Issue Tracker" : 0,
		"Changelog" : 0,
		"About Pixelorama" : 0
		}

	# Load language
	if Global.config_cache.has_section_key("preferences", "locale"):
		var saved_locale : String = Global.config_cache.get_value("preferences", "locale")
		TranslationServer.set_locale(saved_locale)

		# Set the language option menu's default selected option to the loaded locale
		var locale_index: int = Global.loaded_locales.find(saved_locale)
		$PreferencesDialog.languages.get_child(1).pressed = false
		$PreferencesDialog.languages.get_child(locale_index + 2).pressed = true
	else: # If the user doesn't have a language preference, set it to their OS' locale
		TranslationServer.set_locale(OS.get_locale())

	if "zh" in TranslationServer.get_locale():
		theme.default_font = preload("res://Assets/Fonts/CJK/NotoSansCJKtc-Regular.tres")
	else:
		theme.default_font = preload("res://Assets/Fonts/Roboto-Regular.tres")


	file_menu = Global.file_menu.get_popup()
	var edit_menu : PopupMenu = Global.edit_menu.get_popup()
	view_menu = Global.view_menu.get_popup()
	var image_menu : PopupMenu = Global.image_menu.get_popup()
	var help_menu : PopupMenu = Global.help_menu.get_popup()

	var i = 0
	for item in file_menu_items.keys():
		file_menu.add_item(item, i, file_menu_items[item])
		i += 1
	i = 0
	for item in edit_menu_items.keys():
		edit_menu.add_item(item, i, edit_menu_items[item])
		i += 1
	i = 0
	for item in view_menu_items.keys():
		view_menu.add_check_item(item, i, view_menu_items[item])
		i += 1
	view_menu.set_item_checked(2, true) # Show Rulers
	view_menu.set_item_checked(3, true) # Show Guides
	view_menu.set_item_checked(4, true) # Show Animation Timeline
	view_menu.hide_on_checkable_item_selection = false
	i = 0
	for item in image_menu_items.keys():
		image_menu.add_item(item, i, image_menu_items[item])
		if i == 4:
			image_menu.add_separator()
		i += 1
	i = 0
	for item in help_menu_items.keys():
		help_menu.add_item(item, i, help_menu_items[item])
		i += 1

	file_menu.connect("id_pressed", self, "file_menu_id_pressed")
	edit_menu.connect("id_pressed", self, "edit_menu_id_pressed")
	view_menu.connect("id_pressed", self, "view_menu_id_pressed")
	image_menu.connect("id_pressed", self, "image_menu_id_pressed")
	help_menu.connect("id_pressed", self, "help_menu_id_pressed")

	var root = get_tree().get_root()
	# Node, left mouse shortcut, right mouse shortcut
	tools.append([Global.find_node_by_name(root, "Pencil"), "left_pencil_tool", "right_pencil_tool"])
	tools.append([Global.find_node_by_name(root, "Eraser"), "left_eraser_tool", "right_eraser_tool"])
	tools.append([Global.find_node_by_name(root, "Bucket"), "left_fill_tool", "right_fill_tool"])
	tools.append([Global.find_node_by_name(root, "LightenDarken"), "left_lightdark_tool", "right_lightdark_tool"])
	tools.append([Global.find_node_by_name(root, "RectSelect"), "left_rectangle_select_tool", "right_rectangle_select_tool"])
	tools.append([Global.find_node_by_name(root, "ColorPicker"), "left_colorpicker_tool", "right_colorpicker_tool"])

	for t in tools:
		t[0].connect("pressed", self, "_on_Tool_pressed", [t[0]])

	# Checks to see if it's 3.1.x
	if Engine.get_version_info().major == 3 and Engine.get_version_info().minor < 2:
		Global.left_color_picker.get_picker().move_child(Global.left_color_picker.get_picker().get_child(0), 1)
		Global.right_color_picker.get_picker().move_child(Global.right_color_picker.get_picker().get_child(0), 1)

	if OS.get_cmdline_args():
		for arg in OS.get_cmdline_args():
			if arg.get_extension().to_lower() == "pxo":
				_on_OpenSprite_file_selected(arg)
			else:
				$ImportSprites._on_ImportSprites_files_selected([arg])

	Global.window_title = "(" + tr("untitled") + ") - Pixelorama"

	Global.layers[0][0] = tr("Layer") + " 0"
	Global.layers_container.get_child(0).label.text = Global.layers[0][0]
	Global.layers_container.get_child(0).line_edit.text = Global.layers[0][0]

	Import.import_brushes("Brushes")

	Global.left_color_picker.get_picker().presets_visible = false
	Global.right_color_picker.get_picker().presets_visible = false
	$QuitAndSaveDialog.add_button("Save & Exit", false, "Save")
	$QuitAndSaveDialog.get_ok().text = "Exit without saving"


	if not Global.config_cache.has_section_key("preferences", "startup"):
		Global.config_cache.set_value("preferences", "startup", true)
	if Global.config_cache.get_value("preferences", "startup"):
		# Wait for the window to adjust itself, so the popup is correctly centered
		yield(get_tree().create_timer(0.01), "timeout")
		$SplashDialog.popup_centered() # Splash screen
	else:
		Global.can_draw = true

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
		Global.undo_redo.redo()
		redone = false

	if Global.has_focus:
		for t in tools: # Handle tool shortcuts
			if event.is_action_pressed(t[2]): # Shortcut for right button (with Alt)
				_on_Tool_pressed(t[0], false, false)
			elif event.is_action_pressed(t[1]): # Shortcut for left button
				_on_Tool_pressed(t[0], false, true)

func _notification(what : int) -> void:
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST: # Handle exit
		show_quit_dialog()

func file_menu_id_pressed(id : int) -> void:
	match id:
		0: # New
			$CreateNewImage.popup_centered()
			Global.can_draw = false
		1: # Open
			$OpenSprite.popup_centered()
			Global.can_draw = false
			opensprite_file_selected = false
		2: # Save
			is_quitting_on_save = false
			if current_save_path == "":
				$SaveSprite.popup_centered()
				Global.can_draw = false
			else:
				_on_SaveSprite_file_selected(current_save_path)
		3: # Save as
			is_quitting_on_save = false
			$SaveSprite.popup_centered()
			Global.can_draw = false
		4: # Import
			$ImportSprites.popup_centered()
			Global.can_draw = false
			opensprite_file_selected = false
		5: # Export
			if $ExportDialog.was_exported == false:
				$ExportDialog.popup_centered()
				Global.can_draw = false
			else:
				$ExportDialog.external_export()
		6: # Export as
			$ExportDialog.popup_centered()
			Global.can_draw = false
		7: # Quit
			show_quit_dialog()

func edit_menu_id_pressed(id : int) -> void:
	match id:
		0: # Undo
			Global.undo_redo.undo()
		1: # Redo
			redone = true
			Global.undo_redo.redo()
			redone = false
		2: # Clear selection
			Global.canvas.handle_undo("Rectangle Select")
			Global.selection_rectangle.polygon[0] = Vector2.ZERO
			Global.selection_rectangle.polygon[1] = Vector2.ZERO
			Global.selection_rectangle.polygon[2] = Vector2.ZERO
			Global.selection_rectangle.polygon[3] = Vector2.ZERO
			Global.selected_pixels.clear()
			Global.canvas.handle_redo("Rectangle Select")
		3: # Preferences
			$PreferencesDialog.popup_centered(Vector2(400, 280))
			Global.can_draw = false

func view_menu_id_pressed(id : int) -> void:
	match id:
		0: # Tile mode
			Global.tile_mode = !Global.tile_mode
			view_menu.set_item_checked(0, Global.tile_mode)
		1: # Show grid
			Global.draw_grid = !Global.draw_grid
			view_menu.set_item_checked(1, Global.draw_grid)
		2: # Show rulers
			Global.show_rulers = !Global.show_rulers
			view_menu.set_item_checked(2, Global.show_rulers)
			Global.horizontal_ruler.visible = Global.show_rulers
			Global.vertical_ruler.visible = Global.show_rulers
		3: # Show guides
			Global.show_guides = !Global.show_guides
			view_menu.set_item_checked(3, Global.show_guides)
			for canvas in Global.canvases:
				for guide in canvas.get_children():
					if guide is Guide:
						guide.visible = Global.show_guides
		4: # Show animation timeline
			Global.show_animation_timeline = !Global.show_animation_timeline
			view_menu.set_item_checked(4, Global.show_animation_timeline)
			Global.animation_timeline.visible = Global.show_animation_timeline

	Global.canvas.update()

func image_menu_id_pressed(id : int) -> void:
	if Global.layers[Global.current_layer][2]: # No changes if the layer is locked
		return
	match id:
		0: # Scale Image
			$ScaleImage.popup_centered()
			Global.can_draw = false
		1: # Crop Image
			# Use first layer as a starting rectangle
			var used_rect : Rect2 = Global.canvas.layers[0][0].get_used_rect()
			# However, if first layer is empty, loop through all layers until we find one that isn't
			var i := 0
			while(i < Global.canvas.layers.size() - 1 and Global.canvas.layers[i][0].get_used_rect() == Rect2(0, 0, 0, 0)):
				i += 1
				used_rect = Global.canvas.layers[i][0].get_used_rect()

			# Merge all layers with content
			for j in range(Global.canvas.layers.size() - 1, i, -1):
					if Global.canvas.layers[j][0].get_used_rect() != Rect2(0, 0, 0, 0):
						used_rect = used_rect.merge(Global.canvas.layers[j][0].get_used_rect())

			# If no layer has any content, just return
			if used_rect == Rect2(0, 0, 0, 0):
				return

			var width := used_rect.size.x
			var height := used_rect.size.y
			Global.undos += 1
			Global.undo_redo.create_action("Scale")
			Global.undo_redo.add_do_property(Global.canvas, "size", Vector2(width, height).floor())
			# Loop through all the layers to crop them
			for j in range(Global.canvas.layers.size() - 1, -1, -1):
				var sprite : Image = Global.canvas.layers[j][0].get_rect(used_rect)
				Global.undo_redo.add_do_property(Global.canvas.layers[j][0], "data", sprite.data)
				Global.undo_redo.add_undo_property(Global.canvas.layers[j][0], "data", Global.canvas.layers[j][0].data)

			Global.undo_redo.add_undo_property(Global.canvas, "size", Global.canvas.size)
			Global.undo_redo.add_undo_method(Global, "undo", [Global.canvas])
			Global.undo_redo.add_do_method(Global, "redo", [Global.canvas])
			Global.undo_redo.commit_action()
		2: # Flip Horizontal
			var canvas : Canvas = Global.canvas
			canvas.handle_undo("Draw")
			canvas.layers[Global.current_layer][0].unlock()
			canvas.layers[Global.current_layer][0].flip_x()
			canvas.layers[Global.current_layer][0].lock()
			canvas.handle_redo("Draw")
		3: # Flip Vertical
			var canvas : Canvas = Global.canvas
			canvas.handle_undo("Draw")
			canvas.layers[Global.current_layer][0].unlock()
			canvas.layers[Global.current_layer][0].flip_y()
			canvas.layers[Global.current_layer][0].lock()
			canvas.handle_redo("Draw")
		4: # Rotate
			var image : Image = Global.canvas.layers[Global.current_layer][0]
			$RotateImage.set_sprite(image)
			$RotateImage.popup_centered()
		5: # Invert Colors
			var image : Image = Global.canvas.layers[Global.current_layer][0]
			Global.canvas.handle_undo("Draw")
			for xx in image.get_size().x:
				for yy in image.get_size().y:
					var px_color = image.get_pixel(xx, yy).inverted()
					if px_color.a == 0:
						continue
					image.set_pixel(xx, yy, px_color)
			Global.canvas.handle_redo("Draw")
		6: # Desaturation
			var image : Image = Global.canvas.layers[Global.current_layer][0]
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
		7: # Outline
			$OutlineDialog.popup_centered()

func help_menu_id_pressed(id : int) -> void:
	match id:
		0: # Splash Screen
			$SplashDialog.popup_centered()
			Global.can_draw = false
		1: # Issue Tracker
			OS.shell_open("https://github.com/Orama-Interactive/Pixelorama/issues")
		2: # Changelog
			OS.shell_open("https://github.com/Orama-Interactive/Pixelorama/blob/master/Changelog.md#v062---17-02-2020")
		3: # About Pixelorama
			$AboutDialog.popup_centered()
			Global.can_draw = false

func _on_OpenSprite_file_selected(path : String) -> void:
	var file := File.new()
	var err := file.open(path, File.READ)
	if err != OK: # An error occured
		file.close()
		OS.alert("Can't load file")
		return

	var current_version : String = ProjectSettings.get_setting("application/config/Version")
	var current_version_number = float(current_version.substr(1, 3)) # Example, "0.6"
	var version := file.get_line()
	var version_number = float(version.substr(1, 3)) # Example, "0.6"
	if current_version_number < 0.5:
		OS.alert("File is from an older version of Pixelorama, as such it might not work properly")

	var frame := 0
	Global.layers.clear()
	if (version_number - 0.01) > 0.6:
		var global_layer_line := file.get_line()
		while global_layer_line == ".":
			var layer_name := file.get_line()
			var layer_visibility := file.get_8()
			var layer_lock := file.get_8()
			var layer_new_frames_linked := file.get_8()
			var linked_frames = file.get_var()

			# Store [Layer name (0), Layer visibility boolean (1), Layer lock boolean (2), Frame container (3),
			# will new frames be linked boolean (4), Array of linked frames (5)]
			Global.layers.append([layer_name, layer_visibility, layer_lock, HBoxContainer.new(), layer_new_frames_linked, linked_frames])
			global_layer_line = file.get_line()

	var frame_line := file.get_line()
	clear_canvases()
	while frame_line == "--": # Load frames
		var canvas : Canvas = load("res://Prefabs/Canvas.tscn").instance()
		Global.canvas = canvas
		var width := file.get_16()
		var height := file.get_16()

		var layer_line := file.get_line()
		while layer_line == "-": # Load layers
			var buffer := file.get_buffer(width * height * 4)
			if version_number < (0.7 - 0.01):
				var layer_name_old_version = file.get_line()
				if frame == 0:
					# Store [Layer name (0), Layer visibility boolean (1), Layer lock boolean (2), Frame container (3),
					# will new frames be linked boolean (4), Array of linked frames (5)]
					Global.layers.append([layer_name_old_version, true, false, HBoxContainer.new(), false, []])
			var layer_transparency := 1.0
			if version_number > 0.5:
				layer_transparency = file.get_float()
			var image := Image.new()
			image.create_from_data(width, height, false, Image.FORMAT_RGBA8, buffer)
			image.lock()
			var tex := ImageTexture.new()
			tex.create_from_image(image, 0)
			canvas.layers.append([image, tex, layer_transparency])
			layer_line = file.get_line()

		var guide_line := file.get_line() # "guideline" no pun intended
		while guide_line == "|": # Load guides
			var guide := Guide.new()
			guide.default_color = Color.purple
			guide.type = file.get_8()
			if guide.type == guide.Types.HORIZONTAL:
				guide.add_point(Vector2(-99999, file.get_16()))
				guide.add_point(Vector2(99999, file.get_16()))
			else:
				guide.add_point(Vector2(file.get_16(), -99999))
				guide.add_point(Vector2(file.get_16(), 99999))
			guide.has_focus = false
			canvas.add_child(guide)
			guide_line = file.get_line()

		canvas.size = Vector2(width, height)
		Global.canvases.append(canvas)
		canvas.frame = frame
		Global.canvas_parent.add_child(canvas)
		frame_line = file.get_line()
		frame += 1

	Global.canvases = Global.canvases # Just to call Global.canvases_changed
	Global.current_frame = frame - 1
	Global.layers = Global.layers # Just to call Global.layers_changed
	# Load tool options
	Global.left_color_picker.color = file.get_var()
	Global.right_color_picker.color = file.get_var()
	Global.left_brush_size = file.get_8()
	Global.left_brush_size_edit.value = Global.left_brush_size
	Global.right_brush_size = file.get_8()
	Global.right_brush_size_edit.value = Global.right_brush_size
	if version_number < (0.7 - 0.01):
		var left_palette = file.get_var()
		var right_palette = file.get_var()
		for color in left_palette:
			Global.left_color_picker.get_picker().add_preset(color)
		for color in right_palette:
			Global.right_color_picker.get_picker().add_preset(color)

	# Load custom brushes
	Global.custom_brushes.resize(Global.brushes_from_files)
	Global.remove_brush_buttons()

	var brush_line := file.get_line()
	while brush_line == "/":
		var b_width := file.get_16()
		var b_height := file.get_16()
		var buffer := file.get_buffer(b_width * b_height * 4)
		var image := Image.new()
		image.create_from_data(b_width, b_height, false, Image.FORMAT_RGBA8, buffer)
		Global.custom_brushes.append(image)
		Global.create_brush_button(image)
		brush_line = file.get_line()

	file.close()

	current_save_path = path
	$SaveSprite.current_path = path
	$ExportDialog.file_name = path.get_file().trim_suffix(".pxo")
	$ExportDialog.directory_path = path.get_base_dir()
	$ExportDialog.was_exported = false
	file_menu.set_item_text(2, tr("Save") + " %s" % path.get_file())
	file_menu.set_item_text(5, tr("Export"))

	Global.window_title = path.get_file() + " - Pixelorama"


func _on_SaveSprite_file_selected(path : String) -> void:
	current_save_path = path
	$ExportDialog.file_name = path.get_file().trim_suffix(".pxo")
	$ExportDialog.directory_path = path.get_base_dir()
	$ExportDialog.was_exported = false
	file_menu.set_item_text(2, tr("Save") + " %s" % path.get_file())
	var file := File.new()
	var err := file.open(path, File.WRITE)
	if err == OK:
		file.store_line(ProjectSettings.get_setting("application/config/Version"))

		for layer in Global.layers: # Store Global layers
			file.store_line(".")
			file.store_line(layer[0]) # Layer name
			file.store_8(layer[1]) # Layer visibility
			file.store_8(layer[2]) # Layer lock
			file.store_8(layer[4]) # Future frames linked
			file.store_var(layer[5]) # Linked frames
		file.store_line("END_GLOBAL_LAYERS")

		for canvas in Global.canvases: # Store frames
			file.store_line("--")
			file.store_16(canvas.size.x)
			file.store_16(canvas.size.y)
			for layer in canvas.layers: # Store canvas layers
				file.store_line("-")
				file.store_buffer(layer[0].get_data())
				file.store_float(layer[2]) # Layer transparency
			file.store_line("END_LAYERS")

			for child in canvas.get_children(): # Store guides
				if child is Guide:
					file.store_line("|")
					file.store_8(child.type)
					if child.type == child.Types.HORIZONTAL:
						file.store_16(child.points[0].y)
						file.store_16(child.points[1].y)
					else:
						file.store_16(child.points[1].x)
						file.store_16(child.points[0].x)
			file.store_line("END_GUIDES")
		file.store_line("END_FRAMES")

		# Save tool options
		var left_color : Color = Global.left_color_picker.color
		var right_color : Color = Global.right_color_picker.color
		var left_brush_size : int = Global.left_brush_size
		var right_brush_size : int = Global.right_brush_size
		file.store_var(left_color)
		file.store_var(right_color)
		file.store_8(left_brush_size)
		file.store_8(right_brush_size)
		# Save custom brushes
		for i in range(Global.brushes_from_files, Global.custom_brushes.size()):
			var brush = Global.custom_brushes[i]
			file.store_line("/")
			file.store_16(brush.get_size().x)
			file.store_16(brush.get_size().y)
			file.store_buffer(brush.get_data())
		file.store_line("END_BRUSHES")
	file.close()
	if !Global.saved:
		Global.saved = true
		Global.window_title = Global.window_title.rstrip("(*)")

	Global.notification_label("File saved")
	if is_quitting_on_save:
		_on_QuitDialog_confirmed()

func clear_canvases() -> void:
	for child in Global.canvas_parent.get_children():
		if child is Canvas:
			child.queue_free()
	Global.canvases.clear()
	current_save_path = ""
	file_menu.set_item_text(2, "Save")
	file_menu.set_item_text(5, "Export...")
	Global.window_title = "(" + tr("untitled") + ") - Pixelorama"
	Global.undo_redo.clear_history(false)

func _on_ImportSprites_popup_hide() -> void:
	if !opensprite_file_selected:
		Global.can_draw = true

func _on_ViewportContainer_mouse_entered() -> void:
	Global.has_focus = true

func _on_ViewportContainer_mouse_exited() -> void:
	Global.has_focus = false

func _can_draw_true() -> void:
	Global.can_draw = true
func _can_draw_false() -> void:
	Global.can_draw = false

func _on_Tool_pressed(tool_pressed : BaseButton, mouse_press := true, key_for_left := true) -> void:
	var current_action := tool_pressed.name
	if (mouse_press and Input.is_action_just_released("left_mouse")) or (!mouse_press and key_for_left):
		Global.current_left_tool = current_action

		# Start from 3, so the label and checkboxes won't get invisible
		for i in range(3, Global.left_tool_options_container.get_child_count()):
			Global.left_tool_options_container.get_child(i).visible = false

		# Tool options visible depending on the selected tool
		if current_action == "Pencil":
			Global.left_brush_type_container.visible = true
#			Global.left_brush_size_container.visible = true
			Global.left_mirror_container.visible = true
			if Global.current_left_brush_type == Global.Brush_Types.FILE or Global.current_left_brush_type == Global.Brush_Types.CUSTOM or Global.current_left_brush_type == Global.Brush_Types.RANDOM_FILE:
				Global.left_color_interpolation_container.visible = true
		elif current_action == "Eraser":
			Global.left_brush_type_container.visible = true
#			Global.left_brush_size_container.visible = true
			Global.left_mirror_container.visible = true
		elif current_action == "Bucket":
			Global.left_fill_area_container.visible = true
			Global.left_mirror_container.visible = true
			if Global.current_left_brush_type == Global.Brush_Types.FILE or Global.current_left_brush_type == Global.Brush_Types.CUSTOM or Global.current_left_brush_type == Global.Brush_Types.RANDOM_FILE:
				Global.left_color_interpolation_container.visible = true
		elif current_action == "LightenDarken":
#			Global.left_brush_size_container.visible = true
			Global.left_ld_container.visible = true
			Global.left_mirror_container.visible = true
		elif current_action == "ColorPicker":
			Global.left_colorpicker_container.visible = true

	elif (mouse_press and Input.is_action_just_released("right_mouse")) or (!mouse_press and !key_for_left):
		Global.current_right_tool = current_action
		# Start from 3, so the label and checkboxes won't get invisible
		for i in range(3, Global.right_tool_options_container.get_child_count()):
			Global.right_tool_options_container.get_child(i).visible = false

		# Tool options visible depending on the selected tool
		if current_action == "Pencil":
			Global.right_brush_type_container.visible = true
#			Global.right_brush_size_container.visible = true
			Global.right_mirror_container.visible = true
			if Global.current_right_brush_type == Global.Brush_Types.FILE or Global.current_right_brush_type == Global.Brush_Types.CUSTOM or Global.current_right_brush_type == Global.Brush_Types.RANDOM_FILE:
				Global.right_color_interpolation_container.visible = true
		elif current_action == "Eraser":
			Global.right_brush_type_container.visible = true
#			Global.right_brush_size_container.visible = true
			Global.right_mirror_container.visible = true
		elif current_action == "Bucket":
			Global.right_fill_area_container.visible = true
			Global.right_mirror_container.visible = true
			if Global.current_right_brush_type == Global.Brush_Types.FILE or Global.current_right_brush_type == Global.Brush_Types.CUSTOM or Global.current_right_brush_type == Global.Brush_Types.RANDOM_FILE:
				Global.right_color_interpolation_container.visible = true
		elif current_action == "LightenDarken":
#			Global.right_brush_size_container.visible = true
			Global.right_ld_container.visible = true
			Global.right_mirror_container.visible = true
		elif current_action == "ColorPicker":
			Global.right_colorpicker_container.visible = true

	for t in tools:
		var tool_name : String = t[0].name
		if tool_name == Global.current_left_tool and tool_name == Global.current_right_tool:
			t[0].texture_normal = load("res://Assets/Graphics/%s Themes/Tools/%s_l_r.png" % [Global.theme_type, tool_name])
		elif tool_name == Global.current_left_tool:
			t[0].texture_normal = load("res://Assets/Graphics/%s Themes/Tools/%s_l.png" % [Global.theme_type, tool_name])
		elif tool_name == Global.current_right_tool:
			t[0].texture_normal = load("res://Assets/Graphics/%s Themes/Tools/%s_r.png" % [Global.theme_type, tool_name])
		else:
			t[0].texture_normal = load("res://Assets/Graphics/%s Themes/Tools/%s.png" % [Global.theme_type, tool_name])

	Global.left_cursor_tool_texture.create_from_image(load("res://Assets/Graphics/Tool Cursors/%s_Cursor.png" % Global.current_left_tool), 0)
	Global.right_cursor_tool_texture.create_from_image(load("res://Assets/Graphics/Tool Cursors/%s_Cursor.png" % Global.current_right_tool), 0)


func _on_LeftBrushTypeButton_pressed() -> void:
	Global.brushes_popup.popup(Rect2(Global.left_brush_type_button.rect_global_position, Vector2(226, 72)))
	Global.brush_type_window_position = "left"

func _on_RightBrushTypeButton_pressed() -> void:
	Global.brushes_popup.popup(Rect2(Global.right_brush_type_button.rect_global_position, Vector2(226, 72)))
	Global.brush_type_window_position = "right"

func _on_LeftBrushSizeEdit_value_changed(value) -> void:
	Global.left_brush_size_edit.value = value
	Global.left_brush_size_slider.value = value
	var new_size = int(value)
	Global.left_brush_size = new_size
	update_left_custom_brush()

func _on_RightBrushSizeEdit_value_changed(value) -> void:
	Global.right_brush_size_edit.value = value
	Global.right_brush_size_slider.value = value
	var new_size = int(value)
	Global.right_brush_size = new_size
	update_right_custom_brush()


func _on_ColorSwitch_pressed() -> void:
	var temp: Color = Global.left_color_picker.color
	Global.left_color_picker.color = Global.right_color_picker.color
	Global.right_color_picker.color = temp
	update_left_custom_brush()
	update_right_custom_brush()

func _on_ColorDefaults_pressed() -> void:
	Global.left_color_picker.color = Color.black
	Global.right_color_picker.color = Color.white
	update_left_custom_brush()
	update_right_custom_brush()

# warning-ignore:unused_argument
func _on_LeftColorPickerButton_color_changed(color : Color) -> void:
	# If the color changed while it's on full transparency, make it opaque (GH issue #54)
	if color.a == 0:
		if previous_left_color.r != color.r or previous_left_color.g != color.g or previous_left_color.b != color.b:
			Global.left_color_picker.color.a = 1
	update_left_custom_brush()
	previous_left_color = color

# warning-ignore:unused_argument
func _on_RightColorPickerButton_color_changed(color : Color) -> void:
	# If the color changed while it's on full transparency, make it opaque (GH issue #54)
	if color.a == 0:
		if previous_right_color.r != color.r or previous_right_color.g != color.g or previous_right_color.b != color.b:
			Global.right_color_picker.color.a = 1
	update_right_custom_brush()
	previous_right_color = color

# warning-ignore:unused_argument
func _on_LeftInterpolateFactor_value_changed(value : float) -> void:
	Global.left_interpolate_spinbox.value = value
	Global.left_interpolate_slider.value = value
	update_left_custom_brush()

# warning-ignore:unused_argument
func _on_RightInterpolateFactor_value_changed(value : float) -> void:
	Global.right_interpolate_spinbox.value = value
	Global.right_interpolate_slider.value = value
	update_right_custom_brush()

func update_left_custom_brush() -> void:
	Global.update_left_custom_brush()
func update_right_custom_brush() -> void:
	Global.update_right_custom_brush()

func _on_LeftFillAreaOptions_item_selected(ID : int) -> void:
	Global.left_fill_area = ID

func _on_RightFillAreaOptions_item_selected(ID : int) -> void:
	Global.right_fill_area = ID

func _on_LeftLightenDarken_item_selected(ID : int) -> void:
	Global.left_ld = ID
func _on_LeftLDAmountSpinbox_value_changed(value : float) -> void:
	Global.left_ld_amount = value / 100
	Global.left_ld_amount_slider.value = value
	Global.left_ld_amount_spinbox.value = value

func _on_RightLightenDarken_item_selected(ID : int) -> void:
	Global.right_ld = ID
func _on_RightLDAmountSpinbox_value_changed(value : float) -> void:
	Global.right_ld_amount = value / 100
	Global.right_ld_amount_slider.value = value
	Global.right_ld_amount_spinbox.value = value

func _on_LeftForColorOptions_item_selected(ID : int) -> void:
	Global.left_color_picker_for = ID

func _on_RightForColorOptions_item_selected(ID : int) -> void:
	Global.right_color_picker_for = ID

func _on_LeftHorizontalMirroring_toggled(button_pressed) -> void:
	Global.left_horizontal_mirror = button_pressed
func _on_LeftVerticalMirroring_toggled(button_pressed) -> void:
	Global.left_vertical_mirror = button_pressed

func _on_RightHorizontalMirroring_toggled(button_pressed) -> void:
	Global.right_horizontal_mirror = button_pressed
func _on_RightVerticalMirroring_toggled(button_pressed) -> void:
	Global.right_vertical_mirror = button_pressed

func _on_OpacitySlider_value_changed(value) -> void:
	Global.canvas.layers[Global.current_layer][4] = value / 100
	Global.layer_opacity_slider.value = value
	Global.layer_opacity_spinbox.value = value
	Global.canvas.update()

func show_quit_dialog() -> void:
	if !$QuitDialog.visible:
		if Global.saved:
			$QuitDialog.call_deferred("popup_centered")
		else:
			$QuitAndSaveDialog.call_deferred("popup_centered")
	Global.can_draw = false

func _on_QuitAndSaveDialog_custom_action(action : String) -> void:
	if action == "Save":
		is_quitting_on_save = true
		$SaveSprite.popup_centered()
		$QuitDialog.hide()
		Global.can_draw = false

func _on_QuitDialog_confirmed() -> void:
	# Darken the UI to denote that the application is currently exiting
	# (it won't respond to user input in this state).
	modulate = Color(0.5, 0.5, 0.5)

	get_tree().quit()
