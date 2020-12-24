extends VBoxContainer


# Node, shortcut
onready var tools := [
	[$RectSelect, "rectangle_select"],
	[$Zoom, "zoom"],
	[$Pan, "pan"],
	[$ColorPicker, "colorpicker"],
	[$Pencil, "pencil"],
	[$Eraser, "eraser"],
	[$Bucket, "fill"],
	[$LightenDarken, "lightdark"],
]


func _ready() -> void:
	for t in tools:
		t[0].connect("pressed", self, "_on_Tool_pressed", [t[0]])
	Global.update_hint_tooltips()


func _input(event : InputEvent) -> void:
	if not Global.has_focus:
		return
	for action in ["undo", "redo", "redo_secondary"]:
		if event.is_action_pressed(action):
			return
	for t in tools: # Handle tool shortcuts
		if event.is_action_pressed("right_" + t[1] + "_tool") and !event.control: # Shortcut for right button (with Alt)
			Tools.assign_tool(t[0].name, BUTTON_RIGHT)
		elif event.is_action_pressed("left_" + t[1] + "_tool") and !event.control: # Shortcut for left button
			Tools.assign_tool(t[0].name, BUTTON_LEFT)


func _on_Tool_pressed(tool_pressed : BaseButton) -> void:
	var button := -1
	button = BUTTON_LEFT if Input.is_action_just_released("left_mouse") else button
	button = BUTTON_RIGHT if Input.is_action_just_released("right_mouse") else button
	if button != -1:
		Tools.assign_tool(tool_pressed.name, button)
