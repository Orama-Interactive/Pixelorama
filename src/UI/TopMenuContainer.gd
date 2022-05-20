extends Panel

var file_menu: PopupMenu
var view_menu: PopupMenu
var window_menu: PopupMenu
var recent_projects := []
var layouts := [
	["Default", preload("res://assets/layouts/default.tres")],
	["Tallscreen", preload("res://assets/layouts/tallscreen.tres")],
]
var default_layout_size := layouts.size()
var selected_layout := 0
var zen_mode := false

onready var ui_elements: Array = Global.control.find_node("DockableContainer").get_children()
onready var file_menu_button: MenuButton = find_node("FileMenu")
onready var edit_menu_button: MenuButton = find_node("EditMenu")
onready var view_menu_button: MenuButton = find_node("ViewMenu")
onready var window_menu_button: MenuButton = find_node("WindowMenu")
onready var image_menu_button: MenuButton = find_node("ImageMenu")
onready var select_menu_button: MenuButton = find_node("SelectMenu")
onready var help_menu_button: MenuButton = find_node("HelpMenu")

onready var ui: Container = Global.control.find_node("DockableContainer")
onready var greyscale_vision: ColorRect = ui.find_node("GreyscaleVision")
onready var new_image_dialog: ConfirmationDialog = Global.control.find_node("CreateNewImage")
onready var window_opacity_dialog: AcceptDialog = Global.control.find_node("WindowOpacityDialog")
onready var tile_mode_submenu := PopupMenu.new()
onready var panels_submenu := PopupMenu.new()
onready var layouts_submenu := PopupMenu.new()
onready var recent_projects_submenu := PopupMenu.new()


func _ready() -> void:
	var dir := Directory.new()
	dir.make_dir("user://layouts")
	_setup_file_menu()
	_setup_edit_menu()
	_setup_view_menu()
	_setup_window_menu()
	_setup_image_menu()
	_setup_select_menu()
	_setup_help_menu()


func _setup_file_menu() -> void:
	# Order as in FileMenu enum
	var file_menu_items := [
		"New...",
		"Open...",
		"Open last project...",
		"Recent projects",
		"Save...",
		"Save as...",
		"Export...",
		"Export as...",
		"Quit",
	]
	file_menu = file_menu_button.get_popup()
	var i := 0
	for item in file_menu_items:
		if item == "Recent projects":
			_setup_recent_projects_submenu(item)
		else:
			file_menu.add_item(item, i)
		i += 1

	file_menu.connect("id_pressed", self, "file_menu_id_pressed")

	if OS.get_name() == "HTML5":
		file_menu.set_item_disabled(Global.FileMenu.OPEN_LAST_PROJECT, true)
		file_menu.set_item_disabled(Global.FileMenu.SAVE, true)


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
	# Order as in Global.EditMenu enum
	var edit_menu_items := [
		"Undo", "Redo", "Copy", "Cut", "Paste", "Delete", "New Brush", "Preferences"
	]
	var edit_menu: PopupMenu = edit_menu_button.get_popup()
	var i := 0
	for item in edit_menu_items:
		edit_menu.add_item(item, i)
		i += 1

	edit_menu.set_item_disabled(6, true)
	edit_menu.connect("id_pressed", self, "edit_menu_id_pressed")


func _setup_view_menu() -> void:
	# Order as in Global.ViewMenu enum
	var view_menu_items := [
		"Tile Mode",
		"Greyscale View",
		"Mirror View",
		"Show Grid",
		"Show Pixel Grid",
		"Show Rulers",
		"Show Guides",
	]
	view_menu = view_menu_button.get_popup()
	var i := 0
	for item in view_menu_items:
		if item == "Tile Mode":
			_setup_tile_mode_submenu(item)
		else:
			view_menu.add_check_item(item, i)
		i += 1
	view_menu.set_item_checked(Global.ViewMenu.SHOW_RULERS, true)
	view_menu.set_item_checked(Global.ViewMenu.SHOW_GUIDES, true)
	view_menu.hide_on_checkable_item_selection = false
	view_menu.connect("id_pressed", self, "view_menu_id_pressed")

	var draw_grid: bool = Global.config_cache.get_value("view_menu", "draw_grid", Global.draw_grid)
	if draw_grid != Global.draw_grid:
		_toggle_show_grid()

	var draw_pixel_grid: bool = Global.config_cache.get_value(
		"view_menu", "draw_pixel_grid", Global.draw_pixel_grid
	)
	if draw_pixel_grid != Global.draw_pixel_grid:
		_toggle_show_pixel_grid()

	var show_rulers: bool = Global.config_cache.get_value(
		"view_menu", "show_rulers", Global.show_rulers
	)
	if show_rulers != Global.show_rulers:
		_toggle_show_rulers()

	var show_guides: bool = Global.config_cache.get_value(
		"view_menu", "show_guides", Global.show_guides
	)
	if show_guides != Global.show_guides:
		_toggle_show_guides()


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


func _setup_window_menu() -> void:
	# Order as in Global.WindowMenu enum
	var window_menu_items := [
		"Window Opacity",
		"Panels",
		"Layouts",
		"Moveable Panels",
		"Zen Mode",
		"Fullscreen Mode",
	]
	window_menu = window_menu_button.get_popup()
	var i := 0
	for item in window_menu_items:
		if item == "Panels":
			_setup_panels_submenu(item)
		elif item == "Layouts":
			_setup_layouts_submenu(item)
		elif item == "Window Opacity":
			window_menu.add_item(item, i)
		else:
			window_menu.add_check_item(item, i)
		i += 1
	window_menu.hide_on_checkable_item_selection = false
	window_menu.connect("id_pressed", self, "window_menu_id_pressed")
	# Disable window opacity item if per pixel transparency is not allowed
	window_menu.set_item_disabled(
		Global.WindowMenu.WINDOW_OPACITY,
		!ProjectSettings.get_setting("display/window/per_pixel_transparency/allowed")
	)


func _setup_panels_submenu(item: String) -> void:
	panels_submenu.set_name("panels_submenu")
	panels_submenu.hide_on_checkable_item_selection = false
	for element in ui_elements:
		panels_submenu.add_check_item(element.name)
		var is_hidden: bool = ui.is_control_hidden(element)
		panels_submenu.set_item_checked(ui_elements.find(element), !is_hidden)

	panels_submenu.connect("id_pressed", self, "_panels_submenu_id_pressed")
	window_menu.add_child(panels_submenu)
	window_menu.add_submenu_item(item, panels_submenu.get_name())


func _setup_layouts_submenu(item: String) -> void:
	var dir := Directory.new()
	var path := "user://layouts"
	if dir.open(path) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir():
				var file_name_no_tres: String = file_name.get_basename()
				layouts.append([file_name_no_tres, ResourceLoader.load(path.plus_file(file_name))])
			file_name = dir.get_next()

	layouts_submenu.set_name("layouts_submenu")
	layouts_submenu.hide_on_checkable_item_selection = false
	populate_layouts_submenu()

	layouts_submenu.connect("id_pressed", self, "_layouts_submenu_id_pressed")
	window_menu.add_child(layouts_submenu)
	window_menu.add_submenu_item(item, layouts_submenu.get_name())

	var saved_layout = Global.config_cache.get_value("window", "layout", 0)
	set_layout(saved_layout)


func populate_layouts_submenu() -> void:
	layouts_submenu.clear()  # Does not do anything if it's called for the first time
	layouts_submenu.add_item("Manage Layouts", 0)
	for layout in layouts:
		layouts_submenu.add_radio_check_item(layout[0])


func _setup_image_menu() -> void:
	# Order as in Global.ImageMenu enum
	var image_menu_items := [
		"Scale Image",
		"Centralize Image",
		"Crop Image",
		"Resize Canvas",
		"Mirror Image",
		"Rotate Image",
		"Invert Colors",
		"Desaturation",
		"Outline",
		"Drop Shadow",
		"Adjust Hue/Saturation/Value",
		"Gradient",
		# "Shader"
	]
	var image_menu: PopupMenu = image_menu_button.get_popup()
	var i := 0
	for item in image_menu_items:
		image_menu.add_item(item, i)
		if i == Global.ImageMenu.RESIZE_CANVAS:
			image_menu.add_separator()
		i += 1

	image_menu.connect("id_pressed", self, "image_menu_id_pressed")


func _setup_select_menu() -> void:
	# Order as in Global.SelectMenu enum
	var select_menu_items := ["All", "Clear", "Invert"]
	var select_menu: PopupMenu = select_menu_button.get_popup()
	var i := 0
	for item in select_menu_items:
		select_menu.add_item(item, i)
		i += 1

	select_menu.connect("id_pressed", self, "select_menu_id_pressed")


func _setup_help_menu() -> void:
	# Order as in Global.HelpMenu enum
	var help_menu_items := [
		"View Splash Screen",
		"Online Docs",
		"Issue Tracker",
		"Open Logs Folder",
		"Changelog",
		"About Pixelorama",
	]
	var help_menu: PopupMenu = help_menu_button.get_popup()
	var i := 0
	for item in help_menu_items:
		help_menu.add_item(item, i)
		i += 1

	help_menu.connect("id_pressed", self, "help_menu_id_pressed")


func _handle_metadata(id: int, menu_button: MenuButton) -> void:
	# Used for extensions that want to add extra menu items
	var metadata = menu_button.get_popup().get_item_metadata(id)
	if metadata:
		if metadata is Object:
			if metadata.has_method("menu_item_clicked"):
				metadata.call("menu_item_clicked")


func file_menu_id_pressed(id: int) -> void:
	match id:
		Global.FileMenu.NEW:
			_on_new_project_file_menu_option_pressed()
		Global.FileMenu.OPEN:
			_open_project_file()
		Global.FileMenu.OPEN_LAST_PROJECT:
			_on_open_last_project_file_menu_option_pressed()
		Global.FileMenu.SAVE:
			_save_project_file()
		Global.FileMenu.SAVE_AS:
			_save_project_file_as()
		Global.FileMenu.EXPORT:
			_export_file()
		Global.FileMenu.EXPORT_AS:
			Global.export_dialog.popup_centered()
			Global.dialog_open(true)
		Global.FileMenu.QUIT:
			Global.control.show_quit_dialog()
		_:
			_handle_metadata(id, file_menu_button)


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
		Global.EditMenu.UNDO:
			Global.current_project.commit_undo()
		Global.EditMenu.REDO:
			Global.current_project.commit_redo()
		Global.EditMenu.COPY:
			Global.canvas.selection.copy()
		Global.EditMenu.CUT:
			Global.canvas.selection.cut()
		Global.EditMenu.PASTE:
			Global.canvas.selection.paste()
		Global.EditMenu.DELETE:
			Global.canvas.selection.delete()
		Global.EditMenu.NEW_BRUSH:
			Global.canvas.selection.new_brush()
		Global.EditMenu.PREFERENCES:
			Global.preferences_dialog.popup_centered(Vector2(400, 280))
			Global.dialog_open(true)
		_:
			_handle_metadata(id, edit_menu_button)


func view_menu_id_pressed(id: int) -> void:
	match id:
		Global.ViewMenu.GREYSCALE_VIEW:
			_toggle_greyscale_view()
		Global.ViewMenu.MIRROR_VIEW:
			_toggle_mirror_view()
		Global.ViewMenu.SHOW_GRID:
			_toggle_show_grid()
		Global.ViewMenu.SHOW_PIXEL_GRID:
			_toggle_show_pixel_grid()
		Global.ViewMenu.SHOW_RULERS:
			_toggle_show_rulers()
		Global.ViewMenu.SHOW_GUIDES:
			_toggle_show_guides()
		_:
			_handle_metadata(id, view_menu_button)

	Global.canvas.update()


func _tile_mode_submenu_id_pressed(id: int) -> void:
	Global.current_project.tile_mode = id
	Global.transparent_checker.fit_rect(Global.current_project.get_tile_mode_rect())
	for i in Global.TileMode.values():
		tile_mode_submenu.set_item_checked(i, i == id)
	Global.canvas.tile_mode.update()
	Global.canvas.pixel_grid.update()
	Global.canvas.grid.update()


func window_menu_id_pressed(id: int) -> void:
	match id:
		Global.WindowMenu.WINDOW_OPACITY:
			window_opacity_dialog.popup_centered()
			Global.dialog_open(true)
		Global.WindowMenu.MOVABLE_PANELS:
			ui.tabs_visible = !ui.tabs_visible
			window_menu.set_item_checked(id, ui.tabs_visible)
		Global.WindowMenu.ZEN_MODE:
			_toggle_zen_mode()
		Global.WindowMenu.FULLSCREEN_MODE:
			_toggle_fullscreen()
		_:
			_handle_metadata(id, window_menu_button)


func _panels_submenu_id_pressed(id: int) -> void:
	if zen_mode:
		return

	var element_visible = panels_submenu.is_item_checked(id)
	ui.set_control_hidden(ui_elements[id], element_visible)
	panels_submenu.set_item_checked(id, !element_visible)


func _layouts_submenu_id_pressed(id: int) -> void:
	if id == 0:
		Global.control.get_node("Dialogs/ManageLayouts").popup_centered()
		Global.dialog_open(true)
	else:
		set_layout(id - 1)


func set_layout(id: int) -> void:
	if id >= layouts.size():
		id = 0
	selected_layout = id
	ui.layout = layouts[id][1].clone()  # Clone is needed to avoid modifying premade layouts
	for i in layouts.size():
		var offset: int = i + 1
		layouts_submenu.set_item_checked(offset, offset == (id + 1))

	for i in ui_elements.size():
		var is_hidden: bool = ui.is_control_hidden(ui_elements[i])
		panels_submenu.set_item_checked(i, !is_hidden)

	if zen_mode:  # Turn zen mode off
		Global.control.find_node("TabsContainer").visible = true
		zen_mode = false
		window_menu.set_item_checked(Global.WindowMenu.ZEN_MODE, false)

	# Hacky but without 2 idle frames it doesn't work properly. Should be replaced eventually
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	# Call set_tabs_visible to keep tabs visible if there are 2 or more in the same panel
	ui.tabs_visible = ui.tabs_visible


func _toggle_greyscale_view() -> void:
	Global.greyscale_view = !Global.greyscale_view
	greyscale_vision.visible = Global.greyscale_view
	view_menu.set_item_checked(Global.ViewMenu.GREYSCALE_VIEW, Global.greyscale_view)


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
	view_menu.set_item_checked(Global.ViewMenu.MIRROR_VIEW, Global.mirror_view)


func _toggle_show_grid() -> void:
	Global.draw_grid = !Global.draw_grid
	view_menu.set_item_checked(Global.ViewMenu.SHOW_GRID, Global.draw_grid)
	if Global.canvas.grid:
		Global.canvas.grid.update()


func _toggle_show_pixel_grid() -> void:
	Global.draw_pixel_grid = !Global.draw_pixel_grid
	view_menu.set_item_checked(Global.ViewMenu.SHOW_PIXEL_GRID, Global.draw_pixel_grid)
	if Global.canvas.pixel_grid:
		Global.canvas.pixel_grid.update()


func _toggle_show_rulers() -> void:
	Global.show_rulers = !Global.show_rulers
	view_menu.set_item_checked(Global.ViewMenu.SHOW_RULERS, Global.show_rulers)
	Global.horizontal_ruler.visible = Global.show_rulers
	Global.vertical_ruler.visible = Global.show_rulers


func _toggle_show_guides() -> void:
	Global.show_guides = !Global.show_guides
	view_menu.set_item_checked(Global.ViewMenu.SHOW_GUIDES, Global.show_guides)
	for guide in Global.canvas.get_children():
		if guide is Guide and guide in Global.current_project.guides:
			guide.visible = Global.show_guides
			if guide is SymmetryGuide:
				if guide.type == Guide.Types.HORIZONTAL:
					guide.visible = Global.show_x_symmetry_axis and Global.show_guides
				else:
					guide.visible = Global.show_y_symmetry_axis and Global.show_guides


func _toggle_zen_mode() -> void:
	for i in ui_elements.size():
		if ui_elements[i].name == "Main Canvas":
			continue
		if !panels_submenu.is_item_checked(i):
			continue
		ui.set_control_hidden(ui_elements[i], !zen_mode)
	Global.control.find_node("TabsContainer").visible = zen_mode
	zen_mode = !zen_mode
	window_menu.set_item_checked(Global.WindowMenu.ZEN_MODE, zen_mode)


func _toggle_fullscreen() -> void:
	OS.window_fullscreen = !OS.window_fullscreen
	window_menu.set_item_checked(Global.WindowMenu.FULLSCREEN_MODE, OS.window_fullscreen)
	if OS.window_fullscreen:  # If window is fullscreen then reset transparency
		window_opacity_dialog.set_window_opacity(1.0)


func image_menu_id_pressed(id: int) -> void:
	match id:
		Global.ImageMenu.SCALE_IMAGE:
			_show_scale_image_popup()

		Global.ImageMenu.CENTRALIZE_IMAGE:
			DrawingAlgos.centralize()

		Global.ImageMenu.CROP_IMAGE:
			DrawingAlgos.crop_image()

		Global.ImageMenu.RESIZE_CANVAS:
			_show_resize_canvas_popup()

		Global.ImageMenu.FLIP:
			Global.control.get_node("Dialogs/ImageEffects/FlipImageDialog").popup_centered()
			Global.dialog_open(true)

		Global.ImageMenu.ROTATE:
			_show_rotate_image_popup()

		Global.ImageMenu.INVERT_COLORS:
			Global.control.get_node("Dialogs/ImageEffects/InvertColorsDialog").popup_centered()
			Global.dialog_open(true)

		Global.ImageMenu.DESATURATION:
			Global.control.get_node("Dialogs/ImageEffects/DesaturateDialog").popup_centered()
			Global.dialog_open(true)

		Global.ImageMenu.OUTLINE:
			_show_add_outline_popup()

		Global.ImageMenu.DROP_SHADOW:
			_show_drop_shadow_popup()

		Global.ImageMenu.HSV:
			_show_hsv_configuration_popup()

		Global.ImageMenu.GRADIENT:
			Global.control.get_node("Dialogs/ImageEffects/GradientDialog").popup_centered()
			Global.dialog_open(true)

#		Global.ImageMenu.SHADER:
#			Global.control.get_node("Dialogs/ImageEffects/ShaderEffect").popup_centered()
#			Global.dialog_open(true)

		_:
			_handle_metadata(id, image_menu_button)


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


func _show_drop_shadow_popup() -> void:
	Global.control.get_node("Dialogs/ImageEffects/DropShadowDialog").popup_centered()
	Global.dialog_open(true)


func _show_hsv_configuration_popup() -> void:
	Global.control.get_node("Dialogs/ImageEffects/HSVDialog").popup_centered()
	Global.dialog_open(true)


func select_menu_id_pressed(id: int) -> void:
	match id:
		Global.SelectMenu.SELECT_ALL:
			Global.canvas.selection.select_all()
		Global.SelectMenu.CLEAR_SELECTION:
			Global.canvas.selection.clear_selection(true)
		Global.SelectMenu.INVERT:
			Global.canvas.selection.invert()
		_:
			_handle_metadata(id, select_menu_button)


func help_menu_id_pressed(id: int) -> void:
	match id:
		Global.HelpMenu.VIEW_SPLASH_SCREEN:
			Global.control.get_node("Dialogs/SplashDialog").popup_centered()
			Global.dialog_open(true)
		Global.HelpMenu.ONLINE_DOCS:
			OS.shell_open("https://orama-interactive.github.io/Pixelorama-Docs/")
		Global.HelpMenu.ISSUE_TRACKER:
			OS.shell_open("https://github.com/Orama-Interactive/Pixelorama/issues")
		Global.HelpMenu.OPEN_LOGS_FOLDER:
			var dir = Directory.new()
			dir.make_dir_recursive("user://logs")  # In case someone deleted it
			OS.shell_open(ProjectSettings.globalize_path("user://logs"))
		Global.HelpMenu.CHANGELOG:
			OS.shell_open(
				"https://github.com/Orama-Interactive/Pixelorama/blob/master/CHANGELOG.md#v010---2022-04-15"
			)
		Global.HelpMenu.ABOUT_PIXELORAMA:
			Global.control.get_node("Dialogs/AboutDialog").popup_centered()
			Global.dialog_open(true)
		_:
			_handle_metadata(id, help_menu_button)
