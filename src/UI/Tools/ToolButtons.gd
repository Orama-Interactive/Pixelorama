extends FlowContainer


func _input(event: InputEvent) -> void:
	if not Global.has_focus or not Global.can_draw:
		return
	if event is InputEventMouseMotion:
		return
	for action in ["undo", "redo"]:
		if event.is_action_pressed(action):
			return

	for tool_name in Tools.tools:  # Handle tool shortcuts
		var t: Tools.Tool = Tools.tools[tool_name]
		if InputMap.has_action("right_" + t.shortcut + "_tool"):
			if (
				event.is_action_pressed("right_" + t.shortcut + "_tool")
				and (!event.control and !event.command)
			):
				# Shortcut for right button (with Alt)
				Tools.assign_tool(t.name, BUTTON_RIGHT)
				return
		if InputMap.has_action("left_" + t.shortcut + "_tool"):
			if (
				event.is_action_pressed("left_" + t.shortcut + "_tool")
				and (!event.control and !event.command)
			):
				# Shortcut for left button
				Tools.assign_tool(t.name, BUTTON_LEFT)
				return


func _on_Tool_pressed(tool_pressed: BaseButton) -> void:
	var button := -1
	button = BUTTON_LEFT if Input.is_action_just_released("left_mouse") else button
	button = BUTTON_RIGHT if Input.is_action_just_released("right_mouse") else button
	if button != -1:
		Tools.assign_tool(tool_pressed.name, button)
