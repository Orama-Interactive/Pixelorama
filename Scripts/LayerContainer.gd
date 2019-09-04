extends PanelContainer

var i
# warning-ignore:unused_class_variable
var currently_selected := false
var visibility_toggled := false

func _ready() -> void:
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color("3d3b45")
	add_stylebox_override("panel", stylebox)
	changed_selection()

# warning-ignore:unused_argument
func _process(delta) -> void:
	var mouse_pos := get_local_mouse_position() + rect_position
	if point_in_rectangle(mouse_pos, rect_position, rect_position + rect_size) && !visibility_toggled:
		if Input.is_action_just_pressed("left_mouse"):
			Global.canvas.current_layer_index = i
			changed_selection()

func changed_selection() -> void:
	var parent = get_parent()
	for child in parent.get_children():
		if child is PanelContainer:
			if Global.canvas.current_layer_index == child.i:
				child.currently_selected = true
				child.get_stylebox("panel").bg_color = Color("282532")
				
				if Global.canvas.current_layer_index < Global.canvas.layers.size() - 1:
					Global.move_up_layer_button.disabled = false
					Global.move_up_layer_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				else:
					Global.move_up_layer_button.disabled = true
					Global.move_up_layer_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
					
				if Global.canvas.current_layer_index > 0:
					Global.move_down_layer_button.disabled = false
					Global.move_down_layer_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					Global.merge_down_layer_button.disabled = false
					Global.merge_down_layer_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				else:
					Global.move_down_layer_button.disabled = true
					Global.move_down_layer_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
					Global.merge_down_layer_button.disabled = true
					Global.merge_down_layer_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
			else:
				child.currently_selected = false
				child.get_stylebox("panel").bg_color = Color("3d3b45")

func point_in_rectangle(p : Vector2, coord1 : Vector2, coord2 : Vector2) -> bool:
	return p.x > coord1.x && p.y > coord1.y && p.x < coord2.x && p.y < coord2.y

func _on_VisibilityButton_pressed() -> void:
	if Global.canvas.layers[i][3]:
		Global.canvas.layers[i][3] = false
		get_child(0).get_child(0).text = "I"
	else:
		Global.canvas.layers[i][3] = true
		get_child(0).get_child(0).text = "V"


func _on_VisibilityButton_button_down() -> void:
	visibility_toggled = true

func _on_VisibilityButton_button_up() -> void:
	visibility_toggled = false