extends Control

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
	OS.set("min_window_size", Vector2(1024, 576))

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
		"New..." : InputMap.get_action_list("new_file")[0].get_scancode_with_modifiers(),
		"Open..." : InputMap.get_action_list("open_file")[0].get_scancode_with_modifiers(),
		"Save..." : InputMap.get_action_list("save_file")[0].get_scancode_with_modifiers(),
		"Save as..." : InputMap.get_action_list("save_file_as")[0].get_scancode_with_modifiers(),
		"Import..." : InputMap.get_action_list("import_file")[0].get_scancode_with_modifiers(),
		"Export..." : InputMap.get_action_list("export_file")[0].get_scancode_with_modifiers(),
		"Export as..." : InputMap.get_action_list("export_file_as")[0].get_scancode_with_modifiers(),
		"Quit" : InputMap.get_action_list("quit")[0].get_scancode_with_modifiers(),
		}
	var edit_menu_items := {
		"Undo" : InputMap.get_action_list("undo")[0].get_scancode_with_modifiers(),
		"Redo" : InputMap.get_action_list("redo")[0].get_scancode_with_modifiers(),
		"Clear Selection" : 0,
		"Preferences" : 0
		}
	var view_menu_items := {
		"Tile Mode" : InputMap.get_action_list("tile_mode")[0].get_scancode_with_modifiers(),
		"Show Grid" : InputMap.get_action_list("show_grid")[0].get_scancode_with_modifiers(),
		"Show Rulers" : InputMap.get_action_list("show_rulers")[0].get_scancode_with_modifiers(),
		"Show Guides" : InputMap.get_action_list("show_guides")[0].get_scancode_with_modifiers(),
		"Show Animation Timeline" : 0
		}
	var image_menu_items := {
		"Scale Image" : 0,
		"Crop Image" : 0,
		"Flip Horizontal" : InputMap.get_action_list("image_flip_horizontal")[0].get_scancode_with_modifiers(),
		"Flip Vertical" : InputMap.get_action_list("image_flip_vertical")[0].get_scancode_with_modifiers(),
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
			if(!Global.saved):
				$UnsavedCanvasDialog.popup_centered()
			else:
				$CreateNewImage.popup_centered()
			Global.can_draw = false
		1: # Open
			$OpenSprite.popup_centered()
			Global.can_draw = false
			opensprite_file_selected = false
		2: # Save
			is_quitting_on_save = false
			if OpenSave.current_save_path == "":
				$SaveSprite.popup_centered()
				Global.can_draw = false
			else:
				_on_SaveSprite_file_selected(OpenSave.current_save_path)
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
			Global.can_draw = false
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
			Global.can_draw = false

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


func _on_UnsavedCanvasDialog_confirmed() -> void:
	$CreateNewImage.popup_centered()


func _on_OpenSprite_file_selected(path : String) -> void:
	OpenSave.open_pxo_file(path)

	$SaveSprite.current_path = path
	$ExportDialog.file_name = path.get_file().trim_suffix(".pxo")
	$ExportDialog.directory_path = path.get_base_dir()
	$ExportDialog.was_exported = false
	file_menu.set_item_text(2, tr("Save") + " %s" % path.get_file())
	file_menu.set_item_text(5, tr("Export"))


func _on_SaveSprite_file_selected(path : String) -> void:
	OpenSave.save_pxo_file(path)

	$ExportDialog.file_name = path.get_file().trim_suffix(".pxo")
	$ExportDialog.directory_path = path.get_base_dir()
	$ExportDialog.was_exported = false
	file_menu.set_item_text(2, tr("Save") + " %s" % path.get_file())

	if is_quitting_on_save:
		_on_QuitDialog_confirmed()


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

		# Start from 1, so the label won't get invisible
		for i in range(1, Global.left_tool_options_container.get_child_count()):
			Global.left_tool_options_container.get_child(i).visible = false

		# Tool options visible depending on the selected tool
		if current_action == "Pencil":
			Global.left_brush_type_container.visible = true
			Global.left_brush_size_slider.visible = true
			Global.left_mirror_container.visible = true
			if Global.current_left_brush_type == Global.Brush_Types.FILE or Global.current_left_brush_type == Global.Brush_Types.CUSTOM or Global.current_left_brush_type == Global.Brush_Types.RANDOM_FILE:
				Global.left_color_interpolation_container.visible = true
		elif current_action == "Eraser":
			Global.left_brush_type_container.visible = true
			Global.left_brush_size_slider.visible = true
			Global.left_mirror_container.visible = true
		elif current_action == "Bucket":
			Global.left_brush_type_container.visible = true
			Global.left_brush_size_slider.visible = true
			Global.left_fill_area_container.visible = true
			Global.left_mirror_container.visible = true
			if Global.current_left_brush_type == Global.Brush_Types.FILE or Global.current_left_brush_type == Global.Brush_Types.CUSTOM or Global.current_left_brush_type == Global.Brush_Types.RANDOM_FILE:
				Global.left_color_interpolation_container.visible = true
		elif current_action == "LightenDarken":
			Global.left_brush_type_container.visible = true
			Global.left_brush_size_slider.visible = true
			Global.left_ld_container.visible = true
			Global.left_mirror_container.visible = true
		elif current_action == "ColorPicker":
			Global.left_colorpicker_container.visible = true

	elif (mouse_press and Input.is_action_just_released("right_mouse")) or (!mouse_press and !key_for_left):
		Global.current_right_tool = current_action
		# Start from 1, so the label won't get invisible
		for i in range(1, Global.right_tool_options_container.get_child_count()):
			Global.right_tool_options_container.get_child(i).visible = false

		# Tool options visible depending on the selected tool
		if current_action == "Pencil":
			Global.right_brush_type_container.visible = true
			Global.right_brush_size_slider.visible = true
			Global.right_mirror_container.visible = true
			if Global.current_right_brush_type == Global.Brush_Types.FILE or Global.current_right_brush_type == Global.Brush_Types.CUSTOM or Global.current_right_brush_type == Global.Brush_Types.RANDOM_FILE:
				Global.right_color_interpolation_container.visible = true
		elif current_action == "Eraser":
			Global.right_brush_type_container.visible = true
			Global.right_brush_size_slider.visible = true
			Global.right_mirror_container.visible = true
		elif current_action == "Bucket":
			Global.right_brush_type_container.visible = true
			Global.right_brush_size_slider.visible = true
			Global.right_fill_area_container.visible = true
			Global.right_mirror_container.visible = true
			if Global.current_right_brush_type == Global.Brush_Types.FILE or Global.current_right_brush_type == Global.Brush_Types.CUSTOM or Global.current_right_brush_type == Global.Brush_Types.RANDOM_FILE:
				Global.right_color_interpolation_container.visible = true
		elif current_action == "LightenDarken":
			Global.right_brush_type_container.visible = true
			Global.right_brush_size_slider.visible = true
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

