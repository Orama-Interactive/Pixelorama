extends FlowContainer

var pen_inverted := false


func _ready() -> void:
	# Ensure to only call _input() if the cursor is inside the main canvas viewport
	Global.main_viewport.mouse_entered.connect(set_process_input.bind(true))
	Global.main_viewport.mouse_exited.connect(set_process_input.bind(false))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pen_inverted = event.pen_inverted
		return
	if not Global.can_draw:
		return
	if get_tree().current_scene.is_writing_text:
		return
	for action in ["undo", "redo"]:
		if event.is_action_pressed(action):
			return

	if event.is_action_pressed("swap_tools"):
		Tools.swap_tools()

	for tool_name in Tools.tools:  # Handle tool shortcuts
		if not get_node(tool_name).visible:
			continue
		var t: Tools.Tool = Tools.tools[tool_name]
		var right_tool_shortcut := "right_" + t.shortcut + "_tool"
		var left_tool_shortcut := "left_" + t.shortcut + "_tool"
		if not Global.single_tool_mode and InputMap.has_action(right_tool_shortcut):
			if event.is_action_pressed(right_tool_shortcut, false, true):
				# Shortcut for right button (with Alt)
				Tools.assign_tool(t.name, MOUSE_BUTTON_RIGHT)
				return
		if InputMap.has_action(left_tool_shortcut):
			if event.is_action_pressed(left_tool_shortcut, false, true):
				# Shortcut for left button
				Tools.assign_tool(t.name, MOUSE_BUTTON_LEFT)
				return


func _on_tool_pressed(tool_pressed: BaseButton) -> void:
	var button := -1
	button = MOUSE_BUTTON_LEFT if Input.is_action_just_released("left_mouse") else button
	if not Global.single_tool_mode:
		button = (
			MOUSE_BUTTON_RIGHT
			if (
				Input.is_action_just_released("right_mouse")
				or (pen_inverted and Input.is_action_just_released("left_mouse"))
			)
			else button
		)
	if button != -1:
		Tools.assign_tool(tool_pressed.name, button)
