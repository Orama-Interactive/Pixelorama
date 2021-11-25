extends GridContainer

var tooltips := []

# Node, shortcut
onready var tools := [
	[$RectSelect, "rectangle_select"],
	[$EllipseSelect, "ellipse_select"],
	[$PolygonSelect, "polygon_select"],
	[$ColorSelect, "color_select"],
	[$MagicWand, "magic_wand"],
	[$Lasso, "lasso"],
	[$Move, "move"],
	[$Zoom, "zoom"],
	[$Pan, "pan"],
	[$ColorPicker, "colorpicker"],
	[$Pencil, "pencil", "Shift"],
	[$Eraser, "eraser", "Shift"],
	[$Bucket, "fill"],
	[$Shading, "shading"],
	[$LineTool, "linetool", "Shift", "Ctrl", "Alt"],
	[$RectangleTool, "rectangletool", "Shift", "Ctrl", "Alt"],
	[$EllipseTool, "ellipsetool", "Shift", "Ctrl", "Alt"],
]


func _ready() -> void:
	for t in tools:
		t[0].connect("pressed", self, "_on_Tool_pressed", [t[0]])
		tooltips.append(t[0].hint_tooltip)

	# Resize tools panel when window gets resized
	get_tree().get_root().connect("size_changed", self, "_on_ToolsAndCanvas_dragged")


func update_hintooltips() -> void:
	for i in tools.size():
		var toolname: String = tools[i][1]
		var shortcuts := []
		shortcuts.append(InputMap.get_action_list("left_" + toolname + "_tool")[0].as_text())
		shortcuts.append(InputMap.get_action_list("right_" + toolname + "_tool")[0].as_text())
		for j in range(2, tools[i].size()):
			shortcuts.append(tools[i][j])
		tools[i][0].hint_tooltip = tr(tooltips[i]) % shortcuts


func _input(event: InputEvent) -> void:
	if not Global.has_focus or not event is InputEventKey:
		return
	for action in ["undo", "redo", "redo_secondary"]:
		if event.is_action_pressed(action):
			return

	for t in tools:  # Handle tool shortcuts
		if event.is_action_pressed("right_" + t[1] + "_tool") and !event.control:
			# Shortcut for right button (with Alt)
			Tools.assign_tool(t[0].name, BUTTON_RIGHT)
		elif event.is_action_pressed("left_" + t[1] + "_tool") and !event.control:
			# Shortcut for left button
			Tools.assign_tool(t[0].name, BUTTON_LEFT)


func _on_Tool_pressed(tool_pressed: BaseButton) -> void:
	var button := -1
	button = BUTTON_LEFT if Input.is_action_just_released("left_mouse") else button
	button = BUTTON_RIGHT if Input.is_action_just_released("right_mouse") else button
	if button != -1:
		Tools.assign_tool(tool_pressed.name, button)


func _on_ToolsAndCanvas_dragged(_offset: int = 0) -> void:
	var tool_panel_size: Vector2 = get_parent().get_parent().get_parent().rect_size
	if Global.tool_button_size == Global.ButtonSize.SMALL:
		columns = tool_panel_size.x / 28.5
	else:
		columns = tool_panel_size.x / 36.5

	# It doesn't actually set the size to zero, it just resets it
	get_parent().rect_size = Vector2.ZERO
