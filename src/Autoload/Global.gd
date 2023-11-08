extends Node

## The Global autoload of Pixelorama.
##
## This Autoload contains signals, enums, constants, variables and
## references to many UI elements used within Pixelorama.

signal pixelorama_opened  ## Emitted as soon as Pixelorama fully opens up.
signal pixelorama_about_to_close  ## Emitted just before Pixelorama is about to close.
signal project_created(Project)  ## Emitted when a new project class is initialized.
signal project_changed  ## Emitted whenever you switch to some other project tab.
signal cel_changed  ## Emitted whenever you select a different cel.

enum LayerTypes { PIXEL, GROUP, THREE_D }
enum GridTypes { CARTESIAN, ISOMETRIC, ALL }
## ## Used to tell whether a color is being taken from the current theme,
## or if it is a custom color.
enum ColorFrom { THEME, CUSTOM }
enum ButtonSize { SMALL, BIG }


##  Enumeration of items present in the File Menu.
enum FileMenu { NEW, OPEN, OPEN_LAST_PROJECT, RECENT, SAVE, SAVE_AS, EXPORT, EXPORT_AS, QUIT }
##  Enumeration of items present in the Edit Menu.
enum EditMenu { UNDO, REDO, COPY, CUT, PASTE, PASTE_IN_PLACE, DELETE, NEW_BRUSH, PREFERENCES }
##  Enumeration of items present in the View Menu.
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
##  Enumeration of items present in the Window Menu.
enum WindowMenu { WINDOW_OPACITY, PANELS, LAYOUTS, MOVABLE_PANELS, ZEN_MODE, FULLSCREEN_MODE }
##  Enumeration of items present in the Image Menu.
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
##  Enumeration of items present in the Select Menu.
enum SelectMenu { SELECT_ALL, CLEAR_SELECTION, INVERT, TILE_MODE }
##  Enumeration of items present in the Help Menu.
enum HelpMenu {
	VIEW_SPLASH_SCREEN, ONLINE_DOCS, ISSUE_TRACKER, OPEN_LOGS_FOLDER, CHANGELOG, ABOUT_PIXELORAMA
}

## The file used to save preferences that use [code]ProjectSettings.save_custom()[/code].
const OVERRIDE_FILE := "override.cfg"
## The name of folder containing Pixelorama preferences.
const HOME_SUBDIR_NAME := "pixelorama"
## The name of folder that contains subdirectories for users to place brushes, palettes, patterns.
const CONFIG_SUBDIR_NAME := "pixelorama_data"

## It is path to the executable's base drectory.
var root_directory := "."
## The path where preferences and other subdirectories for stuff like layouts, extensions, logs etc.
## will get stored by Pixelorama.
var home_data_directory := OS.get_data_dir().path_join(HOME_SUBDIR_NAME)
## Only read from these directories. This is an [Array] of directories potentially containing
## stuff such as Brushes, Palettes and Patterns in sub-directories.[br]
## ([member home_data_directory] and [member root_directory] are also included in this array).
var data_directories: PackedStringArray = [home_data_directory]
## The config file used to get/set preferences, tool settings etc.
var config_cache := ConfigFile.new()

var projects: Array[Project] = []  ## Array of currently open projects.
var current_project: Project  ## The project that currently in focus.
## The index of project that is currently in focus.
var current_project_index := 0:
	set(value):
		if value >= projects.size():
			return
		canvas.selection.transform_content_confirm()
		current_project_index = value
		current_project = projects[value]
		project_changed.connect(current_project.change_project)
		project_changed.emit()
		project_changed.disconnect(current_project.change_project)
		cel_changed.emit()

# Canvas related stuff
## Tells if the user allowed to draw on the canvas. Usually it is temporarily set to
## [code]false[/code] when we are moving some gizmo and don't want the current tool to accidentally
## start drawing.[br](This does not depend on layer invisibility or lock/unlock status).
var can_draw := false
## (Intended to be used as getter only) Tells if the user allowed to move the guide while on canvas.
var move_guides_on_canvas := true
## Tells if the canvas in currently in focus.
var has_focus := false

var play_only_tags := true  ## If [code]true[/code], animation plays only on frames of the same tag.
## (Intended to be used as getter only) Tells if the x-symmetry guide ( -- ) is visible.
var show_x_symmetry_axis := false
## (Intended to be used as getter only) Tells if the y-symmetry guide ( | ) is visible.
var show_y_symmetry_axis := false

# Preferences
## (Preference Variable) If [code]true[/code], the last saved project will open on startup.
var open_last_project := false
## (Preference Variable) If [code]true[/code], asks for permission to quit on exit.
var quit_confirmation := false
## (Preference Variable) If [code]true[/code], the zoom is smooth.
var smooth_zoom := true
## (Preference Variable) If [code]true[/code], the zoom is restricted to integral multiples of 100%.
var integer_zoom := false:
	set(value):
		integer_zoom = value
		var zoom_slider: ValueSlider = top_menu_container.get_node("%ZoomSlider")
		if value:
			zoom_slider.min_value = 100
			zoom_slider.snap_step = 100
			zoom_slider.step = 100
		else:
			zoom_slider.min_value = 1
			zoom_slider.snap_step = 1
			zoom_slider.step = 1
		zoom_slider.value = zoom_slider.value  # to trigger signal emission

## (Preference Variable) The scale of the Interface.
var shrink := 1.0
## (Preference Variable) The font size used by the Interface.
var font_size := 16:
	set(value):
		font_size = value
		control.theme.default_font_size = value
		control.theme.set_font_size("font_size", "HeaderSmall", value + 2)
## (Preference Variable) If [code]true[/code], the Interface dims on popups.
var dim_on_popup := true
## (Preference Variable) The modulation color (or simply color) of icons.
var modulate_icon_color := Color.GRAY
## (Preference Variable) Determins if [member modulate_icon_color] uses custom or theme color.
var icon_color_from := ColorFrom.THEME:
	set(value):
		icon_color_from = value
		var themes = preferences_dialog.themes
		if icon_color_from == ColorFrom.THEME:
			var current_theme: Theme = themes.themes[themes.theme_index]
			modulate_icon_color = current_theme.get_color("modulate_color", "Icons")
		else:
			modulate_icon_color = custom_icon_color
		themes.change_icon_colors()
## (Preference Variable) Color of icons when [member icon_color_from] is set to use custom colors.
var custom_icon_color := Color.GRAY:
	set(value):
		custom_icon_color = value
		if icon_color_from == ColorFrom.CUSTOM:
			modulate_icon_color = custom_icon_color
			preferences_dialog.themes.change_icon_colors()
## (Preference Variable) The modulation color (or simply color) of canvas background
## (aside from checker background).
var modulate_clear_color := Color.GRAY:
	set(value):
		modulate_clear_color = value
		preferences_dialog.themes.change_clear_color()
## (Preference Variable) Determins if [member modulate_clear_color] uses custom or theme color.
var clear_color_from := ColorFrom.THEME:
	set(value):
		clear_color_from = value
		preferences_dialog.themes.change_clear_color()
## (Preference Variable) The selected size mode of tool buttons using [enum ButtonSize] enum.
var tool_button_size := ButtonSize.SMALL:
	set(value):
		tool_button_size = value
		Tools.set_button_size(tool_button_size)
## (Preference Variable) The left tool color.
var left_tool_color := Color("0086cf"):
	set(value):
		left_tool_color = value
		for child in Tools._tool_buttons.get_children():
			var background: NinePatchRect = child.get_node("BackgroundLeft")
			background.modulate = value
		Tools._slots[MOUSE_BUTTON_LEFT].tool_node.color_rect.color = value
## (Preference Variable) The right tool color.
var right_tool_color := Color("fd6d14"):
	set(value):
		right_tool_color = value
		for child in Tools._tool_buttons.get_children():
			var background: NinePatchRect = child.get_node("BackgroundRight")
			background.modulate = value
		Tools._slots[MOUSE_BUTTON_RIGHT].tool_node.color_rect.color = value

var default_width := 64  ## (Preference Variable) The default width of startup project.
var default_height := 64  ## (Preference Variable) The default height of startup project.
## (Preference Variable) The fill color of startup project.
var default_fill_color := Color(0, 0, 0, 0)
## (Preference Variable) The distance to the guide or grig below which cursor snapping activates.
var snapping_distance := 32.0
## (Preference Variable) The grid type defined by [enum GridTypes] enum.
var grid_type := GridTypes.CARTESIAN:
	set(value):
		grid_type = value
		canvas.grid.queue_redraw()
## (Preference Variable) The size of rectangular grid.
var grid_size := Vector2i(2, 2):
	set(value):
		grid_size = value
		canvas.grid.queue_redraw()
## (Preference Variable) The size of isometric grid.
var isometric_grid_size := Vector2i(16, 8):
	set(value):
		isometric_grid_size = value
		canvas.grid.queue_redraw()
## (Preference Variable) The grid offset from top-left corner of the canvas.
var grid_offset := Vector2i.ZERO:
	set(value):
		grid_offset = value
		canvas.grid.queue_redraw()
## (Preference Variable) If [code]true[/code], The grid draws over the area extended by
## tile-mode as well.
var grid_draw_over_tile_mode := false:
	set(value):
		grid_draw_over_tile_mode = value
		canvas.grid.queue_redraw()
## (Preference Variable) The color of grid.
var grid_color := Color.BLACK:
	set(value):
		grid_color = value
		canvas.grid.queue_redraw()
## (Preference Variable) The minimum zoom after which pixel grid gets drawn if enabled.
var pixel_grid_show_at_zoom := 1500.0:  # percentage
	set(value):
		pixel_grid_show_at_zoom = value
		canvas.pixel_grid.queue_redraw()
## (Preference Variable) The color of pixel grid.
var pixel_grid_color := Color("21212191"):
	set(value):
		pixel_grid_color = value
		canvas.pixel_grid.queue_redraw()
## (Preference Variable) The color of guides.
var guide_color := Color.PURPLE:
	set(value):
		guide_color = value
		for guide in canvas.get_children():
			if guide is Guide:
				guide.set_color(guide_color)
## (Preference Variable) The size of checkers in the checker background.
var checker_size := 10:
	set(value):
		checker_size = value
		transparent_checker.update_rect()
## (Preference Variable) The color of first checker.
var checker_color_1 := Color(0.47, 0.47, 0.47, 1):
	set(value):
		checker_color_1 = value
		transparent_checker.update_rect()
## (Preference Variable) The color of second checker.
var checker_color_2 := Color(0.34, 0.35, 0.34, 1):
	set(value):
		checker_color_2 = value
		transparent_checker.update_rect()
## (Preference Variable) The color of second checker.
var checker_follow_movement := false:
	set(value):
		checker_follow_movement = value
		transparent_checker.update_rect()
## (Preference Variable) If [code]true[/code], the checker follows zoom.
var checker_follow_scale := false:
	set(value):
		checker_follow_scale = value
		transparent_checker.update_rect()
## (Preference Variable) Opacity of the sprites rendered on the extended area of tile-mode.
var tilemode_opacity := 1.0:
	set(value):
		tilemode_opacity = value
		canvas.tile_mode.queue_redraw()

## (Preference Variable) If [code]true[/code], layers get selected when their buttons are pressed.
var select_layer_on_button_click := false
## (Preference Variable) The onion color of past frames.
var onion_skinning_past_color := Color.RED:
	set(value):
		onion_skinning_past_color = value
		canvas.onion_past.blue_red_color = value
		canvas.onion_past.queue_redraw()
## (Preference Variable) The onion color of future frames.
var onion_skinning_future_color := Color.BLUE:
	set(value):
		onion_skinning_future_color = value
		canvas.onion_future.blue_red_color = value
		canvas.onion_future.queue_redraw()

## (Preference Variable) If [code]true[/code], the selection rect has animated borders.
var selection_animated_borders := true:
	set(value):
		selection_animated_borders = value
		var marching_ants: Sprite2D = canvas.selection.marching_ants_outline
		marching_ants.material.set_shader_parameter("animated", selection_animated_borders)
## (Preference Variable) The first color of border.
var selection_border_color_1 := Color.WHITE:
	set(value):
		selection_border_color_1 = value
		var marching_ants: Sprite2D = canvas.selection.marching_ants_outline
		marching_ants.material.set_shader_parameter("first_color", selection_border_color_1)
		canvas.selection.queue_redraw()
## (Preference Variable) The second color of border.
var selection_border_color_2 := Color.BLACK:
	set(value):
		selection_border_color_2 = value
		var marching_ants: Sprite2D = canvas.selection.marching_ants_outline
		marching_ants.material.set_shader_parameter("second_color", selection_border_color_2)
		canvas.selection.queue_redraw()

## (Preference Variable) If [code]true[/code], Pixelorama pauses when unfocused to save cpu usage.
var pause_when_unfocused := true
## (Preference Variable) The max fps, Pixelorama is allowed to use (does not limit fps if it is 0).
var fps_limit := 0:
	set(value):
		fps_limit = value
		Engine.max_fps = fps_limit

## (Preference Variable) The time (in minutes) after which backup is created (if enabled).
var autosave_interval := 1.0:
	set(value):
		autosave_interval = value
		OpenSave.update_autosave()
## (Preference Variable) If [code]true[/code], generation of backups get enabled.
var enable_autosave := true:
	set(value):
		enable_autosave = value
		OpenSave.update_autosave()
		preferences_dialog.autosave_interval.editable = enable_autosave
## (Preference Variable) The index of graphics renderer used by Pixelorama.
var renderer := 0:
	set = _renderer_changed
## (Preference Variable) The index of tablet driver used by Pixelorama.
var tablet_driver := 0:
	set(value):
		tablet_driver = value
		if OS.has_feature("editor"):
			return
		var tablet_driver_name := DisplayServer.tablet_get_current_driver()
		ProjectSettings.set_setting("display/window/tablet_driver", tablet_driver_name)
		ProjectSettings.save_custom(OVERRIDE_FILE)

# Tools & options
## (Preference Variable) If [code]true[/code], the cursor's left tool icon is visible.
var show_left_tool_icon := true
## (Preference Variable) If [code]true[/code], the cursor's right tool icon is visible.
var show_right_tool_icon := true
## (Preference Variable) If [code]true[/code], the left tool's brush indicator is visible.
var left_square_indicator_visible := true
## (Preference Variable) If [code]true[/code], the right tool's brush indicator is visible.
var right_square_indicator_visible := true
## (Preference Variable) If [code]true[/code], native cursors are used instead of default cursors.
var native_cursors := false:
	set(value):
		native_cursors = value
		if native_cursors:
			Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS, Vector2(15, 15))
		else:
			control.set_custom_cursor()
## (Preference Variable) If [code]true[/code], cursor becomes cross shaped when hovering the canvas.
var cross_cursor := true:
	set(value):
		cross_cursor = value
		if cross_cursor:
			main_viewport.mouse_default_cursor_shape = Control.CURSOR_CROSS
		else:
			main_viewport.mouse_default_cursor_shape = Control.CURSOR_ARROW

# View menu options
## If [code]true[/code], the canvas is in greyscale.
var greyscale_view := false
## If [code]true[/code], the content of canvas is flipped.
var mirror_view := false
## If [code]true[/code], the grid is visible.
var draw_grid := false
## If [code]true[/code], the pixel grid is visible.
var draw_pixel_grid := false
## If [code]true[/code], the rulers are visible.
var show_rulers := true
## If [code]true[/code], the guides are visible.
var show_guides := true
## If [code]true[/code], the mouse guides are visible.
var show_mouse_guides := false
## If [code]true[/code], cursor snaps to the boundary of rectangular grid boxes.
var snap_to_rectangular_grid_boundary := false
## If [code]true[/code], cursor snaps to the center of rectangular grid boxes.
var snap_to_rectangular_grid_center := false
## If [code]true[/code], cursor snaps to regular guides.
var snap_to_guides := false
## If [code]true[/code], cursor snaps to perspective guides.
var snap_to_perspective_guides := false

# Onion skinning options
var onion_skinning := false  ## If [code]true[/code], onion skinning is enabled.
var onion_skinning_past_rate := 1  ## Number of past frames shown when onion skinning is enabled.
## Number of future frames shown when onion skinning is enabled.
var onion_skinning_future_rate := 1
var onion_skinning_blue_red := false  ## If [code]true[/code], then blue-red mode is enabled.

## The current version of pixelorama
var current_version: String = ProjectSettings.get_setting("application/config/Version")

# Nodes
## The preload of button used by the [BaseLayer].
var base_layer_button_node: PackedScene = load("res://src/UI/Timeline/BaseLayerButton.tscn")
## The preload of button used by the [PixelLayer].
var pixel_layer_button_node: PackedScene = load("res://src/UI/Timeline/PixelLayerButton.tscn")
## The preload of button used by the [GroupLayer].
var group_layer_button_node: PackedScene = load("res://src/UI/Timeline/GroupLayerButton.tscn")
## The preload of button used by the [PixelCel].
var pixel_cel_button_node: PackedScene = load("res://src/UI/Timeline/PixelCelButton.tscn")
## The preload of button used by the [GroupCel].
var group_cel_button_node: PackedScene = load("res://src/UI/Timeline/GroupCelButton.tscn")
## The preload of button used by the [Cel3D].
var cel_3d_button_node: PackedScene = load("res://src/UI/Timeline/Cel3DButton.tscn")

@onready var main_window := get_window()  ## The main Pixelorama [Window].
## The control node (aka Main node). It has the [param Main.gd] script attached.
@onready var control := get_tree().current_scene

## The main canvas node. It has the [param Canvas.gd] script attached.
@onready var canvas: Canvas = control.find_child("Canvas")
## The project tabs bar. It has the [param Tabs.gd] script attached.
@onready var tabs: TabBar = control.find_child("TabBar")
## The viewport of the main canvas. It has the [param ViewportContainer.gd] script attached.
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


func _init() -> void:
	if OS.has_feature("template"):
		root_directory = OS.get_executable_path().get_base_dir()
	data_directories.append(root_directory.path_join(CONFIG_SUBDIR_NAME))
	if OS.get_name() in ["Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		# Checks the list of files var, and processes them.
		if OS.has_environment("XDG_DATA_DIRS"):
			var raw_env_var := OS.get_environment("XDG_DATA_DIRS")  # includes empties.
			var unappended_subdirs := raw_env_var.split(":", true)
			for unapp_subdir in unappended_subdirs:
				data_directories.append(unapp_subdir.path_join(HOME_SUBDIR_NAME))
		else:
			# Create defaults
			for default_loc in ["/usr/local/share", "/usr/share"]:
				data_directories.append(default_loc.path_join(HOME_SUBDIR_NAME))
	if ProjectSettings.get_setting("display/window/tablet_driver") == "winink":
		tablet_driver = 1


func _ready() -> void:
	_initialize_keychain()
	# Load settings from the config file
	config_cache.load("user://cache.ini")

	default_width = config_cache.get_value("preferences", "default_width", default_width)
	default_height = config_cache.get_value("preferences", "default_height", default_height)
	default_fill_color = config_cache.get_value(
		"preferences", "default_fill_color", default_fill_color
	)
	var proj_size := Vector2i(default_width, default_height)
	projects.append(Project.new([], tr("untitled"), proj_size))
	current_project = projects[0]
	current_project.fill_color = default_fill_color

	await get_tree().process_frame
	project_changed.emit()


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
		"reset_colors_default": Keychain.InputAction.new("", "Buttons"),
		"switch_colors": Keychain.InputAction.new("", "Buttons"),
		"horizontal_mirror": Keychain.InputAction.new("", "Buttons"),
		"vertical_mirror": Keychain.InputAction.new("", "Buttons"),
		"pixel_perfect": Keychain.InputAction.new("", "Buttons"),
		"new_layer": Keychain.InputAction.new("", "Buttons"),
		"remove_layer": Keychain.InputAction.new("", "Buttons"),
		"move_layer_up": Keychain.InputAction.new("", "Buttons"),
		"move_layer_down": Keychain.InputAction.new("", "Buttons"),
		"clone_layer": Keychain.InputAction.new("", "Buttons"),
		"merge_down_layer": Keychain.InputAction.new("", "Buttons"),
		"add_frame": Keychain.InputAction.new("", "Buttons"),
		"remove_frame": Keychain.InputAction.new("", "Buttons"),
		"clone_frame": Keychain.InputAction.new("", "Buttons"),
		"manage_frame_tags": Keychain.InputAction.new("", "Buttons"),
		"move_frame_left": Keychain.InputAction.new("", "Buttons"),
		"move_frame_right": Keychain.InputAction.new("", "Buttons"),
		"go_to_first_frame": Keychain.InputAction.new("", "Buttons"),
		"go_to_last_frame": Keychain.InputAction.new("", "Buttons"),
		"go_to_previous_frame": Keychain.InputAction.new("", "Buttons"),
		"go_to_next_frame": Keychain.InputAction.new("", "Buttons"),
		"play_backwards": Keychain.InputAction.new("", "Buttons"),
		"play_forward": Keychain.InputAction.new("", "Buttons"),
		"onion_skinning_toggle": Keychain.InputAction.new("", "Buttons"),
		"loop_toggle": Keychain.InputAction.new("", "Buttons"),
		"onion_skinning_settings": Keychain.InputAction.new("", "Buttons"),
		"new_palette": Keychain.InputAction.new("", "Buttons"),
		"edit_palette": Keychain.InputAction.new("", "Buttons"),
		"brush_size_increment": Keychain.InputAction.new("", "Buttons"),
		"brush_size_decrement": Keychain.InputAction.new("", "Buttons"),
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


func general_undo(project := current_project) -> void:
	project.undos -= 1
	var action_name := project.undo_redo.get_current_action_name()
	notification_label("Undo: %s" % action_name)


func general_redo(project := current_project) -> void:
	if project.undos < project.undo_redo.get_version():  # If we did undo and then redo
		project.undos = project.undo_redo.get_version()
	if control.redone:
		var action_name := project.undo_redo.get_current_action_name()
		notification_label("Redo: %s" % action_name)


func undo_or_redo(
	undo: bool, frame_index := -1, layer_index := -1, project := current_project
) -> void:
	if undo:
		general_undo(project)
	else:
		general_redo(project)
	var action_name := project.undo_redo.get_current_action_name()
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
					var current_cel := project.frames[i].cels[j]
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

	await RenderingServer.frame_post_draw
	canvas.queue_redraw()
	second_viewport.get_child(0).get_node("CanvasPreview").queue_redraw()
	canvas_preview_container.canvas_preview.queue_redraw()
	if !project.has_changed:
		project.has_changed = true
		if project == current_project:
			main_window.title = main_window.title + "(*)"


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


func path_join_array(basepaths: PackedStringArray, subpath: String) -> PackedStringArray:
	var res := PackedStringArray()
	for _path in basepaths:
		res.append(_path.path_join(subpath))
	return res


func undo_redo_draw_op(
	image: Image, compressed_image_data: PackedByteArray, buffer_size: int
) -> void:
	image.set_data(
		image.get_width(),
		image.get_height(),
		image.has_mipmaps(),
		image.get_format(),
		compressed_image_data.decompress(buffer_size)
	)
