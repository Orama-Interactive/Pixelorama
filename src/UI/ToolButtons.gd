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
	var current_tool : int = Global.Tools.keys().find(current_action.to_upper())
	var left_tool_name := str(Global.Tools.keys()[Global.current_left_tool]).to_lower()
	var right_tool_name := str(Global.Tools.keys()[Global.current_right_tool]).to_lower()
	var current_mouse_button := -1

	if (mouse_press and Input.is_action_just_released("left_mouse")) or (!mouse_press and key_for_left):
		Global.current_left_tool = current_tool
		left_tool_name = current_action.to_lower()
		current_mouse_button = Global.Mouse_Button.LEFT

	elif (mouse_press and Input.is_action_just_released("right_mouse")) or (!mouse_press and !key_for_left):
		Global.current_right_tool = current_tool
		right_tool_name = current_action.to_lower()
		current_mouse_button = Global.Mouse_Button.RIGHT

	if current_mouse_button != -1:
		# Start from 1, so the label won't get invisible
		for i in range(1, Global.tool_options_containers[current_mouse_button].get_child_count()):
			Global.tool_options_containers[current_mouse_button].get_child(i).visible = false

		Global.tool_options_containers[current_mouse_button].get_node("EmptySpacer").visible = true

		# Tool options visible depending on the selected tool
		if current_tool == Global.Tools.PENCIL:
			Global.brush_type_containers[current_mouse_button].visible = true
			Global.brush_size_sliders[current_mouse_button].visible = true
			Global.pixel_perfect_containers[current_mouse_button].visible = true
			Global.mirror_containers[current_mouse_button].visible = true
			if Global.current_brush_types[current_mouse_button] == Global.Brush_Types.FILE or Global.current_brush_types[current_mouse_button] == Global.Brush_Types.CUSTOM or Global.current_brush_types[current_mouse_button] == Global.Brush_Types.RANDOM_FILE:
				Global.color_interpolation_containers[current_mouse_button].visible = true
		elif current_tool == Global.Tools.ERASER:
			Global.brush_type_containers[current_mouse_button].visible = true
			Global.brush_size_sliders[current_mouse_button].visible = true
			Global.pixel_perfect_containers[current_mouse_button].visible = true
			Global.mirror_containers[current_mouse_button].visible = true
		elif current_tool == Global.Tools.BUCKET:
			Global.fill_area_containers[current_mouse_button].visible = true
			Global.mirror_containers[current_mouse_button].visible = true
		elif current_tool == Global.Tools.LIGHTENDARKEN:
			Global.brush_type_containers[current_mouse_button].visible = true
			Global.brush_size_sliders[current_mouse_button].visible = true
			Global.pixel_perfect_containers[current_mouse_button].visible = true
			Global.ld_containers[current_mouse_button].visible = true
			Global.mirror_containers[current_mouse_button].visible = true
		elif current_tool == Global.Tools.COLORPICKER:
			Global.colorpicker_containers[current_mouse_button].visible = true
		elif current_tool == Global.Tools.ZOOM:
			Global.zoom_containers[current_mouse_button].visible = true

	for t in tools:
		var tool_name : String = t[0].name.to_lower()
		var texture_button : TextureRect = t[0].get_child(0)

		if tool_name == left_tool_name and tool_name == right_tool_name:
			Global.change_button_texturerect(texture_button, "%s_l_r.png" % tool_name.to_lower())
		elif tool_name == left_tool_name:
			Global.change_button_texturerect(texture_button, "%s_l.png" % tool_name.to_lower())
		elif tool_name == right_tool_name:
			Global.change_button_texturerect(texture_button, "%s_r.png" % tool_name.to_lower())
		else:
			Global.change_button_texturerect(texture_button, "%s.png" % tool_name.to_lower())

	Global.left_cursor_tool_texture.create_from_image(load("res://assets/graphics/cursor_icons/%s_cursor.png" % left_tool_name), 0)
	Global.right_cursor_tool_texture.create_from_image(load("res://assets/graphics/cursor_icons/%s_cursor.png" % right_tool_name), 0)
