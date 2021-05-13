extends Panel


enum FileMenuId {NEW, OPEN, OPEN_LAST_PROJECT, SAVE, SAVE_AS, EXPORT, EXPORT_AS, QUIT}
enum EditMenuId {UNDO, REDO, COPY, CUT, PASTE, DELETE, PREFERENCES}
enum ViewMenuId {TILE_MODE, WINDOW_TRANSPARENCY, PANEL_LAYOUT, MIRROR_VIEW, SHOW_GRID, SHOW_PIXEL_GRID, SHOW_RULERS, SHOW_GUIDES, SHOW_ANIMATION_TIMELINE, ZEN_MODE, FULLSCREEN_MODE}
enum ImageMenuId {SCALE_IMAGE, CENTRALIZE_IMAGE, CROP_IMAGE, RESIZE_CANVAS, FLIP, ROTATE, INVERT_COLORS, DESATURATION, OUTLINE, HSV, GRADIENT, SHADER}
enum SelectMenuId {SELECT_ALL, CLEAR_SELECTION, INVERT}
enum HelpMenuId {VIEW_SPLASH_SCREEN, ONLINE_DOCS, ISSUE_TRACKER, CHANGELOG, ABOUT_PIXELORAMA}

var file_menu_button : MenuButton
var edit_menu_button : MenuButton
var view_menu_button : MenuButton
var image_menu_button : MenuButton
var select_menu_button : MenuButton
var help_menu_button : MenuButton

var file_menu : PopupMenu
var view_menu : PopupMenu
var zen_mode := false


func _ready() -> void:
	file_menu_button = find_node("FileMenu")
	edit_menu_button = find_node("EditMenu")
	view_menu_button = find_node("ViewMenu")
	image_menu_button = find_node("ImageMenu")
	select_menu_button = find_node("SelectMenu")
	help_menu_button = find_node("HelpMenu")

	setup_file_menu()
	setup_edit_menu()
	setup_view_menu()
	setup_image_menu()
	setup_select_menu()
	setup_help_menu()


func setup_file_menu() -> void:
	var file_menu_items := { # order as in FileMenuId enum
		"New..." : InputMap.get_action_list("new_file")[0].get_scancode_with_modifiers(),
		"Open..." : InputMap.get_action_list("open_file")[0].get_scancode_with_modifiers(),
		'Open last project...' : 0,
		"Recent projects": 0,
		"Save..." : InputMap.get_action_list("save_file")[0].get_scancode_with_modifiers(),
		"Save as..." : InputMap.get_action_list("save_file_as")[0].get_scancode_with_modifiers(),
		"Export..." : InputMap.get_action_list("export_file")[0].get_scancode_with_modifiers(),
		"Export as..." : InputMap.get_action_list("export_file_as")[0].get_scancode_with_modifiers(),
		"Quit" : InputMap.get_action_list("quit")[0].get_scancode_with_modifiers(),
		}
	file_menu = file_menu_button.get_popup()
	var i := 0

	for item in file_menu_items.keys():
		if item == "Recent projects":
			setup_recent_projects_submenu(item)
		else:
			file_menu.add_item(item, i, file_menu_items[item])
			i += 1

	file_menu.connect("id_pressed", self, "file_menu_id_pressed")

	if OS.get_name() == "HTML5":
		file_menu.set_item_disabled(FileMenuId.OPEN_LAST_PROJECT, true)
		file_menu.set_item_disabled(FileMenuId.SAVE, true)


func setup_recent_projects_submenu(item : String) -> void:
	Global.recent_projects_submenu.connect("id_pressed", self, "on_recent_projects_submenu_id_pressed")
	Global.update_recent_projects_submenu()

	file_menu.add_child(Global.recent_projects_submenu)
	file_menu.add_submenu_item(item, Global.recent_projects_submenu.get_name())


func setup_edit_menu() -> void:
	var edit_menu_items := { # order as in EditMenuId enum
		"Undo" : InputMap.get_action_list("undo")[0].get_scancode_with_modifiers(),
		"Redo" : InputMap.get_action_list("redo")[0].get_scancode_with_modifiers(),
		"Copy" : InputMap.get_action_list("copy")[0].get_scancode_with_modifiers(),
		"Cut" : InputMap.get_action_list("cut")[0].get_scancode_with_modifiers(),
		"Paste" : InputMap.get_action_list("paste")[0].get_scancode_with_modifiers(),
		"Delete" : InputMap.get_action_list("delete")[0].get_scancode_with_modifiers(),
		"Preferences" : 0
		}
	var edit_menu : PopupMenu = edit_menu_button.get_popup()
	var i := 0

	for item in edit_menu_items.keys():
		edit_menu.add_item(item, i, edit_menu_items[item])
		i += 1

	edit_menu.connect("id_pressed", self, "edit_menu_id_pressed")


func setup_view_menu() -> void:
	var view_menu_items := { # order as in ViewMenuId enum
		"Tile Mode" : 0,
		"Window Transparency" : 0,
		"Panel Layout" : 0,
		"Mirror View" : InputMap.get_action_list("mirror_view")[0].get_scancode_with_modifiers(),
		"Show Grid" : InputMap.get_action_list("show_grid")[0].get_scancode_with_modifiers(),
		"Show Pixel Grid" : InputMap.get_action_list("show_pixel_grid")[0].get_scancode_with_modifiers(),
		"Show Rulers" : InputMap.get_action_list("show_rulers")[0].get_scancode_with_modifiers(),
		"Show Guides" : InputMap.get_action_list("show_guides")[0].get_scancode_with_modifiers(),
		"Show Animation Timeline" : 0,
		"Zen Mode" : InputMap.get_action_list("zen_mode")[0].get_scancode_with_modifiers(),
		"Fullscreen Mode" : InputMap.get_action_list("toggle_fullscreen")[0].get_scancode_with_modifiers(),
		}
	view_menu = view_menu_button.get_popup()

	var i := 0
	for item in view_menu_items.keys():
		if item == "Tile Mode":
			setup_tile_mode_submenu(item)
		elif item == "Window Transparency":
			setup_window_transparency_submenu(item)
		elif item == "Panel Layout":
			setup_panel_layout_submenu(item)
		else:
			view_menu.add_check_item(item, i, view_menu_items[item])
		i += 1
	view_menu.set_item_checked(ViewMenuId.SHOW_RULERS, true)
	view_menu.set_item_checked(ViewMenuId.SHOW_GUIDES, true)
	view_menu.set_item_checked(ViewMenuId.SHOW_ANIMATION_TIMELINE, true)
	view_menu.hide_on_checkable_item_selection = false
	view_menu.connect("id_pressed", self, "view_menu_id_pressed")
	if OS.get_name() == "HTML5":
		view_menu.set_item_disabled(ViewMenuId.WINDOW_TRANSPARENCY, true)


func setup_tile_mode_submenu(item : String):
	Global.tile_mode_submenu.connect("id_pressed", self, "tile_mode_submenu_id_pressed")
	view_menu.add_child(Global.tile_mode_submenu)
	view_menu.add_submenu_item(item, Global.tile_mode_submenu.get_name())


func setup_window_transparency_submenu(item : String):
	Global.window_transparency_submenu.connect("id_pressed", self, "window_transparency_submenu_id_pressed")
	view_menu.add_child(Global.window_transparency_submenu)
	view_menu.add_submenu_item(item, Global.window_transparency_submenu.get_name())


func setup_panel_layout_submenu(item : String):
	Global.panel_layout_submenu.connect("id_pressed", self, "panel_layout_submenu_id_pressed")
	view_menu.add_child(Global.panel_layout_submenu)
	view_menu.add_submenu_item(item, Global.panel_layout_submenu.get_name())


func setup_image_menu() -> void:
	var image_menu_items := { # order as in ImageMenuId enum
		"Scale Image" : 0,
		"Centralize Image" : 0,
		"Crop Image" : 0,
		"Resize Canvas" : 0,
		"Flip" : 0,
		"Rotate Image" : 0,
		"Invert Colors" : 0,
		"Desaturation" : 0,
		"Outline" : 0,
		"Adjust Hue/Saturation/Value" : 0,
		"Gradient" : 0,
		# "Shader" : 0
		}
	var image_menu : PopupMenu = image_menu_button.get_popup()

	var i := 0
	for item in image_menu_items.keys():
		image_menu.add_item(item, i, image_menu_items[item])
		if i == ImageMenuId.RESIZE_CANVAS:
			image_menu.add_separator()
		i += 1

	image_menu.connect("id_pressed", self, "image_menu_id_pressed")


func setup_select_menu() -> void:
	var select_menu_items := { # order as in EditMenuId enum
		"All" : InputMap.get_action_list("select_all")[0].get_scancode_with_modifiers(),
		"Clear" : InputMap.get_action_list("clear_selection")[0].get_scancode_with_modifiers(),
		"Invert" : InputMap.get_action_list("invert_selection")[0].get_scancode_with_modifiers(),
		}
	var select_menu : PopupMenu = select_menu_button.get_popup()
	var i := 0

	for item in select_menu_items.keys():
		select_menu.add_item(item, i, select_menu_items[item])
		i += 1

	select_menu.connect("id_pressed", self, "select_menu_id_pressed")


func setup_help_menu() -> void:
	var help_menu_items := { # order as in HelpMenuId enum
		"View Splash Screen" : 0,
		"Online Docs" : InputMap.get_action_list("open_docs")[0].get_scancode_with_modifiers(),
		"Issue Tracker" : 0,
		"Changelog" : 0,
		"About Pixelorama" : 0
		}
	var help_menu : PopupMenu = help_menu_button.get_popup()

	var i := 0
	for item in help_menu_items.keys():
		help_menu.add_item(item, i, help_menu_items[item])
		i += 1

	help_menu.connect("id_pressed", self, "help_menu_id_pressed")


func file_menu_id_pressed(id : int) -> void:
	match id:
		FileMenuId.NEW:
			on_new_project_file_menu_option_pressed()
		FileMenuId.OPEN:
			open_project_file()
		FileMenuId.OPEN_LAST_PROJECT:
			on_open_last_project_file_menu_option_pressed()
		FileMenuId.SAVE:
			save_project_file()
		FileMenuId.SAVE_AS:
			save_project_file_as()
		FileMenuId.EXPORT:
			export_file()
		FileMenuId.EXPORT_AS:
			Global.export_dialog.popup_centered()
			Global.dialog_open(true)
		FileMenuId.QUIT:
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
	if Export.was_exported == false:
		Global.export_dialog.popup_centered()
		Global.dialog_open(true)
	else:
		Export.external_export()


func on_recent_projects_submenu_id_pressed(id : int) -> void:
	Global.control.load_recent_project_file(Global.recent_projects[id])


func edit_menu_id_pressed(id : int) -> void:
	match id:
		EditMenuId.UNDO:
			Global.current_project.commit_undo()
		EditMenuId.REDO:
			Global.current_project.commit_redo()
		EditMenuId.COPY:
			Global.canvas.selection.copy()
		EditMenuId.CUT:
			Global.canvas.selection.cut()
		EditMenuId.PASTE:
			Global.canvas.selection.paste()
		EditMenuId.DELETE:
			Global.canvas.selection.delete()
		EditMenuId.PREFERENCES:
			Global.preferences_dialog.popup_centered(Vector2(400, 280))
			Global.dialog_open(true)


func view_menu_id_pressed(id : int) -> void:
	match id:
		ViewMenuId.MIRROR_VIEW:
			toggle_mirror_view()
		ViewMenuId.SHOW_GRID:
			toggle_show_grid()
		ViewMenuId.SHOW_PIXEL_GRID:
			toggle_show_pixel_grid()
		ViewMenuId.SHOW_RULERS:
			toggle_show_rulers()
		ViewMenuId.SHOW_GUIDES:
			toggle_show_guides()
		ViewMenuId.SHOW_ANIMATION_TIMELINE:
			toggle_show_anim_timeline()
		ViewMenuId.ZEN_MODE:
			toggle_zen_mode()
		ViewMenuId.FULLSCREEN_MODE:
			toggle_fullscreen()
	Global.canvas.update()


func tile_mode_submenu_id_pressed(id : int) -> void:
	Global.current_project.tile_mode = id
	Global.transparent_checker.fit_rect(Global.current_project.get_tile_mode_rect())
	for i in Global.TileMode.values():
		Global.tile_mode_submenu.set_item_checked(i, i == id)
	Global.canvas.tile_mode.update()
	Global.canvas.pixel_grid.update()
	Global.canvas.grid.update()


func window_transparency_submenu_id_pressed(id : float) -> void:
	if OS.window_fullscreen:
		for i in 11:
			Global.window_transparency_submenu.set_item_checked(i, i == 10)
		window_transparency(1)
	else:
		for i in 11:
			Global.window_transparency_submenu.set_item_checked(i, i == id)
		window_transparency(id/10)


func panel_layout_submenu_id_pressed(id : int) -> void:
	Global.panel_layout = id
	for i in Global.PanelLayout.values():
		Global.panel_layout_submenu.set_item_checked(i, i == id)
	get_tree().get_root().get_node("Control").handle_resize()


func window_transparency(value :float) -> void:
	if value == 1:
		get_node("../../AlternateTransparentBackground").visible = false
	else:
		get_node("../../AlternateTransparentBackground").visible = true
	var checker :ColorRect = get_parent().get_node("UI/ToolsAndCanvas/CanvasAndTimeline/ViewportAndRulers/HSplitContainer/ViewportandVerticalRuler/ViewportContainer/Viewport/TransparentChecker")
	var color :Color = Global.control.theme.get_stylebox("panel", "PanelContainer").bg_color
	color.a = value
	get_node("../../AlternateTransparentBackground").color = color
	checker.transparency(value)


func toggle_mirror_view() -> void:
	Global.mirror_view = !Global.mirror_view
	Global.canvas.selection.marching_ants_outline.scale.x = -Global.canvas.selection.marching_ants_outline.scale.x
	if Global.mirror_view:
		Global.canvas.selection.marching_ants_outline.position.x = Global.canvas.selection.marching_ants_outline.position.x + Global.current_project.size.x
	else:
		Global.canvas.selection.marching_ants_outline.position.x = 0
	Global.canvas.selection.update()
	view_menu.set_item_checked(ViewMenuId.MIRROR_VIEW, Global.mirror_view)


func toggle_show_grid() -> void:
	Global.draw_grid = !Global.draw_grid
	view_menu.set_item_checked(ViewMenuId.SHOW_GRID, Global.draw_grid)
	Global.canvas.grid.update()


func toggle_show_pixel_grid() -> void:
	Global.draw_pixel_grid = !Global.draw_pixel_grid
	view_menu.set_item_checked(ViewMenuId.SHOW_PIXEL_GRID, Global.draw_pixel_grid)
	Global.canvas.pixel_grid.update()


func toggle_show_rulers() -> void:
	Global.show_rulers = !Global.show_rulers
	view_menu.set_item_checked(ViewMenuId.SHOW_RULERS, Global.show_rulers)
	Global.horizontal_ruler.visible = Global.show_rulers
	Global.vertical_ruler.visible = Global.show_rulers


func toggle_show_guides() -> void:
	Global.show_guides = !Global.show_guides
	view_menu.set_item_checked(ViewMenuId.SHOW_GUIDES, Global.show_guides)
	for guide in Global.canvas.get_children():
		if guide is Guide and guide in Global.current_project.guides:
			guide.visible = Global.show_guides
			if guide is SymmetryGuide:
				if guide.type == Guide.Types.HORIZONTAL:
					guide.visible = Global.show_x_symmetry_axis and Global.show_guides
				else:
					guide.visible = Global.show_y_symmetry_axis and Global.show_guides


func toggle_show_anim_timeline() -> void:
	if zen_mode:
		return
	Global.show_animation_timeline = !Global.show_animation_timeline
	view_menu.set_item_checked(ViewMenuId.SHOW_ANIMATION_TIMELINE, Global.show_animation_timeline)
	Global.animation_timeline.visible = Global.show_animation_timeline


func toggle_zen_mode() -> void:
	if Global.show_animation_timeline:
		Global.animation_timeline.visible = zen_mode
	Global.tool_panel.visible = zen_mode
	Global.right_panel.visible = zen_mode
	Global.tabs_container.visible = zen_mode
	Global.control.tallscreen_hsplit_container.visible = zen_mode
	zen_mode = !zen_mode
	view_menu.set_item_checked(ViewMenuId.ZEN_MODE, zen_mode)


func toggle_fullscreen() -> void:
	OS.window_fullscreen = !OS.window_fullscreen
	view_menu.set_item_checked(ViewMenuId.FULLSCREEN_MODE, OS.window_fullscreen)
	# if window is fullscreen then reset transparency
	if OS.window_fullscreen:
		window_transparency_submenu_id_pressed(10)


func image_menu_id_pressed(id : int) -> void:
	var image : Image = Global.current_project.frames[Global.current_project.current_frame].cels[Global.current_project.current_layer].image
	match id:
		ImageMenuId.SCALE_IMAGE:
			show_scale_image_popup()

		ImageMenuId.CENTRALIZE_IMAGE:
			DrawingAlgos.centralize()

		ImageMenuId.CROP_IMAGE:
			DrawingAlgos.crop_image(image)

		ImageMenuId.RESIZE_CANVAS:
			show_resize_canvas_popup()

		ImageMenuId.FLIP:
			Global.control.get_node("Dialogs/ImageEffects/FlipImageDialog").popup_centered()
			Global.dialog_open(true)

		ImageMenuId.ROTATE:
			show_rotate_image_popup()

		ImageMenuId.INVERT_COLORS:
			Global.control.get_node("Dialogs/ImageEffects/InvertColorsDialog").popup_centered()
			Global.dialog_open(true)

		ImageMenuId.DESATURATION:
			Global.control.get_node("Dialogs/ImageEffects/DesaturateDialog").popup_centered()
			Global.dialog_open(true)

		ImageMenuId.OUTLINE:
			show_add_outline_popup()

		ImageMenuId.HSV:
			show_hsv_configuration_popup()

		ImageMenuId.GRADIENT:
			Global.control.get_node("Dialogs/ImageEffects/GradientDialog").popup_centered()
			Global.dialog_open(true)

		ImageMenuId.SHADER:
			Global.control.get_node("Dialogs/ImageEffects/ShaderEffect").popup_centered()
			Global.dialog_open(true)


func show_scale_image_popup() -> void:
	Global.control.get_node("Dialogs/ImageEffects/ScaleImage").popup_centered()
	Global.dialog_open(true)


func show_resize_canvas_popup() -> void:
	Global.control.get_node("Dialogs/ImageEffects/ResizeCanvas").popup_centered()
	Global.dialog_open(true)


func show_rotate_image_popup() -> void:
	Global.control.get_node("Dialogs/ImageEffects/RotateImage").popup_centered()
	Global.dialog_open(true)


func show_add_outline_popup() -> void:
	Global.control.get_node("Dialogs/ImageEffects/OutlineDialog").popup_centered()
	Global.dialog_open(true)


func show_hsv_configuration_popup() -> void:
	Global.control.get_node("Dialogs/ImageEffects/HSVDialog").popup_centered()
	Global.dialog_open(true)


func select_menu_id_pressed(id : int) -> void:
	match id:
		SelectMenuId.SELECT_ALL:
			Global.canvas.selection.select_all()
		SelectMenuId.CLEAR_SELECTION:
			Global.canvas.selection.clear_selection(true)
		SelectMenuId.INVERT:
			Global.canvas.selection.invert()


func help_menu_id_pressed(id : int) -> void:
	match id:
		HelpMenuId.VIEW_SPLASH_SCREEN:
			Global.control.get_node("Dialogs/SplashDialog").popup_centered()
			Global.dialog_open(true)
		HelpMenuId.ONLINE_DOCS:
			OS.shell_open("https://orama-interactive.github.io/Pixelorama-Docs/")
		HelpMenuId.ISSUE_TRACKER:
			OS.shell_open("https://github.com/Orama-Interactive/Pixelorama/issues")
		HelpMenuId.CHANGELOG:
			OS.shell_open("https://github.com/Orama-Interactive/Pixelorama/blob/master/CHANGELOG.md#v083---2021-05-04")
		HelpMenuId.ABOUT_PIXELORAMA:
			Global.control.get_node("Dialogs/AboutDialog").popup_centered()
			Global.dialog_open(true)
