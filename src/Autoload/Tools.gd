extends Node

signal color_changed(color, button)

enum Dynamics { NONE, PRESSURE, VELOCITY }

var picking_color_for := MOUSE_BUTTON_LEFT
var horizontal_mirror := false
var vertical_mirror := false
var pixel_perfect := false

# Dynamics
var stabilizer_enabled := false
var stabilizer_value := 16
var dynamics_alpha: int = Dynamics.NONE
var dynamics_size: int = Dynamics.NONE
var pen_pressure := 1.0
var pen_pressure_min := 0.2
var pen_pressure_max := 0.8
var pressure_buf := [0, 0]  # past pressure value buffer
var pen_inverted := false
var mouse_velocity := 1.0
var mouse_velocity_min_thres := 0.2
var mouse_velocity_max_thres := 0.8
var mouse_velocity_max := 1000.0
var alpha_min := 0.1
var alpha_max := 1.0
var brush_size_min := 1
var brush_size_max := 4

var tools := {
	"RectSelect":
	Tool.new(
		"RectSelect",
		"Rectangular Selection",
		"rectangle_select",
		"res://src/Tools/SelectionTools/RectSelect.tscn"
	),
	"EllipseSelect":
	Tool.new(
		"EllipseSelect",
		"Elliptical Selection",
		"ellipse_select",
		"res://src/Tools/SelectionTools/EllipseSelect.tscn"
	),
	"PolygonSelect":
	Tool.new(
		"PolygonSelect",
		"Polygonal Selection",
		"polygon_select",
		"res://src/Tools/SelectionTools/PolygonSelect.tscn",
		[],
		"Double-click to connect the last point to the starting point"
	),
	"ColorSelect":
	Tool.new(
		"ColorSelect",
		"Select By Color",
		"color_select",
		"res://src/Tools/SelectionTools/ColorSelect.tscn"
	),
	"MagicWand":
	Tool.new(
		"MagicWand", "Magic Wand", "magic_wand", "res://src/Tools/SelectionTools/MagicWand.tscn"
	),
	"Lasso":
	Tool.new(
		"Lasso", "Lasso / Free Select Tool", "lasso", "res://src/Tools/SelectionTools/Lasso.tscn"
	),
	"PaintSelect":
	Tool.new(
		"PaintSelect",
		"Select by Drawing",
		"paint_selection",
		"res://src/Tools/SelectionTools/PaintSelect.tscn"
	),
	"Move":
	Tool.new(
		"Move", "Move", "move", "res://src/Tools/UtilityTools/Move.tscn", [Global.LayerTypes.PIXEL]
	),
	"Zoom": Tool.new("Zoom", "Zoom", "zoom", "res://src/Tools/UtilityTools/Zoom.tscn"),
	"Pan": Tool.new("Pan", "Pan", "pan", "res://src/Tools/UtilityTools/Pan.tscn"),
	"ColorPicker":
	Tool.new(
		"ColorPicker",
		"Color Picker",
		"colorpicker",
		"res://src/Tools/UtilityTools/ColorPicker.tscn",
		[],
		"Select a color from a pixel of the sprite"
	),
	"Crop":
	Tool.new(
		"Crop",
		"Crop",
		"crop",
		"res://src/Tools/UtilityTools/CropTool.tscn",
		[],
		"Resize the canvas"
	),
	"Pencil":
	Tool.new(
		"Pencil",
		"Pencil",
		"pencil",
		"res://src/Tools/DesignTools/Pencil.tscn",
		[Global.LayerTypes.PIXEL],
		"Hold %s to make a line",
		["draw_create_line"]
	),
	"Eraser":
	Tool.new(
		"Eraser",
		"Eraser",
		"eraser",
		"res://src/Tools/DesignTools/Eraser.tscn",
		[Global.LayerTypes.PIXEL],
		"Hold %s to make a line",
		["draw_create_line"]
	),
	"Bucket":
	Tool.new(
		"Bucket",
		"Bucket",
		"fill",
		"res://src/Tools/DesignTools/Bucket.tscn",
		[Global.LayerTypes.PIXEL]
	),
	"Shading":
	Tool.new(
		"Shading",
		"Shading Tool",
		"shading",
		"res://src/Tools/DesignTools/Shading.tscn",
		[Global.LayerTypes.PIXEL]
	),
	"LineTool":
	(
		Tool
		. new(
			"LineTool",
			"Line Tool",
			"linetool",
			"res://src/Tools/DesignTools/LineTool.tscn",
			[Global.LayerTypes.PIXEL],
			"""Hold %s to snap the angle of the line
Hold %s to center the shape on the click origin
Hold %s to displace the shape's origin""",
			["shape_perfect", "shape_center", "shape_displace"]
		)
	),
	"RectangleTool":
	(
		Tool
		. new(
			"RectangleTool",
			"Rectangle Tool",
			"rectangletool",
			"res://src/Tools/DesignTools/RectangleTool.tscn",
			[Global.LayerTypes.PIXEL],
			"""Hold %s to create a 1:1 shape
Hold %s to center the shape on the click origin
Hold %s to displace the shape's origin""",
			["shape_perfect", "shape_center", "shape_displace"]
		)
	),
	"EllipseTool":
	(
		Tool
		. new(
			"EllipseTool",
			"Ellipse Tool",
			"ellipsetool",
			"res://src/Tools/DesignTools/EllipseTool.tscn",
			[Global.LayerTypes.PIXEL],
			"""Hold %s to create a 1:1 shape
Hold %s to center the shape on the click origin
Hold %s to displace the shape's origin""",
			["shape_perfect", "shape_center", "shape_displace"]
		)
	),
	"3DShapeEdit":
	Tool.new(
		"3DShapeEdit",
		"3D Shape Edit",
		"3dshapeedit",
		"res://src/Tools/3DTools/3DShapeEdit.tscn",
		[Global.LayerTypes.THREE_D]
	),
}

var _tool_button_scene := preload("res://src/UI/ToolsPanel/ToolButton.tscn")
var _slots := {}
var _panels := {}
var _curr_layer_type := Global.LayerTypes.PIXEL
var _left_tools_per_layer_type := {
	Global.LayerTypes.PIXEL: "Pencil",
	Global.LayerTypes.THREE_D: "3DShapeEdit",
}
var _right_tools_per_layer_type := {
	Global.LayerTypes.PIXEL: "Eraser",
	Global.LayerTypes.THREE_D: "Pan",
}
var _tool_buttons: Node
var _active_button := -1
var _last_position := Vector2i(Vector2.INF)


class Tool:
	var name := ""
	var display_name := ""
	var scene_path: String
	var scene: PackedScene
	var icon: Texture2D
	var cursor_icon: Texture2D
	var shortcut := ""
	var extra_hint := ""
	var extra_shortcuts: PackedStringArray = []
	var layer_types: PackedInt32Array = []
	var button_node: BaseButton

	func _init(
		_name: String,
		_display_name: String,
		_shortcut: String,
		_scene_path: String,
		_layer_types: PackedInt32Array = [],
		_extra_hint := "",
		_extra_shortcuts: PackedStringArray = []
	) -> void:
		name = _name
		display_name = _display_name
		shortcut = _shortcut
		scene_path = _scene_path
		layer_types = _layer_types
		extra_hint = _extra_hint
		extra_shortcuts = _extra_shortcuts
		icon = load("res://assets/graphics/tools/%s.png" % name.to_lower())
		cursor_icon = load("res://assets/graphics/tools/cursors/%s.png" % name.to_lower())

	func instantiate_scene() -> Node:
		if not is_instance_valid(scene):
			scene = load(scene_path)
		return scene.instantiate()

	func generate_hint_tooltip() -> String:
		var hint := display_name
		var shortcuts := []
		var left_text := ""
		var right_text := ""
		if InputMap.has_action("left_" + shortcut + "_tool"):
			var left_list := InputMap.action_get_events("left_" + shortcut + "_tool")
			if left_list.size() > 0:
				var left_shortcut: String = left_list[0].as_text()
				shortcuts.append(left_shortcut)
				left_text = "\n%s for left mouse button"
		if InputMap.has_action("right_" + shortcut + "_tool"):
			var right_list := InputMap.action_get_events("right_" + shortcut + "_tool")
			if right_list.size() > 0:
				var right_shortcut: String = right_list[0].as_text()
				shortcuts.append(right_shortcut)
				right_text = "\n%s for right mouse button"

		if !shortcuts.is_empty():
			hint += "\n" + left_text + right_text

		if !extra_hint.is_empty():
			hint += "\n\n" + extra_hint

		var extra_shortcuts_mapped := []
		for action in extra_shortcuts:
			var key_string := "None"
			var events := InputMap.action_get_events(action)
			if events.size() > 0:
				key_string = events[0].as_text()
			extra_shortcuts_mapped.append(key_string)

		shortcuts.append_array(extra_shortcuts_mapped)

		if shortcuts.is_empty():
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
	Global.cel_switched.connect(_cel_switched)
	_tool_buttons = Global.control.find_child("ToolButtons")
	for t in tools:
		add_tool_button(tools[t])
		var tool_shortcut: String = tools[t].shortcut
		var left_tool_shortcut := "left_%s_tool" % tool_shortcut
		var right_tool_shortcut := "right_%s_tool" % tool_shortcut
		Keychain.actions[left_tool_shortcut] = Keychain.InputAction.new("", "Left")
		Keychain.actions[right_tool_shortcut] = Keychain.InputAction.new("", "Right")

	_slots[MOUSE_BUTTON_LEFT] = Slot.new("Left tool")
	_slots[MOUSE_BUTTON_RIGHT] = Slot.new("Right tool")
	_panels[MOUSE_BUTTON_LEFT] = Global.control.find_child("LeftPanelContainer", true, false)
	_panels[MOUSE_BUTTON_RIGHT] = Global.control.find_child("RightPanelContainer", true, false)

	var default_left_tool: String = _left_tools_per_layer_type[0]
	var default_right_tool: String = _right_tools_per_layer_type[0]
	var tool_name: String = Global.config_cache.get_value(
		_slots[MOUSE_BUTTON_LEFT].kname, "tool", default_left_tool
	)
	if not tool_name in tools or not _is_tool_available(Global.LayerTypes.PIXEL, tools[tool_name]):
		tool_name = default_left_tool
	set_tool(tool_name, MOUSE_BUTTON_LEFT)
	tool_name = Global.config_cache.get_value(
		_slots[MOUSE_BUTTON_RIGHT].kname, "tool", default_right_tool
	)
	if not tool_name in tools or not _is_tool_available(Global.LayerTypes.PIXEL, tools[tool_name]):
		tool_name = default_right_tool
	set_tool(tool_name, MOUSE_BUTTON_RIGHT)
	update_tool_buttons()

	horizontal_mirror = Global.config_cache.get_value("preferences", "horizontal_mirror", false)
	vertical_mirror = Global.config_cache.get_value("preferences", "vertical_mirror", false)
	pixel_perfect = Global.config_cache.get_value("preferences", "pixel_perfect", false)

	# Yield is necessary for the color picker nodes to update their color values
	await get_tree().process_frame
	var color_value: Color = Global.config_cache.get_value(
		_slots[MOUSE_BUTTON_LEFT].kname, "color", Color.BLACK
	)
	assign_color(color_value, MOUSE_BUTTON_LEFT, false)
	color_value = Global.config_cache.get_value(
		_slots[MOUSE_BUTTON_RIGHT].kname, "color", Color.WHITE
	)
	assign_color(color_value, MOUSE_BUTTON_RIGHT, false)
	update_tool_cursors()
	var layer: BaseLayer = Global.current_project.layers[Global.current_project.current_layer]
	var layer_type := layer.get_layer_type()

	# Yield is necessary to hide irrelevant tools added by extensions
	await get_tree().process_frame
	_show_relevant_tools(layer_type)


func add_tool_button(t: Tool, insert_pos := -1) -> void:
	var tool_button: BaseButton = _tool_button_scene.instantiate()
	tool_button.name = t.name
	tool_button.get_node("BackgroundLeft").modulate = Global.left_tool_color
	tool_button.get_node("BackgroundRight").modulate = Global.right_tool_color
	tool_button.get_node("ToolIcon").texture = t.icon
	tool_button.tooltip_text = t.generate_hint_tooltip()
	t.button_node = tool_button
	_tool_buttons.add_child(tool_button)
	if insert_pos > -1:
		insert_pos = min(insert_pos, _tool_buttons.get_child_count() - 1)
		_tool_buttons.move_child(tool_button, insert_pos)
	tool_button.pressed.connect(_tool_buttons._on_Tool_pressed.bind(tool_button))


func remove_tool(t: Tool) -> void:
	t.button_node.queue_free()
	tools.erase(t.name)


func set_tool(tool_name: String, button: int) -> void:
	var slot: Slot = _slots[button]
	var panel: Node = _panels[button]
	var node: Node = tools[tool_name].instantiate_scene()
	if button == MOUSE_BUTTON_LEFT:  # As guides are only moved with left mouse
		if tool_name == "Pan":  # tool you want to give more access at guides
			Global.move_guides_on_canvas = true
		else:
			Global.move_guides_on_canvas = false
	node.name = tool_name
	node.tool_slot = slot
	slot.tool_node = node
	slot.button = button
	panel.add_child(slot.tool_node)

	if _curr_layer_type == Global.LayerTypes.GROUP:
		return
	if button == MOUSE_BUTTON_LEFT:
		_left_tools_per_layer_type[_curr_layer_type] = tool_name
	elif button == MOUSE_BUTTON_RIGHT:
		_right_tools_per_layer_type[_curr_layer_type] = tool_name


func assign_tool(tool_name: String, button: int) -> void:
	var slot: Slot = _slots[button]
	var panel: Node = _panels[button]

	if slot.tool_node != null:
		if slot.tool_node.name == tool_name:
			return
		panel.remove_child(slot.tool_node)
		slot.tool_node.queue_free()

	set_tool(tool_name, button)
	update_tool_buttons()
	update_tool_cursors()
	Global.config_cache.set_value(slot.kname, "tool", tool_name)


func default_color() -> void:
	assign_color(Color.BLACK, MOUSE_BUTTON_LEFT)
	assign_color(Color.WHITE, MOUSE_BUTTON_RIGHT)


func swap_color() -> void:
	var left = _slots[MOUSE_BUTTON_LEFT].color
	var right = _slots[MOUSE_BUTTON_RIGHT].color
	assign_color(right, MOUSE_BUTTON_LEFT, false)
	assign_color(left, MOUSE_BUTTON_RIGHT, false)


func assign_color(color: Color, button: int, change_alpha := true) -> void:
	var c: Color = _slots[button].color
	# This was requested by Issue #54 on GitHub
	if color.a == 0 and change_alpha:
		if color.r != c.r or color.g != c.g or color.b != c.b:
			color.a = 1
	_slots[button].color = color
	Global.config_cache.set_value(_slots[button].kname, "color", color)
	color_changed.emit(color, button)


func get_assigned_color(button: int) -> Color:
	return _slots[button].color


func set_button_size(button_size: int) -> void:
	var size := Vector2(24, 24) if button_size == Global.ButtonSize.SMALL else Vector2(32, 32)
	for t in _tool_buttons.get_children():
		t.custom_minimum_size = size


func update_tool_buttons() -> void:
	for child in _tool_buttons.get_children():
		var left_background: NinePatchRect = child.get_node("BackgroundLeft")
		var right_background: NinePatchRect = child.get_node("BackgroundRight")
		left_background.visible = _slots[MOUSE_BUTTON_LEFT].tool_node.name == child.name
		right_background.visible = _slots[MOUSE_BUTTON_RIGHT].tool_node.name == child.name


func update_hint_tooltips() -> void:
	for tool_name in tools:
		var t: Tool = tools[tool_name]
		t.button_node.tooltip_text = t.generate_hint_tooltip()


func update_tool_cursors() -> void:
	var left_tool: Tool = tools[_slots[MOUSE_BUTTON_LEFT].tool_node.name]
	Global.control.left_cursor.texture = left_tool.cursor_icon
	var right_tool: Tool = tools[_slots[MOUSE_BUTTON_RIGHT].tool_node.name]
	Global.control.right_cursor.texture = right_tool.cursor_icon


func draw_indicator() -> void:
	if Global.right_square_indicator_visible:
		_slots[MOUSE_BUTTON_RIGHT].tool_node.draw_indicator(false)
	if Global.left_square_indicator_visible:
		_slots[MOUSE_BUTTON_LEFT].tool_node.draw_indicator(true)


func draw_preview() -> void:
	_slots[MOUSE_BUTTON_LEFT].tool_node.draw_preview()
	_slots[MOUSE_BUTTON_RIGHT].tool_node.draw_preview()


func handle_draw(position: Vector2i, event: InputEvent) -> void:
	if not Global.can_draw:
		return

	var draw_pos := position
	if Global.mirror_view:
		draw_pos.x = Global.current_project.size.x - position.x - 1

	if event.is_action_pressed("activate_left_tool") and _active_button == -1 and not pen_inverted:
		_active_button = MOUSE_BUTTON_LEFT
		_slots[_active_button].tool_node.draw_start(draw_pos)
	elif event.is_action_released("activate_left_tool") and _active_button == MOUSE_BUTTON_LEFT:
		_slots[_active_button].tool_node.draw_end(draw_pos)
		_active_button = -1
	elif (
		(
			event.is_action_pressed("activate_right_tool")
			and _active_button == -1
			and not pen_inverted
		)
		or (event.is_action_pressed("activate_left_tool") and _active_button == -1 and pen_inverted)
	):
		_active_button = MOUSE_BUTTON_RIGHT
		_slots[_active_button].tool_node.draw_start(draw_pos)
	elif (
		(event.is_action_released("activate_right_tool") and _active_button == MOUSE_BUTTON_RIGHT)
		or (event.is_action_released("activate_left_tool") and _active_button == MOUSE_BUTTON_RIGHT)
	):
		_slots[_active_button].tool_node.draw_end(draw_pos)
		_active_button = -1

	if event is InputEventMouseMotion:
		pen_pressure = event.pressure
		# Workaround https://github.com/godotengine/godot/issues/53033#issuecomment-930409407
		# If a pressure value of 1 is encountered, "correct" the value by
		# extrapolating from the delta of the past two values. This will
		# correct the jumping to 1 error while also allowing values that
		# are "supposed" to be 1.
		if pen_pressure == 1 && pressure_buf[0] != 0:
			pen_pressure = minf(1, pressure_buf[0] + pressure_buf[0] - pressure_buf[1])
		pressure_buf.pop_back()
		pressure_buf.push_front(pen_pressure)
		pen_pressure = remap(pen_pressure, pen_pressure_min, pen_pressure_max, 0.0, 1.0)
		pen_pressure = clampf(pen_pressure, 0.0, 1.0)

		pen_inverted = event.pen_inverted

		mouse_velocity = event.velocity.length() / mouse_velocity_max
		mouse_velocity = remap(
			mouse_velocity, mouse_velocity_min_thres, mouse_velocity_max_thres, 0.0, 1.0
		)
		mouse_velocity = clampf(mouse_velocity, 0.0, 1.0)
		if dynamics_alpha != Dynamics.PRESSURE and dynamics_size != Dynamics.PRESSURE:
			pen_pressure = 1.0
		if dynamics_alpha != Dynamics.VELOCITY and dynamics_size != Dynamics.VELOCITY:
			mouse_velocity = 1.0
		if not position == _last_position:
			_last_position = position
			_slots[MOUSE_BUTTON_LEFT].tool_node.cursor_move(position)
			_slots[MOUSE_BUTTON_RIGHT].tool_node.cursor_move(position)
			if _active_button != -1:
				_slots[_active_button].tool_node.draw_move(draw_pos)

	var project := Global.current_project
	var text := "[%s×%s]" % [project.size.x, project.size.y]
	if Global.has_focus:
		text += "    %s, %s" % [position.x, position.y]
	if not _slots[MOUSE_BUTTON_LEFT].tool_node.cursor_text.is_empty():
		text += "    %s" % _slots[MOUSE_BUTTON_LEFT].tool_node.cursor_text
	if not _slots[MOUSE_BUTTON_RIGHT].tool_node.cursor_text.is_empty():
		text += "    %s" % _slots[MOUSE_BUTTON_RIGHT].tool_node.cursor_text
	Global.cursor_position_label.text = text


func get_alpha_dynamic(strength := 1.0) -> float:
	if dynamics_alpha == Dynamics.PRESSURE:
		strength *= lerpf(alpha_min, alpha_max, pen_pressure)
	elif dynamics_alpha == Dynamics.VELOCITY:
		strength *= lerpf(alpha_min, alpha_max, mouse_velocity)
	return strength


func _cel_switched() -> void:
	var layer: BaseLayer = Global.current_project.layers[Global.current_project.current_layer]
	var layer_type := layer.get_layer_type()
	# Do not make any changes when its the same type of layer, or a group layer
	if layer_type == _curr_layer_type or layer_type == Global.LayerTypes.GROUP:
		return
	_show_relevant_tools(layer_type)


func _show_relevant_tools(layer_type: Global.LayerTypes) -> void:
	# Hide tools that are not available in the current layer type
	for button in _tool_buttons.get_children():
		var tool_name: String = button.name
		var t: Tool = tools[tool_name]
		var hide_tool := _is_tool_available(layer_type, t)
		button.visible = hide_tool

	# Assign new tools if the layer type has changed
	_curr_layer_type = layer_type
	var new_tool_name: String = _left_tools_per_layer_type[layer_type]
	assign_tool(new_tool_name, MOUSE_BUTTON_LEFT)

	new_tool_name = _right_tools_per_layer_type[layer_type]
	assign_tool(new_tool_name, MOUSE_BUTTON_RIGHT)


func _is_tool_available(layer_type: int, t: Tool) -> bool:
	return t.layer_types.is_empty() or layer_type in t.layer_types
