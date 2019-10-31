extends Node

var undo_redo : UndoRedo
var undos := 0 #The number of times we added undo properties
var current_frame := 0 setget set_current_frame_label
# warning-ignore:unused_class_variable
var can_draw := false
# warning-ignore:unused_class_variable
var has_focus := false
# warning-ignore:unused_class_variable
var onion_skinning_past_rate := 0
# warning-ignore:unused_class_variable
var onion_skinning_future_rate := 0
# warning-ignore:unused_class_variable
var onion_skinning_blue_red := false
# warning-ignore:unused_class_variable
var tile_mode := false
# warning-ignore:unused_class_variable
var draw_grid := false
var canvases := []
var canvas : Canvas
var canvas_parent : Node
var second_viewport : ViewportContainer
var viewport_separator : VSeparator
var split_screen_button : Button
# warning-ignore:unused_class_variable
var left_square_indicator_visible := true
# warning-ignore:unused_class_variable
var right_square_indicator_visible := false
var camera : Camera2D
var camera2 : Camera2D
var selection_rectangle : Polygon2D
# warning-ignore:unused_class_variable
var selected_pixels := []
var image_clipboard : Image

var file_menu : MenuButton
var edit_menu : MenuButton
var view_menu : MenuButton
var help_menu : MenuButton
var left_indicator : Sprite
var right_indicator : Sprite
var left_color_picker : ColorPickerButton
var right_color_picker : ColorPickerButton
var left_brush_size_edit : SpinBox
var right_brush_size_edit : SpinBox
var left_interpolate_slider : HSlider
var right_interpolate_slider : HSlider
var left_brush_indicator : Sprite
var right_brush_indicator : Sprite

var loop_animation_button : Button
var play_forward : Button
var play_backwards : Button
var frame_container : HBoxContainer
var remove_frame_button : Button
var move_left_frame_button : Button
var move_right_frame_button : Button
var vbox_layer_container : VBoxContainer
var remove_layer_button : Button
var move_up_layer_button : Button
var move_down_layer_button : Button
var merge_down_layer_button : Button
var cursor_position_label : Label
var zoom_level_label : Label
var current_frame_label : Label
# warning-ignore:unused_class_variable
var current_left_tool := "Pencil"
# warning-ignore:unused_class_variable
var current_right_tool := "Eraser"

#Brushes
enum BRUSH_TYPES {PIXEL, CUSTOM}
# warning-ignore:unused_class_variable
var left_brush_size := 1
# warning-ignore:unused_class_variable
var right_brush_size := 1
# warning-ignore:unused_class_variable
var current_left_brush_type = BRUSH_TYPES.PIXEL
# warning-ignore:unused_class_variable
var current_right_brush_type = BRUSH_TYPES.PIXEL
# warning-ignore:unused_class_variable
var left_horizontal_mirror := false
# warning-ignore:unused_class_variable
var left_vertical_mirror := false
# warning-ignore:unused_class_variable
var right_horizontal_mirror := false
# warning-ignore:unused_class_variable
var right_vertical_mirror := false
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


func _ready() -> void:
	undo_redo = UndoRedo.new()
	var root = get_tree().get_root()
	canvas = find_node_by_name(root, "Canvas")
	canvases.append(canvas)
	canvas_parent = canvas.get_parent()
	second_viewport = find_node_by_name(root, "ViewportContainer2")
	viewport_separator = find_node_by_name(root, "ViewportSeparator")
	split_screen_button = find_node_by_name(root, "SplitScreenButton")
	camera = find_node_by_name(canvas_parent, "Camera2D")
	camera2 = find_node_by_name(canvas_parent.get_parent().get_parent(), "Camera2D2")

	selection_rectangle = find_node_by_name(root, "SelectionRectangle")
	image_clipboard = Image.new()

	file_menu = find_node_by_name(root, "FileMenu")
	edit_menu = find_node_by_name(root, "EditMenu")
	view_menu = find_node_by_name(root, "ViewMenu")
	help_menu = find_node_by_name(root, "HelpMenu")
	left_indicator = find_node_by_name(root, "LeftIndicator")
	right_indicator = find_node_by_name(root, "RightIndicator")
	left_color_picker = find_node_by_name(root, "LeftColorPickerButton")
	right_color_picker = find_node_by_name(root, "RightColorPickerButton")
	left_brush_size_edit = find_node_by_name(root, "LeftBrushSizeEdit")
	right_brush_size_edit = find_node_by_name(root, "RightBrushSizeEdit")
	left_interpolate_slider = find_node_by_name(root, "LeftInterpolateFactor")
	right_interpolate_slider = find_node_by_name(root, "RightInterpolateFactor")

	left_brush_indicator = find_node_by_name(root, "LeftBrushIndicator")
	right_brush_indicator = find_node_by_name(root, "RightBrushIndicator")

	loop_animation_button = find_node_by_name(root, "LoopAnim")
	play_forward = find_node_by_name(root, "PlayForward")
	play_backwards = find_node_by_name(root, "PlayBackwards")
	frame_container = find_node_by_name(root, "FrameContainer")
	remove_frame_button = find_node_by_name(root, "RemoveFrame")
	move_left_frame_button = find_node_by_name(root, "MoveFrameLeft")
	move_right_frame_button = find_node_by_name(root, "MoveFrameRight")
	vbox_layer_container = find_node_by_name(root, "VBoxLayerContainer")
	remove_layer_button = find_node_by_name(root, "RemoveLayerButton")
	move_up_layer_button = find_node_by_name(root, "MoveUpLayer")
	move_down_layer_button = find_node_by_name(root, "MoveDownLayer")
	merge_down_layer_button = find_node_by_name(root, "MergeDownLayer")
	cursor_position_label = find_node_by_name(root, "CursorPosition")
	zoom_level_label = find_node_by_name(root, "ZoomLevel")
	current_frame_label = find_node_by_name(root, "CurrentFrame")

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

func undo(canvas : Canvas, layer_index : int) -> void:
	undos -= 1
	var action_name : String = undo_redo.get_current_action_name()
	if action_name == "Draw" || action_name == "Rectangle Select":
		canvas.update_texture(layer_index)
	print("Undo: ", action_name)

func redo(canvas : Canvas, layer_index : int) -> void:
	if undos < undo_redo.get_version(): #If we did undo and then redo
		undos = undo_redo.get_version()
	var action_name : String = undo_redo.get_current_action_name()
	if action_name == "Draw" || action_name == "Rectangle Select":
		canvas.update_texture(layer_index)
	print("Redo: ", action_name)

func change_frame() -> void:
	for c in canvases:
		c.visible = false
	canvas = canvases[current_frame]
	canvas.visible = true
	canvas.generate_layer_panels()
	handle_layer_order_buttons()

func handle_layer_order_buttons() -> void:
	if current_frame == 0:
		move_left_frame_button.disabled = true
		move_left_frame_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	else:
		move_left_frame_button.disabled = false
		move_left_frame_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if current_frame == canvases.size() - 1:
		move_right_frame_button.disabled = true
		move_right_frame_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	else:
		move_right_frame_button.disabled = false
		move_right_frame_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func set_current_frame_label(value) -> void:
	current_frame = value
	current_frame_label.text = "Current frame: %s/%s" % [str(current_frame + 1), canvases.size()]

func create_brush_button(brush_img : Image) -> void:
	var brush_button = load("res://Prefabs/BrushButton.tscn").instance()
	brush_button.brush_type = BRUSH_TYPES.CUSTOM
	brush_button.custom_brush_index = custom_brushes.size() - 1
	var brush_tex := ImageTexture.new()
	brush_tex.create_from_image(brush_img, 0)
	brush_button.get_child(0).texture = brush_tex
	var hbox_container := find_node_by_name(get_tree().get_root(), "BrushHBoxContainer")
	hbox_container.add_child(brush_button)

func remove_brush_buttons() -> void:
	var hbox_container := find_node_by_name(get_tree().get_root(), "BrushHBoxContainer")
	for child in hbox_container.get_children():
		if child.name != "PixelBrushButton":
			hbox_container.remove_child(child)
#	for i in range(0, hbox_container.get_child_count() - 1):
#		hbox_container.remove_child(hbox_container.get_child(i))

func update_left_custom_brush() -> void:
	if custom_left_brush_index > -1:
		var custom_brush := Image.new()
		custom_brush.copy_from(custom_brushes[custom_left_brush_index])
		var custom_brush_size = custom_brush.get_size()
		custom_brush.resize(custom_brush_size.x * left_brush_size, custom_brush_size.y * left_brush_size, Image.INTERPOLATE_NEAREST)
		custom_left_brush_image = blend_image_with_color(custom_brush, left_color_picker.color, left_interpolate_slider.value)
		custom_left_brush_texture.create_from_image(custom_left_brush_image, 0)

func update_right_custom_brush() -> void:
	if custom_right_brush_index > -1:
		var custom_brush := Image.new()
		custom_brush.copy_from(custom_brushes[custom_right_brush_index])
		var custom_brush_size = custom_brush.get_size()
		custom_brush.resize(custom_brush_size.x * right_brush_size, custom_brush_size.y * right_brush_size, Image.INTERPOLATE_NEAREST)
		custom_right_brush_image = blend_image_with_color(custom_brush, right_color_picker.color, right_interpolate_slider.value)
		custom_right_brush_texture.create_from_image(custom_right_brush_image, 0)

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
					#var blended_color = current_color.blend(color)
					var new_color := current_color.linear_interpolate(color, interpolate_factor)
					blended_image.set_pixel(xx, yy, new_color)
			else: #If color is transparent - if it's the eraser
				blended_image.set_pixel(xx, yy, Color(0, 0, 0, 0))
	return blended_image
