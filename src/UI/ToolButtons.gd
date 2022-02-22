extends GridContainer


func _ready() -> void:
	# Resize tools panel when window gets resized
	get_tree().get_root().connect("size_changed", self, "_on_Tools_resized")


func _input(event: InputEvent) -> void:
	if not Global.has_focus or not event is InputEventKey:
		return
	for action in ["undo", "redo", "redo_secondary"]:
		if event.is_action_pressed(action):
			return

	for tool_name in Tools.tools:  # Handle tool shortcuts
		var t: Tools.Tool = Tools.tools[tool_name]
		if InputMap.has_action("right_" + t.shortcut + "_tool"):
			if event.is_action_pressed("right_" + t.shortcut + "_tool") and !event.control:
				# Shortcut for right button (with Alt)
				Tools.assign_tool(t.name, BUTTON_RIGHT)
				return
		if InputMap.has_action("left_" + t.shortcut + "_tool"):
			if event.is_action_pressed("left_" + t.shortcut + "_tool") and !event.control:
				# Shortcut for left button
				Tools.assign_tool(t.name, BUTTON_LEFT)
				return


func _on_Tool_pressed(tool_pressed: BaseButton) -> void:
	var button := -1
	button = BUTTON_LEFT if Input.is_action_just_released("left_mouse") else button
	button = BUTTON_RIGHT if Input.is_action_just_released("right_mouse") else button
	if button != -1:
		Tools.assign_tool(tool_pressed.name, button)


func _on_Tools_resized() -> void:
	var tool_panel_size: Vector2 = get_parent().get_parent().rect_size
	var column_n = tool_panel_size.x / 28.5
	if Global.tool_button_size == Global.ButtonSize.BIG:
		column_n = tool_panel_size.x / 36.5

	if column_n < 1:
		column_n = 1
	columns = column_n
