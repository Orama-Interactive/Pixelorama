extends Panel

enum FileMenuId { NEW, OPEN, OPEN_LAST_PROJECT, SAVE, SAVE_AS, EXPORT, EXPORT_AS, QUIT }
enum EditMenuId { UNDO, REDO, COPY, CUT, PASTE, DELETE, NEW_BRUSH, PREFERENCES }
enum ViewMenuId {
	TILE_MODE,
	WINDOW_OPACITY,
	MIRROR_VIEW,
	SHOW_GRID,
	SHOW_PIXEL_GRID,
	SHOW_RULERS,
	SHOW_GUIDES,
	DOCKERS,
	EDIT_MODE,
	ZEN_MODE,
	FULLSCREEN_MODE
}
enum ImageMenuId {
	SCALE_IMAGE,
	CENTRALIZE_IMAGE,
	CROP_IMAGE,
	RESIZE_CANVAS,
	FLIP,
	ROTATE,
	INVERT_COLORS,
	DESATURATION,
	OUTLINE,
	HSV,
	GRADIENT,
	SHADER
}
enum SelectMenuId { SELECT_ALL, CLEAR_SELECTION, INVERT }
enum HelpMenuId {
	VIEW_SPLASH_SCREEN,
	ONLINE_DOCS,
	ISSUE_TRACKER,
	OPEN_LOGS_FOLDER,
	CHANGELOG,
	ABOUT_PIXELORAMA
}

var file_menu: PopupMenu
var view_menu: PopupMenu
var zen_mode := false
var recent_projects := []

onready var ui_elements: Array = Global.control.find_node("DockableContainer").get_children()
onready var file_menu_button: MenuButton = find_node("FileMenu")
onready var edit_menu_button: MenuButton = find_node("EditMenu")
onready var view_menu_button: MenuButton = find_node("ViewMenu")
onready var image_menu_button: MenuButton = find_node("ImageMenu")
onready var select_menu_button: MenuButton = find_node("SelectMenu")
onready var help_menu_button: MenuButton = find_node("HelpMenu")

onready var new_image_dialog: ConfirmationDialog = Global.control.find_node("CreateNewImage")
onready var window_opacity_dialog: AcceptDialog = Global.control.find_node("WindowOpacityDialog")
onready var tile_mode_submenu := PopupMenu.new()
onready var dockers_submenu := PopupMenu.new()
onready var panel_layout_submenu := PopupMenu.new()
onready var recent_projects_submenu := PopupMenu.new()


func _ready() -> void:
	_setup_file_menu()
	_setup_edit_menu()
	_setup_view_menu()
	_setup_image_menu()
	_setup_select_menu()
	_setup_help_menu()


func _setup_file_menu() -> void:
	var file_menu_items := {  # order as in FileMenuId enum
		"New...": InputMap.get_action_list("new_file")[0].get_scancode_with_modifiers(),
		"Open...": InputMap.get_action_list("open_file")[0].get_scancode_with_modifiers(),
		"Open last project...": 0,
		"Recent projects": 0,
		"Save...": InputMap.get_action_list("save_file")[0].get_scancode_with_modifiers(),
		"Save as...": InputMap.get_action_list("save_file_as")[0].get_scancode_with_modifiers(),
		"Export...": InputMap.get_action_list("export_file")[0].get_scancode_with_modifiers(),
		"Export as...": InputMap.get_action_list("export_file_as")[0].get_scancode_with_modifiers(),
		"Quit": InputMap.get_action_list("quit")[0].get_scancode_with_modifiers(),
	}
	file_menu = file_menu_button.get_popup()
	var i := 0

	for item in file_menu_items.keys():
		if item == "Recent projects":
			_setup_recent_projects_submenu(item)
		else:
			file_menu.add_item(item, i, file_menu_items[item])
			i += 1

	file_menu.connect("id_pressed", self, "file_menu_id_pressed")

	if OS.get_name() == "HTML5":
		file_menu.set_item_disabled(FileMenuId.OPEN_LAST_PROJECT, true)
		file_menu.set_item_disabled(FileMenuId.SAVE, true)


func _setup_recent_projects_submenu(item: String) -> void:
	recent_projects = Global.config_cache.get_value("data", "recent_projects", [])
	recent_projects_submenu.connect("id_pressed", self, "_on_recent_projects_submenu_id_pressed")
	update_recent_projects_submenu()

	file_menu.add_child(recent_projects_submenu)
	file_menu.add_submenu_item(item, recent_projects_submenu.get_name())


func update_recent_projects_submenu() -> void:
	for project in recent_projects:
		recent_projects_submenu.add_item(project.get_file())


func _setup_edit_menu() -> void:
	var edit_menu_items := {  # order as in EditMenuId enum
		"Undo": InputMap.get_action_list("undo")[0].get_scancode_with_modifiers(),
		"Redo": InputMap.get_action_list("redo")[0].get_scancode_with_modifiers(),
		"Copy": InputMap.get_action_list("copy")[0].get_scancode_with_modifiers(),
		"Cut": InputMap.get_action_list("cut")[0].get_scancode_with_modifiers(),
		"Paste": InputMap.get_action_list("paste")[0].get_scancode_with_modifiers(),
		"Delete": InputMap.get_action_list("delete")[0].get_scancode_with_modifiers(),
		"New Brush": InputMap.get_action_list("new_brush")[0].get_scancode_with_modifiers(),
		"Preferences": 0
	}
	var edit_menu: PopupMenu = edit_menu_button.get_popup()
	var i := 0

	for item in edit_menu_items.keys():
		edit_menu.add_item(item, i, edit_menu_items[item])
		i += 1

	edit_menu.set_item_disabled(6, true)
	edit_menu.connect("id_pressed", self, "edit_menu_id_pressed")


func _setup_view_menu() -> void:
	var view_menu_items := {  # order as in ViewMenuId enum
		"Tile Mode": 0,
		"Window Opacity": 0,
		"Mirror View": InputMap.get_action_list("mirror_view")[0].get_scancode_with_modifiers(),
		"Show Grid": InputMap.get_action_list("show_grid")[0].get_scancode_with_modifiers(),
		"Show Pixel Grid":
		InputMap.get_action_list("show_pixel_grid")[0].get_scancode_with_modifiers(),
		"Show Rulers": InputMap.get_action_list("show_rulers")[0].get_scancode_with_modifiers(),
		"Show Guides": InputMap.get_action_list("show_guides")[0].get_scancode_with_modifiers(),
		"Dockers": 0,
		"Edit Mode": InputMap.get_action_list("edit_mode")[0].get_scancode_with_modifiers(),
		"Zen Mode": InputMap.get_action_list("zen_mode")[0].get_scancode_with_modifiers(),
		"Fullscreen Mode":
		InputMap.get_action_list("toggle_fullscreen")[0].get_scancode_with_modifiers(),
	}
	view_menu = view_menu_button.get_popup()

	var i := 0
	for item in view_menu_items.keys():
		if item == "Tile Mode":
			_setup_tile_mode_submenu(item)
		elif item == "Dockers":
			_setup_dockers_submenu(item)
		elif item == "Window Opacity":
			view_menu.add_item(item, i, view_menu_items[item])
		else:
			view_menu.add_check_item(item, i, view_menu_items[item])
		i += 1
	view_menu.set_item_checked(ViewMenuId.SHOW_RULERS, true)
	view_menu.set_item_checked(ViewMenuId.SHOW_GUIDES, true)
	view_menu.hide_on_checkable_item_selection = false
	view_menu.connect("id_pressed", self, "view_menu_id_pressed")
	# Disable window opacity item if per pixel transparency is not allowed
	view_menu.set_item_disabled(
		ViewMenuId.WINDOW_OPACITY,
		!ProjectSettings.get_setting("display/window/per_pixel_transparency/allowed")
	)


func _setup_tile_mode_submenu(item: String) -> void:
	tile_mode_submenu.set_name("tile_mode_submenu")
	tile_mode_submenu.add_radio_check_item("None", Global.TileMode.NONE)
	tile_mode_submenu.set_item_checked(Global.TileMode.NONE, true)
	tile_mode_submenu.add_radio_check_item("Tiled In Both Axis", Global.TileMode.BOTH)
	tile_mode_submenu.add_radio_check_item("Tiled In X Axis", Global.TileMode.X_AXIS)
	tile_mode_submenu.add_radio_check_item("Tiled In Y Axis", Global.TileMode.Y_AXIS)
	tile_mode_submenu.hide_on_checkable_item_selection = false

	tile_mode_submenu.connect("id_pressed", self, "_tile_mode_submenu_id_pressed")
	view_menu.add_child(tile_mode_submenu)
	view_menu.add_submenu_item(item, tile_mode_submenu.get_name())


func _setup_dockers_submenu(item: String) -> void:
	dockers_submenu.set_name("dockers_submenu")
	dockers_submenu.hide_on_checkable_item_selection = false
	for element in ui_elements:
		dockers_submenu.add_check_item(element.name)
		dockers_submenu.set_item_checked(ui_elements.find(element), true)

	dockers_submenu.connect("id_pressed", self, "_dockers_submenu_id_pressed")
	view_menu.add_child(dockers_submenu)
	view_menu.add_submenu_item(item, dockers_submenu.get_name())


func _setup_image_menu() -> void:
	var image_menu_items := {  # order as in ImageMenuId enum
		"Scale Image": 0,
		"Centralize Image": 0,
		"Crop Image": 0,
		"Resize Canvas": 0,
		"Flip": 0,
		"Rotate Image": 0,
		"Invert Colors": 0,
		"Desaturation": 0,
		"Outline": 0,
		"Adjust Hue/Saturation/Value": 0,
		"Gradient": 0,
		# "Shader" : 0
	}
	var image_menu: PopupMenu = image_menu_button.get_popup()

	var i := 0
	for item in image_menu_items.keys():
		image_menu.add_item(item, i, image_menu_items[item])
		if i == ImageMenuId.RESIZE_CANVAS:
			image_menu.add_separator()
		i += 1

	image_menu.connect("id_pressed", self, "image_menu_id_pressed")


func _setup_select_menu() -> void:
	var select_menu_items := {  # order as in EditMenuId enum
		"All": InputMap.get_action_list("select_all")[0].get_scancode_with_modifiers(),
		"Clear": InputMap.get_action_list("clear_selection")[0].get_scancode_with_modifiers(),
		"Invert": InputMap.get_action_list("invert_selection")[0].get_scancode_with_modifiers(),
	}
	var select_menu: PopupMenu = select_menu_button.get_popup()
	var i := 0

	for item in select_menu_items.keys():
		select_menu.add_item(item, i, select_menu_items[item])
		i += 1

	select_menu.connect("id_pressed", self, "select_menu_id_pressed")


func _setup_help_menu() -> void:
	var help_menu_items := {  # order as in HelpMenuId enum
		"View Splash Screen": 0,
		"Online Docs": InputMap.get_action_list("open_docs")[0].get_scancode_with_modifiers(),
		"Issue Tracker": 0,
		"Open Logs Folder": 0,
		"Changelog": 0,
		"About Pixelorama": 0
	}
	var help_menu: PopupMenu = help_menu_button.get_popup()

	var i := 0
	for item in help_menu_items.keys():
		help_menu.add_item(item, i, help_menu_items[item])
		i += 1

	help_menu.connect("id_pressed", self, "help_menu_id_pressed")


func file_menu_id_pressed(id: int) -> void:
	match id:
		FileMenuId.NEW:
			_on_new_project_file_menu_option_pressed()
		FileMenuId.OPEN:
			_open_project_file()
		FileMenuId.OPEN_LAST_PROJECT:
			_on_open_last_project_file_menu_option_pressed()
		FileMenuId.SAVE:
			_save_project_file()
		FileMenuId.SAVE_AS:
			_save_project_file_as()
		FileMenuId.EXPORT:
			_export_file()
		FileMenuId.EXPORT_AS:
			Global.export_dialog.popup_centered()
			Global.dialog_open(true)
		FileMenuId.QUIT:
			Global.control.show_quit_dialog()


func _on_new_project_file_menu_option_pressed() -> void:
	new_image_dialog.popup_centered()
	Global.dialog_open(true)


func _open_project_file() -> void:
	if OS.get_name() == "HTML5":
		Html5FileExchange.load_image()
	else:
		Global.open_sprites_dialog.popup_centered()
		Global.dialog_open(true)
		Global.control.opensprite_file_selected = false


func _on_open_last_project_file_menu_option_pressed() -> void:
	if Global.config_cache.has_section_key("preferences", "last_project_path"):
		Global.control.load_last_project()
	else:
		Global.error_dialog.set_text("You haven't saved or opened any project in Pixelorama yet!")
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)


func _save_project_file() -> void:
	Global.control.is_quitting_on_save = false
	var path = OpenSave.current_save_paths[Global.current_project_index]
	if path == "":
		if OS.get_name() == "HTML5":
			var save_dialog: ConfirmationDialog = Global.save_sprites_html5_dialog
			var save_filename = save_dialog.get_node("FileNameContainer/FileNameLineEdit")
			save_dialog.popup_centered()
			save_filename.text = Global.current_project.name
		else:
			Global.save_sprites_dialog.popup_centered()
			Global.save_sprites_dialog.current_file = Global.current_project.name
		Global.dialog_open(true)
	else:
		Global.control.save_project(path)


func _save_project_file_as() -> void:
	Global.control.is_quitting_on_save = false
	if OS.get_name() == "HTML5":
		var save_dialog: ConfirmationDialog = Global.save_sprites_html5_dialog
		var save_filename = save_dialog.get_node("FileNameContainer/FileNameLineEdit")
		save_dialog.popup_centered()
		save_filename.text = Global.current_project.name
	else:
		Global.save_sprites_dialog.popup_centered()
		Global.save_sprites_dialog.current_file = Global.current_project.name
	Global.dialog_open(true)


func _export_file() -> void:
	if Export.was_exported == false:
		Global.export_dialog.popup_centered()
		Global.dialog_open(true)
	else:
		Export.external_export()


func _on_recent_projects_submenu_id_pressed(id: int) -> void:
	Global.control.load_recent_project_file(recent_projects[id])


func edit_menu_id_pressed(id: int) -> void:
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
		EditMenuId.NEW_BRUSH:
			Global.canvas.selection.new_brush()
		EditMenuId.PREFERENCES:
			Global.preferences_dialog.popup_centered(Vector2(400, 280))
			Global.dialog_open(true)


func view_menu_id_pressed(id: int) -> void:
	match id:
		ViewMenuId.WINDOW_OPACITY:
			window_opacity_dialog.popup_centered()
			Global.dialog_open(true)
		ViewMenuId.MIRROR_VIEW:
			_toggle_mirror_view()
		ViewMenuId.SHOW_GRID:
			_toggle_show_grid()
		ViewMenuId.SHOW_PIXEL_GRID:
			_toggle_show_pixel_grid()
		ViewMenuId.SHOW_RULERS:
			_toggle_show_rulers()
		ViewMenuId.SHOW_GUIDES:
			_toggle_show_guides()
		ViewMenuId.EDIT_MODE:
			Global.control.ui.tabs_visible = !Global.control.ui.tabs_visible
			view_menu.set_item_checked(ViewMenuId.EDIT_MODE, Global.control.ui.tabs_visible)
		ViewMenuId.ZEN_MODE:
			_toggle_zen_mode()
		ViewMenuId.FULLSCREEN_MODE:
			_toggle_fullscreen()
	Global.canvas.update()


func _tile_mode_submenu_id_pressed(id: int) -> void:
	Global.current_project.tile_mode = id
	Global.transparent_checker.fit_rect(Global.current_project.get_tile_mode_rect())
	for i in Global.TileMode.values():
		tile_mode_submenu.set_item_checked(i, i == id)
	Global.canvas.tile_mode.update()
	Global.canvas.pixel_grid.update()
	Global.canvas.grid.update()


func _dockers_submenu_id_pressed(id: int) -> void:
	if zen_mode:
		return
	var element_visible = dockers_submenu.is_item_checked(id)
	Global.control.ui.set_control_hidden(ui_elements[id], element_visible)
	dockers_submenu.set_item_checked(id, !element_visible)


func _toggle_mirror_view() -> void:
	Global.mirror_view = !Global.mirror_view
	var marching_ants_outline: Sprite = Global.canvas.selection.marching_ants_outline
	marching_ants_outline.scale.x = -marching_ants_outline.scale.x
	if Global.mirror_view:
		marching_ants_outline.position.x = (
			marching_ants_outline.position.x
			+ Global.current_project.size.x
		)
	else:
		Global.canvas.selection.marching_ants_outline.position.x = 0
	Global.canvas.selection.update()
	view_menu.set_item_checked(ViewMenuId.MIRROR_VIEW, Global.mirror_view)


func _toggle_show_grid() -> void:
	Global.draw_grid = !Global.draw_grid
	view_menu.set_item_checked(ViewMenuId.SHOW_GRID, Global.draw_grid)
	Global.canvas.grid.update()


func _toggle_show_pixel_grid() -> void:
	Global.draw_pixel_grid = !Global.draw_pixel_grid
	view_menu.set_item_checked(ViewMenuId.SHOW_PIXEL_GRID, Global.draw_pixel_grid)
	Global.canvas.pixel_grid.update()


func _toggle_show_rulers() -> void:
	Global.show_rulers = !Global.show_rulers
	view_menu.set_item_checked(ViewMenuId.SHOW_RULERS, Global.show_rulers)
	Global.horizontal_ruler.visible = Global.show_rulers
	Global.vertical_ruler.visible = Global.show_rulers


func _toggle_show_guides() -> void:
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


func _toggle_zen_mode() -> void:
	Global.control.ui.set_control_hidden(Global.animation_timeline, !zen_mode)
	Global.control.ui.set_control_hidden(Global.tool_panel, !zen_mode)
	Global.control.ui.set_control_hidden(Global.canvas_preview_container, !zen_mode)
	Global.control.ui.set_control_hidden(Global.color_pickers, !zen_mode)
	Global.control.ui.set_control_hidden(Global.left_tool_options_scroll, !zen_mode)
	Global.control.ui.set_control_hidden(Global.right_tool_options_scroll, !zen_mode)
	Global.control.ui.set_control_hidden(Global.palette_panel, !zen_mode)
	Global.control.find_node("TabsContainer").visible = zen_mode
	zen_mode = !zen_mode
	view_menu.set_item_checked(ViewMenuId.ZEN_MODE, zen_mode)


func _toggle_fullscreen() -> void:
	OS.window_fullscreen = !OS.window_fullscreen
	view_menu.set_item_checked(ViewMenuId.FULLSCREEN_MODE, OS.window_fullscreen)
	if OS.window_fullscreen:  # If window is fullscreen then reset transparency
		window_opacity_dialog.set_window_opacity(1.0)


func image_menu_id_pressed(id: int) -> void:
	match id:
		ImageMenuId.SCALE_IMAGE:
			_show_scale_image_popup()

		ImageMenuId.CENTRALIZE_IMAGE:
			DrawingAlgos.centralize()

		ImageMenuId.CROP_IMAGE:
			DrawingAlgos.crop_image()

		ImageMenuId.RESIZE_CANVAS:
			_show_resize_canvas_popup()

		ImageMenuId.FLIP:
			Global.control.get_node("Dialogs/ImageEffects/FlipImageDialog").popup_centered()
			Global.dialog_open(true)

		ImageMenuId.ROTATE:
			_show_rotate_image_popup()

		ImageMenuId.INVERT_COLORS:
			Global.control.get_node("Dialogs/ImageEffects/InvertColorsDialog").popup_centered()
			Global.dialog_open(true)

		ImageMenuId.DESATURATION:
			Global.control.get_node("Dialogs/ImageEffects/DesaturateDialog").popup_centered()
			Global.dialog_open(true)

		ImageMenuId.OUTLINE:
			_show_add_outline_popup()

		ImageMenuId.HSV:
			_show_hsv_configuration_popup()

		ImageMenuId.GRADIENT:
			Global.control.get_node("Dialogs/ImageEffects/GradientDialog").popup_centered()
			Global.dialog_open(true)

		ImageMenuId.SHADER:
			Global.control.get_node("Dialogs/ImageEffects/ShaderEffect").popup_centered()
			Global.dialog_open(true)


func _show_scale_image_popup() -> void:
	Global.control.get_node("Dialogs/ImageEffects/ScaleImage").popup_centered()
	Global.dialog_open(true)


func _show_resize_canvas_popup() -> void:
	Global.control.get_node("Dialogs/ImageEffects/ResizeCanvas").popup_centered()
	Global.dialog_open(true)


func _show_rotate_image_popup() -> void:
	Global.control.get_node("Dialogs/ImageEffects/RotateImage").popup_centered()
	Global.dialog_open(true)


func _show_add_outline_popup() -> void:
	Global.control.get_node("Dialogs/ImageEffects/OutlineDialog").popup_centered()
	Global.dialog_open(true)


func _show_hsv_configuration_popup() -> void:
	Global.control.get_node("Dialogs/ImageEffects/HSVDialog").popup_centered()
	Global.dialog_open(true)


func select_menu_id_pressed(id: int) -> void:
	match id:
		SelectMenuId.SELECT_ALL:
			Global.canvas.selection.select_all()
		SelectMenuId.CLEAR_SELECTION:
			Global.canvas.selection.clear_selection(true)
		SelectMenuId.INVERT:
			Global.canvas.selection.invert()


func help_menu_id_pressed(id: int) -> void:
	match id:
		HelpMenuId.VIEW_SPLASH_SCREEN:
			Global.control.get_node("Dialogs/SplashDialog").popup_centered()
			Global.dialog_open(true)
		HelpMenuId.ONLINE_DOCS:
			OS.shell_open("https://orama-interactive.github.io/Pixelorama-Docs/")
		HelpMenuId.ISSUE_TRACKER:
			OS.shell_open("https://github.com/Orama-Interactive/Pixelorama/issues")
		HelpMenuId.OPEN_LOGS_FOLDER:
			var dir = Directory.new()
			dir.make_dir_recursive("user://logs")  # In case someone deleted it
			OS.shell_open(ProjectSettings.globalize_path("user://logs"))
		HelpMenuId.CHANGELOG:
			OS.shell_open(
				"https://github.com/Orama-Interactive/Pixelorama/blob/master/CHANGELOG.md#v092---2022-01-21"
			)
		HelpMenuId.ABOUT_PIXELORAMA:
			Global.control.get_node("Dialogs/AboutDialog").popup_centered()
			Global.dialog_open(true)
