extends FlowContainer

var pen_inverted := false
## Fixes tools accidentally being switched through shortcuts when user types on a line edit.
var _ignore_shortcuts := false


func _ready() -> void:
	# Ensure to only call _input() if the cursor is inside the main canvas viewport
	Global.main_viewport.mouse_entered.connect(func(): _ignore_shortcuts = false)
	Global.main_viewport.mouse_exited.connect(func(): _ignore_shortcuts = true)


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
	var tool_activated := (
		Input.is_action_pressed(&"activate_left_tool")
		or Input.is_action_pressed(&"activate_right_tool")
	)

	for tool_name in Tools.tools:  # Handle tool shortcuts
		if not get_node(tool_name).visible:
			continue
		var t: Tools.Tool = Tools.tools[tool_name]
		var right_tool_shortcut := "right_" + t.shortcut + "_tool"
		if not Global.single_tool_mode and InputMap.has_action(right_tool_shortcut):
			if event.is_action_pressed(right_tool_shortcut, false, true) and not _ignore_shortcuts:
				# Shortcut for right button (with Alt)
				Tools.assign_tool(t.name, MOUSE_BUTTON_RIGHT)
				return
		var left_tool_shortcut := "left_" + t.shortcut + "_tool"
		if InputMap.has_action(left_tool_shortcut):
			if event.is_action_pressed(left_tool_shortcut, false, true) and not _ignore_shortcuts:
				# Shortcut for left button
				Tools.assign_tool(t.name, MOUSE_BUTTON_LEFT)
				return

		var quick_tool_shortcut := "quick_" + t.shortcut + "_tool"
		if InputMap.has_action(quick_tool_shortcut):
			if (
				event.is_action_pressed(quick_tool_shortcut, false, true)
				and not tool_activated
				and not _ignore_shortcuts
			):
				Tools.quick_assign_tool(t.name, MOUSE_BUTTON_LEFT)
				return
			if event.is_action_released(quick_tool_shortcut):
				Tools.quick_assign_tool_revert(MOUSE_BUTTON_LEFT)
				return


func _on_tool_pressed(tool_pressed: BaseButton) -> void:
	var button := MOUSE_BUTTON_LEFT
	if not Global.single_tool_mode:
		button = (
			MOUSE_BUTTON_RIGHT
			if (
				Input.is_action_just_released("right_mouse")
				or (pen_inverted and Input.is_action_just_released("left_mouse"))
			)
			else button
		)
	if button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		Tools.assign_tool(tool_pressed.name, button)
