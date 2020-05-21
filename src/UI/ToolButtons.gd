extends VBoxContainer


var tools := []


func _ready() -> void:
	# Node, left mouse shortcut, right mouse shortcut
	tools.append([Global.find_node_by_name(self, "Pencil"), "left_pencil_tool", "right_pencil_tool"])
	tools.append([Global.find_node_by_name(self, "Eraser"), "left_eraser_tool", "right_eraser_tool"])
	tools.append([Global.find_node_by_name(self, "Bucket"), "left_fill_tool", "right_fill_tool"])
	tools.append([Global.find_node_by_name(self, "LightenDarken"), "left_lightdark_tool", "right_lightdark_tool"])
	tools.append([Global.find_node_by_name(self, "RectSelect"), "left_rectangle_select_tool", "right_rectangle_select_tool"])
	tools.append([Global.find_node_by_name(self, "ColorPicker"), "left_colorpicker_tool", "right_colorpicker_tool"])
	tools.append([Global.find_node_by_name(self, "Zoom"), "left_zoom_tool", "right_zoom_tool"])

	for t in tools:
		t[0].connect("pressed", self, "_on_Tool_pressed", [t[0]])

	Global.update_hint_tooltips()


func _input(event : InputEvent) -> void:
	if Global.has_focus:
		if event.is_action_pressed("undo") or event.is_action_pressed("redo") or event.is_action_pressed("redo_secondary"):
			return
		for t in tools: # Handle tool shortcuts
			if event.is_action_pressed(t[2]): # Shortcut for right button (with Alt)
				_on_Tool_pressed(t[0], false, false)
			elif event.is_action_pressed(t[1]): # Shortcut for left button
				_on_Tool_pressed(t[0], false, true)


func _on_Tool_pressed(tool_pressed : BaseButton, mouse_press := true, key_for_left := true) -> void:
	var current_action := tool_pressed.name
	if (mouse_press and Input.is_action_just_released("left_mouse")) or (!mouse_press and key_for_left):
		Global.current_left_tool = current_action

		# Start from 1, so the label won't get invisible
		for i in range(1, Global.left_tool_options_container.get_child_count()):
			Global.left_tool_options_container.get_child(i).visible = false

		Global.left_tool_options_container.get_node("EmptySpacer").visible = true

		# Tool options visible depending on the selected tool
		if current_action == "Pencil":
			Global.left_brush_type_container.visible = true
			Global.left_brush_size_slider.visible = true
			Global.left_pixel_perfect_container.visible = true
			Global.left_mirror_container.visible = true
			if Global.current_left_brush_type == Global.Brush_Types.FILE or Global.current_left_brush_type == Global.Brush_Types.CUSTOM or Global.current_left_brush_type == Global.Brush_Types.RANDOM_FILE:
				Global.left_color_interpolation_container.visible = true
		elif current_action == "Eraser":
			Global.left_brush_type_container.visible = true
			Global.left_brush_size_slider.visible = true
			Global.left_pixel_perfect_container.visible = true
			Global.left_mirror_container.visible = true
		elif current_action == "Bucket":
			Global.left_fill_area_container.visible = true
			Global.left_mirror_container.visible = true
		elif current_action == "LightenDarken":
			Global.left_brush_type_container.visible = true
			Global.left_brush_size_slider.visible = true
			Global.left_pixel_perfect_container.visible = true
			Global.left_ld_container.visible = true
			Global.left_mirror_container.visible = true
		elif current_action == "ColorPicker":
			Global.left_colorpicker_container.visible = true
		elif current_action == "Zoom":
			Global.left_zoom_container.visible = true

	elif (mouse_press and Input.is_action_just_released("right_mouse")) or (!mouse_press and !key_for_left):
		Global.current_right_tool = current_action
		# Start from 1, so the label won't get invisible
		for i in range(1, Global.right_tool_options_container.get_child_count()):
			Global.right_tool_options_container.get_child(i).visible = false

		Global.right_tool_options_container.get_node("EmptySpacer").visible = true

		# Tool options visible depending on the selected tool
		if current_action == "Pencil":
			Global.right_brush_type_container.visible = true
			Global.right_brush_size_slider.visible = true
			Global.right_pixel_perfect_container.visible = true
			Global.right_mirror_container.visible = true
			if Global.current_right_brush_type == Global.Brush_Types.FILE or Global.current_right_brush_type == Global.Brush_Types.CUSTOM or Global.current_right_brush_type == Global.Brush_Types.RANDOM_FILE:
				Global.right_color_interpolation_container.visible = true
		elif current_action == "Eraser":
			Global.right_brush_type_container.visible = true
			Global.right_brush_size_slider.visible = true
			Global.right_pixel_perfect_container.visible = true
			Global.right_mirror_container.visible = true
		elif current_action == "Bucket":
			Global.right_fill_area_container.visible = true
			Global.right_mirror_container.visible = true
		elif current_action == "LightenDarken":
			Global.right_brush_type_container.visible = true
			Global.right_brush_size_slider.visible = true
			Global.right_pixel_perfect_container.visible = true
			Global.right_ld_container.visible = true
			Global.right_mirror_container.visible = true
		elif current_action == "ColorPicker":
			Global.right_colorpicker_container.visible = true
		elif current_action == "Zoom":
			Global.right_zoom_container.visible = true

	for t in tools:
		var tool_name : String = t[0].name
		var texture_button : TextureRect = t[0].get_child(0)

		if tool_name == Global.current_left_tool and tool_name == Global.current_right_tool:
			Global.change_button_texturerect(texture_button, "%s_l_r.png" % tool_name.to_lower())
		elif tool_name == Global.current_left_tool:
			Global.change_button_texturerect(texture_button, "%s_l.png" % tool_name.to_lower())
		elif tool_name == Global.current_right_tool:
			Global.change_button_texturerect(texture_button, "%s_r.png" % tool_name.to_lower())
		else:
			Global.change_button_texturerect(texture_button, "%s.png" % tool_name.to_lower())

	Global.left_cursor_tool_texture.create_from_image(load("res://assets/graphics/cursor_icons/%s_cursor.png" % Global.current_left_tool.to_lower()), 0)
	Global.right_cursor_tool_texture.create_from_image(load("res://assets/graphics/cursor_icons/%s_cursor.png" % Global.current_right_tool.to_lower()), 0)
