extends Node

signal project_changed
signal cel_changed

enum LayerTypes { PIXEL, GROUP }
enum GridTypes { CARTESIAN, ISOMETRIC, ALL }
enum ColorFrom { THEME, CUSTOM }
enum ButtonSize { SMALL, BIG }

enum FileMenu { NEW, OPEN, OPEN_LAST_PROJECT, RECENT, SAVE, SAVE_AS, EXPORT, EXPORT_AS, QUIT }
enum EditMenu { UNDO, REDO, COPY, CUT, PASTE, PASTE_IN_PLACE, DELETE, NEW_BRUSH, PREFERENCES }
enum ViewMenu {
	TILE_MODE,
	TILE_MODE_OFFSETS,
	GREYSCALE_VIEW,
	MIRROR_VIEW,
	SHOW_GRID,
	SHOW_PIXEL_GRID,
	SHOW_RULERS,
	SHOW_GUIDES,
	SHOW_MOUSE_GUIDES,
	SNAP_TO,
}
enum WindowMenu { WINDOW_OPACITY, PANELS, LAYOUTS, MOVABLE_PANELS, ZEN_MODE, FULLSCREEN_MODE }
enum ImageMenu {
	SCALE_IMAGE,
	CENTRALIZE_IMAGE,
	CROP_IMAGE,
	RESIZE_CANVAS,
	FLIP,
	ROTATE,
	INVERT_COLORS,
	DESATURATION,
	OUTLINE,
	DROP_SHADOW,
	HSV,
	GRADIENT,
	GRADIENT_MAP,
	SHADER
}
enum SelectMenu { SELECT_ALL, CLEAR_SELECTION, INVERT }
enum HelpMenu {
	VIEW_SPLASH_SCREEN,
	ONLINE_DOCS,
	ISSUE_TRACKER,
	OPEN_LOGS_FOLDER,
	CHANGELOG,
	ABOUT_PIXELORAMA
}

const OVERRIDE_FILE := "override.cfg"

var root_directory := "."
var window_title := "" setget _title_changed  # Why doesn't Godot have get_window_title()?
var config_cache := ConfigFile.new()
var XDGDataPaths = preload("res://src/XDGDataPaths.gd")
var directory_module: Reference

var projects := []  # Array of Projects
var current_project: Project
var current_project_index := 0 setget _project_changed

var ui_tooltips := {}

# Canvas related stuff
var can_draw := false
var move_guides_on_canvas := false
var has_focus := false

var play_only_tags := true
var show_x_symmetry_axis := false
var show_y_symmetry_axis := false

# Preferences
var open_last_project := false
var quit_confirmation := false
var smooth_zoom := true

var shrink := 1.0
var dim_on_popup := true
var modulate_icon_color := Color.gray
var icon_color_from: int = ColorFrom.THEME
var modulate_clear_color := Color.gray
var clear_color_from: int = ColorFrom.THEME
var custom_icon_color := Color.gray
var tool_button_size: int = ButtonSize.SMALL
var left_tool_color := Color("0086cf")
var right_tool_color := Color("fd6d14")

var default_width := 64
var default_height := 64
var default_fill_color := Color(0, 0, 0, 0)
var grid_type = GridTypes.CARTESIAN
var grid_width := 2
var grid_height := 2
var grid_isometric_cell_bounds_width := 16
var grid_isometric_cell_bounds_height := 8
var grid_offset_x := 0
var grid_offset_y := 0
var grid_draw_over_tile_mode := false
var grid_color := Color.black
var pixel_grid_show_at_zoom := 1500.0  # percentage
var pixel_grid_color := Color("91212121")
var guide_color := Color.purple
var checker_size := 10
var checker_color_1 := Color(0.47, 0.47, 0.47, 1)
var checker_color_2 := Color(0.34, 0.35, 0.34, 1)
var checker_follow_movement := false
var checker_follow_scale := false
var tilemode_opacity := 1.0

var selection_animated_borders := true
var selection_border_color_1 := Color.white
var selection_border_color_2 := Color.black

var pause_when_unfocused := true
var fps_limit := 0

var autosave_interval := 1.0
var enable_autosave := true
var renderer := OS.get_current_video_driver() setget _renderer_changed
var tablet_driver := 0 setget _tablet_driver_changed

# Tools & options
var show_left_tool_icon := true
var show_right_tool_icon := true
var left_square_indicator_visible := true
var right_square_indicator_visible := true
var native_cursors := false
var cross_cursor := true

# View menu options
var greyscale_view := false
var mirror_view := false
var draw_grid := false
var draw_pixel_grid := false
var show_rulers := true
var show_guides := true
var show_mouse_guides := false
var snapping_distance := 10.0
var snap_to_rectangular_grid := false
var snap_to_guides := false
var snap_to_perspective_guides := false

# Onion skinning options
var onion_skinning := false
var onion_skinning_past_rate := 1.0
var onion_skinning_future_rate := 1.0
var onion_skinning_blue_red := false

# Palettes
var palettes := {}

# Crop Options:
var crop_top := 0
var crop_bottom := 0
var crop_left := 0
var crop_right := 0

# Nodes
var pixel_layer_button_node: PackedScene = preload("res://src/UI/Timeline/PixelLayerButton.tscn")
var group_layer_button_node: PackedScene = preload("res://src/UI/Timeline/GroupLayerButton.tscn")
var pixel_cel_button_node: PackedScene = preload("res://src/UI/Timeline/PixelCelButton.tscn")
var group_cel_button_node: PackedScene = preload("res://src/UI/Timeline/GroupCelButton.tscn")

onready var control: Node = get_tree().current_scene

onready var canvas: Canvas = control.find_node("Canvas")
onready var tabs: Tabs = control.find_node("Tabs")
onready var main_viewport: ViewportContainer = control.find_node("ViewportContainer")
onready var second_viewport: ViewportContainer = control.find_node("Second Canvas")
onready var canvas_preview_container: Container = control.find_node("Canvas Preview")
onready var global_tool_options: PanelContainer = control.find_node("Global Tool Options")
onready var small_preview_viewport: ViewportContainer = canvas_preview_container.find_node(
	"PreviewViewportContainer"
)
onready var camera: Camera2D = main_viewport.find_node("Camera2D")
onready var camera2: Camera2D = second_viewport.find_node("Camera2D2")
onready var camera_preview: Camera2D = control.find_node("CameraPreview")
onready var cameras := [camera, camera2, camera_preview]
onready var horizontal_ruler: BaseButton = control.find_node("HorizontalRuler")
onready var vertical_ruler: BaseButton = control.find_node("VerticalRuler")
onready var transparent_checker: ColorRect = control.find_node("TransparentChecker")
onready var preview_zoom_slider: VSlider = control.find_node("PreviewZoomSlider")

onready var brushes_popup: Popup = control.find_node("BrushesPopup")
onready var patterns_popup: Popup = control.find_node("PatternsPopup")
onready var palette_panel: PalettePanel = control.find_node("Palettes")

onready var references_panel: ReferencesPanel = control.find_node("Reference Images")
onready var perspective_editor := control.find_node("Perspective Editor")

onready var top_menu_container: Panel = control.find_node("TopMenuContainer")
onready var rotation_level_button: Button = control.find_node("RotationLevel")
onready var rotation_level_spinbox: SpinBox = control.find_node("RotationSpinbox")
onready var zoom_level_button: Button = control.find_node("ZoomLevel")
onready var zoom_level_spinbox: SpinBox = control.find_node("ZoomSpinbox")
onready var cursor_position_label: Label = control.find_node("CursorPosition")
onready var current_frame_mark_label: Label = control.find_node("CurrentFrameMark")

onready var animation_timeline: Panel = control.find_node("Animation Timeline")
onready var animation_timer: Timer = animation_timeline.find_node("AnimationTimer")
onready var frame_hbox: HBoxContainer = animation_timeline.find_node("FrameHBox")
onready var layer_vbox: VBoxContainer = animation_timeline.find_node("LayerVBox")
onready var cel_vbox: VBoxContainer = animation_timeline.find_node("CelVBox")
onready var tag_container: Control = animation_timeline.find_node("TagContainer")
onready var play_forward: BaseButton = animation_timeline.find_node("PlayForward")
onready var play_backwards: BaseButton = animation_timeline.find_node("PlayBackwards")
onready var remove_frame_button: BaseButton = animation_timeline.find_node("DeleteFrame")
onready var move_left_frame_button: BaseButton = animation_timeline.find_node("MoveLeft")
onready var move_right_frame_button: BaseButton = animation_timeline.find_node("MoveRight")
onready var remove_layer_button: BaseButton = animation_timeline.find_node("RemoveLayer")
onready var move_up_layer_button: BaseButton = animation_timeline.find_node("MoveUpLayer")
onready var move_down_layer_button: BaseButton = animation_timeline.find_node("MoveDownLayer")
onready var merge_down_layer_button: BaseButton = animation_timeline.find_node("MergeDownLayer")
onready var layer_opacity_slider: ValueSlider = animation_timeline.find_node("OpacitySlider")

onready var tile_mode_offset_dialog: AcceptDialog = control.find_node("TileModeOffsetsDialog")
onready var open_sprites_dialog: FileDialog = control.find_node("OpenSprite")
onready var save_sprites_dialog: FileDialog = control.find_node("SaveSprite")
onready var save_sprites_html5_dialog: ConfirmationDialog = control.find_node("SaveSpriteHTML5")
onready var export_dialog: AcceptDialog = control.find_node("ExportDialog")
onready var preferences_dialog: AcceptDialog = control.find_node("PreferencesDialog")
onready var error_dialog: AcceptDialog = control.find_node("ErrorDialog")

onready var current_version: String = ProjectSettings.get_setting("application/config/Version")


func _init() -> void:
	if ProjectSettings.get_setting("display/window/tablet_driver") == "winink":
		tablet_driver = 1


func _ready() -> void:
	_initialize_keychain()

	if OS.has_feature("standalone"):
		root_directory = OS.get_executable_path().get_base_dir()
	# root_directory must be set earlier than this is because XDGDataDirs depends on it
	directory_module = XDGDataPaths.new()

	# Load settings from the config file
	config_cache.load("user://cache.ini")

	default_width = config_cache.get_value("preferences", "default_width", default_width)
	default_height = config_cache.get_value("preferences", "default_height", default_height)
	default_fill_color = config_cache.get_value(
		"preferences", "default_fill_color", default_fill_color
	)
	var proj_size := Vector2(default_width, default_height)
	projects.append(Project.new([], tr("untitled"), proj_size))
	current_project = projects[0]
	current_project.fill_color = default_fill_color

	for node in get_tree().get_nodes_in_group("UIButtons"):
		var tooltip: String = node.hint_tooltip
		if !tooltip.empty() and node.shortcut:
			ui_tooltips[node] = tooltip


func _initialize_keychain() -> void:
	Keychain.config_file = config_cache
	Keychain.actions = {
		"new_file": Keychain.MenuInputAction.new("", "File menu", true, "FileMenu", FileMenu.NEW),
		"open_file": Keychain.MenuInputAction.new("", "File menu", true, "FileMenu", FileMenu.OPEN),
		"open_last_project":
		Keychain.MenuInputAction.new("", "File menu", true, "FileMenu", FileMenu.OPEN_LAST_PROJECT),
		"save_file": Keychain.MenuInputAction.new("", "File menu", true, "FileMenu", FileMenu.SAVE),
		"save_file_as":
		Keychain.MenuInputAction.new("", "File menu", true, "FileMenu", FileMenu.SAVE_AS),
		"export_file":
		Keychain.MenuInputAction.new("", "File menu", true, "FileMenu", FileMenu.EXPORT),
		"export_file_as":
		Keychain.MenuInputAction.new("", "File menu", true, "FileMenu", FileMenu.EXPORT_AS),
		"quit": Keychain.MenuInputAction.new("", "File menu", true, "FileMenu", FileMenu.QUIT),
		"redo":
		Keychain.MenuInputAction.new("", "Edit menu", true, "EditMenu", EditMenu.REDO, true),
		"undo":
		Keychain.MenuInputAction.new("", "Edit menu", true, "EditMenu", EditMenu.UNDO, true),
		"cut": Keychain.MenuInputAction.new("", "Edit menu", true, "EditMenu", EditMenu.CUT),
		"copy": Keychain.MenuInputAction.new("", "Edit menu", true, "EditMenu", EditMenu.COPY),
		"paste": Keychain.MenuInputAction.new("", "Edit menu", true, "EditMenu", EditMenu.PASTE),
		"paste_in_place":
		Keychain.MenuInputAction.new("", "Edit menu", true, "EditMenu", EditMenu.PASTE_IN_PLACE),
		"delete": Keychain.MenuInputAction.new("", "Edit menu", true, "EditMenu", EditMenu.DELETE),
		"new_brush":
		Keychain.MenuInputAction.new("", "Edit menu", true, "EditMenu", EditMenu.NEW_BRUSH),
		"preferences":
		Keychain.MenuInputAction.new("", "Edit menu", true, "EditMenu", EditMenu.PREFERENCES),
		"scale_image":
		Keychain.MenuInputAction.new("", "Image menu", true, "ImageMenu", ImageMenu.SCALE_IMAGE),
		"centralize_image":
		Keychain.MenuInputAction.new(
			"", "Image menu", true, "ImageMenu", ImageMenu.CENTRALIZE_IMAGE
		),
		"crop_image":
		Keychain.MenuInputAction.new("", "Image menu", true, "ImageMenu", ImageMenu.CROP_IMAGE),
		"resize_canvas":
		Keychain.MenuInputAction.new("", "Image menu", true, "ImageMenu", ImageMenu.RESIZE_CANVAS),
		"mirror_image":
		Keychain.MenuInputAction.new("", "Image menu", true, "ImageMenu", ImageMenu.FLIP),
		"rotate_image":
		Keychain.MenuInputAction.new("", "Image menu", true, "ImageMenu", ImageMenu.ROTATE),
		"invert_colors":
		Keychain.MenuInputAction.new("", "Image menu", true, "ImageMenu", ImageMenu.INVERT_COLORS),
		"desaturation":
		Keychain.MenuInputAction.new("", "Image menu", true, "ImageMenu", ImageMenu.DESATURATION),
		"outline":
		Keychain.MenuInputAction.new("", "Image menu", true, "ImageMenu", ImageMenu.OUTLINE),
		"drop_shadow":
		Keychain.MenuInputAction.new("", "Image menu", true, "ImageMenu", ImageMenu.DROP_SHADOW),
		"adjust_hsv":
		Keychain.MenuInputAction.new("", "Image menu", true, "ImageMenu", ImageMenu.HSV),
		"gradient":
		Keychain.MenuInputAction.new("", "Image menu", true, "ImageMenu", ImageMenu.GRADIENT),
		"gradient_map":
		Keychain.MenuInputAction.new("", "Image menu", true, "ImageMenu", ImageMenu.GRADIENT_MAP),
		"mirror_view":
		Keychain.MenuInputAction.new("", "View menu", true, "ViewMenu", ViewMenu.MIRROR_VIEW),
		"show_grid":
		Keychain.MenuInputAction.new("", "View menu", true, "ViewMenu", ViewMenu.SHOW_GRID),
		"show_pixel_grid":
		Keychain.MenuInputAction.new("", "View menu", true, "ViewMenu", ViewMenu.SHOW_PIXEL_GRID),
		"show_guides":
		Keychain.MenuInputAction.new("", "View menu", true, "ViewMenu", ViewMenu.SHOW_GUIDES),
		"show_rulers":
		Keychain.MenuInputAction.new("", "View menu", true, "ViewMenu", ViewMenu.SHOW_RULERS),
		"moveable_panels":
		Keychain.MenuInputAction.new(
			"", "Window menu", true, "WindowMenu", WindowMenu.MOVABLE_PANELS
		),
		"zen_mode":
		Keychain.MenuInputAction.new("", "Window menu", true, "WindowMenu", WindowMenu.ZEN_MODE),
		"toggle_fullscreen":
		Keychain.MenuInputAction.new(
			"", "Window menu", true, "WindowMenu", WindowMenu.FULLSCREEN_MODE
		),
		"clear_selection":
		Keychain.MenuInputAction.new(
			"", "Select menu", true, "SelectMenu", SelectMenu.CLEAR_SELECTION
		),
		"select_all":
		Keychain.MenuInputAction.new("", "Select menu", true, "SelectMenu", SelectMenu.SELECT_ALL),
		"invert_selection":
		Keychain.MenuInputAction.new("", "Select menu", true, "SelectMenu", SelectMenu.INVERT),
		"view_splash_screen":
		Keychain.MenuInputAction.new(
			"", "Help menu", true, "HelpMenu", HelpMenu.VIEW_SPLASH_SCREEN
		),
		"open_docs":
		Keychain.MenuInputAction.new("", "Help menu", true, "HelpMenu", HelpMenu.ONLINE_DOCS),
		"issue_tracker":
		Keychain.MenuInputAction.new("", "Help menu", true, "HelpMenu", HelpMenu.ISSUE_TRACKER),
		"open_logs_folder":
		Keychain.MenuInputAction.new("", "Help menu", true, "HelpMenu", HelpMenu.OPEN_LOGS_FOLDER),
		"changelog":
		Keychain.MenuInputAction.new("", "Help menu", true, "HelpMenu", HelpMenu.CHANGELOG),
		"about_pixelorama":
		Keychain.MenuInputAction.new("", "Help menu", true, "HelpMenu", HelpMenu.ABOUT_PIXELORAMA),
		"zoom_in": Keychain.InputAction.new("", "Canvas"),
		"zoom_out": Keychain.InputAction.new("", "Canvas"),
		"camera_left": Keychain.InputAction.new("", "Canvas"),
		"camera_right": Keychain.InputAction.new("", "Canvas"),
		"camera_up": Keychain.InputAction.new("", "Canvas"),
		"camera_down": Keychain.InputAction.new("", "Canvas"),
		"pan": Keychain.InputAction.new("", "Canvas"),
		"activate_left_tool": Keychain.InputAction.new("", "Canvas"),
		"activate_right_tool": Keychain.InputAction.new("", "Canvas"),
		"move_mouse_left": Keychain.InputAction.new("", "Cursor movement"),
		"move_mouse_right": Keychain.InputAction.new("", "Cursor movement"),
		"move_mouse_up": Keychain.InputAction.new("", "Cursor movement"),
		"move_mouse_down": Keychain.InputAction.new("", "Cursor movement"),
		"switch_colors": Keychain.InputAction.new("", "Buttons"),
		"go_to_first_frame": Keychain.InputAction.new("", "Buttons"),
		"go_to_last_frame": Keychain.InputAction.new("", "Buttons"),
		"go_to_previous_frame": Keychain.InputAction.new("", "Buttons"),
		"go_to_next_frame": Keychain.InputAction.new("", "Buttons"),
		"play_backwards": Keychain.InputAction.new("", "Buttons"),
		"play_forward": Keychain.InputAction.new("", "Buttons"),
		"change_tool_mode": Keychain.InputAction.new("", "Tool modifiers", false),
		"draw_create_line": Keychain.InputAction.new("", "Draw tools", false),
		"draw_snap_angle": Keychain.InputAction.new("", "Draw tools", false),
		"draw_color_picker": Keychain.InputAction.new("Quick color picker", "Draw tools", false),
		"shape_perfect": Keychain.InputAction.new("", "Shape tools", false),
		"shape_center": Keychain.InputAction.new("", "Shape tools", false),
		"shape_displace": Keychain.InputAction.new("", "Shape tools", false),
		"selection_add": Keychain.InputAction.new("", "Selection tools", false),
		"selection_subtract": Keychain.InputAction.new("", "Selection tools", false),
		"selection_intersect": Keychain.InputAction.new("", "Selection tools", false),
		"transformation_confirm": Keychain.InputAction.new("", "Transformation tools", false),
		"transformation_cancel": Keychain.InputAction.new("", "Transformation tools", false),
		"transform_snap_axis": Keychain.InputAction.new("", "Transformation tools", false),
		"transform_snap_grid": Keychain.InputAction.new("", "Transformation tools", false),
		"transform_move_selection_only":
		Keychain.InputAction.new("", "Transformation tools", false),
		"transform_copy_selection_content":
		Keychain.InputAction.new("", "Transformation tools", false),
	}

	Keychain.groups = {
		"Canvas": Keychain.InputGroup.new("", false),
		"Cursor movement": Keychain.InputGroup.new("Canvas"),
		"Buttons": Keychain.InputGroup.new(),
		"Tools": Keychain.InputGroup.new(),
		"Left": Keychain.InputGroup.new("Tools"),
		"Right": Keychain.InputGroup.new("Tools"),
		"Menu": Keychain.InputGroup.new(),
		"File menu": Keychain.InputGroup.new("Menu"),
		"Edit menu": Keychain.InputGroup.new("Menu"),
		"View menu": Keychain.InputGroup.new("Menu"),
		"Select menu": Keychain.InputGroup.new("Menu"),
		"Image menu": Keychain.InputGroup.new("Menu"),
		"Window menu": Keychain.InputGroup.new("Menu"),
		"Help menu": Keychain.InputGroup.new("Menu"),
		"Tool modifiers": Keychain.InputGroup.new(),
		"Draw tools": Keychain.InputGroup.new("Tool modifiers"),
		"Shape tools": Keychain.InputGroup.new("Tool modifiers"),
		"Selection tools": Keychain.InputGroup.new("Tool modifiers"),
		"Transformation tools": Keychain.InputGroup.new("Tool modifiers"),
	}
	Keychain.ignore_actions = ["left_mouse", "right_mouse", "middle_mouse", "shift", "ctrl"]
	Keychain.multiple_menu_accelerators = true


func notification_label(text: String) -> void:
	var notification := NotificationLabel.new()
	notification.text = tr(text)
	notification.rect_position = main_viewport.rect_global_position
	notification.rect_position.y += main_viewport.rect_size.y
	control.add_child(notification)


func general_undo(project: Project = current_project) -> void:
	project.undos -= 1
	var action_name: String = project.undo_redo.get_current_action_name()
	notification_label("Undo: %s" % action_name)


func general_redo(project: Project = current_project) -> void:
	if project.undos < project.undo_redo.get_version():  # If we did undo and then redo
		project.undos = project.undo_redo.get_version()
	if control.redone:
		var action_name: String = project.undo_redo.get_current_action_name()
		notification_label("Redo: %s" % action_name)


func undo_or_redo(
	undo: bool, frame_index := -1, layer_index := -1, project: Project = current_project
) -> void:
	if undo:
		general_undo(project)
	else:
		general_redo(project)
	var action_name: String = project.undo_redo.get_current_action_name()
	if (
		action_name
		in [
			"Draw",
			"Draw Shape",
			"Select",
			"Move Selection",
			"Scale",
			"Centralize",
			"Merge Layer",
			"Link Cel",
			"Unlink Cel"
		]
	):
		if layer_index > -1 and frame_index > -1:
			canvas.update_texture(layer_index, frame_index, project)
		else:
			for i in project.frames.size():
				for j in project.layers.size():
					canvas.update_texture(j, i, project)

		canvas.selection.update()
		if action_name == "Scale":
			for i in project.frames.size():
				for j in project.layers.size():
					var current_cel: BaseCel = project.frames[i].cels[j]
					current_cel.image_texture.create_from_image(current_cel.get_image(), 0)
			canvas.camera_zoom()
			canvas.grid.update()
			canvas.pixel_grid.update()
			project.selection_map_changed()
			cursor_position_label.text = "[%s×%s]" % [project.size.x, project.size.y]

	canvas.update()
	if !project.has_changed:
		project.has_changed = true
		if project == current_project:
			self.window_title = window_title + "(*)"


func _title_changed(value: String) -> void:
	window_title = value
	OS.set_window_title(value)


func _project_changed(value: int) -> void:
	canvas.selection.transform_content_confirm()
	current_project_index = value
	current_project = projects[value]
	connect("project_changed", current_project, "change_project")
	emit_signal("project_changed")
	disconnect("project_changed", current_project, "change_project")
	emit_signal("cel_changed")


func _renderer_changed(value: int) -> void:
	renderer = value
	if OS.has_feature("editor"):
		return

	# Sets GLES2 as the default value in `override.cfg`.
	# Without this, switching to GLES3 does not work, because it will default to GLES2.
	ProjectSettings.set_initial_value("rendering/quality/driver/driver_name", "GLES2")
	var renderer_name := OS.get_video_driver_name(renderer)
	ProjectSettings.set_setting("rendering/quality/driver/driver_name", renderer_name)
	ProjectSettings.save_custom(OVERRIDE_FILE)


func _tablet_driver_changed(value: int) -> void:
	tablet_driver = value
	if OS.has_feature("editor"):
		return
	var tablet_driver_name := OS.get_tablet_driver_name(tablet_driver)
	ProjectSettings.set_setting("display/window/tablet_driver", tablet_driver_name)
	ProjectSettings.save_custom(OVERRIDE_FILE)


func dialog_open(open: bool) -> void:
	var dim_color := Color.white
	if open:
		can_draw = false
		if dim_on_popup:
			dim_color = Color(0.5, 0.5, 0.5)
	else:
		can_draw = true

	var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate", dim_color, 0.1)


func disable_button(button: BaseButton, disable: bool) -> void:
	button.disabled = disable
	if disable:
		button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	else:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if button is Button:
		for c in button.get_children():
			if c is TextureRect:
				c.modulate.a = 0.5 if disable else 1.0
				break


func change_button_texturerect(texture_button: TextureRect, new_file_name: String) -> void:
	if !texture_button.texture:
		return
	var file_name := texture_button.texture.resource_path.get_basename().get_file()
	var directory_path := texture_button.texture.resource_path.get_basename().replace(file_name, "")
	texture_button.texture = load(directory_path.plus_file(new_file_name))


func update_hint_tooltips() -> void:
	yield(get_tree(), "idle_frame")
	Tools.update_hint_tooltips()

	for tip in ui_tooltips:
		var hint := "None"
		var event_type: InputEvent = tip.shortcut.shortcut
		if event_type is InputEventKey:
			hint = event_type.as_text()
		elif event_type is InputEventAction:
			var first_key: InputEventKey = Keychain.action_get_first_key(event_type.action)
			hint = first_key.as_text() if first_key else "None"
		tip.hint_tooltip = tr(ui_tooltips[tip]) % hint
