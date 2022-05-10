extends Node

# Change these settings
var presets := [Preset.new("Default", false), Preset.new("Custom")]
var selected_preset: Preset = presets[0]
var actions := {
	"new_file": MenuInputAction.new("", "File Menu", true, "FileMenu", Global.FileMenuId.NEW),
	"open_file": MenuInputAction.new("", "File Menu", true, "FileMenu", Global.FileMenuId.OPEN),
	"save_file": MenuInputAction.new("", "File Menu", true, "FileMenu", Global.FileMenuId.SAVE),
	"save_file_as":
	MenuInputAction.new("", "File Menu", true, "FileMenu", Global.FileMenuId.SAVE_AS),
	"export_file": MenuInputAction.new("", "File Menu", true, "FileMenu", Global.FileMenuId.EXPORT),
	"export_file_as":
	MenuInputAction.new("", "File Menu", true, "FileMenu", Global.FileMenuId.EXPORT_AS),
	"quit": MenuInputAction.new("", "File Menu", true, "FileMenu", Global.FileMenuId.QUIT),
	"redo": MenuInputAction.new("", "Edit Menu", true, "EditMenu", Global.EditMenuId.REDO, true),
	"undo": MenuInputAction.new("", "Edit Menu", true, "EditMenu", Global.EditMenuId.UNDO, true),
	"cut": MenuInputAction.new("", "Edit Menu", true, "EditMenu", Global.EditMenuId.CUT),
	"copy": MenuInputAction.new("", "Edit Menu", true, "EditMenu", Global.EditMenuId.COPY),
	"paste": MenuInputAction.new("", "Edit Menu", true, "EditMenu", Global.EditMenuId.PASTE),
	"delete": MenuInputAction.new("", "Edit Menu", true, "EditMenu", Global.EditMenuId.DELETE),
	"new_brush":
	MenuInputAction.new("", "Edit Menu", true, "EditMenu", Global.EditMenuId.NEW_BRUSH),
	"mirror_view":
	MenuInputAction.new("", "View Menu", true, "ViewMenu", Global.ViewMenuId.MIRROR_VIEW),
	"show_grid":
	MenuInputAction.new("", "View Menu", true, "ViewMenu", Global.ViewMenuId.SHOW_GRID),
	"show_pixel_grid":
	MenuInputAction.new("", "View Menu", true, "ViewMenu", Global.ViewMenuId.SHOW_PIXEL_GRID),
	"show_guides":
	MenuInputAction.new("", "View Menu", true, "ViewMenu", Global.ViewMenuId.SHOW_GUIDES),
	"show_rulers":
	MenuInputAction.new("", "View Menu", true, "ViewMenu", Global.ViewMenuId.SHOW_RULERS),
	"zen_mode":
	MenuInputAction.new("", "Window Menu", true, "WindowMenu", Global.WindowMenuId.ZEN_MODE),
	"toggle_fullscreen":
	MenuInputAction.new("", "Window Menu", true, "WindowMenu", Global.WindowMenuId.FULLSCREEN_MODE),
	"clear_selection":
	MenuInputAction.new("", "Select Menu", true, "SelectMenu", Global.SelectMenuId.CLEAR_SELECTION),
	"select_all":
	MenuInputAction.new("", "Select Menu", true, "SelectMenu", Global.SelectMenuId.SELECT_ALL),
	"invert_selection":
	MenuInputAction.new("", "Select Menu", true, "SelectMenu", Global.SelectMenuId.INVERT),
	"open_docs":
	MenuInputAction.new("", "Help Menu", true, "HelpMenu", Global.HelpMenuId.ONLINE_DOCS),
	"edit_mode": InputAction.new("Moveable Panels", "Window Menu"),
}
var groups := {
	"Tools": InputGroup.new(),
	"Left": InputGroup.new("Tools"),
	"Right": InputGroup.new("Tools"),
	"Menu": InputGroup.new(),
	"File Menu": InputGroup.new("Menu"),
	"Edit Menu": InputGroup.new("Menu"),
	"View Menu": InputGroup.new("Menu"),
	"Select Menu": InputGroup.new("Menu"),
	"Image Menu": InputGroup.new("Menu"),
	"Window Menu": InputGroup.new("Menu"),
	"Help Menu": InputGroup.new("Menu"),
}
var ignore_actions := ["left_mouse", "right_mouse", "middle_mouse"]
var ignore_ui_actions := true
var changeable_types := [true, true, true, false]
var multiple_menu_accelerators := true
var config_path := "user://cache.ini"
var config_file: ConfigFile = Global.config_cache


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
		if !BetterInput.config_file:
			return
		if !customizable:
			return
		for action in bindings:
			var action_list = BetterInput.config_file.get_value(config_section, action, [null])
			if action_list != [null]:
				bindings[action] = action_list

	func change_action(action: String) -> void:
		bindings[action] = InputMap.get_action_list(action)
		if BetterInput.config_file and customizable:
			BetterInput.config_file.set_value(config_section, action, bindings[action])
			BetterInput.config_file.save(BetterInput.config_path)


class InputAction:
	var display_name := ""
	var group := ""
	var global := true

	func _init(_display_name := "", _group := "", _global := true) -> void:
		display_name = _display_name
		group = _group
		global = _global

	func update_node(_action: String) -> void:
		pass

	func handle_input(_event: InputEvent, _action: String) -> bool:
		return false


class MenuInputAction:
	extends InputAction
	var node_path := ""
	var node: PopupMenu
	var menu_item_id := 0
	var echo := false

	func _init(
		_display_name := "",
		_group := "",
		_global := true,
		_node_path := "",
		_menu_item_id := 0,
		_echo := false
	) -> void:
		._init(_display_name, _group, _global)
		node_path = _node_path
		menu_item_id = _menu_item_id
		echo = _echo

	func get_node(root: Node) -> void:
		var temp_node = root.get_node(node_path)
		if temp_node is PopupMenu:
			node = node
		elif temp_node is MenuButton:
			node = temp_node.get_popup()

	func update_node(action: String) -> void:
		if !node:
			return
		var accel := 0
		var events := InputMap.get_action_list(action)
		for event in events:
			if event is InputEventKey:
				accel = event.get_scancode_with_modifiers()
				break
		node.set_item_accelerator(menu_item_id, accel)

	func handle_input(event: InputEvent, action: String) -> bool:
		if not node:
			return false
		if event.is_action_pressed(action):
			if event is InputEventKey:
				var acc: int = node.get_item_accelerator(menu_item_id)
				# If the event is the same as the menu item's accelerator, skip
				if acc == event.get_scancode_with_modifiers():
					return true
			node.emit_signal("id_pressed", menu_item_id)
			return true
		if event.is_action(action) and echo:
			if event.is_echo():
				node.emit_signal("id_pressed", menu_item_id)
				return true

		return false


class InputGroup:
	var parent_group := ""
	var tree_item: TreeItem

	func _init(_parent_group := "") -> void:
		parent_group = _parent_group


func _init() -> void:
	if !config_file:
		config_file = ConfigFile.new()
		if !config_path.empty():
			config_file.load(config_path)


func _ready() -> void:
	set_process_input(multiple_menu_accelerators)
	for action in actions:
		var input_action: InputAction = actions[action]
		if input_action is MenuInputAction:
			input_action.get_node(Global.top_menu_container.get_node("MenuItems"))

	for t in Tools.tools:  # Code not in the original plugin
		var tool_shortcut: String = Tools.tools[t].shortcut
		var left_tool_shortcut := "left_%s_tool" % tool_shortcut
		var right_tool_shortcut := "right_%s_tool" % tool_shortcut
		actions[left_tool_shortcut] = InputAction.new("", "Left")
		actions[right_tool_shortcut] = InputAction.new("", "Right")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		return

	for action in actions:
		var input_action: InputAction = actions[action]
		var done: bool = input_action.handle_input(event, action)
		if done:
			return


func action_add_event(action: String, new_event: InputEvent) -> void:
	InputMap.action_add_event(action, new_event)
	if action in actions:
		actions[action].update_node(action)
	Global.update_hint_tooltips()


func action_erase_event(action: String, event: InputEvent) -> void:
	InputMap.action_erase_event(action, event)
	if action in actions:
		actions[action].update_node(action)
	Global.update_hint_tooltips()


func action_erase_events(action: String) -> void:
	InputMap.action_erase_events(action)
	if action in actions:
		actions[action].update_node(action)
	Global.update_hint_tooltips()


func action_get_first_key(action: String) -> String:
	var text := "None"
	var events := InputMap.get_action_list(action)
	for event in events:
		if event is InputEventKey:
			text = event.as_text()
			break
	return text
