extends Node

enum GridTypes { CARTESIAN, ISOMETRIC, ALL }
enum PressureSensitivity { NONE, ALPHA, SIZE, ALPHA_AND_SIZE }
enum TileMode { NONE, BOTH, X_AXIS, Y_AXIS }
enum IconColorFrom { THEME, CUSTOM }
enum ButtonSize { SMALL, BIG }

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
var layers_changed_skip := false
var can_draw := false
var move_guides_on_canvas := false
var has_focus := false

var play_only_tags := true
var show_x_symmetry_axis := false
var show_y_symmetry_axis := false

# Preferences
var pressure_sensitivity_mode = PressureSensitivity.NONE
var open_last_project := false
var quit_confirmation := false
var smooth_zoom := true

var shrink := 1.0
var dim_on_popup := true
var modulate_icon_color := Color.gray
var icon_color_from: int = IconColorFrom.THEME
var custom_icon_color := Color.gray
var tool_button_size: int = ButtonSize.SMALL

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

# Tools & options
var show_left_tool_icon := true
var show_right_tool_icon := true
var left_square_indicator_visible := true
var right_square_indicator_visible := false
var native_cursors := false
var cross_cursor := true

# View menu options
var greyscale_view := false
var mirror_view := false
var draw_grid := false
var draw_pixel_grid := false
var show_rulers := true
var show_guides := true

# Onion skinning options
var onion_skinning := false
var onion_skinning_past_rate := 1.0
var onion_skinning_future_rate := 1.0
var onion_skinning_blue_red := false

# Palettes
var palettes := {}

# Nodes
var notification_label_node = preload("res://src/UI/NotificationLabel.tscn")

onready var root: Node = get_tree().get_root()
onready var control: Node = root.get_node("Control")

onready var left_cursor: Sprite = control.find_node("LeftCursor")
onready var right_cursor: Sprite = control.find_node("RightCursor")
onready var canvas: Canvas = control.find_node("Canvas")
onready var tabs: Tabs = control.find_node("Tabs")
onready var main_viewport: ViewportContainer = control.find_node("ViewportContainer")
onready var second_viewport: ViewportContainer = control.find_node("Second Canvas")
onready var main_canvas_container: Container = control.find_node("Main Canvas")
onready var canvas_preview_container: Container = control.find_node("Canvas Preview")
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
onready var greyscale_vision: ColorRect = control.find_node("GreyscaleVision")
onready var preview_zoom_slider: VSlider = control.find_node("PreviewZoomSlider")

onready var tool_panel: ScrollContainer = control.find_node("Tools")
onready var left_tool_options_scroll: ScrollContainer = control.find_node("Left Tool Options")
onready var right_tool_options_scroll: ScrollContainer = control.find_node("Right Tool Options")
onready var brushes_popup: Popup = control.find_node("BrushesPopup")
onready var patterns_popup: Popup = control.find_node("PatternsPopup")
onready var palette_panel: PalettePanel = control.find_node("Palette Panel")

onready var top_menu_container: Panel = control.find_node("TopMenuContainer")
onready var rotation_level_button: Button = control.find_node("RotationLevel")
onready var rotation_level_spinbox: SpinBox = control.find_node("RotationSpinbox")
onready var zoom_level_button: Button = control.find_node("ZoomLevel")
onready var zoom_level_spinbox: SpinBox = control.find_node("ZoomSpinbox")
onready var cursor_position_label: Label = control.find_node("CursorPosition")
onready var current_frame_mark_label: Label = control.find_node("CurrentFrameMark")

onready var animation_timeline: Panel = control.find_node("Animation Timeline")
onready var animation_timer: Timer = animation_timeline.find_node("AnimationTimer")
onready var frame_ids: HBoxContainer = animation_timeline.find_node("FrameIDs")
onready var play_forward: BaseButton = animation_timeline.find_node("PlayForward")
onready var play_backwards: BaseButton = animation_timeline.find_node("PlayBackwards")
onready var layers_container: VBoxContainer = animation_timeline.find_node("LayersContainer")
onready var frames_container: VBoxContainer = animation_timeline.find_node("FramesContainer")
onready var tag_container: Control = animation_timeline.find_node("TagContainer")
onready var remove_frame_button: BaseButton = animation_timeline.find_node("DeleteFrame")
onready var move_left_frame_button: BaseButton = animation_timeline.find_node("MoveLeft")
onready var move_right_frame_button: BaseButton = animation_timeline.find_node("MoveRight")
onready var remove_layer_button: BaseButton = animation_timeline.find_node("RemoveLayer")
onready var move_up_layer_button: BaseButton = animation_timeline.find_node("MoveUpLayer")
onready var move_down_layer_button: BaseButton = animation_timeline.find_node("MoveDownLayer")
onready var merge_down_layer_button: BaseButton = animation_timeline.find_node("MergeDownLayer")
onready var layer_opacity_slider: HSlider = animation_timeline.find_node("OpacitySlider")
onready var layer_opacity_spinbox: SpinBox = animation_timeline.find_node("OpacitySpinBox")

onready var open_sprites_dialog: FileDialog = control.find_node("OpenSprite")
onready var save_sprites_dialog: FileDialog = control.find_node("SaveSprite")
onready var save_sprites_html5_dialog: ConfirmationDialog = control.find_node("SaveSpriteHTML5")
onready var export_dialog: AcceptDialog = control.find_node("ExportDialog")
onready var preferences_dialog: AcceptDialog = control.find_node("PreferencesDialog")
onready var error_dialog: AcceptDialog = control.find_node("ErrorDialog")
onready var quit_and_save_dialog: ConfirmationDialog = control.find_node("QuitAndSaveDialog")

onready var current_version: String = ProjectSettings.get_setting("application/config/Version")


func _ready() -> void:
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
	current_project.layers.append(Layer.new())
	current_project.fill_color = default_fill_color
	var frame: Frame = current_project.new_empty_frame()
	current_project.frames.append(frame)

	for node in get_tree().get_nodes_in_group("UIButtons"):
		var tooltip: String = node.hint_tooltip
		if !tooltip.empty() and node.shortcut:
			ui_tooltips[node] = tooltip


func notification_label(text: String) -> void:
	var notification: Label = notification_label_node.instance()
	notification.text = tr(text)
	notification.rect_position = Vector2(70, animation_timeline.rect_position.y)
	notification.theme = control.theme
	get_tree().get_root().add_child(notification)


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
			canvas.camera_zoom()
			canvas.grid.update()
			canvas.pixel_grid.update()
			cursor_position_label.text = "[%s×%s]" % [project.size.x, project.size.y]

	elif "Frame" in action_name:
		# This actually means that frames.size is one, but it hasn't been updated yet
		if (undo and project.frames.size() == 2) or project.frames.size() == 1:  # Stop animating
			play_forward.pressed = false
			play_backwards.pressed = false
			animation_timer.stop()

	elif "Move Cels" == action_name:
		project.frames = project.frames  # to call frames_changed

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
	current_project.change_project()


func dialog_open(open: bool) -> void:
	var dim_color := Color.white
	if open:
		can_draw = false
		if dim_on_popup:
			dim_color = Color(0.5, 0.5, 0.5)
	else:
		can_draw = true

	control.get_node("ModulateTween").interpolate_property(
		control, "modulate", control.modulate, dim_color, 0.1, Tween.TRANS_LINEAR, Tween.EASE_OUT
	)

	control.get_node("ModulateTween").start()


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
	Tools.update_hint_tooltips()

	for tip in ui_tooltips:
		tip.hint_tooltip = tr(ui_tooltips[tip]) % tip.shortcut.get_as_text()
