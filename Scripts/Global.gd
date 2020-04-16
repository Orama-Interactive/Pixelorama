extends Node

enum Grid_Types {CARTESIAN, ISOMETRIC, ALL}
enum Pressure_Sensitivity {NONE, ALPHA, SIZE, ALPHA_AND_SIZE}
enum Brush_Types {PIXEL, CIRCLE, FILLED_CIRCLE, FILE, RANDOM_FILE, CUSTOM}

var root_directory := "."
var window_title := "" setget title_changed # Why doesn't Godot have get_window_title()?
var config_cache := ConfigFile.new()
var XDGDataPaths = preload("res://Scripts/XDGDataPaths.gd")
var directory_module : Node

# Stuff for arrowkey-based canvas movements nyaa ^.^
const low_speed_move_rate := 150.0
const medium_speed_move_rate := 750.0
const high_speed_move_rate := 3750.0

enum Direction {
	UP = 0,
	DOWN = 1,
	LEFT = 2,
	RIGHT = 3
}

# Indices are as in the Direction enum
# This is the total time the key for
# that direction has been pressed.
var key_move_press_time := [0.0, 0.0, 0.0, 0.0]


# warning-ignore:unused_class_variable
var loaded_locales : Array
var undo_redo : UndoRedo
var undos := 0 # The number of times we added undo properties
var saved := true # Checks if the user has saved

# Canvas related stuff
var canvases := [] setget canvases_changed
var layers := [] setget layers_changed
var layers_changed_skip := false
var current_frame := 0 setget frame_changed
var current_layer := 0 setget layer_changed
# warning-ignore:unused_class_variable
var can_draw := false
# warning-ignore:unused_class_variable
var has_focus := false
# warning-ignore:unused_class_variable
var hidden_canvases := []
var pressure_sensitivity_mode = Pressure_Sensitivity.NONE
var smooth_zoom := true
var cursor_image = preload("res://Assets/Graphics/Cursor.png")
var left_cursor_tool_texture : ImageTexture
var right_cursor_tool_texture : ImageTexture
var transparent_background : ImageTexture
# warning-ignore:unused_class_variable
var selected_pixels := []
var image_clipboard : Image
var animation_tags := [] setget animation_tags_changed # [Name, Color, From, To]
var play_only_tags := true

# warning-ignore:unused_class_variable
var theme_type := "Dark"
# warning-ignore:unused_class_variable
var is_default_image := true
# warning-ignore:unused_class_variable
var default_image_width := 64
# warning-ignore:unused_class_variable
var default_image_height := 64
# warning-ignore:unused_class_variable
var default_fill_color := Color(0, 0, 0, 0)
var grid_type = Grid_Types.CARTESIAN
# warning-ignore:unused_class_variable
var grid_width := 1
# warning-ignore:unused_class_variable
var grid_height := 1
# warning-ignore:unused_class_variable
var grid_color := Color.black
# warning-ignore:unused_class_variable
var guide_color := Color.purple

# Tools & options
# warning-ignore:unused_class_variable
var current_left_tool := "Pencil"
# warning-ignore:unused_class_variable
var current_right_tool := "Eraser"
# warning-ignore:unused_class_variable
var show_left_tool_icon := true
# warning-ignore:unused_class_variable
var show_right_tool_icon := true
# warning-ignore:unused_class_variable
var left_square_indicator_visible := true
# warning-ignore:unused_class_variable
var right_square_indicator_visible := false
#0 for area of same color, 1 for all pixels of the same color
# warning-ignore:unused_class_variable
var left_fill_area := 0
# warning-ignore:unused_class_variable
var right_fill_area := 0

# 0 for lighten, 1 for darken
# warning-ignore:unused_class_variable
var left_ld := 0
# warning-ignore:unused_class_variable
var right_ld := 0
# warning-ignore:unused_class_variable
var left_ld_amount := 0.1
# warning-ignore:unused_class_variable
var right_ld_amount := 0.1

# 0 for the left, 1 for the right
# warning-ignore:unused_class_variable
var left_color_picker_for := 0
# warning-ignore:unused_class_variable
var right_color_picker_for := 1

# 0 for zoom in, 1 for zoom out
var left_zoom_mode := 0
var right_zoom_mode := 1

# warning-ignore:unused_class_variable
var left_horizontal_mirror := false
# warning-ignore:unused_class_variable
var left_vertical_mirror := false
# warning-ignore:unused_class_variable
var right_horizontal_mirror := false
# warning-ignore:unused_class_variable
var right_vertical_mirror := false

# View menu options
# warning-ignore:unused_class_variable
var tile_mode := false
# warning-ignore:unused_class_variable
var draw_grid := false
# warning-ignore:unused_class_variable
var show_rulers := true
# warning-ignore:unused_class_variable
var show_guides := true
# warning-ignore:unused_class_variable
var show_animation_timeline := true

# Onion skinning options
var onion_skinning := false
# warning-ignore:unused_class_variable
var onion_skinning_past_rate := 1
# warning-ignore:unused_class_variable
var onion_skinning_future_rate := 1
# warning-ignore:unused_class_variable
var onion_skinning_blue_red := false

# Brushes
# warning-ignore:unused_class_variable
var left_brush_size := 1
# warning-ignore:unused_class_variable
var right_brush_size := 1
# warning-ignore:unused_class_variable
var current_left_brush_type = Brush_Types.PIXEL
# warning-ignore:unused_class_variable
var current_right_brush_type = Brush_Types.PIXEL
# warning-ignore:unused_class_variable
var brush_type_window_position := "left"
var left_circle_points := []
var right_circle_points := []

var brushes_from_files := 0
# warning-ignore:unused_class_variable
var custom_brushes := []
# warning-ignore:unused_class_variable
var custom_left_brush_index := -1
# warning-ignore:unused_class_variable
var custom_right_brush_index := -1
# warning-ignore:unused_class_variable
var custom_left_brush_image : Image
# warning-ignore:unused_class_variable
var custom_right_brush_image : Image
# warning-ignore:unused_class_variable
var custom_left_brush_texture := ImageTexture.new()
# warning-ignore:unused_class_variable
var custom_right_brush_texture := ImageTexture.new()

# Palettes
# warning-ignore:unused_class_variable
var palettes := {}

# Nodes
var control : Node
var top_menu_container : Panel
var left_cursor : Sprite
var right_cursor : Sprite
var canvas : Canvas
var canvas_parent : Node
var main_viewport : ViewportContainer
var second_viewport : ViewportContainer
var camera : Camera2D
var camera2 : Camera2D
var camera_preview : Camera2D
var selection_rectangle : Polygon2D
var horizontal_ruler : BaseButton
var vertical_ruler : BaseButton

var file_menu : MenuButton
var edit_menu : MenuButton
var view_menu : MenuButton
var image_menu : MenuButton
var help_menu : MenuButton
var cursor_position_label : Label
var zoom_level_label : Label

var import_sprites_dialog : FileDialog

var left_color_picker : ColorPickerButton
var right_color_picker : ColorPickerButton

var color_switch_button : TextureButton

var left_tool_options_container : Container
var right_tool_options_container : Container

var left_brush_type_container : Container
var right_brush_type_container : Container
var left_brush_type_button : BaseButton
var right_brush_type_button : BaseButton
var brushes_popup : Popup
var file_brush_container : GridContainer
var project_brush_container : GridContainer

var left_brush_size_edit : SpinBox
var left_brush_size_slider : HSlider
var right_brush_size_edit : SpinBox
var right_brush_size_slider : HSlider

var left_color_interpolation_container : Container
var right_color_interpolation_container : Container
var left_interpolate_spinbox : SpinBox
var left_interpolate_slider : HSlider
var right_interpolate_spinbox : SpinBox
var right_interpolate_slider : HSlider

var left_fill_area_container : Container
var right_fill_area_container : Container

var left_ld_container : Container
var left_ld_amount_slider : HSlider
var left_ld_amount_spinbox : SpinBox
var right_ld_container : Container
var right_ld_amount_slider : HSlider
var right_ld_amount_spinbox : SpinBox

var left_colorpicker_container : Container
var right_colorpicker_container : Container

var left_zoom_container : Container
var right_zoom_container : Container

var left_mirror_container : Container
var right_mirror_container : Container

var animation_timeline : Panel

var animation_timer : Timer
var frame_ids : HBoxContainer
var current_frame_label : Label
var onion_skinning_button : BaseButton
var loop_animation_button : BaseButton
var play_forward : BaseButton
var play_backwards : BaseButton
var timeline_seconds : Control
var layers_container : VBoxContainer
var frames_container : VBoxContainer
var tag_container : Control
var tag_dialog : AcceptDialog

var remove_layer_button : BaseButton
var move_up_layer_button : BaseButton
var move_down_layer_button : BaseButton
var merge_down_layer_button : BaseButton
var layer_opacity_slider : HSlider
var layer_opacity_spinbox : SpinBox

var add_palette_button : TextureButton
var edit_palette_button : BaseButton
var palette_option_button : OptionButton
var palette_container : GridContainer
var edit_palette_popup : WindowDialog
var new_palette_dialog : ConfirmationDialog
var new_palette_name_line_edit : LineEdit
var palette_import_file_dialog : FileDialog

var error_dialog : AcceptDialog

func _ready() -> void:
	randomize()
	if OS.has_feature("standalone"):
		root_directory = OS.get_executable_path().get_base_dir()
	# Load settings from the config file
	config_cache.load("user://cache.ini")

	# The fact that root_dir is set earlier than this is important
	# XDGDataDirs depends on it nyaa
	directory_module = XDGDataPaths.new()

	undo_redo = UndoRedo.new()
	transparent_background = ImageTexture.new()
	transparent_background.create_from_image(preload("res://Assets/Graphics/Canvas Backgrounds/Transparent Background Dark.png"), 0)
	image_clipboard = Image.new()

	var root = get_tree().get_root()
	control = find_node_by_name(root, "Control")
	top_menu_container = find_node_by_name(control, "TopMenuContainer")
	left_cursor = find_node_by_name(root, "LeftCursor")
	right_cursor = find_node_by_name(root, "RightCursor")
	canvas = find_node_by_name(root, "Canvas")
	canvases.append(canvas)
	left_cursor_tool_texture = ImageTexture.new()
	left_cursor_tool_texture.create_from_image(preload("res://Assets/Graphics/Tool Cursors/Pencil_Cursor.png"))
	right_cursor_tool_texture = ImageTexture.new()
	right_cursor_tool_texture.create_from_image(preload("res://Assets/Graphics/Tool Cursors/Eraser_Cursor.png"))
	canvas_parent = canvas.get_parent()
	main_viewport = find_node_by_name(root, "ViewportContainer")
	second_viewport = find_node_by_name(root, "ViewportContainer2")
	camera = find_node_by_name(canvas_parent, "Camera2D")
	camera2 = find_node_by_name(root, "Camera2D2")
	camera_preview = find_node_by_name(root, "CameraPreview")
	selection_rectangle = find_node_by_name(root, "SelectionRectangle")
	horizontal_ruler = find_node_by_name(root, "HorizontalRuler")
	vertical_ruler = find_node_by_name(root, "VerticalRuler")

	file_menu = find_node_by_name(root, "FileMenu")
	edit_menu = find_node_by_name(root, "EditMenu")
	view_menu = find_node_by_name(root, "ViewMenu")
	image_menu = find_node_by_name(root, "ImageMenu")
	help_menu = find_node_by_name(root, "HelpMenu")
	cursor_position_label = find_node_by_name(root, "CursorPosition")
	zoom_level_label = find_node_by_name(root, "ZoomLevel")

	import_sprites_dialog = find_node_by_name(root, "ImportSprites")

	left_tool_options_container = find_node_by_name(root, "LeftToolOptions")
	right_tool_options_container = find_node_by_name(root, "RightToolOptions")

	left_color_picker = find_node_by_name(root, "LeftColorPickerButton")
	right_color_picker = find_node_by_name(root, "RightColorPickerButton")
	color_switch_button = find_node_by_name(root, "ColorSwitch")

	left_brush_type_container = find_node_by_name(left_tool_options_container, "LeftBrushType")
	right_brush_type_container = find_node_by_name(right_tool_options_container, "RightBrushType")
	left_brush_type_button = find_node_by_name(left_brush_type_container, "LeftBrushTypeButton")
	right_brush_type_button = find_node_by_name(right_brush_type_container, "RightBrushTypeButton")
	brushes_popup = find_node_by_name(root, "BrushesPopup")
	file_brush_container = find_node_by_name(brushes_popup, "FileBrushContainer")
	project_brush_container = find_node_by_name(brushes_popup, "ProjectBrushContainer")

	left_brush_size_edit = find_node_by_name(root, "LeftBrushSizeEdit")
	left_brush_size_slider = find_node_by_name(root, "LeftBrushSizeSlider")
	right_brush_size_edit = find_node_by_name(root, "RightBrushSizeEdit")
	right_brush_size_slider = find_node_by_name(root, "RightBrushSizeSlider")

	left_color_interpolation_container = find_node_by_name(root, "LeftColorInterpolation")
	right_color_interpolation_container = find_node_by_name(root, "RightColorInterpolation")
	left_interpolate_spinbox = find_node_by_name(root, "LeftInterpolateFactor")
	left_interpolate_slider = find_node_by_name(root, "LeftInterpolateSlider")
	right_interpolate_spinbox = find_node_by_name(root, "RightInterpolateFactor")
	right_interpolate_slider = find_node_by_name(root, "RightInterpolateSlider")

	left_fill_area_container = find_node_by_name(root, "LeftFillArea")
	right_fill_area_container = find_node_by_name(root, "RightFillArea")

	left_ld_container = find_node_by_name(root, "LeftLDOptions")
	left_ld_amount_slider = find_node_by_name(root, "LeftLDAmountSlider")
	left_ld_amount_spinbox = find_node_by_name(root, "LeftLDAmountSpinbox")
	right_ld_container = find_node_by_name(root, "RightLDOptions")
	right_ld_amount_slider = find_node_by_name(root, "RightLDAmountSlider")
	right_ld_amount_spinbox = find_node_by_name(root, "RightLDAmountSpinbox")

	left_colorpicker_container = find_node_by_name(root, "LeftColorPickerOptions")
	right_colorpicker_container = find_node_by_name(root, "RightColorPickerOptions")

	left_zoom_container = find_node_by_name(root, "LeftZoomOptions")
	right_zoom_container = find_node_by_name(root, "RightZoomOptions")

	left_mirror_container = find_node_by_name(root, "LeftMirrorButtons")
	right_mirror_container = find_node_by_name(root, "RightMirrorButtons")

	animation_timeline = find_node_by_name(root, "AnimationTimeline")

	layers_container = find_node_by_name(animation_timeline, "LayersContainer")
	frames_container = find_node_by_name(animation_timeline, "FramesContainer")
	animation_timer = find_node_by_name(animation_timeline, "AnimationTimer")
	frame_ids = find_node_by_name(animation_timeline, "FrameIDs")
	current_frame_label = find_node_by_name(animation_timeline, "CurrentFrame")
	onion_skinning_button = find_node_by_name(animation_timeline, "OnionSkinning")
	loop_animation_button = find_node_by_name(animation_timeline, "LoopAnim")
	play_forward = find_node_by_name(animation_timeline, "PlayForward")
	play_backwards = find_node_by_name(animation_timeline, "PlayBackwards")
	tag_container = find_node_by_name(animation_timeline, "TagContainer")
	tag_dialog = find_node_by_name(animation_timeline, "FrameTagDialog")

	remove_layer_button = find_node_by_name(animation_timeline, "RemoveLayer")
	move_up_layer_button = find_node_by_name(animation_timeline, "MoveUpLayer")
	move_down_layer_button = find_node_by_name(animation_timeline, "MoveDownLayer")
	merge_down_layer_button = find_node_by_name(animation_timeline, "MergeDownLayer")

	layer_opacity_slider = find_node_by_name(animation_timeline, "OpacitySlider")
	layer_opacity_spinbox = find_node_by_name(animation_timeline, "OpacitySpinBox")

	add_palette_button = find_node_by_name(root, "AddPalette")
	edit_palette_button = find_node_by_name(root, "EditPalette")
	palette_option_button = find_node_by_name(root, "PaletteOptionButton")
	palette_container = find_node_by_name(root, "PaletteContainer")
	edit_palette_popup = find_node_by_name(root, "EditPalettePopup")
	new_palette_dialog = find_node_by_name(root, "NewPaletteDialog")
	new_palette_name_line_edit = find_node_by_name(new_palette_dialog, "NewPaletteNameLineEdit")
	palette_import_file_dialog = find_node_by_name(root, "PaletteImportFileDialog")

	error_dialog = find_node_by_name(root, "ErrorDialog")

	# Store [Layer name (0), Layer visibility boolean (1), Layer lock boolean (2), Frame container (3),
	# will new frames be linked boolean (4), Array of linked frames (5)]
	layers.append([tr("Layer") + " 0", true, false, HBoxContainer.new(), false, []])


# Thanks to https://godotengine.org/qa/17524/how-to-find-an-instanced-scene-by-its-name
func find_node_by_name(root, node_name) -> Node:
	if root.get_name() == node_name:
		return root
	for child in root.get_children():
		if child.get_name() == node_name:
			return child
		var found = find_node_by_name(child, node_name)
		if found:
			return found
	return null

func notification_label(text : String) -> void:
	var notification : Label = load("res://Prefabs/NotificationLabel.tscn").instance()
	notification.text = tr(text)
	notification.rect_position = Vector2(240, OS.window_size.y - animation_timeline.rect_size.y - 20)
	notification.theme = control.theme
	get_tree().get_root().add_child(notification)

func undo(_canvases : Array, layer_index : int = -1) -> void:
	undos -= 1
	var action_name := undo_redo.get_current_action_name()
	if action_name == "Draw" || action_name == "Rectangle Select" || action_name == "Scale" || action_name == "Merge Layer":
		for c in _canvases:
			if layer_index > -1:
				c.update_texture(layer_index)
			else:
				for i in c.layers.size():
					c.update_texture(i)

			if action_name == "Scale":
				c.camera_zoom()

	if action_name == "Add Frame":
		canvas_parent.remove_child(_canvases[0])
		# This actually means that canvases.size is one, but it hasn't been updated yet
		if canvases.size() == 2: # Stop animating
			play_forward.pressed = false
			play_backwards.pressed = false
			animation_timer.stop()
	elif action_name == "Remove Frame":
		canvas_parent.add_child(_canvases[0])
		canvas_parent.move_child(_canvases[0], _canvases[0].frame)
	elif action_name == "Change Frame Order":
		canvas_parent.move_child(_canvases[0], _canvases[0].frame)

	canvas.update()
	if saved:
		saved = false
		self.window_title = window_title + "(*)"
	notification_label("Undo: %s" % action_name)


func redo(_canvases : Array, layer_index : int = -1) -> void:
	if undos < undo_redo.get_version(): # If we did undo and then redo
		undos = undo_redo.get_version()
	var action_name := undo_redo.get_current_action_name()
	if action_name == "Draw" || action_name == "Rectangle Select" || action_name == "Scale" || action_name == "Merge Layer":
		for c in _canvases:
			if layer_index > -1:
				c.update_texture(layer_index)
			else:
				for i in c.layers.size():
					c.update_texture(i)

			if action_name == "Scale":
				c.camera_zoom()

	if action_name == "Add Frame":
		canvas_parent.add_child(_canvases[0])
	elif action_name == "Remove Frame":
		canvas_parent.remove_child(_canvases[0])
		if canvases.size() == 1: # Stop animating
			play_forward.pressed = false
			play_backwards.pressed = false
			animation_timer.stop()
	elif action_name == "Change Frame Order":
		canvas_parent.move_child(_canvases[0], _canvases[0].frame)

	canvas.update()
	if saved:
		saved = false
		self.window_title = window_title + "(*)"
	if control.redone:
		notification_label("Redo: %s" % action_name)

func title_changed(value : String) -> void:
	window_title = value
	OS.set_window_title(value)

func canvases_changed(value : Array) -> void:
	canvases = value
	for container in frames_container.get_children():
		for button in container.get_children():
			container.remove_child(button)
			button.queue_free()
		frames_container.remove_child(container)

	for frame_id in frame_ids.get_children():
		frame_ids.remove_child(frame_id)
		frame_id.queue_free()

	for i in range(layers.size() - 1, -1, -1):
		frames_container.add_child(layers[i][3])

	for j in range(canvases.size()):
		var label := Label.new()
		label.rect_min_size.x = 36
		label.align = Label.ALIGN_CENTER
		label.text = str(j + 1)
		frame_ids.add_child(label)

		for i in range(layers.size() - 1, -1, -1):
			var frame_button = load("res://Prefabs/FrameButton.tscn").instance()
			frame_button.frame = j
			frame_button.layer = i
			frame_button.get_child(0).texture = Global.canvases[j].layers[i][1]

			layers[i][3].add_child(frame_button)

func clear_canvases() -> void:
	for child in canvas_parent.get_children():
		if child is Canvas:
			child.queue_free()
	canvases.clear()
	animation_tags.clear()
	self.animation_tags = animation_tags # To execute animation_tags_changed()

	window_title = "(" + tr("untitled") + ") - Pixelorama"
	undo_redo.clear_history(false)

func layers_changed(value : Array) -> void:
	layers = value
	if layers_changed_skip:
		layers_changed_skip = false
		return

	for container in layers_container.get_children():
		container.queue_free()

	for container in frames_container.get_children():
		for button in container.get_children():
			container.remove_child(button)
			button.queue_free()
		frames_container.remove_child(container)

	for i in range(layers.size() - 1, -1, -1):
		var layer_container = load("res://Prefabs/LayerContainer.tscn").instance()
		layer_container.i = i
		if !layers[i][0]:
			layers[i][0] = tr("Layer") + " %s" % i

		layers_container.add_child(layer_container)
		layer_container.label.text = layers[i][0]
		layer_container.line_edit.text = layers[i][0]

		frames_container.add_child(layers[i][3])
		for j in range(canvases.size()):
			var frame_button = load("res://Prefabs/FrameButton.tscn").instance()
			frame_button.frame = j
			frame_button.layer = i
			frame_button.get_child(0).texture = Global.canvases[j].layers[i][1]

			layers[i][3].add_child(frame_button)

	var layer_button = layers_container.get_child(layers_container.get_child_count() - 1 - current_layer)
	layer_button.pressed = true
	self.current_frame = current_frame # Call frame_changed to update UI

	if layers[current_layer][2]:
		remove_layer_button.disabled = true
		remove_layer_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN

	if layers.size() == 1:
		remove_layer_button.disabled = true
		remove_layer_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		move_up_layer_button.disabled = true
		move_up_layer_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		move_down_layer_button.disabled = true
		move_down_layer_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		merge_down_layer_button.disabled = true
		merge_down_layer_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	elif !layers[current_layer][2]:
		remove_layer_button.disabled = false
		remove_layer_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func frame_changed(value : int) -> void:
	current_frame = value
	current_frame_label.text = tr("Current frame:") + " %s/%s" % [str(current_frame + 1), canvases.size()]

	var i := 0
	for c in canvases: # De-select all the other canvases/frames
		c.visible = false
		c.is_making_line = false
		c.line_2d.set_point_position(1, c.line_2d.points[0])
		var text_color := Color.white
		if theme_type == "Gold" || theme_type == "Light":
			text_color = Color.black
		frame_ids.get_child(i).add_color_override("font_color", text_color)
		for layer in layers:
			if i < layer[3].get_child_count():
				layer[3].get_child(i).pressed = false
		i += 1

	# Select the new canvas/frame
	canvas = canvases[current_frame]
	canvas.visible = true
	frame_ids.get_child(current_frame).add_color_override("font_color", Color("#3c5d75"))
	if current_frame < layers[current_layer][3].get_child_count():
		layers[current_layer][3].get_child(current_frame).pressed = true

func layer_changed(value : int) -> void:
	current_layer = value
	layer_opacity_slider.value = canvas.layers[current_layer][2] * 100
	layer_opacity_spinbox.value = canvas.layers[current_layer][2] * 100

	for container in layers_container.get_children():
		container.pressed = false

	if current_layer < layers_container.get_child_count():
		var layer_button = layers_container.get_child(layers_container.get_child_count() - 1 - current_layer)
		layer_button.pressed = true

	if current_layer < layers.size() - 1:
		move_up_layer_button.disabled = false
		move_up_layer_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		move_up_layer_button.disabled = true
		move_up_layer_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN

	if current_layer > 0:
		move_down_layer_button.disabled = false
		move_down_layer_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		merge_down_layer_button.disabled = false
		merge_down_layer_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		move_down_layer_button.disabled = true
		move_down_layer_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		merge_down_layer_button.disabled = true
		merge_down_layer_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN

	if current_layer < layers.size():
		if layers[current_layer][2]:
			remove_layer_button.disabled = true
			remove_layer_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		else:
			if layers.size() > 1:
				remove_layer_button.disabled = false
				remove_layer_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	yield(get_tree().create_timer(0.01), "timeout")
	self.current_frame = current_frame # Call frame_changed to update UI


func animation_tags_changed(value : Array) -> void:
	animation_tags = value
	for child in tag_container.get_children():
		child.queue_free()

	for tag in animation_tags:
		var tag_c : Container = load("res://Prefabs/AnimationTag.tscn").instance()
		tag_container.add_child(tag_c)
		var tag_position := tag_container.get_child_count() - 1
		tag_container.move_child(tag_c, tag_position)
		tag_c.get_node("Label").text = tag[0]
		tag_c.get_node("Label").modulate = tag[1]
		tag_c.get_node("Line2D").default_color = tag[1]

		tag_c.rect_position.x = (tag[2] - 1) * 39 + tag[2]

		var size : int = tag[3] - tag[2]
		tag_c.rect_min_size.x = (size + 1) * 39
		tag_c.get_node("Line2D").points[2] = Vector2(tag_c.rect_min_size.x, 0)
		tag_c.get_node("Line2D").points[3] = Vector2(tag_c.rect_min_size.x, 32)


func update_hint_tooltips() -> void:
	var root = get_tree().get_root()

	var rect_select : BaseButton = find_node_by_name(root, "RectSelect")
	rect_select.hint_tooltip = tr("""Rectangular Selection

%s for left mouse button
%s for right mouse button

Press %s to move the content""") % [InputMap.get_action_list("left_rectangle_select_tool")[0].as_text(), InputMap.get_action_list("right_rectangle_select_tool")[0].as_text(), "Shift"]

	var zoom_tool : BaseButton = find_node_by_name(root, "Zoom")
	zoom_tool.hint_tooltip = tr("""Zoom

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_zoom_tool")[0].as_text(), InputMap.get_action_list("right_zoom_tool")[0].as_text()]


	var color_picker : BaseButton = find_node_by_name(root, "ColorPicker")
	color_picker.hint_tooltip = tr("""Color Picker
Select a color from a pixel of the sprite

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_colorpicker_tool")[0].as_text(), InputMap.get_action_list("right_colorpicker_tool")[0].as_text()]

	var pencil : BaseButton = find_node_by_name(root, "Pencil")
	pencil.hint_tooltip = tr("""Pencil

%s for left mouse button
%s for right mouse button

Hold %s to make a line""") % [InputMap.get_action_list("left_pencil_tool")[0].as_text(), InputMap.get_action_list("right_pencil_tool")[0].as_text(), "Shift"]

	var eraser : BaseButton = find_node_by_name(root, "Eraser")
	eraser.hint_tooltip = tr("""Eraser

%s for left mouse button
%s for right mouse button

Hold %s to make a line""") % [InputMap.get_action_list("left_eraser_tool")[0].as_text(), InputMap.get_action_list("right_eraser_tool")[0].as_text(), "Shift"]

	var bucket : BaseButton = find_node_by_name(root, "Bucket")
	bucket.hint_tooltip = tr("""Bucket

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_fill_tool")[0].as_text(), InputMap.get_action_list("right_fill_tool")[0].as_text()]

	var ld : BaseButton = find_node_by_name(root, "LightenDarken")
	ld.hint_tooltip = tr("""Lighten/Darken

%s for left mouse button
%s for right mouse button""") % [InputMap.get_action_list("left_lightdark_tool")[0].as_text(), InputMap.get_action_list("right_lightdark_tool")[0].as_text()]

	var color_switch : BaseButton = find_node_by_name(root, "ColorSwitch")
	color_switch.hint_tooltip = tr("""Switch left and right colors
(%s)""") % InputMap.get_action_list("switch_colors")[0].as_text()

	var first_frame : BaseButton = find_node_by_name(root, "FirstFrame")
	first_frame.hint_tooltip = tr("""Jump to the first frame
(%s)""") % "Ctrl+Home"

	var previous_frame : BaseButton = find_node_by_name(root, "PreviousFrame")
	previous_frame.hint_tooltip = tr("""Go to the previous frame
(%s)""") % "Ctrl+Left"

	play_backwards.hint_tooltip = tr("""Play the animation backwards (from end to beginning)
(%s)""") % "F4"

	play_forward.hint_tooltip = tr("""Play the animation forward (from beginning to end)
(%s)""") % "F5"

	var next_frame : BaseButton = find_node_by_name(root, "NextFrame")
	next_frame.hint_tooltip = tr("""Go to the next frame
(%s)""") % "Ctrl+Right"

	var last_frame : BaseButton = find_node_by_name(root, "LastFrame")
	last_frame.hint_tooltip = tr("""Jump to the last frame
(%s)""") % "Ctrl+End"


func create_brush_button(brush_img : Image, brush_type := Brush_Types.CUSTOM, hint_tooltip := "") -> void:
	var brush_container
	var brush_button = load("res://Prefabs/BrushButton.tscn").instance()
	brush_button.brush_type = brush_type
	brush_button.custom_brush_index = custom_brushes.size() - 1
	if brush_type == Brush_Types.FILE || brush_type == Brush_Types.RANDOM_FILE:
		brush_container = file_brush_container
	else:
		brush_container = project_brush_container
	var brush_tex := ImageTexture.new()
	brush_tex.create_from_image(brush_img, 0)
	brush_button.get_child(0).texture = brush_tex
	brush_button.hint_tooltip = hint_tooltip
	if brush_type == Brush_Types.RANDOM_FILE:
		brush_button.random_brushes.append(brush_img)
	brush_container.add_child(brush_button)

func remove_brush_buttons() -> void:
	current_left_brush_type = Brush_Types.PIXEL
	current_right_brush_type = Brush_Types.PIXEL
	for child in project_brush_container.get_children():
		child.queue_free()

func undo_custom_brush(_brush_button : BaseButton = null) -> void:
	undos -= 1
	var action_name := undo_redo.get_current_action_name()
	if action_name == "Delete Custom Brush":
		project_brush_container.add_child(_brush_button)
		project_brush_container.move_child(_brush_button, _brush_button.custom_brush_index - brushes_from_files)
		_brush_button.get_node("DeleteButton").visible = false
	notification_label("Undo: %s" % action_name)

func redo_custom_brush(_brush_button : BaseButton = null) -> void:
	if undos < undo_redo.get_version(): # If we did undo and then redo
		undos = undo_redo.get_version()
	var action_name := undo_redo.get_current_action_name()
	if action_name == "Delete Custom Brush":
		project_brush_container.remove_child(_brush_button)
	if control.redone:
		notification_label("Redo: %s" % action_name)

func update_left_custom_brush() -> void:
	if current_left_brush_type == Brush_Types.PIXEL:
		var pixel := Image.new()
		pixel = preload("res://Assets/Graphics/pixel_image.png")
		left_brush_type_button.get_child(0).texture.create_from_image(pixel, 0)
	elif current_left_brush_type == Brush_Types.CIRCLE:
		var pixel := Image.new()
		pixel = preload("res://Assets/Graphics/circle_9x9.png")
		left_brush_type_button.get_child(0).texture.create_from_image(pixel, 0)
		left_circle_points = plot_circle(left_brush_size)
	elif current_left_brush_type == Brush_Types.FILLED_CIRCLE:
		var pixel := Image.new()
		pixel = preload("res://Assets/Graphics/circle_filled_9x9.png")
		left_brush_type_button.get_child(0).texture.create_from_image(pixel, 0)
		left_circle_points = plot_circle(left_brush_size)
	else:
		var custom_brush := Image.new()
		custom_brush.copy_from(custom_brushes[custom_left_brush_index])
		var custom_brush_size = custom_brush.get_size()
		custom_brush.resize(custom_brush_size.x * left_brush_size, custom_brush_size.y * left_brush_size, Image.INTERPOLATE_NEAREST)
		custom_left_brush_image = blend_image_with_color(custom_brush, left_color_picker.color, left_interpolate_spinbox.value / 100)
		custom_left_brush_texture.create_from_image(custom_left_brush_image, 0)

		left_brush_type_button.get_child(0).texture = custom_left_brush_texture

func update_right_custom_brush() -> void:
	if current_right_brush_type == Brush_Types.PIXEL:
		var pixel := Image.new()
		pixel = preload("res://Assets/Graphics/pixel_image.png")
		right_brush_type_button.get_child(0).texture.create_from_image(pixel, 0)
	elif current_right_brush_type == Brush_Types.CIRCLE:
		var pixel := Image.new()
		pixel = preload("res://Assets/Graphics/circle_9x9.png")
		right_brush_type_button.get_child(0).texture.create_from_image(pixel, 0)
		right_circle_points = plot_circle(right_brush_size)
	elif current_right_brush_type == Brush_Types.FILLED_CIRCLE:
		var pixel := Image.new()
		pixel = preload("res://Assets/Graphics/circle_filled_9x9.png")
		right_brush_type_button.get_child(0).texture.create_from_image(pixel, 0)
		right_circle_points = plot_circle(right_brush_size)
	else:
		var custom_brush := Image.new()
		custom_brush.copy_from(custom_brushes[custom_right_brush_index])
		var custom_brush_size = custom_brush.get_size()
		custom_brush.resize(custom_brush_size.x * right_brush_size, custom_brush_size.y * right_brush_size, Image.INTERPOLATE_NEAREST)
		custom_right_brush_image = blend_image_with_color(custom_brush, right_color_picker.color, right_interpolate_spinbox.value / 100)
		custom_right_brush_texture.create_from_image(custom_right_brush_image, 0)

		right_brush_type_button.get_child(0).texture = custom_right_brush_texture

func blend_image_with_color(image : Image, color : Color, interpolate_factor : float) -> Image:
	var blended_image := Image.new()
	blended_image.copy_from(image)
	var size := image.get_size()
	blended_image.lock()
	for xx in size.x:
		for yy in size.y:
			if color.a > 0: # If it's the pencil
				var current_color := blended_image.get_pixel(xx, yy)
				if current_color.a > 0:
					var new_color := current_color.linear_interpolate(color, interpolate_factor)
					new_color.a = current_color.a
					blended_image.set_pixel(xx, yy, new_color)
			else: # If color is transparent - if it's the eraser
				blended_image.set_pixel(xx, yy, Color(0, 0, 0, 0))
	return blended_image

# Algorithm based on http://members.chello.at/easyfilter/bresenham.html
# This is not used for drawing, rather for finding the points required
# for the mouse cursor/position indicator
func plot_circle(r : int) -> Array:
	var circle_points := []
	var xm := 0
	var ym := 0
	var x := -r
	var y := 0
	var err := 2 - r * 2
	while x < 0:
		circle_points.append(Vector2(xm - x, ym + y))
		circle_points.append(Vector2(xm - y, ym - x))
		circle_points.append(Vector2(xm + x, ym - y))
		circle_points.append(Vector2(xm + y, ym + x))
		r = err
		if r <= y:
			y += 1
			err += y * 2 + 1
		if r > x || err > y:
			x += 1
			err += x * 2 + 1
	return circle_points

func scale3X(sprite : Image, tol : float = 50) -> Image:
	var scaled = Image.new()
	scaled.create(sprite.get_width()*3, sprite.get_height()*3, false, Image.FORMAT_RGBA8)
	scaled.lock()
	sprite.lock()
	var a : Color
	var b : Color
	var c : Color
	var d : Color
	var e : Color
	var f : Color
	var g : Color
	var h : Color
	var i : Color

	for x in range(1,sprite.get_width()-1):
		for y in range(1,sprite.get_height()-1):
			var xs : float = 3*x
			var ys : float = 3*y

			a = sprite.get_pixel(x-1,y-1)
			b = sprite.get_pixel(x,y-1)
			c = sprite.get_pixel(x+1,y-1)
			d = sprite.get_pixel(x-1,y)
			e = sprite.get_pixel(x,y)
			f = sprite.get_pixel(x+1,y)
			g = sprite.get_pixel(x-1,y+1)
			h = sprite.get_pixel(x,y+1)
			i = sprite.get_pixel(x+1,y+1)

			var db : bool = similarColors(d, b, tol)
			var dh : bool = similarColors(d, h, tol)
			var bf : bool = similarColors(f, b, tol)
			var ec : bool = similarColors(e, c, tol)
			var ea : bool = similarColors(e, a, tol)
			var fh : bool = similarColors(f, h, tol)
			var eg : bool = similarColors(e, g, tol)
			var ei : bool = similarColors(e, i, tol)

			scaled.set_pixel(xs-1, ys-1, d if (db and !dh and !bf) else e )
			scaled.set_pixel(xs, ys-1, b if (db and !dh and !bf and !ec) or
			(bf and !db and !fh and !ea) else e)
			scaled.set_pixel(xs+1, ys-1, f if (bf and !db and !fh) else e)
			scaled.set_pixel(xs-1, ys, d if (dh and !fh and !db and !ea) or
			 (db and !dh and !bf and !eg) else e)
			scaled.set_pixel(xs, ys, e);
			scaled.set_pixel(xs+1, ys, f if (bf and !db and !fh and !ei) or
			(fh and !bf and !dh and !ec) else e)
			scaled.set_pixel(xs-1, ys+1, d if (dh and !fh and !db) else e)
			scaled.set_pixel(xs, ys+1, h if (fh and !bf and !dh and !eg) or
			(dh and !fh and !db and !ei) else e)
			scaled.set_pixel(xs+1, ys+1, f if (fh and !bf and !dh) else e)

	scaled.unlock()
	sprite.unlock()
	return scaled

func rotxel(sprite : Image, angle : float) -> void:

	# If angle is simple, then nn rotation is the best

	if angle == 0 || angle == PI/2 || angle == PI || angle == 2*PI:
		nn_rotate(sprite, angle)
		return

	var aux : Image = Image.new()
	aux.copy_from(sprite)
	var center : Vector2 = Vector2(sprite.get_width()/2, sprite.get_height()/2)
	var ox : int
	var oy : int
	var p : Color
	aux.lock()
	sprite.lock()
	for x in range(sprite.get_width()):
		for y in range(sprite.get_height()):
			var dx = 3*(x - center.x)
			var dy = 3*(y - center.y)
			var found_pixel : bool = false
			for k in range(9):
				var i = -1 + k % 3
				var j = -1 + int(k / 3)
				var dir = atan2(dy + j, dx + i)
				var mag = sqrt(pow(dx + i, 2) + pow(dy + j, 2))
				dir -= angle
				ox = round(center.x*3 + 1 + mag*cos(dir))
				oy = round(center.y*3 + 1 + mag*sin(dir))

				if (sprite.get_width() % 2 != 0):
					ox += 1
					oy += 1

				if (ox >= 0 && ox < sprite.get_width()*3
					&& oy >= 0 && oy < sprite.get_height()*3):
						found_pixel = true
						break

			if !found_pixel:
				sprite.set_pixel(x, y, Color(0,0,0,0))
				continue

			var fil : int = oy % 3
			var col : int = ox % 3
			var index : int = col + 3*fil

			ox = round((ox - 1)/3.0);
			oy = round((oy - 1)/3.0);
			var a : Color
			var b : Color
			var c : Color
			var d : Color
			var e : Color
			var f : Color
			var g : Color
			var h : Color
			var i : Color
			if (ox == 0 || ox == sprite.get_width() - 1 ||
				oy == 0 || oy == sprite.get_height() - 1):
					p = aux.get_pixel(ox, oy)
			else:
				a = aux.get_pixel(ox-1,oy-1);
				b = aux.get_pixel(ox,oy-1);
				c = aux.get_pixel(ox+1,oy-1);
				d = aux.get_pixel(ox-1,oy);
				e = aux.get_pixel(ox,oy);
				f = aux.get_pixel(ox+1,oy);
				g = aux.get_pixel(ox-1,oy+1);
				h = aux.get_pixel(ox,oy+1);
				i = aux.get_pixel(ox+1,oy+1);

				match(index):
					0:
						p = d if (similarColors(d,b) && !similarColors(d,h)
						 && !similarColors(b,f)) else e;
					1:
						p = b if ((similarColors(d,b) && !similarColors(d,h) &&
						 !similarColors(b,f) && !similarColors(e,c)) ||
						 (similarColors(b,f) && !similarColors(d,b) &&
						 !similarColors(f,h) && !similarColors(e,a))) else e;
					2:
						p = f if (similarColors(b,f) && !similarColors(d,b) &&
						 !similarColors(f,h)) else e;
					3:
						p = d if ((similarColors(d,h) && !similarColors(f,h) &&
						 !similarColors(d,b) && !similarColors(e,a)) ||
						 (similarColors(d,b) && !similarColors(d,h) &&
						!similarColors(b,f) && !similarColors(e,g))) else e;
					4:
						p = e
					5:
						p =  f if((similarColors(b,f) && !similarColors(d,b) &&
						 !similarColors(f,h) && !similarColors(e,i))
						 || (similarColors(f,h) && !similarColors(b,f) &&
						 !similarColors(d,h) && !similarColors(e,c))) else e;
					6:
						p = d if (similarColors(d,h) && !similarColors(f,h) &&
						 !similarColors(d,b)) else e;
					7:
						p = h if ((similarColors(f,h) && !similarColors(f,b) &&
						 !similarColors(d,h) && !similarColors(e,g))
						 || (similarColors(d,h) && !similarColors(f,h) &&
						 !similarColors(d,b) && !similarColors(e,i))) else e;
					8:
						p = f if (similarColors(f,h) && !similarColors(f,b) &&
						 !similarColors(d,h)) else e;
			sprite.set_pixel(x, y, p)
	sprite.unlock()
	aux.unlock()

func fake_rotsprite(sprite : Image, angle : float) -> void:
	sprite.copy_from(scale3X(sprite))
	nn_rotate(sprite,angle)
	sprite.resize(sprite.get_width()/3,sprite.get_height()/3,0)

func nn_rotate(sprite : Image, angle : float) -> void:
	var aux : Image = Image.new()
	aux.copy_from(sprite)
	sprite.lock()
	aux.lock()
	var ox: int
	var oy: int
	var center : Vector2 = Vector2(sprite.get_width()/2, sprite.get_height()/2)
	for x in range(sprite.get_width()):
		for y in range(sprite.get_height()):
			ox = (x - center.x)*cos(angle) + (y - center.y)*sin(angle) + center.x
			oy = -(x - center.x)*sin(angle) + (y - center.y)*cos(angle) + center.y
			if ox >= 0 && ox < sprite.get_width() && oy >= 0 && oy < sprite.get_height():
				sprite.set_pixel(x, y, aux.get_pixel(ox, oy))
			else:
				sprite.set_pixel(x, y, Color(0,0,0,0))
	sprite.unlock()
	aux.unlock()

func similarColors(c1 : Color, c2 : Color, tol : float = 100) -> bool:
	var dist = colorDistance(c1, c2)
	return dist <= tol

func colorDistance(c1 : Color, c2 : Color) -> float:
		return sqrt(pow((c1.r - c2.r)*255, 2) + pow((c1.g - c2.g)*255, 2)
		+ pow((c1.b - c2.b)*255, 2) + pow((c1.a - c2.a)*255, 2))

func _exit_tree() -> void:
	config_cache.set_value("window", "screen", OS.current_screen)
	config_cache.set_value("window", "maximized", OS.window_maximized || OS.window_fullscreen)
	config_cache.set_value("window", "position", OS.window_position)
	config_cache.set_value("window", "size", OS.window_size)
	config_cache.save("user://cache.ini")

	# Thanks to qarmin from GitHub for pointing this out
	undo_redo.free()
