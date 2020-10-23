extends Node


class Slot:

	var name : String
	var kname : String
	var tool_node : Node = null
	var button : int
	var color : Color

	var pixel_perfect := false
	var horizontal_mirror := false
	var vertical_mirror := false


	func _init(slot_name : String) -> void:
		name = slot_name
		kname = name.replace(" ", "_").to_lower()
		load_config()


	func save_config() -> void:
		var config := {
			"pixel_perfect" : pixel_perfect,
			"horizontal_mirror" : horizontal_mirror,
			"vertical_mirror" : vertical_mirror,
		}
		Global.config_cache.set_value(kname, "slot", config)


	func load_config() -> void:
		var config = Global.config_cache.get_value(kname, "slot", {})
		pixel_perfect = config.get("pixel_perfect", pixel_perfect)
		horizontal_mirror = config.get("horizontal_mirror", horizontal_mirror)
		vertical_mirror = config.get("vertical_mirror", vertical_mirror)


signal color_changed(color, button)

var _tools = {
	"RectSelect" : "res://src/Tools/RectSelect.tscn",
	"Zoom" : "res://src/Tools/Zoom.tscn",
	"ColorPicker" : "res://src/Tools/ColorPicker.tscn",
	"Pencil" : "res://src/Tools/Pencil.tscn",
	"Eraser" : "res://src/Tools/Eraser.tscn",
	"Bucket" : "res://src/Tools/Bucket.tscn",
	"LightenDarken" : "res://src/Tools/LightenDarken.tscn",
}
var _slots = {}
var _panels = {}
var _tool_buttons : Node
var _active_button := -1
var _last_position := Vector2.INF

var pen_pressure := 1.0
var control := false
var shift := false
var alt := false


func _ready() -> void:
	yield(get_tree(), "idle_frame")
	_slots[BUTTON_LEFT] = Slot.new("Left tool")
	_slots[BUTTON_RIGHT] = Slot.new("Right tool")
	_panels[BUTTON_LEFT] = Global.find_node_by_name(Global.control, "LeftPanelContainer")
	_panels[BUTTON_RIGHT] = Global.find_node_by_name(Global.control, "RightPanelContainer")
	_tool_buttons = Global.find_node_by_name(Global.control, "ToolButtons")

	var value = Global.config_cache.get_value(_slots[BUTTON_LEFT].kname, "tool", "Pencil")
	set_tool(value, BUTTON_LEFT)
	value = Global.config_cache.get_value(_slots[BUTTON_RIGHT].kname, "tool", "Eraser")
	set_tool(value, BUTTON_RIGHT)
	value = Global.config_cache.get_value(_slots[BUTTON_LEFT].kname, "color", Color.black)
	assign_color(value, BUTTON_LEFT, false)
	value = Global.config_cache.get_value(_slots[BUTTON_RIGHT].kname, "color", Color.white)
	assign_color(value, BUTTON_RIGHT, false)

	update_tool_buttons()
	update_tool_cursors()


func set_tool(name : String, button : int) -> void:
	var slot = _slots[button]
	var panel : Node = _panels[button]
	var node : Node = load(_tools[name]).instance()
	node.name = name
	node.tool_slot = slot
	slot.tool_node = node
	slot.button = button
	panel.add_child(slot.tool_node)


func assign_tool(name : String, button : int) -> void:
	var slot = _slots[button]
	var panel : Node = _panels[button]

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


func assign_color(color : Color, button : int, change_alpha := true) -> void:
	var c : Color = _slots[button].color
	# This was requested by Issue #54 on GitHub
	if color.a == 0 and change_alpha:
		if color.r != c.r or color.g != c.g or color.b != c.b:
			color.a = 1
	_slots[button].color = color
	Global.config_cache.set_value(_slots[button].kname, "color", color)
	emit_signal("color_changed", color, button)


func get_assigned_color(button : int) -> Color:
	return _slots[button].color


func update_tool_buttons() -> void:
	for child in _tool_buttons.get_children():
		var texture : TextureRect = child.get_child(0)
		var filename = child.name.to_lower()
		if _slots[BUTTON_LEFT].tool_node.name == child.name:
			filename += "_l"
		if _slots[BUTTON_RIGHT].tool_node.name == child.name:
			filename += "_r"
		filename += ".png"
		Global.change_button_texturerect(texture, filename)


func update_tool_cursors() -> void:
	var image = "res://assets/graphics/cursor_icons/%s_cursor.png" % _slots[BUTTON_LEFT].tool_node.name.to_lower()
	Global.left_cursor_tool_texture.create_from_image(load(image), 0)
	image = "res://assets/graphics/cursor_icons/%s_cursor.png" % _slots[BUTTON_RIGHT].tool_node.name.to_lower()
	Global.right_cursor_tool_texture.create_from_image(load(image), 0)


func draw_indicator() -> void:
	if Global.left_square_indicator_visible:
		_slots[BUTTON_LEFT].tool_node.draw_indicator()
	if Global.right_square_indicator_visible:
		_slots[BUTTON_RIGHT].tool_node.draw_indicator()


func handle_draw(position : Vector2, event : InputEvent) -> void:
	if not (Global.can_draw and Global.has_focus):
		return

	if event is InputEventWithModifiers:
		control = event.control
		shift = event.shift
		alt = event.alt

	if event is InputEventMouseButton:
		if event.button_index in [BUTTON_LEFT, BUTTON_RIGHT]:
			if event.pressed and _active_button == -1:
				_active_button = event.button_index
				_slots[_active_button].tool_node.draw_start(position)
			elif not event.pressed and event.button_index == _active_button:
				_slots[_active_button].tool_node.draw_end(position)
				_active_button = -1

	if event is InputEventMouseMotion:
		if Engine.get_version_info().major == 3 && Engine.get_version_info().minor >= 2:
			pen_pressure = event.pressure
			if Global.pressure_sensitivity_mode == Global.Pressure_Sensitivity.NONE:
				pen_pressure = 1.0

		if not position.is_equal_approx(_last_position):
			_last_position = position
			_slots[BUTTON_LEFT].tool_node.cursor_move(position)
			_slots[BUTTON_RIGHT].tool_node.cursor_move(position)
			if _active_button != -1:
				_slots[_active_button].tool_node.draw_move(position)

	var project : Project = Global.current_project
	var text := "[%s×%s]" % [project.size.x, project.size.y]
	if Global.has_focus:
		text += "    %s, %s" % [position.x, position.y]
	if not _slots[BUTTON_LEFT].tool_node.cursor_text.empty():
		text += "    %s" % _slots[BUTTON_LEFT].tool_node.cursor_text
	if not _slots[BUTTON_RIGHT].tool_node.cursor_text.empty():
		text += "    %s" % _slots[BUTTON_RIGHT].tool_node.cursor_text
	Global.cursor_position_label.text = text
