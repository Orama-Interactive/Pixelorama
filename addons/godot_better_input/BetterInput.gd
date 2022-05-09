extends Node

# Change these settings
var presets := [Preset.new("Default", false), Preset.new("Custom")]
var selected_preset: Preset = presets[0]
var actions := {
	"new_file":
	MenuInputAction.new(
		"", "Menu", true, "MenuAndUI/TopMenuContainer/MenuItems/FileMenu", Global.FileMenuId.NEW
	),
	"open_file":
	MenuInputAction.new(
		"", "Menu", true, "MenuAndUI/TopMenuContainer/MenuItems/FileMenu", Global.FileMenuId.OPEN
	),
	"save_file":
	MenuInputAction.new(
		"", "Menu", true, "MenuAndUI/TopMenuContainer/MenuItems/FileMenu", Global.FileMenuId.SAVE
	),
	"save_file_as":
	MenuInputAction.new(
		"", "Menu", true, "MenuAndUI/TopMenuContainer/MenuItems/FileMenu", Global.FileMenuId.SAVE_AS
	),
	"export_file":
	MenuInputAction.new(
		"", "Menu", true, "MenuAndUI/TopMenuContainer/MenuItems/FileMenu", Global.FileMenuId.EXPORT
	),
	"export_file_as":
	MenuInputAction.new(
		"",
		"Menu",
		true,
		"MenuAndUI/TopMenuContainer/MenuItems/FileMenu",
		Global.FileMenuId.EXPORT_AS
	),
	"quit":
	MenuInputAction.new(
		"", "Menu", true, "MenuAndUI/TopMenuContainer/MenuItems/FileMenu", Global.FileMenuId.QUIT
	),
	"redo":
	MenuInputAction.new(
		"",
		"Menu",
		true,
		"MenuAndUI/TopMenuContainer/MenuItems/EditMenu",
		Global.EditMenuId.REDO,
		true
	),
	"undo":
	MenuInputAction.new(
		"",
		"Menu",
		true,
		"MenuAndUI/TopMenuContainer/MenuItems/EditMenu",
		Global.EditMenuId.UNDO,
		true
	),
	"cut":
	MenuInputAction.new(
		"",
		"Menu",
		true,
		"MenuAndUI/TopMenuContainer/MenuItems/EditMenu",
		Global.EditMenuId.CUT,
		true
	),
	"copy":
	MenuInputAction.new(
		"",
		"Menu",
		true,
		"MenuAndUI/TopMenuContainer/MenuItems/EditMenu",
		Global.EditMenuId.COPY,
		true
	),
	"paste":
	MenuInputAction.new(
		"",
		"Menu",
		true,
		"MenuAndUI/TopMenuContainer/MenuItems/EditMenu",
		Global.EditMenuId.PASTE,
		true
	),
	"new_brush":
	MenuInputAction.new(
		"",
		"Menu",
		true,
		"MenuAndUI/TopMenuContainer/MenuItems/EditMenu",
		Global.EditMenuId.NEW_BRUSH,
		true
	),
	"mirror_view":
	MenuInputAction.new(
		"",
		"Menu",
		true,
		"MenuAndUI/TopMenuContainer/MenuItems/ViewMenu",
		Global.ViewMenuId.MIRROR_VIEW,
		true
	),
	"show_grid":
	MenuInputAction.new(
		"",
		"Menu",
		true,
		"MenuAndUI/TopMenuContainer/MenuItems/ViewMenu",
		Global.ViewMenuId.SHOW_GRID
	),
	"show_pixel_grid":
	MenuInputAction.new(
		"",
		"Menu",
		true,
		"MenuAndUI/TopMenuContainer/MenuItems/ViewMenu",
		Global.ViewMenuId.SHOW_PIXEL_GRID
	),
	"show_rulers":
	MenuInputAction.new(
		"",
		"Menu",
		true,
		"MenuAndUI/TopMenuContainer/MenuItems/ViewMenu",
		Global.ViewMenuId.SHOW_RULERS
	),
	"zen_mode":
	MenuInputAction.new(
		"",
		"Menu",
		true,
		"MenuAndUI/TopMenuContainer/MenuItems/WindowMenu",
		Global.WindowMenuId.ZEN_MODE
	),
	"toggle_fullscreen":
	MenuInputAction.new(
		"",
		"Menu",
		true,
		"MenuAndUI/TopMenuContainer/MenuItems/WindowMenu",
		Global.WindowMenuId.FULLSCREEN_MODE
	),
	"clear_selection":
	MenuInputAction.new(
		"",
		"Menu",
		true,
		"MenuAndUI/TopMenuContainer/MenuItems/SelectMenu",
		Global.SelectMenuId.CLEAR_SELECTION
	),
	"select_all":
	MenuInputAction.new(
		"",
		"Menu",
		true,
		"MenuAndUI/TopMenuContainer/MenuItems/SelectMenu",
		Global.SelectMenuId.SELECT_ALL
	),
	"invert_selection":
	MenuInputAction.new(
		"",
		"Menu",
		true,
		"MenuAndUI/TopMenuContainer/MenuItems/SelectMenu",
		Global.SelectMenuId.INVERT
	),
	"open_docs":
	MenuInputAction.new(
		"",
		"Menu",
		true,
		"MenuAndUI/TopMenuContainer/MenuItems/HelpMenu",
		Global.HelpMenuId.ONLINE_DOCS
	),
	"edit_mode": InputAction.new("Moveable Panels", "Menu"),
}
var groups := {
	"Tools": InputGroup.new(),
	"Menu": InputGroup.new(),
}
var ignore_actions := []
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


class MenuInputAction:
	extends InputAction
	var menu_node_path := ""
	var menu_node: PopupMenu
	var menu_item_id := 0
	var echo := false

	func _init(
		_display_name := "",
		_group := "",
		_global := true,
		_menu_node_path := "",
		_menu_item_id := 0,
		_echo := false
	) -> void:
		._init(_display_name, _group, _global)
		menu_node_path = _menu_node_path
		menu_item_id = _menu_item_id
		echo = _echo

	func get_menu_node(root: Node) -> void:
		var node = root.get_node(menu_node_path)
		if node is PopupMenu:
			menu_node = node
		elif node is MenuButton:
			menu_node = node.get_popup()

	func update_item_accelerator(action: String) -> void:
		if !menu_node:
			return
		var accel := 0
		var events := InputMap.get_action_list(action)
		for event in events:
			if event is InputEventKey:
				accel = event.get_scancode_with_modifiers()
				break
		menu_node.set_item_accelerator(menu_item_id, accel)


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
	for t in Tools.tools:  # Code not in the original plugin
		var tool_shortcut: String = Tools.tools[t].shortcut
		var left_tool_shortcut := "left_%s_tool" % tool_shortcut
		var right_tool_shortcut := "right_%s_tool" % tool_shortcut
		actions[left_tool_shortcut] = InputAction.new("", "Tools")
		actions[right_tool_shortcut] = InputAction.new("", "Tools")


func _input(event: InputEvent) -> void:
	for action in actions:
		var input_action: InputAction = actions[action]
		if not input_action is MenuInputAction:
			continue

		if event.is_action_pressed(action):
			var menu: PopupMenu = input_action.menu_node
			if not menu:
				return
			if event is InputEventKey:
				var acc: int = menu.get_item_accelerator(input_action.menu_item_id)
				# If the event is the same as the menu item's accelerator, skip
				if acc == event.get_scancode_with_modifiers():
					return
			menu.emit_signal("id_pressed", input_action.menu_item_id)
			return
		if event.is_action(action) and input_action.echo:
			if event.is_echo():
				var menu: PopupMenu = input_action.menu_node
				menu.emit_signal("id_pressed", input_action.menu_item_id)
				return


func action_add_event(action: String, new_event: InputEvent) -> void:
	InputMap.action_add_event(action, new_event)
	if action in actions and actions[action] is MenuInputAction:
		actions[action].update_item_accelerator(action)


func action_erase_event(action: String, event: InputEvent) -> void:
	InputMap.action_erase_event(action, event)
	if action in actions and actions[action] is MenuInputAction:
		actions[action].update_item_accelerator(action)


func action_erase_events(action: String) -> void:
	InputMap.action_erase_events(action)
	if action in actions and actions[action] is MenuInputAction:
		actions[action].update_item_accelerator(action)
