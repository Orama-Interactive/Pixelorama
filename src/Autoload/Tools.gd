extends Node

signal color_changed(color, button)

var pen_pressure := 1.0
var horizontal_mirror := false
var vertical_mirror := false
var pixel_perfect := false
var control := false
var shift := false
var alt := false

var tools := {
	"RectSelect":
	Tool.new(
		"RectSelect",
		"Rectangular Selection",
		"rectangle_select",
		preload("res://src/Tools/SelectionTools/RectSelect.tscn")
	),
	"EllipseSelect":
	Tool.new(
		"EllipseSelect",
		"Elliptical Selection",
		"ellipse_select",
		preload("res://src/Tools/SelectionTools/EllipseSelect.tscn")
	),
	"PolygonSelect":
	Tool.new(
		"PolygonSelect",
		"Polygonal Selection",
		"polygon_select",
		preload("res://src/Tools/SelectionTools/PolygonSelect.tscn"),
		"Double-click to connect the last point to the starting point"
	),
	"ColorSelect":
	Tool.new(
		"ColorSelect",
		"Select By Color",
		"color_select",
		preload("res://src/Tools/SelectionTools/ColorSelect.tscn")
	),
	"MagicWand":
	Tool.new(
		"MagicWand",
		"Magic Wand",
		"magic_wand",
		preload("res://src/Tools/SelectionTools/MagicWand.tscn")
	),
	"Lasso":
	Tool.new(
		"Lasso",
		"Lasso / Free Select Tool",
		"lasso",
		preload("res://src/Tools/SelectionTools/Lasso.tscn")
	),
	"Move": Tool.new("Move", "Move", "move", preload("res://src/Tools/Move.tscn")),
	"Zoom": Tool.new("Zoom", "Zoom", "zoom", preload("res://src/Tools/Zoom.tscn")),
	"Pan": Tool.new("Pan", "Pan", "pan", preload("res://src/Tools/Pan.tscn")),
	"ColorPicker":
	Tool.new(
		"ColorPicker",
		"Color Picker",
		"colorpicker",
		preload("res://src/Tools/ColorPicker.tscn"),
		"Select a color from a pixel of the sprite"
	),
	"Pencil":
	Tool.new(
		"Pencil",
		"Pencil",
		"pencil",
		preload("res://src/Tools/Pencil.tscn"),
		"Hold %s to make a line",
		["Shift"]
	),
	"Eraser":
	Tool.new(
		"Eraser",
		"Eraser",
		"eraser",
		preload("res://src/Tools/Eraser.tscn"),
		"Hold %s to make a line",
		["Shift"]
	),
	"Bucket": Tool.new("Bucket", "Bucket", "fill", preload("res://src/Tools/Bucket.tscn")),
	"Shading":
	Tool.new("Shading", "Shading Tool", "shading", preload("res://src/Tools/Shading.tscn")),
	"LineTool":
	Tool.new(
		"LineTool",
		"Line Tool",
		"linetool",
		preload("res://src/Tools/LineTool.tscn"),
		"""Hold %s to snap the angle of the line
Hold %s to center the shape on the click origin
Hold %s to displace the shape's origin""",
		["Shift", "Ctrl", "Alt"]
	),
	"RectangleTool":
	Tool.new(
		"RectangleTool",
		"Rectangle Tool",
		"rectangletool",
		preload("res://src/Tools/RectangleTool.tscn"),
		"""Hold %s to create a 1:1 shape
Hold %s to center the shape on the click origin
Hold %s to displace the shape's origin""",
		["Shift", "Ctrl", "Alt"]
	),
	"EllipseTool":
	Tool.new(
		"EllipseTool",
		"Ellipse Tool",
		"ellipsetool",
		preload("res://src/Tools/EllipseTool.tscn"),
		"""Hold %s to create a 1:1 shape
Hold %s to center the shape on the click origin
Hold %s to displace the shape's origin""",
		["Shift", "Ctrl", "Alt"]
	),
}

var _tool_button_scene: PackedScene = preload("res://src/Tools/ToolButton.tscn")
var _slots := {}
var _panels := {}
var _tool_buttons: Node
var _active_button := -1
var _last_position := Vector2.INF


class Tool:
	var name := ""
	var display_name := ""
	var scene: PackedScene
	var icon: Texture
	var cursor_icon: Texture
	var shortcut := ""
	var extra_hint := ""
	var extra_shortcuts := []  # Array of String(s)
	var button_node: BaseButton

	func _init(
		_name: String,
		_display_name: String,
		_shortcut: String,
		_scene: PackedScene,
		_extra_hint := "",
		_extra_shortucts := []
	) -> void:
		name = _name
		display_name = _display_name
		shortcut = _shortcut
		scene = _scene
		extra_hint = _extra_hint
		extra_shortcuts = _extra_shortucts
		icon = load("res://assets/graphics/tools/%s.png" % name.to_lower())
		cursor_icon = load("res://assets/graphics/tools/cursors/%s.png" % name.to_lower())

	func generate_hint_tooltip() -> String:
		var hint := display_name
		var shortcuts := []
		var left_text := ""
		var right_text := ""
		if InputMap.has_action("left_" + shortcut + "_tool"):
			var left_shortcut: String = InputMap.get_action_list("left_" + shortcut + "_tool")[0].as_text()
			shortcuts.append(left_shortcut)
			left_text = "\n%s for left mouse button"
		if InputMap.has_action("right_" + shortcut + "_tool"):
			var right_shortcut: String = InputMap.get_action_list("right_" + shortcut + "_tool")[0].as_text()
			shortcuts.append(right_shortcut)
			right_text = "\n%s for right mouse button"

		if !shortcuts.empty():
			hint += "\n" + left_text + right_text

		if !extra_hint.empty():
			hint += "\n\n" + extra_hint

		shortcuts.append_array(extra_shortcuts)
		if shortcuts.empty():
			hint = tr(hint)
		else:
			hint = tr(hint) % shortcuts
		return hint


class Slot:
	var name: String
	var kname: String
	var tool_node: Node = null
	var button: int
	var color: Color

	func _init(slot_name: String) -> void:
		name = slot_name
		kname = name.replace(" ", "_").to_lower()


func _ready() -> void:
	_tool_buttons = Global.control.find_node("ToolButtons")
	for t in tools:
		add_tool_button(tools[t])
	_slots[BUTTON_LEFT] = Slot.new("Left tool")
	_slots[BUTTON_RIGHT] = Slot.new("Right tool")
	_panels[BUTTON_LEFT] = Global.control.find_node("LeftPanelContainer", true, false)
	_panels[BUTTON_RIGHT] = Global.control.find_node("RightPanelContainer", true, false)

	var tool_name: String = Global.config_cache.get_value(
		_slots[BUTTON_LEFT].kname, "tool", "Pencil"
	)
	if not tool_name in tools:
		tool_name = "Pencil"
	set_tool(tool_name, BUTTON_LEFT)
	tool_name = Global.config_cache.get_value(_slots[BUTTON_RIGHT].kname, "tool", "Eraser")
	if not tool_name in tools:
		tool_name = "Eraser"
	set_tool(tool_name, BUTTON_RIGHT)

	update_tool_buttons()
	update_tool_cursors()

	horizontal_mirror = Global.config_cache.get_value("preferences", "horizontal_mirror", false)
	vertical_mirror = Global.config_cache.get_value("preferences", "vertical_mirror", false)
	pixel_perfect = Global.config_cache.get_value("preferences", "pixel_perfect", false)

	# Yield is necessary for the color picker nodes to update their color values
	yield(get_tree(), "idle_frame")
	var color_value: Color = Global.config_cache.get_value(
		_slots[BUTTON_LEFT].kname, "color", Color.black
	)
	assign_color(color_value, BUTTON_LEFT, false)
	color_value = Global.config_cache.get_value(_slots[BUTTON_RIGHT].kname, "color", Color.white)
	assign_color(color_value, BUTTON_RIGHT, false)


func add_tool_button(t: Tool) -> void:
	var tool_button: BaseButton = _tool_button_scene.instance()
	tool_button.name = t.name
	tool_button.get_node("ToolIcon").texture = t.icon
	tool_button.hint_tooltip = t.generate_hint_tooltip()
	t.button_node = tool_button
	_tool_buttons.add_child(tool_button)
	tool_button.connect("pressed", _tool_buttons, "_on_Tool_pressed", [tool_button])


func remove_tool(t: Tool) -> void:
	t.button_node.queue_free()
	tools.erase(t.name)


func set_tool(name: String, button: int) -> void:
	var slot = _slots[button]
	var panel: Node = _panels[button]
	var node: Node = tools[name].scene.instance()
	if button == BUTTON_LEFT:  # As guides are only moved with left mouse
		if name == "Pan":  # tool you want to give more access at guides
			Global.move_guides_on_canvas = true
		else:
			Global.move_guides_on_canvas = false
	node.name = name
	node.tool_slot = slot
	slot.tool_node = node
	slot.button = button
	panel.add_child(slot.tool_node)


func assign_tool(name: String, button: int) -> void:
	var slot = _slots[button]
	var panel: Node = _panels[button]

	if slot.tool_node != null:
		if slot.tool_node.name == name:
			return
		panel.remove_child(slot.tool_node)
		slot.tool_node.queue_free()

	set_tool(name, button)
	update_tool_buttons()
	update_tool_cursors()
	Global.config_cache.set_value(slot.kname, "tool", name)


func default_color() -> void:
	assign_color(Color.black, BUTTON_LEFT)
	assign_color(Color.white, BUTTON_RIGHT)


func swap_color() -> void:
	var left = _slots[BUTTON_LEFT].color
	var right = _slots[BUTTON_RIGHT].color
	assign_color(right, BUTTON_LEFT, false)
	assign_color(left, BUTTON_RIGHT, false)


func assign_color(color: Color, button: int, change_alpha := true) -> void:
	var c: Color = _slots[button].color
	# This was requested by Issue #54 on GitHub
	if color.a == 0 and change_alpha:
		if color.r != c.r or color.g != c.g or color.b != c.b:
			color.a = 1
	_slots[button].color = color
	Global.config_cache.set_value(_slots[button].kname, "color", color)
	emit_signal("color_changed", color, button)


func get_assigned_color(button: int) -> Color:
	return _slots[button].color


func set_button_size(button_size: int) -> void:
	if button_size == Global.ButtonSize.SMALL:
		for t in _tool_buttons.get_children():
			t.rect_min_size = Vector2(24, 24)
			t.get_node("BackgroundLeft").rect_size.x = 12
			t.get_node("BackgroundRight").rect_size.x = 12
			t.get_node("BackgroundRight").rect_position = Vector2(24, 24)
	else:
		for t in _tool_buttons.get_children():
			t.rect_min_size = Vector2(32, 32)
			t.get_node("BackgroundLeft").rect_size.x = 16
			t.get_node("BackgroundRight").rect_size.x = 16
			t.get_node("BackgroundRight").rect_position = Vector2(32, 32)


func update_tool_buttons() -> void:
	for child in _tool_buttons.get_children():
		var left_background: NinePatchRect = child.get_node("BackgroundLeft")
		var right_background: NinePatchRect = child.get_node("BackgroundRight")
		left_background.visible = _slots[BUTTON_LEFT].tool_node.name == child.name
		right_background.visible = _slots[BUTTON_RIGHT].tool_node.name == child.name


func update_hint_tooltips() -> void:
	for tool_name in tools:
		var t: Tool = tools[tool_name]
		t.button_node.hint_tooltip = t.generate_hint_tooltip()


func update_tool_cursors() -> void:
	var left_tool: Tool = tools[_slots[BUTTON_LEFT].tool_node.name]
	Global.left_cursor.texture = left_tool.cursor_icon
	var right_tool: Tool = tools[_slots[BUTTON_RIGHT].tool_node.name]
	Global.right_cursor.texture = right_tool.cursor_icon


func draw_indicator() -> void:
	if Global.left_square_indicator_visible:
		_slots[BUTTON_LEFT].tool_node.draw_indicator()
	if Global.right_square_indicator_visible:
		_slots[BUTTON_RIGHT].tool_node.draw_indicator()


func draw_preview() -> void:
	_slots[BUTTON_LEFT].tool_node.draw_preview()
	_slots[BUTTON_RIGHT].tool_node.draw_preview()


func handle_draw(position: Vector2, event: InputEvent) -> void:
	if not (Global.can_draw and Global.has_focus):
		return

	var draw_pos := position
	if Global.mirror_view:
		draw_pos.x = Global.current_project.size.x - position.x - 1

	if event is InputEventWithModifiers:
		control = event.control
		shift = event.shift
		alt = event.alt

	if event is InputEventMouseButton:
		if event.button_index in [BUTTON_LEFT, BUTTON_RIGHT]:
			if event.pressed and _active_button == -1:
				_active_button = event.button_index
				_slots[_active_button].tool_node.draw_start(draw_pos)
			elif not event.pressed and event.button_index == _active_button:
				_slots[_active_button].tool_node.draw_end(draw_pos)
				_active_button = -1

	if event is InputEventMouseMotion:
		pen_pressure = event.pressure
		if Global.pressure_sensitivity_mode == Global.PressureSensitivity.NONE:
			pen_pressure = 1.0

		if not position.is_equal_approx(_last_position):
			_last_position = position
			_slots[BUTTON_LEFT].tool_node.cursor_move(position)
			_slots[BUTTON_RIGHT].tool_node.cursor_move(position)
			if _active_button != -1:
				_slots[_active_button].tool_node.draw_move(draw_pos)

	var project: Project = Global.current_project
	var text := "[%s×%s]" % [project.size.x, project.size.y]
	if Global.has_focus:
		text += "    %s, %s" % [position.x, position.y]
	if not _slots[BUTTON_LEFT].tool_node.cursor_text.empty():
		text += "    %s" % _slots[BUTTON_LEFT].tool_node.cursor_text
	if not _slots[BUTTON_RIGHT].tool_node.cursor_text.empty():
		text += "    %s" % _slots[BUTTON_RIGHT].tool_node.cursor_text
	Global.cursor_position_label.text = text
