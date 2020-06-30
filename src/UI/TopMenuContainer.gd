extends Panel


var file_menu : PopupMenu
var view_menu : PopupMenu
var zen_mode := false


func _ready() -> void:
	setup_file_menu()
	setup_edit_menu()
	setup_view_menu()
	setup_image_menu()
	setup_help_menu()


func setup_file_menu() -> void:
	var file_menu_items := {
		"New..." : InputMap.get_action_list("new_file")[0].get_scancode_with_modifiers(),
		"Open..." : InputMap.get_action_list("open_file")[0].get_scancode_with_modifiers(),
		'Open last project...' : 0,
		"Save..." : InputMap.get_action_list("save_file")[0].get_scancode_with_modifiers(),
		"Save as..." : InputMap.get_action_list("save_file_as")[0].get_scancode_with_modifiers(),
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
		"Show Animation Timeline" : 0,
		"Zen Mode" : InputMap.get_action_list("zen_mode")[0].get_scancode_with_modifiers()
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
		"Resize Canvas" : 0,
		"Flip Horizontal" : InputMap.get_action_list("image_flip_horizontal")[0].get_scancode_with_modifiers(),
		"Flip Vertical" : InputMap.get_action_list("image_flip_vertical")[0].get_scancode_with_modifiers(),
		"Rotate Image" : 0,
		"Invert Colors" : 0,
		"Desaturation" : 0,
		"Outline" : 0,
		"Adjust Hue/Saturation/Value" : 0
		}
	var image_menu : PopupMenu = Global.image_menu.get_popup()

	var i := 0
	for item in image_menu_items.keys():
		image_menu.add_item(item, i, image_menu_items[item])
		if i == 2:
			image_menu.add_separator()
		i += 1

	image_menu.connect("id_pressed", self, "image_menu_id_pressed")


func setup_help_menu() -> void:
	var help_menu_items := {
		"View Splash Screen" : 0,
		"Online Docs" : InputMap.get_action_list("open_docs")[0].get_scancode_with_modifiers(),
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
		5: # Export
			export_file()
		6: # Export as
			Global.export_dialog.popup_centered()
			Global.dialog_open(true)
		7: # Quit
			Global.control.show_quit_dialog()


func on_new_project_file_menu_option_pressed() -> void:
	Global.new_image_dialog.popup_centered()
	Global.dialog_open(true)


func open_project_file() -> void:
	if OS.get_name() == "HTML5":
		Html5FileExchange.load_image()
	else:
		Global.open_sprites_dialog.popup_centered()
		Global.dialog_open(true)
		Global.control.opensprite_file_selected = false


func on_open_last_project_file_menu_option_pressed() -> void:
	# Check if last project path is set and if yes then open
	if Global.config_cache.has_section_key("preferences", "last_project_path"):
		Global.control.load_last_project()
	else: # if not then warn user that he didn't edit any project yet
		Global.error_dialog.set_text("You haven't saved or opened any project in Pixelorama yet!")
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)


func save_project_file() -> void:
	Global.control.is_quitting_on_save = false
	var path = OpenSave.current_save_paths[Global.current_project_index]
	if path == "":
		if OS.get_name() == "HTML5":
			Global.save_sprites_html5_dialog.popup_centered()
		else:
			Global.save_sprites_dialog.popup_centered()
		Global.dialog_open(true)
	else:
		Global.control._on_SaveSprite_file_selected(path)


func save_project_file_as() -> void:
	Global.control.is_quitting_on_save = false
	if OS.get_name() == "HTML5":
		Global.save_sprites_html5_dialog.popup_centered()
	else:
		Global.save_sprites_dialog.popup_centered()
	Global.dialog_open(true)


func export_file() -> void:
	if Global.export_dialog.was_exported == false:
		Global.export_dialog.popup_centered()
		Global.dialog_open(true)
	else:
		Global.export_dialog.external_export()


func edit_menu_id_pressed(id : int) -> void:
	match id:
		0: # Undo
			Global.current_project.undo_redo.undo()
		1: # Redo
			Global.control.redone = true
			Global.current_project.undo_redo.redo()
			Global.control.redone = false
		2: # Clear selection
			Global.canvas.handle_undo("Rectangle Select")
			Global.selection_rectangle.polygon[0] = Vector2.ZERO
			Global.selection_rectangle.polygon[1] = Vector2.ZERO
			Global.selection_rectangle.polygon[2] = Vector2.ZERO
			Global.selection_rectangle.polygon[3] = Vector2.ZERO
			Global.current_project.selected_pixels.clear()
			Global.canvas.handle_redo("Rectangle Select")
		3: # Preferences
			Global.preferences_dialog.popup_centered(Vector2(400, 280))
			Global.dialog_open(true)


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
		5: # Fullscreen mode
			toggle_zen_mode()

	Global.canvas.update()


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
	if zen_mode:
		return
	Global.show_animation_timeline = !Global.show_animation_timeline
	view_menu.set_item_checked(4, Global.show_animation_timeline)
	Global.animation_timeline.visible = Global.show_animation_timeline


func toggle_zen_mode() -> void:
	if Global.show_animation_timeline:
		Global.animation_timeline.visible = zen_mode
	Global.control.get_node("MenuAndUI/UI/ToolPanel").visible = zen_mode
	Global.control.get_node("MenuAndUI/UI/RightPanel").visible = zen_mode
	Global.control.get_node("MenuAndUI/UI/CanvasAndTimeline/ViewportAndRulers/TabsContainer").visible = zen_mode
	zen_mode = !zen_mode
	view_menu.set_item_checked(5, zen_mode)


func image_menu_id_pressed(id : int) -> void:
	if Global.current_project.layers[Global.current_project.current_layer].locked: # No changes if the layer is locked
		return
	var image : Image = Global.current_project.frames[0].cels[0].image
	match id:
		0: # Scale Image
			show_scale_image_popup()

		1: # Crop Image
			DrawingAlgos.crop_image(image)

		2: # Resize Canvas
			show_resize_canvas_popup()

		3: # Flip Horizontal
			flip_image(true)

		4: # Flip Vertical
			flip_image(false)

		5: # Rotate
			show_rotate_image_popup()

		6: # Invert Colors
			DrawingAlgos.invert_image_colors(image)

		7: # Desaturation
			DrawingAlgos.desaturate_image(image)

		8: # Outline
			show_add_outline_popup()

		9: # HSV
			show_hsv_configuration_popup()


func show_scale_image_popup() -> void:
	Global.control.get_node("ScaleImage").popup_centered()
	Global.dialog_open(true)


func show_resize_canvas_popup() -> void:
	Global.control.get_node("ResizeCanvas").popup_centered()
	Global.dialog_open(true)


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
	Global.control.get_node("RotateImage").set_sprite(image)
	Global.control.get_node("RotateImage").popup_centered()
	Global.dialog_open(true)


func show_add_outline_popup() -> void:
	Global.control.get_node("OutlineDialog").popup_centered()
	Global.dialog_open(true)


func show_hsv_configuration_popup() -> void:
	Global.control.get_node("HSVDialog").popup_centered()
	Global.dialog_open(true)


func help_menu_id_pressed(id : int) -> void:
	match id:
		0: # Splash Screen
			Global.control.get_node("SplashDialog").popup_centered()
			Global.dialog_open(true)
		1: # Online Docs
			OS.shell_open("https://orama-interactive.github.io/Pixelorama-Docs/")
		2: # Issue Tracker
			OS.shell_open("https://github.com/Orama-Interactive/Pixelorama/issues")
		3: # Changelog
			OS.shell_open("https://github.com/Orama-Interactive/Pixelorama/blob/master/CHANGELOG.md#v07---2020-05-16")
		4: # About Pixelorama
			Global.control.get_node("AboutDialog").popup_centered()
			Global.dialog_open(true)
