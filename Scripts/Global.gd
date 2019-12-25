extends Node

var config_cache := ConfigFile.new()
# warning-ignore:unused_class_variable
var loaded_locales : Array
var undo_redo : UndoRedo
var undos := 0 #The number of times we added undo properties

#Canvas related stuff
var current_frame := 0 setget frame_changed
# warning-ignore:unused_class_variable
var can_draw := false
# warning-ignore:unused_class_variable
var has_focus := false
var canvases := []
# warning-ignore:unused_class_variable
var hidden_canvases := []
var left_cursor_tool_texture : ImageTexture
var right_cursor_tool_texture : ImageTexture
var transparent_background : ImageTexture
# warning-ignore:unused_class_variable
var selected_pixels := []
var image_clipboard : Image
# warning-ignore:unused_class_variable
var theme_type := "Dark"
# warning-ignore:unused_class_variable
var grid_width := 1
# warning-ignore:unused_class_variable
var grid_height := 1
# warning-ignore:unused_class_variable
var grid_color := Color.black

#Tools & options
# warning-ignore:unused_class_variable
var current_left_tool := "Pencil"
# warning-ignore:unused_class_variable
var current_right_tool := "Eraser"
# warning-ignore:unused_class_variable
var left_square_indicator_visible := true
# warning-ignore:unused_class_variable
var right_square_indicator_visible := false
#0 for area of same color, 1 for all pixels of the same color
# warning-ignore:unused_class_variable
var left_fill_area := 0
# warning-ignore:unused_class_variable
var right_fill_area := 0

#0 for lighten, 1 for darken
# warning-ignore:unused_class_variable
var left_ld := 0
# warning-ignore:unused_class_variable
var right_ld := 0
# warning-ignore:unused_class_variable
var left_ld_amount := 0.1
# warning-ignore:unused_class_variable
var right_ld_amount := 0.1

# warning-ignore:unused_class_variable
var left_horizontal_mirror := false
# warning-ignore:unused_class_variable
var left_vertical_mirror := false
# warning-ignore:unused_class_variable
var right_horizontal_mirror := false
# warning-ignore:unused_class_variable
var right_vertical_mirror := false

#View menu options
# warning-ignore:unused_class_variable
var tile_mode := false
# warning-ignore:unused_class_variable
var draw_grid := false
# warning-ignore:unused_class_variable
var show_rulers := true
# warning-ignore:unused_class_variable
var show_guides := true

#Onion skinning options
# warning-ignore:unused_class_variable
var onion_skinning_past_rate := 0
# warning-ignore:unused_class_variable
var onion_skinning_future_rate := 0
# warning-ignore:unused_class_variable
var onion_skinning_blue_red := false

#Brushes
enum BRUSH_TYPES {PIXEL, FILE, CUSTOM}
# warning-ignore:unused_class_variable
var left_brush_size := 1
# warning-ignore:unused_class_variable
var right_brush_size := 1
# warning-ignore:unused_class_variable
var current_left_brush_type = BRUSH_TYPES.PIXEL
# warning-ignore:unused_class_variable
var current_right_brush_type = BRUSH_TYPES.PIXEL
# warning-ignore:unused_class_variable
var brush_type_window_position := "left"

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

#Palettes
# warning-ignore:unused_class_variable
var palettes := {}

#Nodes
var control : Node
var top_menu_container : Panel
var left_cursor : Sprite
var right_cursor : Sprite
var canvas : Canvas
var canvas_parent : Node
var main_viewport : ViewportContainer
var second_viewport : ViewportContainer
var viewport_separator : VSeparator
var split_screen_button : BaseButton
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

var left_color_picker : ColorPickerButton
var right_color_picker : ColorPickerButton

var left_tool_options_container : Container
var right_tool_options_container : Container

var left_brush_type_container : Container
var right_brush_type_container : Container
var left_brush_type_button : BaseButton
var right_brush_type_button : BaseButton
var left_brush_type_label : Label
var right_brush_type_label : Label
var brushes_popup : Popup
var file_brush_container : GridContainer
var project_brush_container : GridContainer

var left_brush_size_container : Container
var right_brush_size_container : Container
var left_brush_size_edit : SpinBox
var right_brush_size_edit : SpinBox

var left_color_interpolation_container : Container
var right_color_interpolation_container : Container
var left_interpolate_slider : SpinBox
var right_interpolate_slider : SpinBox

var left_fill_area_container : Container
var right_fill_area_container : Container

var left_ld_container : Container
var right_ld_container : Container

var left_mirror_container : Container
var right_mirror_container : Container

var animation_timer : Timer

var current_frame_label : Label
var loop_animation_button : BaseButton
var play_forward : BaseButton
var play_backwards : BaseButton
var frame_container : HBoxContainer

var vbox_layer_container : VBoxContainer
var remove_layer_button : BaseButton
var move_up_layer_button : BaseButton
var move_down_layer_button : BaseButton
var merge_down_layer_button : BaseButton
var layer_opacity_slider : HSlider
var layer_opacity_spinbox : SpinBox

var add_palette_button : TextureButton
var remove_palette_button : TextureButton
var palette_option_button : OptionButton
var edit_palette_button : BaseButton
var palette_container : GridContainer
var edit_palette_popup : WindowDialog
var new_palette_dialog : ConfirmationDialog
var new_palette_name_line_edit : LineEdit
var palette_import_file_dialog : FileDialog

var error_dialog : AcceptDialog

func _ready() -> void:
	# Load settings from the config file
	config_cache.load("user://cache.ini")

	undo_redo = UndoRedo.new()
	transparent_background = ImageTexture.new()
	transparent_background.create_from_image(preload("res://Assets/Graphics/Transparent Background Dark.png"), 0)
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
	viewport_separator = find_node_by_name(root, "ViewportSeparator")
	split_screen_button = find_node_by_name(root, "SplitScreenButton")
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

	left_tool_options_container = find_node_by_name(root, "LeftToolOptions")
	right_tool_options_container = find_node_by_name(root, "RightToolOptions")

	left_color_picker = find_node_by_name(root, "LeftColorPickerButton")
	right_color_picker = find_node_by_name(root, "RightColorPickerButton")

	left_brush_type_container = find_node_by_name(left_tool_options_container, "LeftBrushType")
	right_brush_type_container = find_node_by_name(right_tool_options_container, "RightBrushType")
	left_brush_type_button = find_node_by_name(left_brush_type_container, "LeftBrushTypeButton")
	right_brush_type_button = find_node_by_name(right_brush_type_container, "RightBrushTypeButton")
	left_brush_type_label = find_node_by_name(left_brush_type_container, "LeftBrushTypeLabel")
	right_brush_type_label = find_node_by_name(right_brush_type_container, "RightBrushTypeLabel")
	brushes_popup = find_node_by_name(root, "BrushesPopup")
	file_brush_container = find_node_by_name(brushes_popup, "FileBrushContainer")
	project_brush_container = find_node_by_name(brushes_popup, "ProjectBrushContainer")

	left_brush_size_container = find_node_by_name(left_tool_options_container, "LeftBrushSize")
	right_brush_size_container = find_node_by_name(right_tool_options_container, "RightBrushSize")
	left_brush_size_edit = find_node_by_name(left_brush_size_container, "LeftBrushSizeEdit")
	right_brush_size_edit = find_node_by_name(right_brush_size_container, "RightBrushSizeEdit")

	left_color_interpolation_container = find_node_by_name(left_tool_options_container, "LeftColorInterpolation")
	right_color_interpolation_container = find_node_by_name(right_tool_options_container, "RightColorInterpolation")
	left_interpolate_slider = find_node_by_name(left_color_interpolation_container, "LeftInterpolateFactor")
	right_interpolate_slider = find_node_by_name(right_color_interpolation_container, "RightInterpolateFactor")

	left_fill_area_container = find_node_by_name(left_tool_options_container, "LeftFillArea")
	right_fill_area_container = find_node_by_name(right_tool_options_container, "RightFillArea")

	left_ld_container = find_node_by_name(left_tool_options_container, "LeftLDOptions")
	right_ld_container = find_node_by_name(right_tool_options_container, "RightLDOptions")

	left_mirror_container = find_node_by_name(left_tool_options_container, "LeftMirroring")
	right_mirror_container = find_node_by_name(right_tool_options_container, "RightMirroring")

	animation_timer = find_node_by_name(root, "AnimationTimer")

	current_frame_label = find_node_by_name(root, "CurrentFrame")
	loop_animation_button = find_node_by_name(root, "LoopAnim")
	play_forward = find_node_by_name(root, "PlayForward")
	play_backwards = find_node_by_name(root, "PlayBackwards")
	frame_container = find_node_by_name(root, "FrameContainer")

	var layer_stuff_container = find_node_by_name(root, "LayerVBoxContainer")
	var layer_buttons = find_node_by_name(layer_stuff_container, "LayerButtons")
	remove_layer_button = find_node_by_name(layer_buttons, "RemoveLayer")
	move_up_layer_button = find_node_by_name(layer_buttons, "MoveUpLayer")
	move_down_layer_button = find_node_by_name(layer_buttons, "MovwDownLayer")
	merge_down_layer_button = find_node_by_name(layer_buttons, "MergeDownLayer")

	layer_opacity_slider = find_node_by_name(layer_stuff_container, "OpacitySlider")
	layer_opacity_spinbox = find_node_by_name(layer_stuff_container, "OpacitySpinBox")
	vbox_layer_container = find_node_by_name(layer_stuff_container, "VBoxLayerContainer")

	add_palette_button = find_node_by_name(root, "AddPalette")
	remove_palette_button = find_node_by_name(root, "RemovePalette")
	palette_option_button = find_node_by_name(root, "PaletteOptionButton")
	edit_palette_button = find_node_by_name(root, "EditPalette")
	palette_container = find_node_by_name(root, "PaletteContainer")
	edit_palette_popup = find_node_by_name(root, "EditPalettePopup")
	new_palette_dialog = find_node_by_name(root, "NewPaletteDialog")
	new_palette_name_line_edit = find_node_by_name(new_palette_dialog, "NewPaletteNameLineEdit")
	palette_import_file_dialog = find_node_by_name(root, "PaletteImportFileDialog")

	error_dialog = find_node_by_name(root, "ErrorDialog")

#Thanks to https://godotengine.org/qa/17524/how-to-find-an-instanced-scene-by-its-name
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
	notification.rect_position = Vector2(240, OS.window_size.y - 150)
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
	if "Layer" in action_name:
		var current_layer_index : int = _canvases[0].current_layer_index
		_canvases[0].generate_layer_panels()
		if action_name == "Change Layer Order":
			_canvases[0].current_layer_index = current_layer_index
			_canvases[0].get_layer_container(current_layer_index).changed_selection()

	if action_name == "Add Frame":
		canvas_parent.remove_child(_canvases[0])
		frame_container.remove_child(_canvases[0].frame_button)
		#This actually means that canvases.size is one, but it hasn't been updated yet
		if canvases.size() == 2: #Stop animating
			play_forward.pressed = false
			play_backwards.pressed = false
			animation_timer.stop()
	elif action_name == "Remove Frame":
		canvas_parent.add_child(_canvases[0])
		canvas_parent.move_child(_canvases[0], _canvases[0].frame)
		frame_container.add_child(_canvases[0].frame_button)
		frame_container.move_child(_canvases[0].frame_button, _canvases[0].frame)
	elif action_name == "Change Frame Order":
		frame_container.move_child(_canvases[0].frame_button, _canvases[0].frame)
		canvas_parent.move_child(_canvases[0], _canvases[0].frame)

	notification_label("Undo: %s" % action_name)


func redo(_canvases : Array, layer_index : int = -1) -> void:
	if undos < undo_redo.get_version(): #If we did undo and then redo
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
	if "Layer" in action_name:
		var current_layer_index : int = _canvases[0].current_layer_index
		_canvases[0].generate_layer_panels()
		if action_name == "Change Layer Order":
			_canvases[0].current_layer_index = current_layer_index
			_canvases[0].get_layer_container(current_layer_index).changed_selection()

	if action_name == "Add Frame":
		canvas_parent.add_child(_canvases[0])
		if !Global.frame_container.is_a_parent_of(_canvases[0].frame_button):
			Global.frame_container.add_child(_canvases[0].frame_button)
	elif action_name == "Remove Frame":
		canvas_parent.remove_child(_canvases[0])
		frame_container.remove_child(_canvases[0].frame_button)
		if canvases.size() == 1: #Stop animating
			play_forward.pressed = false
			play_backwards.pressed = false
			animation_timer.stop()
	elif action_name == "Change Frame Order":
		frame_container.move_child(_canvases[0].frame_button, _canvases[0].frame)
		canvas_parent.move_child(_canvases[0], _canvases[0].frame)

	if control.redone:
		notification_label("Redo: %s" % action_name)

func frame_changed(value : int) -> void:
	current_frame = value
	current_frame_label.text = tr("Current frame:") + " %s/%s" % [str(current_frame + 1), canvases.size()]

	for c in canvases:
		c.visible = false
	canvas = canvases[current_frame]
	canvas.visible = true
	canvas.generate_layer_panels()
	#Make all frame buttons unpressed
	for c in canvases:
		var text_color := Color.white
		if theme_type == "Gold" || theme_type == "Light":
			text_color = Color.black
		c.frame_button.get_node("FrameButton").pressed = false
		c.frame_button.get_node("FrameID").add_color_override("font_color", text_color)
	#Make only the current frame button pressed
	canvas.frame_button.get_node("FrameButton").pressed = true
	canvas.frame_button.get_node("FrameID").add_color_override("font_color", Color("#3c5d75"))


func create_brush_button(brush_img : Image, brush_type := BRUSH_TYPES.CUSTOM, hint_tooltip := "") -> void:
	var brush_container
	var brush_button = load("res://Prefabs/BrushButton.tscn").instance()
	brush_button.brush_type = brush_type
	brush_button.custom_brush_index = custom_brushes.size() - 1
	if brush_type == BRUSH_TYPES.FILE:
		brush_container = file_brush_container
	else:
		brush_container = project_brush_container
	var brush_tex := ImageTexture.new()
	brush_tex.create_from_image(brush_img, 0)
	brush_button.get_child(0).texture = brush_tex
	brush_button.hint_tooltip = hint_tooltip
	brush_container.add_child(brush_button)

func remove_brush_buttons() -> void:
	current_left_brush_type = BRUSH_TYPES.PIXEL
	current_right_brush_type = BRUSH_TYPES.PIXEL
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
	if undos < undo_redo.get_version(): #If we did undo and then redo
		undos = undo_redo.get_version()
	var action_name := undo_redo.get_current_action_name()
	if action_name == "Delete Custom Brush":
		project_brush_container.remove_child(_brush_button)
	if control.redone:
		notification_label("Redo: %s" % action_name)

func update_left_custom_brush() -> void:
	if current_left_brush_type == BRUSH_TYPES.PIXEL:
		var pixel := Image.new()
		pixel = preload("res://Assets/Graphics/pixel_image.png")
		pixel = blend_image_with_color(pixel, left_color_picker.color, 1)
		left_brush_type_button.get_child(0).texture.create_from_image(pixel)
	else:
		var custom_brush := Image.new()
		custom_brush.copy_from(custom_brushes[custom_left_brush_index])
		var custom_brush_size = custom_brush.get_size()
		custom_brush.resize(custom_brush_size.x * left_brush_size, custom_brush_size.y * left_brush_size, Image.INTERPOLATE_NEAREST)
		custom_left_brush_image = blend_image_with_color(custom_brush, left_color_picker.color, left_interpolate_slider.value / 100)
		custom_left_brush_texture.create_from_image(custom_left_brush_image, 0)

		left_brush_type_button.get_child(0).texture = custom_left_brush_texture

func update_right_custom_brush() -> void:
	if current_right_brush_type == BRUSH_TYPES.PIXEL:
		var pixel := Image.new()
		pixel = preload("res://Assets/Graphics/pixel_image.png")
		pixel = blend_image_with_color(pixel, right_color_picker.color, 1)
		right_brush_type_button.get_child(0).texture.create_from_image(pixel)
	else:
		var custom_brush := Image.new()
		custom_brush.copy_from(custom_brushes[custom_right_brush_index])
		var custom_brush_size = custom_brush.get_size()
		custom_brush.resize(custom_brush_size.x * right_brush_size, custom_brush_size.y * right_brush_size, Image.INTERPOLATE_NEAREST)
		custom_right_brush_image = blend_image_with_color(custom_brush, right_color_picker.color, right_interpolate_slider.value / 100)
		custom_right_brush_texture.create_from_image(custom_right_brush_image, 0)

		right_brush_type_button.get_child(0).texture = custom_right_brush_texture

func blend_image_with_color(image : Image, color : Color, interpolate_factor : float) -> Image:
	var blended_image := Image.new()
	blended_image.copy_from(image)
	var size := image.get_size()
	blended_image.lock()
	for xx in size.x:
		for yy in size.y:
			if color.a > 0: #If it's the pencil
				var current_color := blended_image.get_pixel(xx, yy)
				if current_color.a > 0:
					var new_color := current_color.linear_interpolate(color, interpolate_factor)
					blended_image.set_pixel(xx, yy, new_color)
			else: #If color is transparent - if it's the eraser
				blended_image.set_pixel(xx, yy, Color(0, 0, 0, 0))
	return blended_image

func _exit_tree() -> void:
	config_cache.set_value("window", "screen", OS.current_screen)
	config_cache.set_value("window", "maximized", OS.window_maximized || OS.window_fullscreen)
	config_cache.set_value("window", "position", OS.window_position)
	config_cache.set_value("window", "size", OS.window_size)
	config_cache.save("user://cache.ini")

	# Thanks to qarmin from GitHub for pointing this out
	undo_redo.free()
