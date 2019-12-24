extends Control

var current_save_path := ""
var current_export_path := ""
var opensprite_file_selected := false
var view_menu : PopupMenu
var tools := []
var import_as_new_frame : CheckBox
var export_all_frames : CheckBox
var export_as_single_file : CheckBox
var export_vertical_spritesheet : CheckBox
var redone := false
var fps := 6.0
var animation_loop := 0 #0 is no loop, 1 is cycle loop, 2 is ping-pong loop
var animation_forward := true
var previous_left_color := Color.black
var previous_right_color := Color.white

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	OS.set_window_title("(untitled) - Pixelorama")
	# Set a minimum window size to prevent UI elements from collapsing on each other.
	# This property is only available in 3.2alpha or later, so use `set()` to fail gracefully if it doesn't exist.
	OS.set("min_window_size", Vector2(1152, 648))

	# `TranslationServer.get_loaded_locales()` was added in 3.2beta and in 3.1.2
	# The `has_method()` check and the `else` branch can be removed once 3.2 is released.
	if TranslationServer.has_method("get_loaded_locales"):
		Global.loaded_locales = TranslationServer.get_loaded_locales()
	else:
		# Hardcoded list of locales
		Global.loaded_locales = ["de", "el", "en", "fr", "pl", "pt_BR", "ru", "zh_TW"]

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
		"Import PNG..." : KEY_MASK_CMD + KEY_I,
		"Export PNG..." : KEY_MASK_CMD + KEY_E,
		"Export PNG as..." : KEY_MASK_SHIFT + KEY_MASK_CMD + KEY_E,
		"Quit" : KEY_MASK_CMD + KEY_Q
		}
	var edit_menu_items := {
		"Undo" : KEY_MASK_CMD + KEY_Z,
		"Redo" : KEY_MASK_CMD + KEY_Y,
		"Scale Image" : 0,
		"Crop Image" : 0,
		"Clear Selection" : 0,
		"Flip Horizontal" : KEY_MASK_SHIFT + KEY_H,
		"Flip Vertical" : KEY_MASK_SHIFT + KEY_V,
		"Preferences" : 0
		}
	var view_menu_items := {
		"Tile Mode" : KEY_MASK_CMD + KEY_T,
		"Show Grid" : KEY_MASK_CMD + KEY_G,
		"Show Rulers" : KEY_MASK_CMD + KEY_R,
		"Show Guides" : KEY_MASK_CMD + KEY_F
		}
	var image_menu_items := {
		"Invert Colors" : 0,
		"Outline" : 0
		}
	var help_menu_items := {
		"About Pixelorama" : 0
		}

	# Load language
	if Global.config_cache.has_section_key("preferences", "locale"):
		var saved_locale : String = Global.config_cache.get_value("preferences", "locale")
		TranslationServer.set_locale(saved_locale)

		# Set the language option menu's default selected option to the loaded locale
		var locale_index := Global.loaded_locales.find(saved_locale)
		$PreferencesDialog/VBoxContainer/OptionsContainer/LanguageOption.selected = locale_index + 1
	else: # If the user doesn't have a language preference, set it to their OS' locale
		TranslationServer.set_locale(OS.get_locale())

	if TranslationServer.get_locale() == "zh_TW":
		theme.default_font = preload("res://Assets/Fonts/NotoSansCJKtc-Regular.tres")
	else:
		theme.default_font = preload("res://Assets/Fonts/Roboto-Regular.tres")


	var file_menu : PopupMenu = Global.file_menu.get_popup()
	var edit_menu : PopupMenu = Global.edit_menu.get_popup()
	view_menu = Global.view_menu.get_popup()
	var image_menu : PopupMenu = Global.image_menu.get_popup()
	var help_menu : PopupMenu = Global.help_menu.get_popup()
	var add_palette_menu : PopupMenu = Global.add_palette_button.get_child(0)

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
	view_menu.set_item_checked(2, true) #Show Rulers
	view_menu.set_item_checked(3, true) #Show Guides
	view_menu.hide_on_checkable_item_selection = false
	i = 0
	for item in image_menu_items.keys():
		image_menu.add_item(item, i, image_menu_items[item])
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
	add_palette_menu.connect("id_pressed", self, "add_palette_menu_id_pressed")

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

	Global.left_color_picker.get_picker().move_child(Global.left_color_picker.get_picker().get_child(0), 1)
	Global.right_color_picker.get_picker().move_child(Global.right_color_picker.get_picker().get_child(0), 1)

	# Options for Import
	import_as_new_frame = CheckBox.new()
	import_as_new_frame.text = tr("IMPORT_FILE_LABEL")
	$ImportSprites.get_vbox().add_child(import_as_new_frame)

	# Options for Export
	var export_project_hbox := HBoxContainer.new()
	export_all_frames = CheckBox.new()
	export_all_frames.text = tr("EXPORT_ALLFRAMES_LABEL")
	export_as_single_file = CheckBox.new()
	export_as_single_file.text = tr("EXPORT_FRAMES_ASFILE_LABEL")
	export_vertical_spritesheet = CheckBox.new()
	export_vertical_spritesheet.text = tr("EXPORT_VERTICAL_SPRITESHEET_LABEL")
	$ExportSprites.get_vbox().add_child(export_project_hbox)
	export_project_hbox.add_child(export_all_frames)
	export_project_hbox.add_child(export_as_single_file)
	export_project_hbox.add_child(export_vertical_spritesheet)

	var path := "Brushes"
	var brushes_dir := Directory.new()
	if !brushes_dir.dir_exists(path):
		brushes_dir.make_dir(path)

	brushes_dir.open(path)
	brushes_dir.list_dir_begin(true, true)
	var file := brushes_dir.get_next()
	while file != "":
		if file.get_extension().to_upper() == "PNG":
			var image := Image.new()
			var err := image.load(path.plus_file(file))
			if err == OK:
				image.convert(Image.FORMAT_RGBA8)
				Global.custom_brushes.append(image)
				Global.create_brush_button(image, Global.BRUSH_TYPES.FILE, file.trim_suffix(".png"))
		file = brushes_dir.get_next()
	brushes_dir.list_dir_end()
	Global.brushes_from_files = Global.custom_brushes.size()

func _input(event : InputEvent) -> void:
	Global.left_cursor.position = get_global_mouse_position() + Vector2(-32, 32)
	Global.left_cursor.texture = Global.left_cursor_tool_texture
	Global.right_cursor.position = get_global_mouse_position() + Vector2(32, 32)
	Global.right_cursor.texture = Global.right_cursor_tool_texture
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
		$QuitDialog.call_deferred("popup_centered")
		Global.can_draw = false

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
			if current_save_path == "":
				$SaveSprite.popup_centered()
				Global.can_draw = false
			else:
				_on_SaveSprite_file_selected(current_save_path)
		3: # Save as
			$SaveSprite.popup_centered()
			Global.can_draw = false
		4: # Import
			$ImportSprites.popup_centered()
			Global.can_draw = false
			opensprite_file_selected = false
		5: # Export
			if current_export_path == "":
				$ExportSprites.popup_centered()
				Global.can_draw = false
			else:
				export_project()
		6: # Export as
			$ExportSprites.popup_centered()
			Global.can_draw = false
		7: # Quit
			$QuitDialog.popup_centered()
			Global.can_draw = false

func edit_menu_id_pressed(id : int) -> void:
	match id:
		0: # Undo
			Global.undo_redo.undo()
		1: # Redo
			redone = true
			Global.undo_redo.redo()
			redone = false
		2: # Scale Image
			$ScaleImage.popup_centered()
			Global.can_draw = false
		3: # Crop Image
			# Use first layer as a starting rectangle
			var used_rect : Rect2 = Global.canvas.layers[0][0].get_used_rect()
			# However, if first layer is empty, loop through all layers until we find one that isn't
			var i := 0
			while(i < Global.canvas.layers.size() - 1 && Global.canvas.layers[i][0].get_used_rect() == Rect2(0, 0, 0, 0)):
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
		4: # Clear selection
			Global.canvas.handle_undo("Rectangle Select")
			Global.selection_rectangle.polygon[0] = Vector2.ZERO
			Global.selection_rectangle.polygon[1] = Vector2.ZERO
			Global.selection_rectangle.polygon[2] = Vector2.ZERO
			Global.selection_rectangle.polygon[3] = Vector2.ZERO
			Global.selected_pixels.clear()
			Global.canvas.handle_redo("Rectangle Select")
		5: # Flip Horizontal
			var canvas : Canvas = Global.canvas
			canvas.handle_undo("Draw")
			canvas.layers[canvas.current_layer_index][0].unlock()
			canvas.layers[canvas.current_layer_index][0].flip_x()
			canvas.layers[canvas.current_layer_index][0].lock()
			canvas.handle_redo("Draw")
		6: # Flip Vertical
			var canvas : Canvas = Global.canvas
			canvas.handle_undo("Draw")
			canvas.layers[canvas.current_layer_index][0].unlock()
			canvas.layers[canvas.current_layer_index][0].flip_y()
			canvas.layers[canvas.current_layer_index][0].lock()
			canvas.handle_redo("Draw")
		7: # Preferences
			$PreferencesDialog.popup_centered()
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

func image_menu_id_pressed(id : int) -> void:
	match id:
		0: # Invert Colors
			var image : Image = Global.canvas.layers[Global.canvas.current_layer_index][0]
			Global.canvas.handle_undo("Draw")
			for xx in image.get_size().x:
				for yy in image.get_size().y:
					var px_color = image.get_pixel(xx, yy).inverted()
					if px_color.a == 0:
						continue
					image.set_pixel(xx, yy, px_color)
			Global.canvas.handle_redo("Draw")
		1: # Outline
			$OutlineDialog.popup_centered()

func help_menu_id_pressed(id : int) -> void:
	match id:
		0: # About Pixelorama
			$AboutDialog.popup_centered()
			Global.can_draw = false

func _on_CreateNewImage_confirmed() -> void:
	var width : int = $CreateNewImage/VBoxContainer/OptionsContainer/WidthValue.value
	var height : int = $CreateNewImage/VBoxContainer/OptionsContainer/HeightValue.value
	var fill_color : Color = $CreateNewImage/VBoxContainer/OptionsContainer/FillColor.color
	clear_canvases()
	Global.canvas = load("res://Prefabs/Canvas.tscn").instance()
	Global.canvas.size = Vector2(width, height).floor()

	Global.canvases.append(Global.canvas)
	Global.canvas_parent.add_child(Global.canvas)
	Global.current_frame = 0
	if fill_color.a > 0:
		Global.canvas.layers[0][0].fill(fill_color)
		Global.canvas.layers[0][0].lock()
		Global.canvas.update_texture(0)
	Global.undo_redo.clear_history(false)

func _on_OpenSprite_file_selected(path : String) -> void:
	var file := File.new()
	var err := file.open(path, File.READ)
	if err != OK: #An error occured
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
	var frame_line := file.get_line()
	clear_canvases()
	while frame_line == "--": #Load frames
		var canvas : Canvas = load("res://Prefabs/Canvas.tscn").instance()
		Global.canvas = canvas
		var width := file.get_16()
		var height := file.get_16()

		var layer_line := file.get_line()
		while layer_line == "-": #Load layers
			var buffer := file.get_buffer(width * height * 4)
			var layer_name := file.get_line()
			var layer_transparency := 1.0
			if version_number > 0.5:
				layer_transparency = file.get_float()
			var image := Image.new()
			image.create_from_data(width, height, false, Image.FORMAT_RGBA8, buffer)
			image.lock()
			var tex := ImageTexture.new()
			tex.create_from_image(image, 0)
			canvas.layers.append([image, tex, layer_name, true, layer_transparency])
			layer_line = file.get_line()

		var guide_line := file.get_line() #"guideline" no pun intended
		while guide_line == "|": #Load guides
			var guide := Guide.new()
			guide.default_color = Color.purple
			guide.type = file.get_8()
			if guide.type == guide.TYPE.HORIZONTAL:
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

	Global.current_frame = frame - 1
	#Load tool options
	Global.left_color_picker.color = file.get_var()
	Global.right_color_picker.color = file.get_var()
	Global.left_brush_size = file.get_8()
	Global.left_brush_size_edit.value = Global.left_brush_size
	Global.right_brush_size = file.get_8()
	Global.right_brush_size_edit.value = Global.right_brush_size
	var left_palette = file.get_var()
	var right_palette = file.get_var()
	for color in left_palette:
		Global.left_color_picker.get_picker().add_preset(color)
	for color in right_palette:
		Global.right_color_picker.get_picker().add_preset(color)

	#Load custom brushes
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
	Global.undo_redo.clear_history(false)

	OS.set_window_title(path.get_file() + " - Pixelorama")


func _on_SaveSprite_file_selected(path) -> void:
	current_save_path = path
	var file := File.new()
	var err := file.open(path, File.WRITE)
	if err == 0:
		file.store_line(ProjectSettings.get_setting("application/config/Version"))
		for canvas in Global.canvases: # Store frames
			file.store_line("--")
			file.store_16(canvas.size.x)
			file.store_16(canvas.size.y)
			for layer in canvas.layers: # Store layers
				file.store_line("-")
				file.store_buffer(layer[0].get_data())
				file.store_line(layer[2]) # Layer name
				file.store_float(layer[4]) # Layer transparency
			file.store_line("END_LAYERS")

			for child in canvas.get_children(): #Store guides
				if child is Guide:
					file.store_line("|")
					file.store_8(child.type)
					if child.type == child.TYPE.HORIZONTAL:
						file.store_16(child.points[0].y)
						file.store_16(child.points[1].y)
					else:
						file.store_16(child.points[1].x)
						file.store_16(child.points[0].x)
			file.store_line("END_GUIDES")
		file.store_line("END_FRAMES")

		#Save tool options
		var left_color := Global.left_color_picker.color
		var right_color := Global.right_color_picker.color
		var left_brush_size := Global.left_brush_size
		var right_brush_size := Global.right_brush_size
		var left_palette := Global.left_color_picker.get_picker().get_presets()
		var right_palette := Global.right_color_picker.get_picker().get_presets()
		file.store_var(left_color)
		file.store_var(right_color)
		file.store_8(left_brush_size)
		file.store_8(right_brush_size)
		file.store_var(left_palette)
		file.store_var(right_palette)
		#Save custom brushes
		for i in range(Global.brushes_from_files, Global.custom_brushes.size()):
			var brush = Global.custom_brushes[i]
			file.store_line("/")
			file.store_16(brush.get_size().x)
			file.store_16(brush.get_size().y)
			file.store_buffer(brush.get_data())
		file.store_line("END_BRUSHES")
	file.close()
	Global.notification_label("File saved")

func _on_ImportSprites_files_selected(paths) -> void:
	if !import_as_new_frame.pressed: #If we're not adding a new frame, delete the previous
		clear_canvases()

	#Find the biggest image and let it handle the camera zoom options
	var max_size : Vector2
	var biggest_canvas : Canvas
	var i := Global.canvases.size()
	for path in paths:
		var image := Image.new()
		var err := image.load(path)
		if err != OK: #An error occured
			OS.alert("Can't load file")
			continue

		opensprite_file_selected = true
		var canvas : Canvas = load("res://Prefabs/Canvas.tscn").instance()
		canvas.size = image.get_size()
		image.convert(Image.FORMAT_RGBA8)
		image.lock()
		var tex := ImageTexture.new()
		tex.create_from_image(image, 0)
		#Store [Image, ImageTexture, Layer Name, Visibity boolean, Opacity]
		canvas.layers.append([image, tex, "Layer 0", true, 1])
		canvas.frame = i
		Global.canvases.append(canvas)
		Global.canvas_parent.add_child(canvas)
		canvas.visible = false
		if path == paths[0]: #If it's the first file
			max_size = canvas.size
			biggest_canvas = canvas
		else:
			if canvas.size > max_size:
				biggest_canvas = canvas

		i += 1
	Global.current_frame = i - 1
	Global.canvas = Global.canvases[Global.canvases.size() - 1]
	Global.canvas.visible = true
	biggest_canvas.camera_zoom()

	Global.undo_redo.clear_history(false)

	var first_path : String = paths[0]
	OS.set_window_title(first_path.get_file() + " (imported) - Pixelorama")

func clear_canvases() -> void:
	for child in Global.vbox_layer_container.get_children():
		if child is PanelContainer:
			child.queue_free()
	for child in Global.frame_container.get_children():
		child.queue_free()
	for child in Global.canvas_parent.get_children():
		if child is Canvas:
			child.queue_free()
	Global.canvases.clear()
	current_save_path = ""
	current_export_path = ""

func _on_ExportSprites_file_selected(path : String) -> void:
	current_export_path = path
	export_project()

func export_project() -> void:
	if export_all_frames.pressed:
		if !export_as_single_file.pressed:
			var i := 1
			for canvas in Global.canvases:
				var path := "%s_%s" % [current_export_path, str(i)]
				path = path.replace(".png", "")
				path = "%s.png" % path
				save_sprite(canvas, path)
				i += 1
		else:
			save_spritesheet()
	else:
		save_sprite(Global.canvas, current_export_path)
	Global.notification_label("File exported")

func save_sprite(canvas : Canvas, path : String) -> void:
	var whole_image := Image.new()
	whole_image.create(canvas.size.x, canvas.size.y, false, Image.FORMAT_RGBA8)
	whole_image.lock()
	for layer in canvas.layers:
		var img : Image = layer[0]
		img.lock()
		if layer[4] < 1: # If we have layer transparency
			for xx in img.get_size().x:
				for yy in img.get_size().y:
					var pixel_color := img.get_pixel(xx, yy)
					var alpha : float = pixel_color.a * layer[4]
					img.set_pixel(xx, yy, Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha))

		canvas.blend_rect(whole_image, img, Rect2(canvas.position, canvas.size), Vector2.ZERO)
		layer[0].lock()
	var err = whole_image.save_png(path)
	if err != OK:
		OS.alert("Can't save file")

func save_spritesheet() -> void:
	var width
	var height
	if export_vertical_spritesheet.pressed: #Vertical spritesheet
		width = Global.canvas.size.x
		height = 0
		for canvas in Global.canvases:
			height += canvas.size.y
			if canvas.size.x > width:
				width = canvas.size.x
	else: #Horizontal spritesheet
		width = 0
		height = Global.canvas.size.y
		for canvas in Global.canvases:
			width += canvas.size.x
			if canvas.size.y > height:
				height = canvas.size.y
	var whole_image := Image.new()
	whole_image.create(width, height, false, Image.FORMAT_RGBA8)
	whole_image.lock()
	var dst := Vector2.ZERO
	for canvas in Global.canvases:
		for layer in canvas.layers:
			var img : Image = layer[0]
			img.lock()
			if layer[4] < 1: # If we have layer transparency
				for xx in img.get_size().x:
					for yy in img.get_size().y:
						var pixel_color := img.get_pixel(xx, yy)
						var alpha : float = pixel_color.a * layer[4]
						img.set_pixel(xx, yy, Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha))

			canvas.blend_rect(whole_image, img, Rect2(canvas.position, canvas.size), dst)
			layer[0].lock()

		if export_vertical_spritesheet.pressed:
			dst += Vector2(0, canvas.size.y)
		else:
			dst += Vector2(canvas.size.x, 0)

	var err = whole_image.save_png(current_export_path)
	if err != OK:
		OS.alert("Can't save file")

func _on_ScaleImage_confirmed() -> void:
	var width : int = $ScaleImage/VBoxContainer/OptionsContainer/WidthValue.value
	var height : int = $ScaleImage/VBoxContainer/OptionsContainer/HeightValue.value
	var interpolation : int = $ScaleImage/VBoxContainer/OptionsContainer/InterpolationType.selected
	Global.undos += 1
	Global.undo_redo.create_action("Scale")
	Global.undo_redo.add_do_property(Global.canvas, "size", Vector2(width, height).floor())

	for i in range(Global.canvas.layers.size() - 1, -1, -1):
		var sprite : Image = Global.canvas.layers[i][1].get_data()
		sprite.resize(width, height, interpolation)
		Global.undo_redo.add_do_property(Global.canvas.layers[i][0], "data", sprite.data)
		Global.undo_redo.add_undo_property(Global.canvas.layers[i][0], "data", Global.canvas.layers[i][0].data)

	Global.undo_redo.add_undo_property(Global.canvas, "size", Global.canvas.size)
	Global.undo_redo.add_undo_method(Global, "undo", [Global.canvas])
	Global.undo_redo.add_do_method(Global, "redo", [Global.canvas])
	Global.undo_redo.commit_action()

func _on_OutlineDialog_confirmed() -> void:
	var outline_color : Color = $OutlineDialog/OptionsContainer/OutlineColor.color
	var thickness : int = $OutlineDialog/OptionsContainer/ThickValue.value
	var image : Image = Global.canvas.layers[Global.canvas.current_layer_index][0]
	if image.is_invisible():
		return
	var new_image := Image.new()
	new_image.copy_from(image)
	new_image.lock()

	Global.canvas.handle_undo("Draw")
	for xx in image.get_size().x:
		for yy in image.get_size().y:
			var pos = Vector2(xx, yy)
			var current_pixel := image.get_pixelv(pos)
			if current_pixel.a == 0:
				continue

			for i in range(1, thickness + 1):
				var new_pos : Vector2 = pos + Vector2.LEFT * i
				if new_pos.x >= 0:
					var new_pixel = image.get_pixelv(new_pos)
					if new_pixel.a == 0:
						new_image.set_pixelv(new_pos, outline_color)

				new_pos = pos + Vector2.RIGHT * i
				if new_pos.x < Global.canvas.size.x:
					var new_pixel = image.get_pixelv(new_pos)
					if new_pixel.a == 0:
						new_image.set_pixelv(new_pos, outline_color)

				new_pos = pos + Vector2.UP * i
				if new_pos.y >= 0:
					var new_pixel = image.get_pixelv(new_pos)
					if new_pixel.a == 0:
						new_image.set_pixelv(new_pos, outline_color)

				new_pos = pos + Vector2.DOWN * i
				if new_pos.y < Global.canvas.size.y:
					var new_pixel = image.get_pixelv(new_pos)
					if new_pixel.a == 0:
						new_image.set_pixelv(new_pos, outline_color)

	image.copy_from(new_image)
	Global.canvas.handle_redo("Draw")

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
	if (mouse_press && Input.is_action_just_released("left_mouse")) || (!mouse_press && key_for_left):
		Global.current_left_tool = current_action

		#Start from 2, so the label and the cursor checkbox won't get invisible
		for i in range(2, Global.left_tool_options_container.get_child_count()):
			Global.left_tool_options_container.get_child(i).visible = false

		#Tool options visible depending on the selected tool
		if current_action == "Pencil":
			Global.left_brush_type_container.visible = true
			Global.left_brush_size_container.visible = true
			Global.left_mirror_container.visible = true
			if Global.current_left_brush_type != Global.BRUSH_TYPES.PIXEL:
				Global.left_color_interpolation_container.visible = true
		elif current_action == "Eraser":
			Global.left_brush_type_container.visible = true
			Global.left_brush_size_container.visible = true
			Global.left_mirror_container.visible = true
		elif current_action == "Bucket":
			Global.left_fill_area_container.visible = true
			Global.left_mirror_container.visible = true
		elif current_action == "LightenDarken":
			Global.left_brush_size_container.visible = true
			Global.left_ld_container.visible = true
			Global.left_mirror_container.visible = true

	elif (mouse_press && Input.is_action_just_released("right_mouse")) || (!mouse_press && !key_for_left):
		Global.current_right_tool = current_action
		#Start from 2, so the label and the cursor checkbox won't get invisible
		for i in range(2, Global.right_tool_options_container.get_child_count()):
			Global.right_tool_options_container.get_child(i).visible = false

		#Tool options visible depending on the selected tool
		if current_action == "Pencil":
			Global.right_brush_type_container.visible = true
			Global.right_brush_size_container.visible = true
			Global.right_mirror_container.visible = true
			if Global.current_right_brush_type != Global.BRUSH_TYPES.PIXEL:
				Global.right_color_interpolation_container.visible = true
		elif current_action == "Eraser":
			Global.right_brush_type_container.visible = true
			Global.right_brush_size_container.visible = true
			Global.right_mirror_container.visible = true
		elif current_action == "Bucket":
			Global.right_fill_area_container.visible = true
			Global.right_mirror_container.visible = true
		elif current_action == "LightenDarken":
			Global.right_brush_size_container.visible = true
			Global.right_ld_container.visible = true
			Global.right_mirror_container.visible = true

	for t in tools:
		var tool_name : String = t[0].name
		if tool_name == Global.current_left_tool && tool_name == Global.current_right_tool:
			t[0].texture_normal = load("res://Assets/Graphics/%s Themes/Tools/%s_l_r.png" % [Global.theme_type, tool_name])
		elif tool_name == Global.current_left_tool:
			t[0].texture_normal = load("res://Assets/Graphics/%s Themes/Tools/%s_l.png" % [Global.theme_type, tool_name])
		elif tool_name == Global.current_right_tool:
			t[0].texture_normal = load("res://Assets/Graphics/%s Themes/Tools/%s_r.png" % [Global.theme_type, tool_name])
		else:
			t[0].texture_normal = load("res://Assets/Graphics/%s Themes/Tools/%s.png" % [Global.theme_type, tool_name])

	Global.left_cursor_tool_texture.create_from_image(load("res://Assets/Graphics/Tool Cursors/%s_Cursor.png" % Global.current_left_tool))
	Global.right_cursor_tool_texture.create_from_image(load("res://Assets/Graphics/Tool Cursors/%s_Cursor.png" % Global.current_right_tool))

func _on_LeftIndicatorCheckbox_toggled(button_pressed) -> void:
	Global.left_square_indicator_visible = button_pressed

func _on_RightIndicatorCheckbox_toggled(button_pressed) -> void:
	Global.right_square_indicator_visible = button_pressed

func _on_LeftBrushTypeButton_pressed() -> void:
	Global.brushes_popup.popup(Rect2(Global.left_brush_type_button.rect_global_position, Vector2(226, 72)))
	Global.brush_type_window_position = "left"

func _on_RightBrushTypeButton_pressed() -> void:
	Global.brushes_popup.popup(Rect2(Global.right_brush_type_button.rect_global_position, Vector2(226, 72)))
	Global.brush_type_window_position = "right"

func _on_LeftBrushSizeEdit_value_changed(value) -> void:
	var new_size = int(value)
	Global.left_brush_size = new_size
	update_left_custom_brush()

func _on_RightBrushSizeEdit_value_changed(value) -> void:
	var new_size = int(value)
	Global.right_brush_size = new_size
	update_right_custom_brush()

func add_layer(is_new := true) -> void:
	var new_layer := Image.new()
	if is_new:
		new_layer.create(Global.canvas.size.x, Global.canvas.size.y, false, Image.FORMAT_RGBA8)
	else: #clone layer
		new_layer.copy_from(Global.canvas.layers[Global.canvas.current_layer_index][0])
	new_layer.lock()
	var new_layer_tex := ImageTexture.new()
	new_layer_tex.create_from_image(new_layer, 0)

	var new_layers := Global.canvas.layers.duplicate()
	new_layers.append([new_layer, new_layer_tex, null, true, 1])
	Global.undos += 1
	Global.undo_redo.create_action("Add Layer")
	Global.undo_redo.add_do_property(Global.canvas, "layers", new_layers)
	Global.undo_redo.add_undo_property(Global.canvas, "layers", Global.canvas.layers)

	Global.undo_redo.add_undo_method(Global, "undo", [Global.canvas])
	Global.undo_redo.add_do_method(Global, "redo", [Global.canvas])
	Global.undo_redo.commit_action()

func _on_RemoveLayerButton_pressed() -> void:
	var new_layers := Global.canvas.layers.duplicate()
	new_layers.remove(Global.canvas.current_layer_index)
	Global.undos += 1
	Global.undo_redo.create_action("Remove Layer")
	Global.undo_redo.add_do_property(Global.canvas, "layers", new_layers)
	Global.undo_redo.add_undo_property(Global.canvas, "layers", Global.canvas.layers)

	Global.undo_redo.add_undo_method(Global, "undo", [Global.canvas])
	Global.undo_redo.add_do_method(Global, "redo", [Global.canvas])
	Global.undo_redo.commit_action()

func change_layer_order(rate : int) -> void:
	var change = Global.canvas.current_layer_index + rate

	var new_layers := Global.canvas.layers.duplicate()
	var temp = new_layers[Global.canvas.current_layer_index]
	new_layers[Global.canvas.current_layer_index] = new_layers[change]
	new_layers[change] = temp
	Global.undo_redo.create_action("Change Layer Order")
	Global.undo_redo.add_do_property(Global.canvas, "layers", new_layers)
	Global.undo_redo.add_do_property(Global.canvas, "current_layer_index", change)
	Global.undo_redo.add_undo_property(Global.canvas, "layers", Global.canvas.layers)
	Global.undo_redo.add_undo_property(Global.canvas, "current_layer_index", Global.canvas.current_layer_index)

	Global.undo_redo.add_undo_method(Global, "undo", [Global.canvas])
	Global.undo_redo.add_do_method(Global, "redo", [Global.canvas])
	Global.undo_redo.commit_action()

func _on_MergeLayer_pressed() -> void:
	var new_layers := Global.canvas.layers.duplicate()
	new_layers.remove(Global.canvas.current_layer_index)
	var selected_layer = Global.canvas.layers[Global.canvas.current_layer_index][0]

	var new_layer := Image.new()
	new_layer.copy_from(Global.canvas.layers[Global.canvas.current_layer_index - 1][0])
	new_layer.lock()
	Global.canvas.blend_rect(new_layer, selected_layer, Rect2(Global.canvas.position, Global.canvas.size), Vector2.ZERO)

	Global.undos += 1
	Global.undo_redo.create_action("Merge Layer")
	Global.undo_redo.add_do_property(Global.canvas, "layers", new_layers)
	Global.undo_redo.add_do_property(Global.canvas.layers[Global.canvas.current_layer_index - 1][0], "data", new_layer.data)
	Global.undo_redo.add_undo_property(Global.canvas, "layers", Global.canvas.layers)
	Global.undo_redo.add_undo_property(Global.canvas.layers[Global.canvas.current_layer_index - 1][0], "data", Global.canvas.layers[Global.canvas.current_layer_index - 1][0].data)

	Global.undo_redo.add_undo_method(Global, "undo", [Global.canvas])
	Global.undo_redo.add_do_method(Global, "redo", [Global.canvas])
	Global.undo_redo.commit_action()

func add_frame() -> void:
	var new_canvas : Canvas = load("res://Prefabs/Canvas.tscn").instance()
	new_canvas.size = Global.canvas.size
	new_canvas.frame = Global.canvases.size()

	var new_canvases := Global.canvases.duplicate()
	new_canvases.append(new_canvas)
	var new_hidden_canvases := Global.hidden_canvases.duplicate()
	new_hidden_canvases.append(new_canvas)

	Global.undos += 1
	Global.undo_redo.create_action("Add Frame")
	Global.undo_redo.add_do_method(Global, "redo", [new_canvas])
	Global.undo_redo.add_undo_method(Global, "undo", [new_canvas])

	Global.undo_redo.add_do_property(Global, "canvases", new_canvases)
	Global.undo_redo.add_do_property(Global, "hidden_canvases", Global.hidden_canvases)
	Global.undo_redo.add_do_property(Global, "canvas", new_canvas)
	Global.undo_redo.add_do_property(Global, "current_frame", new_canvases.size() - 1)
	for child in Global.frame_container.get_children():
		var frame_button = child.get_node("FrameButton")
		Global.undo_redo.add_do_property(frame_button, "pressed", false)
		Global.undo_redo.add_undo_property(frame_button, "pressed", frame_button.pressed)
	for c in Global.canvases:
		Global.undo_redo.add_do_property(c, "visible", false)
		Global.undo_redo.add_undo_property(c, "visible", c.visible)

	Global.undo_redo.add_undo_property(Global, "canvases", Global.canvases)
	Global.undo_redo.add_undo_property(Global, "hidden_canvases", new_hidden_canvases)
	Global.undo_redo.add_undo_property(Global, "canvas", Global.canvas)
	Global.undo_redo.add_undo_property(Global, "current_frame", Global.current_frame)
	Global.undo_redo.commit_action()

func _on_LoopAnim_pressed() -> void:
	match animation_loop:
		0:
			#Make it loop
			animation_loop = 1
			Global.loop_animation_button.texture_normal = load("res://Assets/Graphics/%s Themes/Timeline/Loop.png" % Global.theme_type)
			Global.loop_animation_button.hint_tooltip = "Cycle loop"
		1:
			#Make it ping-pong
			animation_loop = 2
			Global.loop_animation_button.texture_normal = load("res://Assets/Graphics/%s Themes/Timeline/Loop_PingPong.png" % Global.theme_type)
			Global.loop_animation_button.hint_tooltip = "Ping-pong loop"
		2:
			#Make it stop
			animation_loop = 0
			Global.loop_animation_button.texture_normal = load("res://Assets/Graphics/%s Themes/Timeline/Loop_None.png" % Global.theme_type)
			Global.loop_animation_button.hint_tooltip = "No loop"

func _on_PlayForward_toggled(button_pressed) -> void:
	Global.play_backwards.pressed = false
	if Global.canvases.size() == 1:
		Global.play_forward.pressed = !button_pressed
		return

	if button_pressed:
		Global.animation_timer.wait_time = 1 / fps
		Global.animation_timer.start()
		animation_forward = true
	else:
		Global.animation_timer.stop()

func _on_PlayBackwards_toggled(button_pressed) -> void:
	Global.play_forward.pressed = false
	if Global.canvases.size() == 1:
		Global.play_backwards.pressed = !button_pressed
		return

	if button_pressed:
		Global.animation_timer.wait_time = 1 / fps
		Global.animation_timer.start()
		animation_forward = false
	else:
		Global.animation_timer.stop()

func _on_NextFrame_pressed() -> void:
	if Global.current_frame < Global.canvases.size() - 1:
		Global.current_frame += 1

func _on_PreviousFrame_pressed() -> void:
	if Global.current_frame > 0:
		Global.current_frame -= 1

func _on_LastFrame_pressed() -> void:
	Global.current_frame = Global.canvases.size() - 1

func _on_FirstFrame_pressed() -> void:
	Global.current_frame = 0

func _on_AnimationTimer_timeout() -> void:
	if animation_forward:
		if Global.current_frame < Global.canvases.size() - 1:
			Global.current_frame += 1
		else:
			match animation_loop:
				0: #No loop
					Global.play_forward.pressed = false
					Global.play_backwards.pressed = false
					Global.animation_timer.stop()
				1: #Cycle loop
					Global.current_frame = 0
				2: #Ping pong loop
					animation_forward = false
					_on_AnimationTimer_timeout()

	else:
		if Global.current_frame > 0:
			Global.current_frame -= 1
		else:
			match animation_loop:
				0: #No loop
					Global.play_backwards.pressed = false
					Global.play_forward.pressed = false
					Global.animation_timer.stop()
				1: #Cycle loop
					Global.current_frame = Global.canvases.size() - 1
				2: #Ping pong loop
					animation_forward = true
					_on_AnimationTimer_timeout()

func _on_FPSValue_value_changed(value) -> void:
	fps = float(value)
	Global.animation_timer.wait_time = 1 / fps

func _on_PastOnionSkinning_value_changed(value) -> void:
	Global.onion_skinning_past_rate = int(value)

func _on_FutureOnionSkinning_value_changed(value) -> void:
	Global.onion_skinning_future_rate = int(value)

func _on_BlueRedMode_toggled(button_pressed) -> void:
	Global.onion_skinning_blue_red = button_pressed

func _on_SplitScreenButton_toggled(button_pressed) -> void:
	if button_pressed:
		Global.viewport_separator.visible = true
		Global.second_viewport.visible = true
		$SplitScreenButton.hint_tooltip = tr("SPLITSCREEN_HIDE_HT")
	else:
		Global.viewport_separator.visible = false
		Global.second_viewport.visible = false
		$SplitScreenButton.hint_tooltip = tr("SPLITSCREEN_HT")

func _on_ColorSwitch_pressed() -> void:
	var temp := Global.left_color_picker.color
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
		if previous_left_color.r != color.r || previous_left_color.g != color.g || previous_left_color.b != color.b:
			Global.left_color_picker.color.a = 1
	update_left_custom_brush()
	previous_left_color = color

# warning-ignore:unused_argument
func _on_RightColorPickerButton_color_changed(color : Color) -> void:
	# If the color changed while it's on full transparency, make it opaque (GH issue #54)
	if color.a == 0:
		if previous_right_color.r != color.r || previous_right_color.g != color.g || previous_right_color.b != color.b:
			Global.right_color_picker.color.a = 1
	update_right_custom_brush()
	previous_right_color = color

# warning-ignore:unused_argument
func _on_LeftInterpolateFactor_value_changed(value : float) -> void:
	update_left_custom_brush()

# warning-ignore:unused_argument
func _on_RightInterpolateFactor_value_changed(value : float) -> void:
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

func _on_RightLightenDarken_item_selected(ID : int) -> void:
	Global.right_ld = ID
func _on_RightLDAmountSpinbox_value_changed(value : float) -> void:
	Global.right_ld_amount = value / 100

func _on_LeftHorizontalMirroring_toggled(button_pressed) -> void:
	Global.left_horizontal_mirror = button_pressed
func _on_LeftVerticalMirroring_toggled(button_pressed) -> void:
	Global.left_vertical_mirror = button_pressed

func _on_RightHorizontalMirroring_toggled(button_pressed) -> void:
	Global.right_horizontal_mirror = button_pressed
func _on_RightVerticalMirroring_toggled(button_pressed) -> void:
	Global.right_vertical_mirror = button_pressed

func _on_OpacitySlider_value_changed(value) -> void:
	Global.canvas.layers[Global.canvas.current_layer_index][4] = value / 100

func _on_QuitDialog_confirmed() -> void:
	# Darken the UI to denote that the application is currently exiting
	# (it won't respond to user input in this state).
	modulate = Color(0.5, 0.5, 0.5)

	get_tree().quit()

func _on_AddPalette_pressed() -> void:
	Global.add_palette_button.get_child(0).popup(Rect2(Global.add_palette_button.rect_global_position, Vector2.ONE))

func _on_RemovePalette_pressed() -> void:
	Global.palette_container.remove_current_palette()

func _on_PaletteOptionButton_item_selected(ID) -> void:
	var palette_name = Global.palette_option_button.get_item_metadata(ID)
	Global.palette_container.on_palette_select(palette_name)

func _on_EditPalette_pressed() -> void:
	Global.palette_container.on_edit_palette()

func add_palette_menu_id_pressed(id) -> void:
	match id:
		0:	# New Empty Palette
			Global.palette_container.on_new_empty_palette()
		1:	# Import Palette
			Global.palette_container.on_import_palette()

func _on_NewPaletteDialog_confirmed() -> void:
	Global.palette_container.on_new_palette_confirmed()

func _on_PaletteImportFileDialog_file_selected(path) -> void:
	Global.palette_container.on_palette_import_file_selected(path)

