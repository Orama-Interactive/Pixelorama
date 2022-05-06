extends Control

enum { KEYBOARD, MOUSE, JOY_BUTTON, JOY_AXIS }

const MOUSE_BUTTON_NAMES := [
	"Left Button",
	"Right Button",
	"Middle Button",
	"Wheel Up Button",
	"Wheel Down Button",
	"Wheel Left Button",
	"Wheel Right Button",
	"X Button 1",
	"X Button 2",
]

const JOY_BUTTON_NAMES := [
	"DualShock Cross, Xbox A, Nintendo B",
	"DualShock Circle, Xbox B, Nintendo A",
	"DualShock Square, Xbox X, Nintendo Y",
	"DualShock Triangle, Xbox Y, Nintendo X",
	"L, L1",
	"R, R1",
	"L2",
	"R2",
	"L3",
	"R3",
	"Select, DualShock Share, Nintendo -",
	"Start, DualShock Options, Nintendo +",
	"D-Pad Up",
	"D-Pad Down",
	"D-Pad Left",
	"D-Pad Right",
	"Home, DualShock PS, Guide",
	"Xbox Share, PS5 Microphone, Nintendo Capture",
	"Xbox Paddle 1",
	"Xbox Paddle 2",
	"Xbox Paddle 3",
	"Xbox Paddle 4",
	"PS4/5 Touchpad",
]

const JOY_AXIS_NAMES := [
	" (Left Stick Left)",
	" (Left Stick Right)",
	" (Left Stick Up)",
	" (Left Stick Down)",
	" (Right Stick Left)",
	" (Right Stick Right)",
	" (Right Stick Up)",
	" (Right Stick Down)",
	"",
	"",
	"",
	"",
	"",
	" (L2)",
	"",
	" (R2)",
	"",
	"",
	"",
	"",
]

export(Array, String) var ignore_actions := []
export(bool) var ignore_ui_actions := true
export(Array, bool) var changeable_types := [true, true, true, false]

var presets := [Preset.new("Default", false), Preset.new("Custom")]
var selected_preset: Preset = presets[0]
var actions := {}
var groups := {}
var currently_editing_tree_item: TreeItem

# Textures taken from Godot https://github.com/godotengine/godot/tree/master/editor/icons
var add_tex: Texture = preload("res://addons/godot_better_input/assets/add.svg")
var edit_tex: Texture = preload("res://addons/godot_better_input/assets/edit.svg")
var delete_tex: Texture = preload("res://addons/godot_better_input/assets/close.svg")
var joy_axis_tex: Texture = preload("res://addons/godot_better_input/assets/joy_axis.svg")
var joy_button_tex: Texture = preload("res://addons/godot_better_input/assets/joy_button.svg")
var key_tex: Texture = preload("res://addons/godot_better_input/assets/keyboard.svg")
var key_phys_tex: Texture = preload("res://addons/godot_better_input/assets/keyboard_physical.svg")
var mouse_tex: Texture = preload("res://addons/godot_better_input/assets/mouse.svg")
var shortcut_tex: Texture = preload("res://addons/godot_better_input/assets/shortcut.svg")
var folder_tex: Texture = preload("res://addons/godot_better_input/assets/folder.svg")

onready var tree: Tree = $VBoxContainer/ShortcutTree
onready var presets_option_button: OptionButton = find_node("PresetsOptionButton")
onready var shortcut_type_menu: PopupMenu = $ShortcutTypeMenu
onready var keyboard_shortcut_selector: ConfirmationDialog = $KeyboardShortcutSelectorDialog
onready var mouse_shortcut_selector: ConfirmationDialog = $MouseShortcutSelectorDialog
onready var joy_key_shortcut_selector: ConfirmationDialog = $JoyKeyShortcutSelectorDialog
onready var joy_axis_shortcut_selector: ConfirmationDialog = $JoyAxisShortcutSelectorDialog


class Preset:
	var name := ""
	var customizable := true
	var bindings := {}
	var config_section := ""

	func _init(_name := "", _customizable := true) -> void:
		name = _name
		customizable = _customizable
		config_section = "shortcuts-%s" % name

		for action in InputMap.get_actions():
			bindings[action] = InputMap.get_action_list(action)

	func load_from_file() -> void:
		if !Global.config_cache:
			return
		if !customizable:
			return
		for action in bindings:
			var action_list: Array = Global.config_cache.get_value(config_section, action, [])
			if action_list:
				bindings[action] = action_list

	func change_action(action: String) -> void:
		bindings[action] = InputMap.get_action_list(action)
		if Global.config_cache and customizable:
			Global.config_cache.set_value(config_section, action, bindings[action])
			Global.config_cache.save("user://cache.ini")


class InputAction:
	var display_name := ""
	var group := ""
	var global := true

	func _init(_display_name := "", _group := "", _global := true) -> void:
		display_name = _display_name
		group = _group
		global = _global


class InputGroup:
	var parent_group := ""
	var tree_item: TreeItem

	func _init(_parent_group := "") -> void:
		parent_group = _parent_group


func _ready() -> void:
	for preset in presets:
		preset.load_from_file()
		presets_option_button.add_item(preset.name)
	_fill_selector_options()

	var i := 0
	for type in changeable_types:
		if !type:
			shortcut_type_menu.remove_item(i)
		else:
			i += 1

	_construct_tree()


func _construct_tree() -> void:
	var buttons_disabled := false if selected_preset.customizable else true
	var tree_root: TreeItem = tree.create_item()
	for group in groups:  # Create groups
		var input_group: InputGroup = groups[group]
		_create_group_tree_item(input_group, group)

	for action in selected_preset.bindings:  # Fill the tree with actions and their events
		if action in ignore_actions:
			continue
		if ignore_ui_actions and action.begins_with("ui_"):
			continue
		var display_name := get_action_name(action)
		var group_name := ""
		if action in actions:
			var input_action: InputAction = actions[action]
			group_name = input_action.group

		var tree_item: TreeItem
		if group_name and group_name in groups:
			var input_group: InputGroup = groups[group_name]
			var group_root: TreeItem = input_group.tree_item
			tree_item = tree.create_item(group_root)

		else:
			tree_item = tree.create_item(tree_root)

		tree_item.set_text(0, display_name)
		tree_item.set_metadata(0, action)
		tree_item.set_icon(0, shortcut_tex)
		for event in InputMap.get_action_list(action):
			add_event_tree_item(event, tree_item)

		tree_item.add_button(0, add_tex, 0, buttons_disabled, "Add")
		tree_item.add_button(0, delete_tex, 1, buttons_disabled, "Delete")
		tree_item.collapsed = true


func _fill_selector_options() -> void:
	keyboard_shortcut_selector.entered_shortcut.visible = true
	keyboard_shortcut_selector.option_button.visible = false
	mouse_shortcut_selector.input_type_l.text = "Mouse Button Index:"
	joy_key_shortcut_selector.input_type_l.text = "Joypad Button Index:"
	joy_axis_shortcut_selector.input_type_l.text = "Joypad Axis Index:"

	var mouse_option_button: OptionButton = mouse_shortcut_selector.option_button
	for option in MOUSE_BUTTON_NAMES:
		mouse_option_button.add_item(option)

	var joy_key_option_button: OptionButton = joy_key_shortcut_selector.option_button
	for i in JOY_BUTTON_MAX:
		var text: String = "Button %s" % i
		if i < JOY_BUTTON_NAMES.size():
			text += " (%s)" % JOY_BUTTON_NAMES[i]
		joy_key_option_button.add_item(text)

	var joy_axis_option_button: OptionButton = joy_axis_shortcut_selector.option_button
	var i := 0.0
	for option in JOY_AXIS_NAMES:
		var sign_symbol = "+" if floor(i) != i else "-"
		var text: String = "Axis %s %s%s" % [floor(i), sign_symbol, option]
		joy_axis_option_button.add_item(text)
		i += 0.5


func _create_group_tree_item(group: InputGroup, group_name: String) -> void:
	if group.tree_item:
		return

	var group_root: TreeItem
	if group.parent_group:
		var parent_group: InputGroup = groups[group.parent_group]
		_create_group_tree_item(parent_group, group.parent_group)
		group_root = tree.create_item(parent_group.tree_item)
	else:
		group_root = tree.create_item(tree.get_root())
	group_root.set_text(0, group_name)
	group_root.set_icon(0, folder_tex)
	group.tree_item = group_root


func get_action_name(action: String) -> String:
	var display_name := ""
	if action in actions:
		display_name = actions[action].display_name

	if display_name.empty():
		display_name = _humanize_snake_case(action)
	return display_name


func _humanize_snake_case(text: String) -> String:
	text = text.replace("_", " ")
	var first_letter := text.left(1)
	first_letter = first_letter.capitalize()
	text.erase(0, 1)
	text = text.insert(0, first_letter)
	return text


func add_event_tree_item(event: InputEvent, action_tree_item: TreeItem) -> void:
	var event_class := event.get_class()
	match event_class:
		"InputEventKey":
			if !changeable_types[0]:
				return
		"InputEventMouseButton":
			if !changeable_types[1]:
				return
		"InputEventJoypadButton":
			if !changeable_types[2]:
				return
		"InputEventJoypadMotion":
			if !changeable_types[3]:
				return

	var buttons_disabled := false if selected_preset.customizable else true
	var event_tree_item: TreeItem = tree.create_item(action_tree_item)
	event_tree_item.set_text(0, event_to_str(event))
	event_tree_item.set_metadata(0, event)
	match event_class:
		"InputEventKey":
			var scancode: int = event.get_scancode_with_modifiers()
			if scancode > 0:
				event_tree_item.set_icon(0, key_tex)
			else:
				event_tree_item.set_icon(0, key_phys_tex)
		"InputEventMouseButton":
			event_tree_item.set_icon(0, mouse_tex)
		"InputEventJoypadButton":
			event_tree_item.set_icon(0, joy_button_tex)
		"InputEventJoypadMotion":
			event_tree_item.set_icon(0, joy_axis_tex)
	event_tree_item.add_button(0, edit_tex, 0, buttons_disabled, "Edit")
	event_tree_item.add_button(0, delete_tex, 1, buttons_disabled, "Delete")


func event_to_str(event: InputEvent) -> String:
	var output := ""
	if event is InputEventKey:
		var scancode: int = event.get_scancode_with_modifiers()
		var physical_str := ""
		if scancode == 0:
			scancode = event.get_physical_scancode_with_modifiers()
			physical_str = " " + tr("(Physical)")
		output = OS.get_scancode_string(scancode) + physical_str

	elif event is InputEventMouseButton:
		output = MOUSE_BUTTON_NAMES[event.button_index - 1]

	elif event is InputEventJoypadButton:
		var button_index: int = event.button_index
		if button_index >= JOY_BUTTON_NAMES.size():
			output = "Button %s" % button_index
		else:
			output = "Button %s (%s)" % [button_index, JOY_BUTTON_NAMES[button_index]]

	elif event is InputEventJoypadMotion:
		var positive_axis: bool = event.axis_value > 0
		var axis_value: int = event.axis * 2 + int(positive_axis)
		var sign_symbol = "+" if positive_axis else "-"
		output = "Axis %s %s%s" % [event.axis, sign_symbol, JOY_AXIS_NAMES[axis_value]]
	return output


func _on_ShortcutTree_button_pressed(item: TreeItem, _column: int, id: int) -> void:
	var action = item.get_metadata(0)
	currently_editing_tree_item = item
	if action is String:
		if id == 0:  # Add
			var rect: Rect2 = tree.get_item_area_rect(item, 0)
			rect.position.x = rect.end.x
			rect.position.y += 42 - tree.get_scroll().y
			rect.size = Vector2(110, 23 * shortcut_type_menu.get_item_count())
			shortcut_type_menu.popup(rect)
		elif id == 1:  # Delete
			InputMap.action_erase_events(action)
			selected_preset.change_action(action)
			var child := item.get_children()
			while child != null:
				child.free()
				child = item.get_children()

	elif action is InputEvent:
		var parent_action = item.get_parent().get_metadata(0)
		if id == 0:  # Edit
			if action is InputEventKey:
				keyboard_shortcut_selector.popup_centered()
			elif action is InputEventMouseButton:
				mouse_shortcut_selector.popup_centered()
			elif action is InputEventJoypadButton:
				joy_key_shortcut_selector.popup_centered()
			elif action is InputEventJoypadMotion:
				joy_axis_shortcut_selector.popup_centered()
		elif id == 1:  # Delete
			if not parent_action is String:
				return
			InputMap.action_erase_event(parent_action, action)
			selected_preset.change_action(parent_action)
			item.free()


func _on_ShortcutTree_item_activated() -> void:
	var selected_item: TreeItem = tree.get_selected()
	if selected_item.get_button_count(0) > 0 and !selected_item.is_button_disabled(0, 0):
		_on_ShortcutTree_button_pressed(tree.get_selected(), 0, 0)


func _on_ShortcutTypeMenu_id_pressed(id: int) -> void:
	if id == KEYBOARD:
		keyboard_shortcut_selector.popup_centered()
	elif id == MOUSE:
		mouse_shortcut_selector.popup_centered()
	elif id == JOY_BUTTON:
		joy_key_shortcut_selector.popup_centered()
	elif id == JOY_AXIS:
		joy_axis_shortcut_selector.popup_centered()


func _on_PresetsOptionButton_item_selected(index: int) -> void:
	selected_preset = presets[index]
	for action in selected_preset.bindings:
		InputMap.action_erase_events(action)
		for event in selected_preset.bindings[action]:
			InputMap.action_add_event(action, event)

	# Re-construct the tree
	for group in groups:
		groups[group].tree_item = null
	tree.clear()
	_construct_tree()
