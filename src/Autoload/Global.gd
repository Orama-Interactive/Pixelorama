extends Node


enum GridTypes {CARTESIAN, ISOMETRIC, ALL}
enum PressureSensitivity {NONE, ALPHA, SIZE, ALPHA_AND_SIZE}
enum Direction {UP, DOWN, LEFT, RIGHT}
enum ThemeTypes {DARK, BLUE, CARAMEL, LIGHT}
enum TileMode {NONE, BOTH, X_AXIS, Y_AXIS}
enum PanelLayout {AUTO, WIDESCREEN, TALLSCREEN}
enum IconColorFrom {THEME, CUSTOM}
enum ButtonSize {SMALL, BIG}

var root_directory := "."
var window_title := "" setget title_changed # Why doesn't Godot have get_window_title()?
var config_cache := ConfigFile.new()
var XDGDataPaths = preload("res://src/XDGDataPaths.gd")
var directory_module : Reference

var projects := [] # Array of Projects
var current_project : Project
var current_project_index := 0 setget project_changed

var recent_projects := []
var panel_layout = PanelLayout.AUTO

# Indices are as in the Direction enum
# This is the total time the key for
# that direction has been pressed.
var key_move_press_time := [0.0, 0.0, 0.0, 0.0]

# Canvas related stuff
var layers_changed_skip := false
var can_draw := false
var has_focus := false
var cursor_image = preload("res://assets/graphics/cursor.png")
var left_cursor_tool_texture := StreamTexture.new()
var right_cursor_tool_texture := StreamTexture.new()

var image_clipboard : Image
var play_only_tags := true
var show_x_symmetry_axis := false
var show_y_symmetry_axis := false
var default_clear_color := Color.gray

# Preferences
var pressure_sensitivity_mode = PressureSensitivity.NONE
var open_last_project := false
var smooth_zoom := true

var shrink := 1.0
var dim_on_popup := true
var theme_type : int = ThemeTypes.DARK
var modulate_icon_color := Color.gray
var icon_color_from : int = IconColorFrom.THEME
var custom_icon_color := Color.gray
var tool_button_size : int = ButtonSize.SMALL

var default_image_width := 64
var default_image_height := 64
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
var pixel_grid_show_at_zoom := 1500.0 # percentage
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

var fps_limit_focus := true
var fps_limit := 0
var idle_fps := 1

var autosave_interval := 1.0
var enable_autosave := true

# Tools & options
var show_left_tool_icon := true
var show_right_tool_icon := true
var left_square_indicator_visible := true
var right_square_indicator_visible := false

# View menu options
var mirror_view := false
var draw_grid := false
var draw_pixel_grid := false
var show_rulers := true
var show_guides := true
var show_animation_timeline := true

# Onion skinning options
var onion_skinning := false
var onion_skinning_past_rate := 1.0
var onion_skinning_future_rate := 1.0
var onion_skinning_blue_red := false

# Palettes
var palettes := {}

# Nodes
var notification_label_node = preload("res://src/UI/NotificationLabel.tscn")

onready var root : Node = get_tree().get_root()
onready var control : Node = root.get_node("Control")
onready var top_menu_container : Panel = control.find_node("TopMenuContainer")
onready var left_cursor : Sprite = control.find_node("LeftCursor")
onready var right_cursor : Sprite = control.find_node("RightCursor")
onready var canvas : Canvas = control.find_node("Canvas")
onready var tabs : Tabs = control.find_node("Tabs")
onready var main_viewport : ViewportContainer = control.find_node("ViewportContainer")
onready var second_viewport : ViewportContainer = control.find_node("ViewportContainer2")
onready var canvas_preview_container : Container = control.find_node("CanvasPreviewContainer")
onready var small_preview_viewport : ViewportContainer = canvas_preview_container.find_node("PreviewViewportContainer")
onready var camera : Camera2D = main_viewport.find_node("Camera2D")
onready var camera2 : Camera2D = control.find_node("Camera2D2")
onready var camera_preview : Camera2D = control.find_node("CameraPreview")
onready var horizontal_ruler : BaseButton = control.find_node("HorizontalRuler")
onready var vertical_ruler : BaseButton = control.find_node("VerticalRuler")
onready var transparent_checker : ColorRect = control.find_node("TransparentChecker")

onready var rotation_level_button : Button = control.find_node("RotationLevel")
onready var rotation_level_spinbox : SpinBox = control.find_node("RotationSpinbox")
onready var zoom_level_button : Button = control.find_node("ZoomLevel")
onready var zoom_level_spinbox : SpinBox = control.find_node("ZoomSpinbox")
onready var cursor_position_label : Label = control.find_node("CursorPosition")

onready var tool_panel : Panel = control.find_node("ToolPanel")
onready var right_panel : Panel = control.find_node("RightPanel")
onready var tabs_container : PanelContainer = control.find_node("TabsContainer")

onready var recent_projects_submenu : PopupMenu = PopupMenu.new()
onready var tile_mode_submenu : PopupMenu = PopupMenu.new()
onready var window_transparency_submenu : PopupMenu = PopupMenu.new()
onready var panel_layout_submenu : PopupMenu = PopupMenu.new()

onready var new_image_dialog : ConfirmationDialog = control.find_node("CreateNewImage")
onready var open_sprites_dialog : FileDialog = control.find_node("OpenSprite")
onready var save_sprites_dialog : FileDialog = control.find_node("SaveSprite")
onready var save_sprites_html5_dialog : ConfirmationDialog = control.find_node("SaveSpriteHTML5")
onready var export_dialog : AcceptDialog = control.find_node("ExportDialog")
onready var preferences_dialog : AcceptDialog = control.find_node("PreferencesDialog")
onready var unsaved_changes_dialog : ConfirmationDialog = control.find_node("UnsavedCanvasDialog")

onready var color_switch_button : BaseButton = control.find_node("ColorSwitch")

onready var brushes_popup : Popup = control.find_node("BrushesPopup")
onready var patterns_popup : Popup = control.find_node("PatternsPopup")

onready var animation_timeline : Panel = control.find_node("AnimationTimeline")

onready var animation_timer : Timer = animation_timeline.find_node("AnimationTimer")
onready var frame_properties : ConfirmationDialog = control.find_node("FrameProperties")
onready var frame_ids : HBoxContainer = animation_timeline.find_node("FrameIDs")
onready var current_frame_mark_label : Label = control.find_node("CurrentFrameMark")
onready var onion_skinning_button : BaseButton = animation_timeline.find_node("OnionSkinning")
onready var loop_animation_button : BaseButton = animation_timeline.find_node("LoopAnim")
onready var play_forward : BaseButton = animation_timeline.find_node("PlayForward")
onready var play_backwards : BaseButton = animation_timeline.find_node("PlayBackwards")
onready var layers_container : VBoxContainer = animation_timeline.find_node("LayersContainer")
onready var frames_container : VBoxContainer = animation_timeline.find_node("FramesContainer")
onready var tag_container : Control = animation_timeline.find_node("TagContainer")
onready var tag_dialog : AcceptDialog = animation_timeline.find_node("FrameTagDialog")

onready var remove_frame_button : BaseButton = animation_timeline.find_node("DeleteFrame")
onready var move_left_frame_button : BaseButton = animation_timeline.find_node("MoveLeft")
onready var move_right_frame_button : BaseButton = animation_timeline.find_node("MoveRight")

onready var remove_layer_button : BaseButton = animation_timeline.find_node("RemoveLayer")
onready var move_up_layer_button : BaseButton = animation_timeline.find_node("MoveUpLayer")
onready var move_down_layer_button : BaseButton = animation_timeline.find_node("MoveDownLayer")
onready var merge_down_layer_button : BaseButton = animation_timeline.find_node("MergeDownLayer")
onready var layer_opacity_slider : HSlider = animation_timeline.find_node("OpacitySlider")
onready var layer_opacity_spinbox : SpinBox = animation_timeline.find_node("OpacitySpinBox")

onready var preview_zoom_slider : VSlider = control.find_node("PreviewZoomSlider")
onready var palette_panel : PalettePanel = control.find_node("PalettePanel")

onready var error_dialog : AcceptDialog = control.find_node("ErrorDialog")
onready var quit_dialog : ConfirmationDialog = control.find_node("QuitDialog")
onready var quit_and_save_dialog : ConfirmationDialog = control.find_node("QuitAndSaveDialog")

onready var current_version : String = ProjectSettings.get_setting("application/config/Version")


func _ready() -> void:
	randomize()
	if OS.get_name() == "OSX":
		use_osx_shortcuts()
	if OS.has_feature("standalone"):
		root_directory = OS.get_executable_path().get_base_dir()
	# Load settings from the config file
	config_cache.load("user://cache.ini")

	recent_projects = config_cache.get_value("data", "recent_projects", [])
	panel_layout = config_cache.get_value("window", "panel_layout", PanelLayout.AUTO)

	# The fact that root_dir is set earlier than this is important
	# XDGDataDirs depends on it nyaa
	directory_module = XDGDataPaths.new()
	image_clipboard = Image.new()
	Input.set_custom_mouse_cursor(cursor_image, Input.CURSOR_CROSS, Vector2(15, 15))

	recent_projects_submenu.set_name("recent_projects_submenu")

	tile_mode_submenu.set_name("tile_mode_submenu")
	tile_mode_submenu.add_radio_check_item("None", TileMode.NONE)
	tile_mode_submenu.set_item_checked(TileMode.NONE, true)
	tile_mode_submenu.add_radio_check_item("Tiled In Both Axis", TileMode.BOTH)
	tile_mode_submenu.add_radio_check_item("Tiled In X Axis", TileMode.X_AXIS)
	tile_mode_submenu.add_radio_check_item("Tiled In Y Axis", TileMode.Y_AXIS)
	tile_mode_submenu.hide_on_checkable_item_selection = false

	window_transparency_submenu.set_name("set value")
	window_transparency_submenu.add_radio_check_item("100%")
	window_transparency_submenu.add_radio_check_item("90%")
	window_transparency_submenu.add_radio_check_item("80%")
	window_transparency_submenu.add_radio_check_item("70%")
	window_transparency_submenu.add_radio_check_item("60%")
	window_transparency_submenu.add_radio_check_item("50%")
	window_transparency_submenu.add_radio_check_item("40%")
	window_transparency_submenu.add_radio_check_item("30%")
	window_transparency_submenu.add_radio_check_item("20%")
	window_transparency_submenu.add_radio_check_item("10%")
	window_transparency_submenu.add_radio_check_item("0%")
	window_transparency_submenu.set_item_checked(10, true)
	window_transparency_submenu.hide_on_checkable_item_selection = false

	panel_layout_submenu.set_name("panel_layout_submenu")
	panel_layout_submenu.add_radio_check_item("Auto", PanelLayout.AUTO)
	panel_layout_submenu.add_radio_check_item("Widescreen", PanelLayout.WIDESCREEN)
	panel_layout_submenu.add_radio_check_item("Tallscreen", PanelLayout.TALLSCREEN)
	panel_layout_submenu.hide_on_checkable_item_selection = false
	panel_layout_submenu.set_item_checked(panel_layout, true)

	projects.append(Project.new())
	projects[0].layers.append(Layer.new())
	current_project = projects[0]


func notification_label(text : String) -> void:
	var notification : Label = notification_label_node.instance()
	notification.text = tr(text)
	notification.rect_position = Vector2(70, animation_timeline.rect_position.y)
	notification.theme = control.theme
	get_tree().get_root().add_child(notification)


func general_undo(project : Project = current_project) -> void:
	project.undos -= 1
	var action_name : String = project.undo_redo.get_current_action_name()
	notification_label("Undo: %s" % action_name)


func general_redo(project : Project = current_project) -> void:
	if project.undos < project.undo_redo.get_version(): # If we did undo and then redo
		project.undos = project.undo_redo.get_version()
	if control.redone:
		var action_name : String = project.undo_redo.get_current_action_name()
		notification_label("Redo: %s" % action_name)


func undo(_frame_index := -1, _layer_index := -1, project : Project = current_project) -> void:
	general_undo(project)
	var action_name : String = project.undo_redo.get_current_action_name()
	if action_name == "Draw" or action_name == "Draw Shape" or action_name == "Rectangle Select" or action_name == "Move Selection" or action_name == "Scale" or action_name == "Centralize" or action_name == "Merge Layer" or action_name == "Link Cel" or action_name == "Unlink Cel":
		if _layer_index > -1 and _frame_index > -1:
			canvas.update_texture(_layer_index, _frame_index, project)
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
		if project.frames.size() == 2: # Stop animating
			play_forward.pressed = false
			play_backwards.pressed = false
			animation_timer.stop()

	elif "Move Cels" == action_name:
		project.frames = project.frames # to call frames_changed

	canvas.update()
	if !project.has_changed:
		project.has_changed = true
		if project == current_project:
			self.window_title = window_title + "(*)"


func redo(_frame_index := -1, _layer_index := -1, project : Project = current_project) -> void:
	general_redo(project)
	var action_name : String = project.undo_redo.get_current_action_name()
	if action_name == "Draw" or action_name == "Draw Shape" or action_name == "Rectangle Select" or action_name == "Move Selection" or action_name == "Scale" or action_name == "Centralize" or action_name == "Merge Layer" or action_name == "Link Cel" or action_name == "Unlink Cel":
		if _layer_index > -1 and _frame_index > -1:
			canvas.update_texture(_layer_index, _frame_index, project)
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
		if project.frames.size() == 1: # Stop animating
			play_forward.pressed = false
			play_backwards.pressed = false
			animation_timer.stop()

	elif "Move Cels" == action_name:
		project.frames = project.frames # to call frames_changed

	canvas.update()
	if !project.has_changed:
		project.has_changed = true
		if project == current_project:
			self.window_title = window_title + "(*)"


func title_changed(value : String) -> void:
	window_title = value
	OS.set_window_title(value)


func project_changed(value : int) -> void:
	canvas.selection.transform_content_confirm()
	current_project_index = value
	current_project = projects[value]
	current_project.change_project()


func dialog_open(open : bool) -> void:
	if open:
		can_draw = false
		if dim_on_popup:
			control.get_node("ModulateTween").interpolate_property(control, "modulate", control.modulate, Color(0.5, 0.5, 0.5), 0.1, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	else:
		can_draw = true
		control.get_node("ModulateTween").interpolate_property(control, "modulate", control.modulate, Color.white, 0.1, Tween.TRANS_LINEAR, Tween.EASE_OUT)

	control.get_node("ModulateTween").start()


func disable_button(button : BaseButton, disable : bool) -> void:
	button.disabled = disable
	if disable:
		button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	else:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if button is Button:
		for c in button.get_children():
			if c is TextureRect:
				if disable:
					c.modulate.a = 0.5
				else:
					c.modulate.a = 1
				break


func change_button_texturerect(texture_button : TextureRect, new_file_name : String) -> void:
	var file_name := texture_button.texture.resource_path.get_basename().get_file()
	var directory_path := texture_button.texture.resource_path.get_basename().replace(file_name, "")
	texture_button.texture = load(directory_path.plus_file(new_file_name))


func update_hint_tooltips() -> void:
	var tool_buttons = control.find_node("ToolButtons")

	var rect_select : BaseButton = tool_buttons.find_node("RectSelect")
	rect_select.hint_tooltip = tr("""Rectangular Selection

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_rectangle_select_tool")[0].as_text(), InputMap.get_action_list("right_rectangle_select_tool")[0].as_text()]

	var ellipse_select : BaseButton = tool_buttons.find_node("EllipseSelect")
	ellipse_select.hint_tooltip = tr("""Elliptical Selection

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_ellipse_select_tool")[0].as_text(), InputMap.get_action_list("right_ellipse_select_tool")[0].as_text()]


	var polygon_select : BaseButton = tool_buttons.find_node("PolygonSelect")
	polygon_select.hint_tooltip = tr("""Polygonal Selection
Double-click to connect the last point to the starting point

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_polygon_select_tool")[0].as_text(), InputMap.get_action_list("right_polygon_select_tool")[0].as_text()]


	var color_select : BaseButton = tool_buttons.find_node("ColorSelect")
	color_select.hint_tooltip = tr("""Select By Color

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_color_select_tool")[0].as_text(), InputMap.get_action_list("right_color_select_tool")[0].as_text()]


	var magic_wand : BaseButton = tool_buttons.find_node("MagicWand")
	magic_wand.hint_tooltip = tr("""Magic Wand

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_magic_wand_tool")[0].as_text(), InputMap.get_action_list("right_magic_wand_tool")[0].as_text()]


	var lasso : BaseButton = tool_buttons.find_node("Lasso")
	lasso.hint_tooltip = tr("""Lasso / Free Select Tool

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_lasso_tool")[0].as_text(), InputMap.get_action_list("right_lasso_tool")[0].as_text()]


	var move_select : BaseButton = tool_buttons.find_node("Move")
	move_select.hint_tooltip = tr("""Move

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_move_tool")[0].as_text(), InputMap.get_action_list("right_move_tool")[0].as_text()]


	var zoom_tool : BaseButton = tool_buttons.find_node("Zoom")
	zoom_tool.hint_tooltip = tr("""Zoom

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_zoom_tool")[0].as_text(), InputMap.get_action_list("right_zoom_tool")[0].as_text()]

	var pan_tool : BaseButton = tool_buttons.find_node("Pan")
	pan_tool.hint_tooltip = tr("""Pan

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_pan_tool")[0].as_text(), InputMap.get_action_list("right_pan_tool")[0].as_text()]

	var color_picker : BaseButton = tool_buttons.find_node("ColorPicker")
	color_picker.hint_tooltip = tr("""Color Picker
Select a color from a pixel of the sprite

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_colorpicker_tool")[0].as_text(), InputMap.get_action_list("right_colorpicker_tool")[0].as_text()]

	var pencil : BaseButton = tool_buttons.find_node("Pencil")
	pencil.hint_tooltip = tr("""Pencil

%s for left mouse button
%s for right mouse button

Hold %s to make a line""") % [InputMap.get_action_list("left_pencil_tool")[0].as_text(), InputMap.get_action_list("right_pencil_tool")[0].as_text(), "Shift"]

	var eraser : BaseButton = tool_buttons.find_node("Eraser")
	eraser.hint_tooltip = tr("""Eraser

%s for left mouse button
%s for right mouse button

Hold %s to make a line""") % [InputMap.get_action_list("left_eraser_tool")[0].as_text(), InputMap.get_action_list("right_eraser_tool")[0].as_text(), "Shift"]

	var bucket : BaseButton = tool_buttons.find_node("Bucket")
	bucket.hint_tooltip = tr("""Bucket

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_fill_tool")[0].as_text(), InputMap.get_action_list("right_fill_tool")[0].as_text()]

	var ld : BaseButton = tool_buttons.find_node("Shading")
	ld.hint_tooltip = tr("""Shading Tool

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_shading_tool")[0].as_text(), InputMap.get_action_list("right_shading_tool")[0].as_text()]

	var linetool : BaseButton = tool_buttons.find_node("LineTool")
	linetool.hint_tooltip = tr("""Line Tool

%s for left mouse button
%s for right mouse button

Hold %s to snap the angle of the line
Hold %s to center the shape on the click origin
Hold %s to displace the shape's origin""") % [InputMap.get_action_list("left_linetool_tool")[0].as_text(), InputMap.get_action_list("right_linetool_tool")[0].as_text(), "Shift", "Ctrl", "Alt"]

	var recttool : BaseButton = tool_buttons.find_node("RectangleTool")
	recttool.hint_tooltip = tr("""Rectangle Tool

%s for left mouse button
%s for right mouse button

Hold %s to create a 1:1 shape
Hold %s to center the shape on the click origin
Hold %s to displace the shape's origin""") % [InputMap.get_action_list("left_rectangletool_tool")[0].as_text(), InputMap.get_action_list("right_rectangletool_tool")[0].as_text(), "Shift", "Ctrl", "Alt"]

	var ellipsetool : BaseButton = tool_buttons.find_node("EllipseTool")
	ellipsetool.hint_tooltip = tr("""Ellipse Tool

%s for left mouse button
%s for right mouse button

Hold %s to create a 1:1 shape
Hold %s to center the shape on the click origin
Hold %s to displace the shape's origin""") % [InputMap.get_action_list("left_ellipsetool_tool")[0].as_text(), InputMap.get_action_list("right_ellipsetool_tool")[0].as_text(), "Shift", "Ctrl", "Alt"]

	var color_switch : BaseButton = control.find_node("ColorSwitch")
	color_switch.hint_tooltip = tr("""Switch left and right colors
(%s)""") % InputMap.get_action_list("switch_colors")[0].as_text()

	var first_frame : BaseButton = control.find_node("FirstFrame")
	first_frame.hint_tooltip = tr("""Jump to the first frame
(%s)""") % InputMap.get_action_list("go_to_first_frame")[0].as_text()

	var previous_frame : BaseButton = control.find_node("PreviousFrame")
	previous_frame.hint_tooltip = tr("""Go to the previous frame
(%s)""") % InputMap.get_action_list("go_to_previous_frame")[0].as_text()

	play_backwards.hint_tooltip = tr("""Play the animation backwards (from end to beginning)
(%s)""") % InputMap.get_action_list("play_backwards")[0].as_text()

	play_forward.hint_tooltip = tr("""Play the animation forward (from beginning to end)
(%s)""") % InputMap.get_action_list("play_forward")[0].as_text()

	var next_frame : BaseButton = control.find_node("NextFrame")
	next_frame.hint_tooltip = tr("""Go to the next frame
(%s)""") % InputMap.get_action_list("go_to_next_frame")[0].as_text()

	var last_frame : BaseButton = control.find_node("LastFrame")
	last_frame.hint_tooltip = tr("""Jump to the last frame
(%s)""") % InputMap.get_action_list("go_to_last_frame")[0].as_text()


func is_cjk(locale : String) -> bool:
	return "zh" in locale or "ko" in locale or "ja" in locale


func _exit_tree() -> void:
	config_cache.set_value("window", "panel_layout", panel_layout)
	config_cache.set_value("window", "screen", OS.current_screen)
	config_cache.set_value("window", "maximized", OS.window_maximized || OS.window_fullscreen)
	config_cache.set_value("window", "position", OS.window_position)
	config_cache.set_value("window", "size", OS.window_size)
	config_cache.save("user://cache.ini")

	var i := 0
	for project in projects:
		project.undo_redo.free()
		OpenSave.remove_backup(i)
		i += 1


func save_project_to_recent_list(path : String) -> void:
	if path.get_file().substr(0, 7) == "backup-" or path == "":
		return

	if recent_projects.has(path):
		return

	if recent_projects.size() >= 5:
		recent_projects.pop_front()
	recent_projects.push_back(path)

	config_cache.set_value("data", "recent_projects", recent_projects)

	recent_projects_submenu.clear()
	update_recent_projects_submenu()


func update_recent_projects_submenu() -> void:
	for project in recent_projects:
		recent_projects_submenu.add_item(project.get_file())


func use_osx_shortcuts() -> void:
	var inputmap := InputMap

	for action in inputmap.get_actions():
		var event : InputEvent = inputmap.get_action_list(action)[0]

		if event.is_action("show_pixel_grid"):
			event.shift = true

		if event.control:
			event.control = false
			event.command = true
