extends Panel

enum ColorModes { RGBA, INDEXED }

const DOCS_URL := "https://www.oramainteractive.com/Pixelorama-Docs/"
const ISSUES_URL := "https://github.com/Orama-Interactive/Pixelorama/issues"
const SUPPORT_URL := "https://www.patreon.com/OramaInteractive"
# gdlint: ignore=max-line-length
const CHANGELOG_URL := "https://github.com/Orama-Interactive/Pixelorama/blob/master/CHANGELOG.md#v105---2024-11-18"
const EXTERNAL_LINK_ICON := preload("res://assets/graphics/misc/external_link.svg")
const PIXELORAMA_ICON := preload("res://assets/graphics/icons/icon_16x16.png")
const HEART_ICON := preload("res://assets/graphics/misc/heart.svg")

var recent_projects := []
var selected_layout := 0
var zen_mode := false
var tile_mode_submenu := PopupMenu.new()
var selection_modify_submenu := PopupMenu.new()
var color_mode_submenu := PopupMenu.new()
var snap_to_submenu := PopupMenu.new()
var panels_submenu := PopupMenu.new()
var layouts_submenu := PopupMenu.new()
var recent_projects_submenu := PopupMenu.new()
var effects_transform_submenu := PopupMenu.new()
var effects_color_submenu := PopupMenu.new()
var effects_procedural_submenu := PopupMenu.new()
var effects_blur_submenu := PopupMenu.new()
var effects_loaded_submenu: PopupMenu

# Dialogs
var new_image_dialog := Dialog.new("res://src/UI/Dialogs/CreateNewImage.tscn")
var project_properties_dialog := Dialog.new("res://src/UI/Dialogs/ProjectProperties.tscn")
var preferences_dialog := Dialog.new("res://src/Preferences/PreferencesDialog.tscn")
var modify_selection := Dialog.new("res://src/UI/Dialogs/ModifySelection.tscn")
var offset_image_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/OffsetImage.tscn")
var scale_image_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/ScaleImage.tscn")
var resize_canvas_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/ResizeCanvas.tscn")
var mirror_image_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/FlipImageDialog.tscn")
var rotate_image_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/RotateImage.tscn")
var invert_colors_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/InvertColorsDialog.tscn")
var desaturate_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/DesaturateDialog.tscn")
var outline_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/OutlineDialog.tscn")
var drop_shadow_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/DropShadowDialog.tscn")
var hsv_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/HSVDialog.tscn")
var adjust_brightness_saturation_dialog := Dialog.new(
	"res://src/UI/Dialogs/ImageEffects/BrightnessContrastDialog.tscn"
)
var color_curves_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/ColorCurvesDialog.tscn")
var gaussian_blur_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/GaussianBlur.tscn")
var gradient_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/GradientDialog.tscn")
var gradient_map_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/GradientMapDialog.tscn")
var palettize_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/PalettizeDialog.tscn")
var pixelize_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/PixelizeDialog.tscn")
var posterize_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/Posterize.tscn")
var loaded_effect_dialogs: Array[Dialog] = []
var window_opacity_dialog := Dialog.new("res://src/UI/Dialogs/WindowOpacityDialog.tscn")
var about_dialog := Dialog.new("res://src/UI/Dialogs/AboutDialog.tscn")

@onready var main_ui := Global.control.find_child("DockableContainer") as DockableContainer
@onready var ui_elements := main_ui.get_children()
@onready var file_menu := $MarginContainer/HBoxContainer/MenuBar/File as PopupMenu
@onready var edit_menu := $MarginContainer/HBoxContainer/MenuBar/Edit as PopupMenu
@onready var select_menu := $MarginContainer/HBoxContainer/MenuBar/Select as PopupMenu
@onready var image_menu := $MarginContainer/HBoxContainer/MenuBar/Image as PopupMenu
@onready var effects_menu := $MarginContainer/HBoxContainer/MenuBar/Effects as PopupMenu
@onready var view_menu := $MarginContainer/HBoxContainer/MenuBar/View as PopupMenu
@onready var window_menu := $MarginContainer/HBoxContainer/MenuBar/Window as PopupMenu
@onready var help_menu := $MarginContainer/HBoxContainer/MenuBar/Help as PopupMenu
@onready var add_layout_confirmation := $AddLayoutConfirmation as ConfirmationDialog
@onready var delete_layout_confirmation := $DeleteLayoutConfirmation as ConfirmationDialog
@onready var layout_name_line_edit := %LayoutName as LineEdit
@onready var layout_from_option_button := %LayoutFrom as OptionButton

@onready var greyscale_vision: ColorRect = main_ui.find_child("GreyscaleVision")
@onready var current_frame_mark := %CurrentFrameMark as Label


class Dialog:
	## This class is used to help with lazy loading dialog scenes in order to
	## reduce Pixelorama's initial loading time, by only loading each dialog
	## scene when it's actually needed.
	var scene_path := ""
	var node: Window

	func _init(_scene_path: String) -> void:
		scene_path = _scene_path

	func popup(dialog_size := Vector2i.ZERO) -> void:
		if not is_instance_valid(node):
			instantiate_scene()
		node.popup_centered(dialog_size)
		var is_file_dialog := node is FileDialog
		Global.dialog_open(true, is_file_dialog)

	func instantiate_scene() -> void:
		var scene := load(scene_path)
		if not scene is PackedScene:
			return
		node = scene.instantiate()
		if is_instance_valid(node):
			Global.control.get_node("Dialogs").add_child(node)


func _ready() -> void:
	Global.project_switched.connect(_project_switched)
	Global.cel_switched.connect(_update_current_frame_mark)
	OpenSave.shader_copied.connect(_load_shader_file)
	_setup_file_menu()
	_setup_edit_menu()
	_setup_view_menu()
	_setup_window_menu()
	_setup_image_menu()
	_setup_effects_menu()
	_setup_select_menu()
	_setup_help_menu()
	# Fill the copy layout from option button with the default layouts
	for layout in Global.default_layouts:
		layout_from_option_button.add_item(layout.resource_path.get_basename().get_file())


func _input(event: InputEvent) -> void:
	# Workaround for https://github.com/Orama-Interactive/Pixelorama/issues/1070
	if event is InputEventMouseButton and event.pressed:
		file_menu.activate_item_by_event(event)
		edit_menu.activate_item_by_event(event)
		select_menu.activate_item_by_event(event)
		image_menu.activate_item_by_event(event)
		effects_menu.activate_item_by_event(event)
		view_menu.activate_item_by_event(event)
		window_menu.activate_item_by_event(event)
		help_menu.activate_item_by_event(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and Global.current_project != null:
		_update_file_menu_buttons(Global.current_project)


func _project_switched() -> void:
	var project := Global.current_project
	edit_menu.set_item_disabled(Global.EditMenu.NEW_BRUSH, not project.has_selection)
	_update_file_menu_buttons(project)
	for j in Tiles.MODE.values():
		tile_mode_submenu.set_item_checked(j, j == project.tiles.mode)
	_check_color_mode_submenu_item(project)

	_update_current_frame_mark()


func _update_file_menu_buttons(project: Project) -> void:
	if project.export_directory_path.is_empty():
		file_menu.set_item_text(Global.FileMenu.SAVE, tr("Save"))
	else:
		file_menu.set_item_text(Global.FileMenu.SAVE, tr("Save") + " %s" % project.file_name)
	if project.was_exported:
		var f_name := " %s" % (project.file_name + Export.file_format_string(project.file_format))
		if project.export_overwrite:
			file_menu.set_item_text(Global.FileMenu.EXPORT, tr("Overwrite") + f_name)
		else:
			file_menu.set_item_text(Global.FileMenu.EXPORT, tr("Export") + f_name)
	else:
		file_menu.set_item_text(Global.FileMenu.EXPORT, tr("Export"))


func _update_current_frame_mark() -> void:
	var project := Global.current_project
	current_frame_mark.text = "%s/%s" % [str(project.current_frame + 1), project.frames.size()]


func _setup_file_menu() -> void:
	# Order as in FileMenu enum
	var file_menu_items := {
		"New...": "new_file",
		"Open...": "open_file",
		"Open last project...": "open_last_project",
		"Recent projects": "",
		"Save...": "save_file",
		"Save as...": "save_file_as",
		"Export...": "export_file",
		"Export as...": "export_file_as",
		"Quit": "quit",
	}
	var i := 0
	for item in file_menu_items:
		if item == "Recent projects":
			_setup_recent_projects_submenu(item)
		else:
			_set_menu_shortcut(file_menu_items[item], file_menu, i, item)
		i += 1

	file_menu.id_pressed.connect(file_menu_id_pressed)

	if OS.get_name() == "Web":
		file_menu.set_item_disabled(Global.FileMenu.OPEN_LAST_PROJECT, true)
		file_menu.set_item_disabled(Global.FileMenu.RECENT, true)


func _setup_recent_projects_submenu(item: String) -> void:
	recent_projects_submenu.name = "RecentProjectsPopupMenu"
	recent_projects = Global.config_cache.get_value("data", "recent_projects", [])
	recent_projects_submenu.id_pressed.connect(_on_recent_projects_submenu_id_pressed)
	update_recent_projects_submenu()

	file_menu.add_child(recent_projects_submenu)
	file_menu.add_submenu_item(item, recent_projects_submenu.get_name())


func update_recent_projects_submenu() -> void:
	var reversed_recent_projects := recent_projects.duplicate()
	reversed_recent_projects.reverse()
	for project in reversed_recent_projects:
		recent_projects_submenu.add_item(project.get_file())


func _setup_edit_menu() -> void:
	# Order as in Global.EditMenu enum
	var edit_menu_items := {
		"Undo": "undo",
		"Redo": "redo",
		"Copy": "copy",
		"Cut": "cut",
		"Paste": "paste",
		"Paste in Place": "paste_in_place",
		"Paste from Clipboard": "paste_from_clipboard",
		"Delete": "delete",
		"New Brush": "new_brush",
		"Preferences": "preferences"
	}
	var i := 0
	for item in edit_menu_items:
		var echo := false
		if item in ["Undo", "Redo"]:
			echo = true
		_set_menu_shortcut(edit_menu_items[item], edit_menu, i, item, false, echo)
		i += 1

	edit_menu.set_item_disabled(Global.EditMenu.NEW_BRUSH, true)
	edit_menu.id_pressed.connect(edit_menu_id_pressed)


func _setup_view_menu() -> void:
	# Order as in Global.ViewMenu enum
	var view_menu_items := {
		"Center Canvas": "center_canvas",
		"Tile Mode": "",
		"Tile Mode Offsets": "",
		"Grayscale View": "",
		"Mirror View": "mirror_view",
		"Show Grid": "show_grid",
		"Show Pixel Grid": "show_pixel_grid",
		"Show Pixel Indices": "show_pixel_indices",
		"Show Rulers": "show_rulers",
		"Show Guides": "show_guides",
		"Show Mouse Guides": "",
		"Show Reference Images": "show_reference_images",
		"Display Layer Effects": &"display_layer_effects",
		"Snap To": "",
	}
	for i in view_menu_items.size():
		var item: String = view_menu_items.keys()[i]
		if item == "Tile Mode":
			_setup_tile_mode_submenu(item)
		elif item == "Snap To":
			_setup_snap_to_submenu(item)
		elif item == "Tile Mode Offsets":
			view_menu.add_item(item, i)
		elif item == "Center Canvas":
			_set_menu_shortcut(view_menu_items[item], view_menu, i, item)
		else:
			_set_menu_shortcut(view_menu_items[item], view_menu, i, item, true)
	view_menu.set_item_checked(Global.ViewMenu.SHOW_RULERS, true)
	view_menu.set_item_checked(Global.ViewMenu.SHOW_GUIDES, true)
	view_menu.set_item_checked(Global.ViewMenu.SHOW_REFERENCE_IMAGES, true)
	view_menu.set_item_checked(Global.ViewMenu.DISPLAY_LAYER_EFFECTS, true)
	view_menu.hide_on_checkable_item_selection = false
	view_menu.id_pressed.connect(view_menu_id_pressed)

	# Load settings from the config file
	var draw_grid: bool = Global.config_cache.get_value("view_menu", "draw_grid", Global.draw_grid)
	var draw_pixel_grid: bool = Global.config_cache.get_value(
		"view_menu", "draw_pixel_grid", Global.draw_pixel_grid
	)
	var show_pixel_indices: bool = Global.config_cache.get_value(
		"view_menu", "show_pixel_indices", Global.show_pixel_indices
	)
	var show_rulers: bool = Global.config_cache.get_value(
		"view_menu", "show_rulers", Global.show_rulers
	)
	var show_guides: bool = Global.config_cache.get_value(
		"view_menu", "show_guides", Global.show_guides
	)
	var show_mouse_guides: bool = Global.config_cache.get_value(
		"view_menu", "show_mouse_guides", Global.show_mouse_guides
	)
	var display_layer_effects: bool = Global.config_cache.get_value(
		"view_menu", "display_layer_effects", Global.display_layer_effects
	)
	var snap_to_rectangular_grid_boundary: bool = Global.config_cache.get_value(
		"view_menu", "snap_to_rectangular_grid_boundary", Global.snap_to_rectangular_grid_boundary
	)
	var snap_to_rectangular_grid_center: bool = Global.config_cache.get_value(
		"view_menu", "snap_to_rectangular_grid_center", Global.snap_to_rectangular_grid_center
	)
	var snap_to_guides: bool = Global.config_cache.get_value(
		"view_menu", "snap_to_guides", Global.snap_to_guides
	)
	var snap_to_perspective_guides: bool = Global.config_cache.get_value(
		"view_menu", "snap_to_perspective_guides", Global.snap_to_perspective_guides
	)
	if draw_grid != Global.draw_grid:
		_toggle_show_grid()
	if draw_pixel_grid != Global.draw_pixel_grid:
		_toggle_show_pixel_grid()
	if show_rulers != Global.show_rulers:
		_toggle_show_rulers()
	if show_guides != Global.show_guides:
		_toggle_show_guides()
	if show_mouse_guides != Global.show_mouse_guides:
		_toggle_show_mouse_guides()
	if show_pixel_indices != Global.show_pixel_indices:
		_toggle_show_pixel_indices()
	if display_layer_effects != Global.display_layer_effects:
		Global.display_layer_effects = display_layer_effects
	if snap_to_rectangular_grid_boundary != Global.snap_to_rectangular_grid_boundary:
		_snap_to_submenu_id_pressed(0)
	if snap_to_rectangular_grid_center != Global.snap_to_rectangular_grid_center:
		_snap_to_submenu_id_pressed(1)
	if snap_to_guides != Global.snap_to_guides:
		_snap_to_submenu_id_pressed(2)
	if snap_to_perspective_guides != Global.snap_to_perspective_guides:
		_snap_to_submenu_id_pressed(3)


func _setup_tile_mode_submenu(item: String) -> void:
	tile_mode_submenu.set_name("tile_mode_submenu")
	tile_mode_submenu.add_radio_check_item("None", Tiles.MODE.NONE)
	tile_mode_submenu.set_item_checked(Tiles.MODE.NONE, true)
	tile_mode_submenu.add_radio_check_item("Tiled In Both Axis", Tiles.MODE.BOTH)
	tile_mode_submenu.add_radio_check_item("Tiled In X Axis", Tiles.MODE.X_AXIS)
	tile_mode_submenu.add_radio_check_item("Tiled In Y Axis", Tiles.MODE.Y_AXIS)
	tile_mode_submenu.hide_on_checkable_item_selection = false

	tile_mode_submenu.id_pressed.connect(_tile_mode_submenu_id_pressed)
	view_menu.add_child(tile_mode_submenu)
	view_menu.add_submenu_item(item, tile_mode_submenu.get_name())


func _setup_snap_to_submenu(item: String) -> void:
	snap_to_submenu.set_name("snap_to_submenu")
	snap_to_submenu.add_check_item("Snap to Rectangular Grid Boundary")
	snap_to_submenu.add_check_item("Snap to Rectangular Grid Center")
	snap_to_submenu.add_check_item("Snap to Guides")
	snap_to_submenu.add_check_item("Snap to Perspective Guides")
	snap_to_submenu.id_pressed.connect(_snap_to_submenu_id_pressed)
	view_menu.add_child(snap_to_submenu)
	view_menu.add_submenu_item(item, snap_to_submenu.get_name())


func _setup_window_menu() -> void:
	# Order as in Global.WindowMenu enum
	var window_menu_items := {
		"Window Opacity": "",
		"Panels": "",
		"Layouts": "",
		"Moveable Panels": "moveable_panels",
		"Zen Mode": "zen_mode",
		"Fullscreen Mode": "toggle_fullscreen",
	}
	var i := 0
	for item in window_menu_items:
		if item == "Panels":
			_setup_panels_submenu(item)
		elif item == "Layouts":
			_setup_layouts_submenu(item)
		elif item == "Window Opacity":
			window_menu.add_item(item, i)
		else:
			_set_menu_shortcut(window_menu_items[item], window_menu, i, item, true)
		i += 1
	window_menu.hide_on_checkable_item_selection = false
	window_menu.id_pressed.connect(window_menu_id_pressed)
	# Disable window opacity item if per pixel transparency is not allowed
	window_menu.set_item_disabled(
		Global.WindowMenu.WINDOW_OPACITY,
		!ProjectSettings.get_setting("display/window/per_pixel_transparency/allowed")
	)


func _setup_panels_submenu(item: String) -> void:
	panels_submenu.set_name("panels_submenu")
	panels_submenu.hide_on_checkable_item_selection = false
	for element in ui_elements:
		if element.name == "Tiles":
			continue
		var id := ui_elements.find(element)
		panels_submenu.add_check_item(element.name, id)
		var is_hidden: bool = main_ui.is_control_hidden(element)
		var index := panels_submenu.get_item_index(id)
		panels_submenu.set_item_checked(index, !is_hidden)

	panels_submenu.id_pressed.connect(_panels_submenu_id_pressed)
	window_menu.add_child(panels_submenu)
	window_menu.add_submenu_item(item, panels_submenu.get_name())


func _setup_layouts_submenu(item: String) -> void:
	layouts_submenu.hide_on_checkable_item_selection = false
	populate_layouts_submenu()

	layouts_submenu.id_pressed.connect(_layouts_submenu_id_pressed)
	window_menu.add_child(layouts_submenu)
	window_menu.add_submenu_node_item(item, layouts_submenu)

	var saved_layout: int = Global.config_cache.get_value("window", "layout", 0)
	set_layout(saved_layout)


func populate_layouts_submenu() -> void:
	layouts_submenu.clear()  # Does not do anything if it's called for the first time
	for layout in Global.layouts:
		var layout_name := layout.resource_path.get_basename().get_file()
		layouts_submenu.add_radio_check_item(layout_name)
	layouts_submenu.add_separator()
	layouts_submenu.add_item("Add Layout")
	layouts_submenu.add_item(tr("Delete %s") % "Default")
	layouts_submenu.add_item(tr("Reset %s") % "Default")


func _setup_image_menu() -> void:
	# Order as in Global.ImageMenu enum
	var image_menu_items := {
		"Project Properties": "project_properties",
		"Color Mode": "",
		"Resize Canvas": "resize_canvas",
		"Scale Image": "scale_image",
		"Crop to Selection": "crop_to_selection",
		"Crop to Content": "crop_to_content",
	}
	for i in image_menu_items.size():
		var item: String = image_menu_items.keys()[i]
		if item == "Color Mode":
			_setup_color_mode_submenu(item)
		else:
			_set_menu_shortcut(image_menu_items[item], image_menu, i, item)
	image_menu.set_item_disabled(Global.ImageMenu.CROP_TO_SELECTION, true)
	image_menu.id_pressed.connect(image_menu_id_pressed)


func _setup_color_mode_submenu(item: String) -> void:
	color_mode_submenu.set_name("color_mode_submenu")
	color_mode_submenu.add_radio_check_item("RGBA", ColorModes.RGBA)
	color_mode_submenu.set_item_checked(ColorModes.RGBA, true)
	color_mode_submenu.add_radio_check_item("Indexed", ColorModes.INDEXED)

	color_mode_submenu.id_pressed.connect(_color_mode_submenu_id_pressed)
	image_menu.add_child(color_mode_submenu)
	image_menu.add_submenu_item(item, color_mode_submenu.get_name())


func _setup_effects_menu() -> void:
	_set_menu_shortcut(&"offset_image", effects_transform_submenu, 0, "Offset Image")
	_set_menu_shortcut(&"mirror_image", effects_transform_submenu, 1, "Mirror Image")
	_set_menu_shortcut(&"rotate_image", effects_transform_submenu, 2, "Rotate Image")
	effects_transform_submenu.id_pressed.connect(_on_effects_transform_submenu_id_pressed)
	effects_menu.add_child(effects_transform_submenu)
	effects_menu.add_submenu_node_item("Transform", effects_transform_submenu)

	_set_menu_shortcut(&"invert_colors", effects_color_submenu, 0, "Invert Colors")
	_set_menu_shortcut(&"desaturation", effects_color_submenu, 1, "Desaturation")
	_set_menu_shortcut(&"adjust_hsv", effects_color_submenu, 2, "Adjust Hue/Saturation/Value")
	_set_menu_shortcut(
		&"adjust_brightness_contrast", effects_color_submenu, 3, "Adjust Brightness/Contrast"
	)
	_set_menu_shortcut(&"color_curves", effects_color_submenu, 4, "Color Curves")
	_set_menu_shortcut(&"palettize", effects_color_submenu, 5, "Palettize")
	_set_menu_shortcut(&"posterize", effects_color_submenu, 6, "Posterize")
	_set_menu_shortcut(&"gradient_map", effects_color_submenu, 7, "Gradient Map")
	effects_color_submenu.id_pressed.connect(_on_effects_color_submenu_id_pressed)
	effects_menu.add_child(effects_color_submenu)
	effects_menu.add_submenu_node_item("Color", effects_color_submenu)

	_set_menu_shortcut(&"outline", effects_procedural_submenu, 0, "Outline")
	_set_menu_shortcut(&"drop_shadow", effects_procedural_submenu, 1, "Drop Shadow")
	_set_menu_shortcut(&"gradient", effects_procedural_submenu, 2, "Gradient")
	effects_procedural_submenu.id_pressed.connect(_on_effects_procedural_submenu_id_pressed)
	effects_menu.add_child(effects_procedural_submenu)
	effects_menu.add_submenu_node_item("Procedural", effects_procedural_submenu)

	_set_menu_shortcut(&"pixelize", effects_blur_submenu, 0, "Pixelize")
	_set_menu_shortcut(&"gaussian_blur", effects_blur_submenu, 1, "Gaussian Blur")
	effects_blur_submenu.id_pressed.connect(_on_effects_blur_submenu_id_pressed)
	effects_menu.add_child(effects_blur_submenu)
	effects_menu.add_submenu_node_item("Blur", effects_blur_submenu)

	_setup_effects_loaded_submenu()
	effects_menu.id_pressed.connect(effects_menu_id_pressed)


func _setup_effects_loaded_submenu() -> void:
	if not DirAccess.dir_exists_absolute(OpenSave.SHADERS_DIRECTORY):
		DirAccess.make_dir_recursive_absolute(OpenSave.SHADERS_DIRECTORY)
	var shader_files := DirAccess.get_files_at(OpenSave.SHADERS_DIRECTORY)
	if shader_files.size() == 0:
		return
	for shader_file in shader_files:
		_load_shader_file(OpenSave.SHADERS_DIRECTORY.path_join(shader_file))


func _load_shader_file(file_path: String) -> void:
	var file := load(file_path)
	if file is not Shader:
		return
	var effect_name := file_path.get_file().get_basename()
	if not is_instance_valid(effects_loaded_submenu):
		effects_loaded_submenu = PopupMenu.new()
		effects_loaded_submenu.set_name("effects_loaded_submenu")
		effects_loaded_submenu.id_pressed.connect(_effects_loaded_submenu_id_pressed)
		effects_menu.add_child(effects_loaded_submenu)
		effects_menu.add_submenu_node_item("Loaded", effects_loaded_submenu)
	effects_loaded_submenu.add_item(effect_name)
	var effect_index := effects_loaded_submenu.item_count - 1
	effects_loaded_submenu.set_item_metadata(effect_index, file)
	loaded_effect_dialogs.append(Dialog.new("res://src/UI/Dialogs/ImageEffects/ShaderEffect.tscn"))


func _setup_select_menu() -> void:
	# Order as in Global.SelectMenu enum
	var select_menu_items := {
		"All": "select_all",
		"Clear": "clear_selection",
		"Invert": "invert_selection",
		"Wrap Strokes": "",
		"Modify": ""
	}
	for i in select_menu_items.size():
		var item: String = select_menu_items.keys()[i]
		if item == "Wrap Strokes":
			select_menu.add_check_item(item, i)
		elif item == "Modify":
			_setup_selection_modify_submenu(item)
		else:
			_set_menu_shortcut(select_menu_items[item], select_menu, i, item)
	select_menu.id_pressed.connect(select_menu_id_pressed)


func _setup_selection_modify_submenu(item: String) -> void:
	selection_modify_submenu.set_name("selection_modify_submenu")
	selection_modify_submenu.add_item("Expand")
	selection_modify_submenu.add_item("Shrink")
	selection_modify_submenu.add_item("Border")
	selection_modify_submenu.id_pressed.connect(_selection_modify_submenu_id_pressed)
	select_menu.add_child(selection_modify_submenu)
	select_menu.add_submenu_item(item, selection_modify_submenu.get_name())


func _setup_help_menu() -> void:
	# Order as in Global.HelpMenu enum
	var help_menu_items := {
		"View Splash Screen": "view_splash_screen",
		"Online Docs": "open_docs",
		"Issue Tracker": "issue_tracker",
		"Open Editor Data Folder": "open_editor_data_folder",
		"Changelog": "changelog",
		"About Pixelorama": "about_pixelorama",
		"Support Pixelorama's Development": &"",
	}
	var i := 0
	for item in help_menu_items:
		var icon: Texture2D = null
		if (
			i == Global.HelpMenu.ONLINE_DOCS
			or i == Global.HelpMenu.ISSUE_TRACKER
			or i == Global.HelpMenu.CHANGELOG
		):
			icon = EXTERNAL_LINK_ICON
		if i == Global.HelpMenu.ABOUT_PIXELORAMA:
			icon = PIXELORAMA_ICON
		elif i == Global.HelpMenu.SUPPORT_PIXELORAMA:
			icon = HEART_ICON
		_set_menu_shortcut(help_menu_items[item], help_menu, i, item, false, false, icon)

		i += 1

	help_menu.id_pressed.connect(help_menu_id_pressed)


func _set_menu_shortcut(
	action: StringName,
	menu: PopupMenu,
	index: int,
	text: String,
	is_check := false,
	echo := false,
	icon: Texture2D = null
) -> void:
	if action.is_empty():
		if is_check:
			menu.add_check_item(text, index)
		else:
			menu.add_item(text, index)
	else:
		var shortcut := Shortcut.new()
		var event := InputEventAction.new()
		event.action = action
		shortcut.events.append(event)
		if is_check:
			menu.add_check_shortcut(shortcut, index)
		else:
			menu.add_shortcut(shortcut, index, false, echo)
		menu.set_item_text(index, text)
	if is_instance_valid(icon):
		menu.set_item_icon(index, icon)


func _handle_metadata(id: int, popup_menu: PopupMenu) -> void:
	# Used for extensions that want to add extra menu items
	var metadata = popup_menu.get_item_metadata(id)
	if metadata:
		if metadata is Object:
			if metadata.has_method(&"menu_item_clicked"):
				metadata.call(&"menu_item_clicked")


func _popup_dialog(dialog: Window, dialog_size := Vector2i.ZERO) -> void:
	dialog.popup_centered(dialog_size)
	var is_file_dialog := dialog is FileDialog
	Global.dialog_open(true, is_file_dialog)


func file_menu_id_pressed(id: int) -> void:
	match id:
		Global.FileMenu.NEW:
			new_image_dialog.popup()
		Global.FileMenu.OPEN:
			_open_project_file()
		Global.FileMenu.OPEN_LAST_PROJECT:
			_on_open_last_project_file_menu_option_pressed()
		Global.FileMenu.SAVE:
			_save_project_file()
		Global.FileMenu.SAVE_AS:
			Global.control.show_save_dialog()
		Global.FileMenu.EXPORT:
			_export_file()
		Global.FileMenu.EXPORT_AS:
			_popup_dialog(Global.export_dialog)
		Global.FileMenu.QUIT:
			Global.control.show_quit_dialog()
		_:
			_handle_metadata(id, file_menu)


func _open_project_file() -> void:
	if OS.get_name() == "Web":
		Html5FileExchange.load_image()
	else:
		_popup_dialog(Global.control.open_sprite_dialog)
		Global.control.opensprite_file_selected = false


func _on_open_last_project_file_menu_option_pressed() -> void:
	if Global.config_cache.has_section_key("data", "last_project_path"):
		Global.control.load_last_project()
	else:
		Global.popup_error("You haven't saved or opened any project in Pixelorama yet!")


func _save_project_file() -> void:
	if Global.current_project is ResourceProject:
		Global.current_project.resource_updated.emit(Global.current_project)
		if Global.current_project.has_changed:
			Global.current_project.has_changed = false
		Global.notification_label("Resource Updated")
		return
	var path: String = Global.current_project.save_path
	if path == "":
		Global.control.show_save_dialog()
	else:
		Global.control.save_project(path)


func _export_file() -> void:
	if Global.current_project.was_exported == false:
		_popup_dialog(Global.export_dialog)
	else:
		Export.external_export()


func _on_recent_projects_submenu_id_pressed(id: int) -> void:
	var reversed_recent_projects := recent_projects.duplicate()
	reversed_recent_projects.reverse()
	Global.control.load_recent_project_file(reversed_recent_projects[id])


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
		Global.EditMenu.PASTE_IN_PLACE:
			Global.canvas.selection.paste(true)
		Global.EditMenu.PASTE_FROM_CLIPBOARD:
			Global.canvas.selection.paste_from_clipboard()
		Global.EditMenu.DELETE:
			Global.canvas.selection.delete()
		Global.EditMenu.NEW_BRUSH:
			Global.canvas.selection.new_brush()
		Global.EditMenu.PREFERENCES:
			preferences_dialog.popup()
		_:
			_handle_metadata(id, edit_menu)


func view_menu_id_pressed(id: int) -> void:
	match id:
		Global.ViewMenu.CENTER_CANVAS:
			Global.camera.offset = Global.current_project.size / 2
		Global.ViewMenu.TILE_MODE_OFFSETS:
			_popup_dialog(get_tree().current_scene.tile_mode_offsets_dialog)
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
		Global.ViewMenu.SHOW_MOUSE_GUIDES:
			_toggle_show_mouse_guides()
		Global.ViewMenu.SHOW_REFERENCE_IMAGES:
			Global.show_reference_images = not Global.show_reference_images
			view_menu.set_item_checked(
				Global.ViewMenu.SHOW_REFERENCE_IMAGES, Global.show_reference_images
			)
		Global.ViewMenu.SHOW_PIXEL_INDICES:
			_toggle_show_pixel_indices()
		Global.ViewMenu.DISPLAY_LAYER_EFFECTS:
			Global.display_layer_effects = not Global.display_layer_effects
		_:
			_handle_metadata(id, view_menu)

	Global.canvas.queue_redraw()


func window_menu_id_pressed(id: int) -> void:
	match id:
		Global.WindowMenu.WINDOW_OPACITY:
			window_opacity_dialog.popup()
		Global.WindowMenu.MOVABLE_PANELS:
			main_ui.hide_single_tab = not main_ui.hide_single_tab
			window_menu.set_item_checked(id, not main_ui.hide_single_tab)
		Global.WindowMenu.ZEN_MODE:
			_toggle_zen_mode()
		Global.WindowMenu.FULLSCREEN_MODE:
			_toggle_fullscreen()
		_:
			_handle_metadata(id, window_menu)


func _tile_mode_submenu_id_pressed(id: Tiles.MODE) -> void:
	Global.current_project.tiles.mode = id
	Global.transparent_checker.fit_rect(Global.current_project.tiles.get_bounding_rect())
	for i in Tiles.MODE.values():
		tile_mode_submenu.set_item_checked(i, i == id)
	Global.canvas.tile_mode.queue_redraw()
	Global.canvas.pixel_grid.queue_redraw()
	Global.canvas.grid.queue_redraw()
	get_tree().current_scene.tile_mode_offsets_dialog.change_mask()


func _selection_modify_submenu_id_pressed(id: int) -> void:
	modify_selection.popup()
	modify_selection.node.type = id


func _color_mode_submenu_id_pressed(id: ColorModes) -> void:
	var project := Global.current_project
	var old_color_mode := project.color_mode
	var redo_data := {}
	var undo_data := {}
	var pixel_cels: Array[BaseCel]
	# We need to do it this way because Godot
	# doesn't like casting typed arrays into other types.
	for cel in project.get_all_pixel_cels():
		pixel_cels.append(cel)
	project.serialize_cel_undo_data(pixel_cels, undo_data)
	# Change the color mode directly before undo/redo in order to affect the images,
	# so we can store them as redo data.
	if id == ColorModes.RGBA:
		project.color_mode = Image.FORMAT_RGBA8
	else:
		project.color_mode = Project.INDEXED_MODE
	project.update_tilemaps(undo_data, TileSetPanel.TileEditingMode.AUTO)
	project.serialize_cel_undo_data(pixel_cels, redo_data)
	project.undo_redo.create_action("Change color mode")
	project.undos += 1
	project.undo_redo.add_do_property(project, "color_mode", project.color_mode)
	project.undo_redo.add_undo_property(project, "color_mode", old_color_mode)
	project.deserialize_cel_undo_data(redo_data, undo_data)
	project.undo_redo.add_do_method(_check_color_mode_submenu_item.bind(project))
	project.undo_redo.add_undo_method(_check_color_mode_submenu_item.bind(project))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()


func _check_color_mode_submenu_item(project: Project) -> void:
	color_mode_submenu.set_item_checked(ColorModes.RGBA, project.color_mode == Image.FORMAT_RGBA8)
	color_mode_submenu.set_item_checked(ColorModes.INDEXED, project.is_indexed())


func _snap_to_submenu_id_pressed(id: int) -> void:
	if id == 0:
		Global.snap_to_rectangular_grid_boundary = !Global.snap_to_rectangular_grid_boundary
		snap_to_submenu.set_item_checked(id, Global.snap_to_rectangular_grid_boundary)
	if id == 1:
		Global.snap_to_rectangular_grid_center = !Global.snap_to_rectangular_grid_center
		snap_to_submenu.set_item_checked(id, Global.snap_to_rectangular_grid_center)
	elif id == 2:
		Global.snap_to_guides = !Global.snap_to_guides
		snap_to_submenu.set_item_checked(id, Global.snap_to_guides)
	elif id == 3:
		Global.snap_to_perspective_guides = !Global.snap_to_perspective_guides
		snap_to_submenu.set_item_checked(id, Global.snap_to_perspective_guides)


func _effects_loaded_submenu_id_pressed(id: int) -> void:
	var dialog := loaded_effect_dialogs[id]
	if is_instance_valid(dialog.node):
		dialog.popup()
	else:
		dialog.instantiate_scene()
		var shader := effects_loaded_submenu.get_item_metadata(id) as Shader
		dialog.node.change_shader(shader, effects_loaded_submenu.get_item_text(id))
		dialog.popup()


func _panels_submenu_id_pressed(id: int) -> void:
	if zen_mode:
		return
	var index := panels_submenu.get_item_index(id)
	var element_visible := panels_submenu.is_item_checked(index)
	main_ui.set_control_hidden(ui_elements[id], element_visible)
	panels_submenu.set_item_checked(index, !element_visible)


func _layouts_submenu_id_pressed(id: int) -> void:
	var layout_count := Global.layouts.size()
	if id < layout_count:
		set_layout(id)
	elif id == layout_count + 1:
		layout_name_line_edit.text = "New layout"
		add_layout_confirmation.popup_centered()
	elif id == layout_count + 2:
		delete_layout_confirmation.popup_centered()
	elif id == layout_count + 3:
		Global.layouts[selected_layout].reset()


func set_layout(id: int) -> void:
	if Global.layouts.size() == 0:
		return
	if id >= Global.layouts.size():
		id = 0
	selected_layout = id
	var layout := Global.layouts[id]
	main_ui.layout = layout
	var layout_name := layout.resource_path.get_basename().get_file()
	layouts_submenu.set_item_text(layouts_submenu.item_count - 2, tr("Delete %s") % layout_name)
	layouts_submenu.set_item_text(layouts_submenu.item_count - 1, tr("Reset %s") % layout_name)
	layouts_submenu.set_item_disabled(
		layouts_submenu.item_count - 1, layout.layout_reset_path.is_empty()
	)
	for i in Global.layouts.size():
		layouts_submenu.set_item_checked(i, i == id)

	for i in ui_elements.size():
		var index := panels_submenu.get_item_index(i)
		var is_hidden := main_ui.is_control_hidden(ui_elements[i])
		panels_submenu.set_item_checked(index, !is_hidden)

	if zen_mode:  # Turn zen mode off
		Global.control.find_child("TabsContainer").visible = true
		zen_mode = false
		window_menu.set_item_checked(Global.WindowMenu.ZEN_MODE, false)


func _on_add_layout_confirmation_confirmed() -> void:
	var file_name := layout_name_line_edit.text + ".tres"
	var path := Global.LAYOUT_DIR.path_join(file_name)
	var layout: DockableLayout
	if layout_from_option_button.selected == 0:
		layout = Global.control.main_ui.layout.clone()
		layout.layout_reset_path = ""
	else:
		layout = Global.default_layouts[layout_from_option_button.selected - 1].clone()
	layout.resource_name = layout_name_line_edit.text
	layout.resource_path = path
	var err := ResourceSaver.save(layout, path)
	if err != OK:
		print(err)
		return
	Global.layouts.append(layout)
	# Save the layout every time it changes
	layout.save_on_change = true
	Global.control.main_ui.layout = layout
	Global.layouts.sort_custom(
		func(a: DockableLayout, b: DockableLayout):
			return a.resource_path.get_file() < b.resource_path.get_file()
	)
	var layout_index := Global.layouts.find(layout)
	populate_layouts_submenu()
	set_layout(layout_index)


func _on_delete_layout_confirmation_confirmed() -> void:
	if Global.layouts.size() <= 1:  # Don't delete any layout if we only have one left.
		return
	var layout_name := Global.layouts[selected_layout].resource_path.get_basename().get_file()
	delete_layout_file(layout_name + ".tres")
	Global.layouts.remove_at(selected_layout)
	populate_layouts_submenu()
	set_layout(0)


func delete_layout_file(file_name: String) -> void:
	var dir := DirAccess.open(Global.LAYOUT_DIR)
	if not is_instance_valid(dir):
		return
	dir.remove(Global.LAYOUT_DIR.path_join(file_name))


func _on_add_layout_confirmation_visibility_changed() -> void:
	Global.dialog_open(add_layout_confirmation.visible)


func _on_delete_layout_confirmation_visibility_changed() -> void:
	Global.dialog_open(delete_layout_confirmation.visible)


func _toggle_greyscale_view() -> void:
	Global.greyscale_view = !Global.greyscale_view
	greyscale_vision.visible = Global.greyscale_view
	view_menu.set_item_checked(Global.ViewMenu.GREYSCALE_VIEW, Global.greyscale_view)


func _toggle_mirror_view() -> void:
	Global.mirror_view = !Global.mirror_view
	var marching_ants_outline: Sprite2D = Global.canvas.selection.marching_ants_outline
	marching_ants_outline.scale.x = -marching_ants_outline.scale.x
	if Global.mirror_view:
		marching_ants_outline.position.x = (
			marching_ants_outline.position.x + Global.current_project.size.x
		)
	else:
		Global.canvas.selection.marching_ants_outline.position.x = 0
	Global.canvas.selection.queue_redraw()
	view_menu.set_item_checked(Global.ViewMenu.MIRROR_VIEW, Global.mirror_view)


func _toggle_show_grid() -> void:
	Global.draw_grid = !Global.draw_grid
	view_menu.set_item_checked(Global.ViewMenu.SHOW_GRID, Global.draw_grid)
	if Global.canvas.grid:
		Global.canvas.grid.queue_redraw()


func _toggle_show_pixel_grid() -> void:
	Global.draw_pixel_grid = !Global.draw_pixel_grid
	view_menu.set_item_checked(Global.ViewMenu.SHOW_PIXEL_GRID, Global.draw_pixel_grid)


func _toggle_show_pixel_indices() -> void:
	Global.show_pixel_indices = !Global.show_pixel_indices
	view_menu.set_item_checked(Global.ViewMenu.SHOW_PIXEL_INDICES, Global.show_pixel_indices)


func _toggle_show_rulers() -> void:
	Global.show_rulers = !Global.show_rulers
	view_menu.set_item_checked(Global.ViewMenu.SHOW_RULERS, Global.show_rulers)


func _toggle_show_guides() -> void:
	Global.show_guides = !Global.show_guides
	view_menu.set_item_checked(Global.ViewMenu.SHOW_GUIDES, Global.show_guides)
	for guide in Global.canvas.get_children():
		if guide is Guide and guide in Global.current_project.guides:
			guide.visible = Global.show_guides
			if guide is SymmetryGuide:
				if guide.type == Guide.Types.HORIZONTAL:
					guide.visible = Global.show_x_symmetry_axis and Global.show_guides
				elif guide.type == Guide.Types.VERTICAL:
					guide.visible = Global.show_y_symmetry_axis and Global.show_guides
				elif guide.type == Guide.Types.XY:
					guide.visible = Global.show_xy_symmetry_axis and Global.show_guides
				elif guide.type == Guide.Types.X_MINUS_Y:
					guide.visible = Global.show_x_minus_y_symmetry_axis and Global.show_guides


func _toggle_show_mouse_guides() -> void:
	Global.show_mouse_guides = !Global.show_mouse_guides
	view_menu.set_item_checked(Global.ViewMenu.SHOW_MOUSE_GUIDES, Global.show_mouse_guides)
	if Global.show_mouse_guides:
		if Global.canvas.mouse_guide_container:
			Global.canvas.mouse_guide_container.get_child(0).queue_redraw()
			Global.canvas.mouse_guide_container.get_child(1).queue_redraw()


func _toggle_zen_mode() -> void:
	for i in ui_elements.size():
		var index := panels_submenu.get_item_index(i)
		var panel_name := ui_elements[i].name
		if panel_name == "Main Canvas" or panel_name == "Tiles":
			continue
		if !panels_submenu.is_item_checked(index):
			continue
		main_ui.set_control_hidden(ui_elements[i], !zen_mode)
	Global.control.find_child("TabsContainer").visible = zen_mode
	zen_mode = !zen_mode
	window_menu.set_item_checked(Global.WindowMenu.ZEN_MODE, zen_mode)


func _toggle_fullscreen() -> void:
	var is_fullscreen := (
		(get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN)
		or (get_window().mode == Window.MODE_FULLSCREEN)
	)
	get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if !is_fullscreen else Window.MODE_WINDOWED
	is_fullscreen = not is_fullscreen
	window_menu.set_item_checked(Global.WindowMenu.FULLSCREEN_MODE, is_fullscreen)


func image_menu_id_pressed(id: int) -> void:
	match id:
		Global.ImageMenu.PROJECT_PROPERTIES:
			project_properties_dialog.popup()
		Global.ImageMenu.SCALE_IMAGE:
			scale_image_dialog.popup()
		Global.ImageMenu.CROP_TO_SELECTION:
			DrawingAlgos.crop_to_selection()
		Global.ImageMenu.CROP_TO_CONTENT:
			DrawingAlgos.crop_to_content()
		Global.ImageMenu.RESIZE_CANVAS:
			resize_canvas_dialog.popup()
		_:
			_handle_metadata(id, image_menu)


func effects_menu_id_pressed(id: int) -> void:
	_handle_metadata(id, effects_menu)


func _on_effects_transform_submenu_id_pressed(id: int) -> void:
	match id:
		0:
			offset_image_dialog.popup()
		1:
			mirror_image_dialog.popup()
		2:
			rotate_image_dialog.popup()


func _on_effects_color_submenu_id_pressed(id: int) -> void:
	match id:
		0:
			invert_colors_dialog.popup()
		1:
			desaturate_dialog.popup()
		2:
			hsv_dialog.popup()
		3:
			adjust_brightness_saturation_dialog.popup()
		4:
			color_curves_dialog.popup()
		5:
			palettize_dialog.popup()
		6:
			posterize_dialog.popup()
		7:
			gradient_map_dialog.popup()


func _on_effects_procedural_submenu_id_pressed(id: int) -> void:
	match id:
		0:
			outline_dialog.popup()
		1:
			drop_shadow_dialog.popup()
		2:
			gradient_dialog.popup()


func _on_effects_blur_submenu_id_pressed(id: int) -> void:
	match id:
		0:
			pixelize_dialog.popup()
		1:
			gaussian_blur_dialog.popup()


func select_menu_id_pressed(id: int) -> void:
	match id:
		Global.SelectMenu.SELECT_ALL:
			Global.canvas.selection.select_all()
		Global.SelectMenu.CLEAR_SELECTION:
			Global.canvas.selection.clear_selection(true)
		Global.SelectMenu.INVERT:
			Global.canvas.selection.invert()
		Global.SelectMenu.WRAP_STROKES:
			var state = select_menu.is_item_checked(id)
			Global.canvas.selection.flag_tilemode = !state
			select_menu.set_item_checked(id, !state)
		_:
			_handle_metadata(id, select_menu)


func help_menu_id_pressed(id: int) -> void:
	match id:
		Global.HelpMenu.VIEW_SPLASH_SCREEN:
			_popup_dialog(get_tree().current_scene.splash_dialog)
		Global.HelpMenu.ONLINE_DOCS:
			OS.shell_open(DOCS_URL)
			SteamManager.set_achievement("ACH_ONLINE_DOCS")
		Global.HelpMenu.ISSUE_TRACKER:
			OS.shell_open(ISSUES_URL)
		Global.HelpMenu.OPEN_EDITOR_DATA_FOLDER:
			OS.shell_open(ProjectSettings.globalize_path("user://"))
		Global.HelpMenu.CHANGELOG:
			OS.shell_open(CHANGELOG_URL)
		Global.HelpMenu.ABOUT_PIXELORAMA:
			about_dialog.popup()
		Global.HelpMenu.SUPPORT_PIXELORAMA:
			OS.shell_open(SUPPORT_URL)
			SteamManager.set_achievement("ACH_SUPPORT_DEVELOPMENT")
		_:
			_handle_metadata(id, help_menu)
