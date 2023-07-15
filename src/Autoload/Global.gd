extends Node

signal project_changed
signal cel_changed

enum LayerTypes { PIXEL, GROUP, THREE_D }
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
	RESIZE_CANVAS,
	OFFSET_IMAGE,
	SCALE_IMAGE,
	CROP_IMAGE,
	FLIP,
	ROTATE,
	OUTLINE,
	DROP_SHADOW,
	INVERT_COLORS,
	DESATURATION,
	HSV,
	POSTERIZE,
	GRADIENT,
	GRADIENT_MAP,
	SHADER
}
enum SelectMenu { SELECT_ALL, CLEAR_SELECTION, INVERT, TILE_MODE }
enum HelpMenu {
	VIEW_SPLASH_SCREEN, ONLINE_DOCS, ISSUE_TRACKER, OPEN_LOGS_FOLDER, CHANGELOG, ABOUT_PIXELORAMA
}

const OVERRIDE_FILE := "override.cfg"

var root_directory := "."
var window_title := "":
	set = _title_changed
var config_cache := ConfigFile.new()
var XDGDataPaths := preload("res://src/XDGDataPaths.gd")
var directory_module: RefCounted

var projects: Array[Project] = []
var current_project: Project
var current_project_index := 0:
	set = _project_changed

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
var integer_zoom := false setget set_integer_zoom

var shrink := 1.0
var dim_on_popup := true
var modulate_icon_color := Color.GRAY
var icon_color_from := ColorFrom.THEME
var modulate_clear_color := Color.GRAY
var clear_color_from := ColorFrom.THEME
var custom_icon_color := Color.GRAY
var tool_button_size := ButtonSize.SMALL
var left_tool_color := Color("0086cf")
var right_tool_color := Color("fd6d14")

var default_width := 64
var default_height := 64
var default_fill_color := Color(0, 0, 0, 0)
var snapping_distance := 32.0
var grid_type = GridTypes.CARTESIAN
var grid_size := Vector2i(2, 2)
var isometric_grid_size := Vector2i(16, 8)
var grid_offset := Vector2i.ZERO
var grid_draw_over_tile_mode := false
var grid_color := Color.BLACK
var pixel_grid_show_at_zoom := 1500.0  # percentage
var pixel_grid_color := Color("91212121")
var guide_color := Color.PURPLE
var checker_size := 10
var checker_color_1 := Color(0.47, 0.47, 0.47, 1)
var checker_color_2 := Color(0.34, 0.35, 0.34, 1)
var checker_follow_movement := false
var checker_follow_scale := false
var tilemode_opacity := 1.0

var select_layer_on_button_click := false
var onion_skinning_past_color := Color.RED
var onion_skinning_future_color := Color.BLUE

var selection_animated_borders := true
var selection_border_color_1 := Color.WHITE
var selection_border_color_2 := Color.BLACK

var pause_when_unfocused := true
var fps_limit := 0

var autosave_interval := 1.0
var enable_autosave := true
var renderer := 0:
	set = _renderer_changed
var tablet_driver := 0:
	set = _tablet_driver_changed

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
var base_layer_button_node: PackedScene = load("res://src/UI/Timeline/BaseLayerButton.tscn")
var pixel_layer_button_node: PackedScene = load("res://src/UI/Timeline/PixelLayerButton.tscn")
var group_layer_button_node: PackedScene = load("res://src/UI/Timeline/GroupLayerButton.tscn")
var pixel_cel_button_node: PackedScene = load("res://src/UI/Timeline/PixelCelButton.tscn")
var group_cel_button_node: PackedScene = load("res://src/UI/Timeline/GroupCelButton.tscn")
var cel_3d_button_node: PackedScene = load("res://src/UI/Timeline/Cel3DButton.tscn")

@onready var control: Node = get_tree().current_scene

@onready var canvas: Canvas = control.find_child("Canvas")
@onready var tabs: TabBar = control.find_child("TabBar")
@onready var main_viewport: SubViewportContainer = control.find_child("SubViewportContainer")
@onready var second_viewport: SubViewportContainer = control.find_child("Second Canvas")
@onready var canvas_preview_container: Container = control.find_child("Canvas Preview")
@onready var global_tool_options: PanelContainer = control.find_child("Global Tool Options")
@onready var small_preview_viewport: SubViewportContainer = canvas_preview_container.find_child(
	"PreviewViewportContainer"
)
@onready var camera: Camera2D = main_viewport.find_child("Camera2D")
@onready var camera2: Camera2D = second_viewport.find_child("Camera2D2")
@onready var camera_preview: Camera2D = control.find_child("CameraPreview")
@onready var cameras := [camera, camera2, camera_preview]
@onready var horizontal_ruler: BaseButton = control.find_child("HorizontalRuler")
@onready var vertical_ruler: BaseButton = control.find_child("VerticalRuler")
@onready var transparent_checker: ColorRect = control.find_child("TransparentChecker")

@onready var brushes_popup: Popup = control.find_child("BrushesPopup")
@onready var patterns_popup: Popup = control.find_child("PatternsPopup")
@onready var palette_panel: PalettePanel = control.find_child("Palettes")

@onready var references_panel: ReferencesPanel = control.find_child("Reference Images")
@onready var perspective_editor := control.find_child("Perspective Editor")

@onready var top_menu_container: Panel = control.find_child("TopMenuContainer")
@onready var cursor_position_label: Label = control.find_child("CursorPosition")
@onready var current_frame_mark_label: Label = control.find_child("CurrentFrameMark")

@onready var animation_timeline: Panel = control.find_child("Animation Timeline")
@onready var animation_timer: Timer = animation_timeline.find_child("AnimationTimer")
@onready var frame_hbox: HBoxContainer = animation_timeline.find_child("FrameHBox")
@onready var layer_vbox: VBoxContainer = animation_timeline.find_child("LayerVBox")
@onready var cel_vbox: VBoxContainer = animation_timeline.find_child("CelVBox")
@onready var tag_container: Control = animation_timeline.find_child("TagContainer")
@onready var play_forward: BaseButton = animation_timeline.find_child("PlayForward")
@onready var play_backwards: BaseButton = animation_timeline.find_child("PlayBackwards")
@onready var remove_frame_button: BaseButton = animation_timeline.find_child("DeleteFrame")
@onready var move_left_frame_button: BaseButton = animation_timeline.find_child("MoveLeft")
@onready var move_right_frame_button: BaseButton = animation_timeline.find_child("MoveRight")
@onready var remove_layer_button: BaseButton = animation_timeline.find_child("RemoveLayer")
@onready var move_up_layer_button: BaseButton = animation_timeline.find_child("MoveUpLayer")
@onready var move_down_layer_button: BaseButton = animation_timeline.find_child("MoveDownLayer")
@onready var merge_down_layer_button: BaseButton = animation_timeline.find_child("MergeDownLayer")
@onready var layer_opacity_slider: ValueSlider = animation_timeline.find_child("OpacitySlider")

@onready var tile_mode_offset_dialog: AcceptDialog = control.find_child("TileModeOffsetsDialog")
@onready var open_sprites_dialog: FileDialog = control.find_child("OpenSprite")
@onready var save_sprites_dialog: FileDialog = control.find_child("SaveSprite")
@onready var save_sprites_html5_dialog: ConfirmationDialog = control.find_child("SaveSpriteHTML5")
@onready var export_dialog: AcceptDialog = control.find_child("ExportDialog")
@onready var preferences_dialog: AcceptDialog = control.find_child("PreferencesDialog")
@onready var error_dialog: AcceptDialog = control.find_child("ErrorDialog")

@onready var current_version: String = ProjectSettings.get_setting("application/config/Version")


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
		var tooltip: String = node.tooltip_text
		if !tooltip.is_empty() and node.shortcut:
			ui_tooltips[node] = tooltip
	await get_tree().process_frame
	project_changed.emit()


func set_integer_zoom(enabled: bool):
	integer_zoom = enabled
	var zoom_slider: ValueSlider = top_menu_container.get_node("%ZoomSlider")
	if enabled:
		zoom_slider.snap_step = 100
		zoom_slider.step = 100
	else:
		zoom_slider.snap_step = 1
		zoom_slider.step = 1
	zoom_slider.value = zoom_slider.value  # to trigger signal emmission


func _initialize_keychain() -> void:
	Keychain.config_file = config_cache
	Keychain.actions = {
		"new_file": Keychain.InputAction.new("", "File menu", true),
		"open_file": Keychain.InputAction.new("", "File menu", true),
		"open_last_project": Keychain.InputAction.new("", "File menu", true),
		"save_file": Keychain.InputAction.new("", "File menu", true),
		"save_file_as": Keychain.InputAction.new("", "File menu", true),
		"export_file": Keychain.InputAction.new("", "File menu", true),
		"export_file_as": Keychain.InputAction.new("", "File menu", true),
		"quit": Keychain.InputAction.new("", "File menu", true),
		"redo": Keychain.InputAction.new("", "Edit menu", true),
		"undo": Keychain.InputAction.new("", "Edit menu", true),
		"cut": Keychain.InputAction.new("", "Edit menu", true),
		"copy": Keychain.InputAction.new("", "Edit menu", true),
		"paste": Keychain.InputAction.new("", "Edit menu", true),
		"paste_in_place": Keychain.InputAction.new("", "Edit menu", true),
		"delete": Keychain.InputAction.new("", "Edit menu", true),
		"new_brush": Keychain.InputAction.new("", "Edit menu", true),
		"preferences": Keychain.InputAction.new("", "Edit menu", true),
		"scale_image": Keychain.InputAction.new("", "Image menu", true),
		"crop_image": Keychain.InputAction.new("", "Image menu", true),
		"resize_canvas": Keychain.InputAction.new("", "Image menu", true),
		"offset_image": Keychain.InputAction.new("", "Image menu", true),
		"mirror_image": Keychain.InputAction.new("", "Image menu", true),
		"rotate_image": Keychain.InputAction.new("", "Image menu", true),
		"invert_colors": Keychain.InputAction.new("", "Image menu", true),
		"desaturation": Keychain.InputAction.new("", "Image menu", true),
		"outline": Keychain.InputAction.new("", "Image menu", true),
		"drop_shadow": Keychain.InputAction.new("", "Image menu", true),
		"adjust_hsv": Keychain.InputAction.new("", "Image menu", true),
		"gradient": Keychain.InputAction.new("", "Image menu", true),
		"gradient_map": Keychain.InputAction.new("", "Image menu", true),
		"posterize": Keychain.InputAction.new("", "Image menu", true),
		"mirror_view": Keychain.InputAction.new("", "View menu", true),
		"show_grid": Keychain.InputAction.new("", "View menu", true),
		"show_pixel_grid": Keychain.InputAction.new("", "View menu", true),
		"show_guides": Keychain.InputAction.new("", "View menu", true),
		"show_rulers": Keychain.InputAction.new("", "View menu", true),
		"moveable_panels": Keychain.InputAction.new("", "Window menu", true),
		"zen_mode": Keychain.InputAction.new("", "Window menu", true),
		"toggle_fullscreen": Keychain.InputAction.new("", "Window menu", true),
		"clear_selection": Keychain.InputAction.new("", "Select menu", true),
		"select_all": Keychain.InputAction.new("", "Select menu", true),
		"invert_selection": Keychain.InputAction.new("", "Select menu", true),
		"view_splash_screen": Keychain.InputAction.new("", "Help menu", true),
		"open_docs": Keychain.InputAction.new("", "Help menu", true),
		"issue_tracker": Keychain.InputAction.new("", "Help menu", true),
		"open_logs_folder": Keychain.InputAction.new("", "Help menu", true),
		"changelog": Keychain.InputAction.new("", "Help menu", true),
		"about_pixelorama": Keychain.InputAction.new("", "Help menu", true),
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


func notification_label(text: String) -> void:
	var notif := NotificationLabel.new()
	notif.text = tr(text)
	notif.position = main_viewport.global_position
	notif.position.y += main_viewport.size.y
	control.add_child(notif)


func general_undo(project: Project = current_project) -> void:
	project.undos -= 1
	var action_name := project.undo_redo.get_current_action_name()
	notification_label("Undo: %s" % action_name)


func general_redo(project: Project = current_project) -> void:
	if project.undos < project.undo_redo.get_version():  # If we did undo and then redo
		project.undos = project.undo_redo.get_version()
	if control.redone:
		var action_name := project.undo_redo.get_current_action_name()
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
			"Center Frames",
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

		canvas.selection.queue_redraw()
		if action_name == "Scale":
			for i in project.frames.size():
				for j in project.layers.size():
					var current_cel: BaseCel = project.frames[i].cels[j]
					if current_cel is Cel3D:
						current_cel.size_changed(project.size)
					else:
						current_cel.image_texture = ImageTexture.create_from_image(
							current_cel.get_image()
						)
			canvas.camera_zoom()
			canvas.grid.queue_redraw()
			canvas.pixel_grid.queue_redraw()
			project.selection_map_changed()
			cursor_position_label.text = "[%s×%s]" % [project.size.x, project.size.y]

	canvas.queue_redraw()
	second_viewport.get_child(0).get_node("CanvasPreview").queue_redraw()
	canvas_preview_container.canvas_preview.queue_redraw()
	if !project.has_changed:
		project.has_changed = true
		if project == current_project:
			window_title = window_title + "(*)"


func _title_changed(value: String) -> void:
	window_title = value
	get_window().set_title(value)


func _project_changed(value: int) -> void:
	if value >= projects.size():
		return
	canvas.selection.transform_content_confirm()
	current_project_index = value
	current_project = projects[value]
	project_changed.connect(current_project.change_project)
	project_changed.emit()
	project_changed.disconnect(current_project.change_project)
	cel_changed.emit()


func _renderer_changed(value: int) -> void:
	renderer = value


#	if OS.has_feature("editor"):
#		return
#
#	# Sets GLES2 as the default value in `override.cfg`.
#	# Without this, switching to GLES3 does not work, because it will default to GLES2.
#	ProjectSettings.set_initial_value("rendering/quality/driver/driver_name", "GLES2")
#	var renderer_name := OS.get_video_driver_name(renderer)
#	ProjectSettings.set_setting("rendering/quality/driver/driver_name", renderer_name)
#	ProjectSettings.save_custom(OVERRIDE_FILE)


func _tablet_driver_changed(value: int) -> void:
	tablet_driver = value
	if OS.has_feature("editor"):
		return
	var tablet_driver_name := DisplayServer.tablet_get_current_driver()
	ProjectSettings.set_setting("display/window/tablet_driver", tablet_driver_name)
	ProjectSettings.save_custom(OVERRIDE_FILE)


func dialog_open(open: bool) -> void:
	var dim_color := Color.WHITE
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
	texture_button.texture = load(directory_path.path_join(new_file_name))


func update_hint_tooltips() -> void:
	await get_tree().process_frame
	Tools.update_hint_tooltips()

	for tip in ui_tooltips:
		var hint := "None"
		var events: Array = tip.shortcut.events
		if events.size() > 0:
			var event_type: InputEvent = events[0]
			hint = event_type.as_text()
		tip.tooltip_text = tr(ui_tooltips[tip]) % hint
