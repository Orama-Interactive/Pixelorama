extends Node

const TRANSLATIONS_PATH := "res://addons/keychain/translations"
const PROFILES_PATH := "user://shortcut_profiles"

# Change these settings
var profiles := [preload("profiles/default.tres")]
var selected_profile: ShortcutProfile = profiles[0]
var profile_index := 0
# Syntax: "action_name": InputAction.new("Action Display Name", "Group", true)
# Note that "action_name" must already exist in the Project's Input Map.
var actions := {}
# Syntax: "Group Name": InputGroup.new("Parent Group Name")
var groups := {}
var ignore_actions := []
var ignore_ui_actions := true
var changeable_types := [true, true, true, true]
var multiple_menu_accelerators := false
var config_path := "user://cache.ini"
var config_file: ConfigFile


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


# This class is useful for the accelerators of PopupMenu items
# It's possible for PopupMenu items to have multiple shortcuts by using
# set_item_shortcut(), but we have no control over the accelerator text that appears.
# Thus, we are stuck with using accelerators instead of shortcuts.
# If Godot ever receives the ability to change the accelerator text of the items,
# we could in theory remove this class.
# If you don't care about PopupMenus in the same scene as ShortcutEdit
# such as projects like Pixelorama where everything is in the same scene,
# then you can ignore this class.
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
		var first_key: InputEventKey = Keychain.action_get_first_key(action)
		var accel := first_key.get_scancode_with_modifiers() if first_key else 0
		node.set_item_accelerator(menu_item_id, accel)

	func handle_input(event: InputEvent, action: String) -> bool:
		if not node:
			return false
		if event.is_action_pressed(action, false, true):
			if event is InputEventKey:
				var acc: int = node.get_item_accelerator(menu_item_id)
				# If the event is the same as the menu item's accelerator, skip
				if acc == event.get_scancode_with_modifiers():
					return true
			node.emit_signal("id_pressed", menu_item_id)
			return true
		if event.is_action(action, true) and echo:
			if event.is_echo():
				node.emit_signal("id_pressed", menu_item_id)
				return true

		return false


class InputGroup:
	var parent_group := ""
	var folded := true
	var tree_item: TreeItem

	func _init(_parent_group := "", _folded := true) -> void:
		parent_group = _parent_group
		folded = _folded


func _ready() -> void:
	if !config_file:
		config_file = ConfigFile.new()
		if !config_path.empty():
			config_file.load(config_path)

	set_process_input(multiple_menu_accelerators)

	# Load shortcut profiles
	var profile_dir := Directory.new()
	profile_dir.make_dir(PROFILES_PATH)
	profile_dir.open(PROFILES_PATH)
	profile_dir.list_dir_begin()
	var file_name = profile_dir.get_next()
	while file_name != "":
		if !profile_dir.current_is_dir():
			if file_name.get_extension() == "tres":
				var file = load(PROFILES_PATH.plus_file(file_name))
				if file is ShortcutProfile:
					profiles.append(file)
		file_name = profile_dir.get_next()

	# If there are no profiles besides the default, create one custom
	if profiles.size() == 1:
		var profile := ShortcutProfile.new()
		profile.name = "Custom"
		profile.resource_path = PROFILES_PATH.plus_file("custom.tres")
		var saved := profile.save()
		if saved:
			profiles.append(profile)

	for profile in profiles:
		profile.fill_bindings()

	var l18n_dir := Directory.new()
	l18n_dir.open(TRANSLATIONS_PATH)
	l18n_dir.list_dir_begin()
	file_name = l18n_dir.get_next()
	while file_name != "":
		if !l18n_dir.current_is_dir():
			if file_name.get_extension() == "po":
				var t: Translation = load(TRANSLATIONS_PATH.plus_file(file_name))
				TranslationServer.add_translation(t)
		file_name = l18n_dir.get_next()

	profile_index = config_file.get_value("shortcuts", "shortcuts_profile", 0)
	change_profile(profile_index)

	for action in actions:
		var input_action: InputAction = actions[action]
		if input_action is MenuInputAction:
			# Below line has been modified
			input_action.get_node(Global.top_menu_container.get_node("MenuItems"))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		return

	for action in actions:
		var input_action: InputAction = actions[action]
		var done: bool = input_action.handle_input(event, action)
		if done:
			return


func change_profile(index: int) -> void:
	if index >= profiles.size():
		index = profiles.size() - 1
	profile_index = index
	selected_profile = profiles[index]
	for action in selected_profile.bindings:
		action_erase_events(action)
		for event in selected_profile.bindings[action]:
			action_add_event(action, event)
	# NOTE: Following line not present in the plugin itself, be careful not to overwrite
	Global.update_hint_tooltips()


func action_add_event(action: String, event: InputEvent) -> void:
	InputMap.action_add_event(action, event)
	if action in actions:
		actions[action].update_node(action)


func action_erase_event(action: String, event: InputEvent) -> void:
	InputMap.action_erase_event(action, event)
	if action in actions:
		actions[action].update_node(action)


func action_erase_events(action: String) -> void:
	InputMap.action_erase_events(action)
	if action in actions:
		actions[action].update_node(action)


func action_get_first_key(action: String) -> InputEventKey:
	var first_key: InputEventKey = null
	var events := InputMap.get_action_list(action)
	for event in events:
		if event is InputEventKey:
			first_key = event
			break
	return first_key
