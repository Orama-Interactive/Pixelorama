extends Node

var current_frame := 0 setget set_current_frame_label
# warning-ignore:unused_class_variable
var can_draw := false
# warning-ignore:unused_class_variable
var has_focus := true
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
# warning-ignore:unused_class_variable
var left_square_indicator_visible := true
# warning-ignore:unused_class_variable
var right_square_indicator_visible := false
# warning-ignore:unused_class_variable
var left_brush_size := 1
# warning-ignore:unused_class_variable
var right_brush_size := 1
var camera : Camera2D
var selection_rectangle : Polygon2D
var selected_pixels := []
var image_clipboard : Image

var file_menu : MenuButton
var edit_menu : MenuButton
var view_menu : MenuButton
var left_indicator : Sprite
var right_indicator : Sprite
var left_color_picker : ColorPickerButton
var right_color_picker : ColorPickerButton
var left_brush_size_edit : SpinBox
var right_brush_size_edit : SpinBox
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

func _ready() -> void:
	var root = get_tree().get_root()
	canvas = find_node_by_name(root, "Canvas")
	canvases.append(canvas)
	canvas_parent = canvas.get_parent()
	camera = find_node_by_name(canvas_parent, "Camera2D")
	
	selection_rectangle = find_node_by_name(root, "SelectionRectangle")
	image_clipboard = Image.new()
	
	file_menu = find_node_by_name(root, "FileMenu")
	edit_menu = find_node_by_name(root, "EditMenu")
	view_menu = find_node_by_name(root, "ViewMenu")
	left_indicator = find_node_by_name(root, "LeftIndicator")
	right_indicator = find_node_by_name(root, "RightIndicator")
	left_color_picker = find_node_by_name(root, "LeftColorPickerButton")
	right_color_picker = find_node_by_name(root, "RightColorPickerButton")
	left_brush_size_edit = find_node_by_name(root, "LeftBrushSizeEdit")
	right_brush_size_edit = find_node_by_name(root, "RightBrushSizeEdit")
	
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