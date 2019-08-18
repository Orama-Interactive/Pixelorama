extends Node

# warning-ignore:unused_class_variable
var can_draw := false
# warning-ignore:unused_class_variable
var has_focus := true
var canvas : Canvas
var canvas_parent
var left_color_picker : ColorPickerButton
var right_color_picker : ColorPickerButton
var file_menu : MenuButton
var edit_menu : MenuButton
var left_indicator : Sprite
var right_indicator : Sprite
var vbox_layer_container : VBoxContainer
var remove_layer_button : Button
var move_up_layer_button : Button
var move_down_layer_button : Button
var merge_down_layer_button : Button
# warning-ignore:unused_class_variable
var current_left_tool := "Pencil"
# warning-ignore:unused_class_variable
var current_right_tool := "Eraser"

func _ready() -> void:
	var root = get_tree().get_root()
	canvas = find_node_by_name(root, "Canvas")
	canvas_parent = canvas.get_parent()
	left_color_picker = find_node_by_name(root, "LeftColorPickerButton")
	right_color_picker = find_node_by_name(root, "RightColorPickerButton")
	file_menu = find_node_by_name(root, "FileMenu")
	edit_menu = find_node_by_name(root, "EditMenu")
	left_indicator = find_node_by_name(root, "LeftIndicator")
	right_indicator = find_node_by_name(root, "RightIndicator")
	vbox_layer_container = find_node_by_name(root, "VBoxLayerContainer")
	remove_layer_button = find_node_by_name(root, "RemoveLayerButton")
	move_up_layer_button = find_node_by_name(root, "MoveUpLayer")
	move_down_layer_button = find_node_by_name(root, "MoveDownLayer")
	merge_down_layer_button = find_node_by_name(root, "MergeDownLayer")

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