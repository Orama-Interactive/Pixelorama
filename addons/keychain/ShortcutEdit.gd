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
	"(Left Stick Left)",
	"(Left Stick Right)",
	"(Left Stick Up)",
	"(Left Stick Down)",
	"(Right Stick Left)",
	"(Right Stick Right)",
	"(Right Stick Up)",
	"(Right Stick Down)",
	"",
	"",
	"",
	"",
	"",
	"(L2)",
	"",
	"(R2)",
	"",
	"",
	"",
	"",
]

var currently_editing_tree_item: TreeItem
var is_editing := false
# Textures taken from Godot https://github.com/godotengine/godot/tree/master/editor/icons
var add_tex: Texture = preload("assets/add.svg")
var edit_tex: Texture = preload("assets/edit.svg")
var delete_tex: Texture = preload("assets/close.svg")
var joy_axis_tex: Texture = preload("assets/joy_axis.svg")
var joy_button_tex: Texture = preload("assets/joy_button.svg")
var key_tex: Texture = preload("assets/keyboard.svg")
var key_phys_tex: Texture = preload("assets/keyboard_physical.svg")
var mouse_tex: Texture = preload("assets/mouse.svg")
var shortcut_tex: Texture = preload("assets/shortcut.svg")
var folder_tex: Texture = preload("assets/folder.svg")

onready var tree: Tree = $VBoxContainer/ShortcutTree
onready var profile_option_button: OptionButton = find_node("ProfileOptionButton")
onready var rename_profile_button: Button = find_node("RenameProfile")
onready var delete_profile_button: Button = find_node("DeleteProfile")
onready var shortcut_type_menu: PopupMenu = $ShortcutTypeMenu
onready var keyboard_shortcut_selector: ConfirmationDialog = $KeyboardShortcutSelectorDialog
onready var mouse_shortcut_selector: ConfirmationDialog = $MouseShortcutSelectorDialog
onready var joy_key_shortcut_selector: ConfirmationDialog = $JoyKeyShortcutSelectorDialog
onready var joy_axis_shortcut_selector: ConfirmationDialog = $JoyAxisShortcutSelectorDialog
onready var profile_settings: ConfirmationDialog = $ProfileSettings
onready var profile_name: LineEdit = $ProfileSettings/ProfileName
onready var delete_confirmation: ConfirmationDialog = $DeleteConfirmation


func _ready() -> void:
	for profile in Keychain.profiles:
		profile_option_button.add_item(profile.name)

	_fill_selector_options()

	# Remove input types that are not changeable
	var i := 0
	for type in Keychain.changeable_types:
		if !type:
			shortcut_type_menu.remove_item(i)
		else:
			i += 1

	profile_option_button.select(Keychain.profile_index)
	_on_ProfileOptionButton_item_selected(Keychain.profile_index)
	if OS.get_name() == "HTML5":
		$VBoxContainer/HBoxContainer/OpenProfileFolder.queue_free()


func _construct_tree() -> void:
	var buttons_disabled := false if Keychain.selected_profile.customizable else true
	var tree_root: TreeItem = tree.create_item()
	for group in Keychain.groups:  # Create groups
		var input_group: Keychain.InputGroup = Keychain.groups[group]
		_create_group_tree_item(input_group, group)

	for action in InputMap.get_actions():  # Fill the tree with actions and their events
		if action in Keychain.ignore_actions:
			continue
		if Keychain.ignore_ui_actions and action.begins_with("ui_"):
			continue

		var display_name := get_action_name(action)
		var group_name := ""
		if action in Keychain.actions:
			var input_action: Keychain.InputAction = Keychain.actions[action]
			group_name = input_action.group

		var tree_item: TreeItem
		if group_name and group_name in Keychain.groups:
			var input_group: Keychain.InputGroup = Keychain.groups[group_name]
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
		var text: String = tr("Button") + " %s" % i
		if i < JOY_BUTTON_NAMES.size():
			text += " (%s)" % tr(JOY_BUTTON_NAMES[i])
		joy_key_option_button.add_item(text)

	var joy_axis_option_button: OptionButton = joy_axis_shortcut_selector.option_button
	var i := 0.0
	for option in JOY_AXIS_NAMES:
		var sign_symbol = "+" if floor(i) != i else "-"
		var text: String = tr("Axis") + " %s %s %s" % [floor(i), sign_symbol, tr(option)]
		joy_axis_option_button.add_item(text)
		i += 0.5


func _create_group_tree_item(group: Keychain.InputGroup, group_name: String) -> void:
	if group.tree_item:
		return

	var group_root: TreeItem
	if group.parent_group:
		var parent_group: Keychain.InputGroup = Keychain.groups[group.parent_group]
		_create_group_tree_item(parent_group, group.parent_group)
		group_root = tree.create_item(parent_group.tree_item)
	else:
		group_root = tree.create_item(tree.get_root())
	group_root.set_text(0, group_name)
	group_root.set_icon(0, folder_tex)
	group.tree_item = group_root
	if group.folded:
		group_root.collapsed = true


func get_action_name(action: String) -> String:
	var display_name := ""
	if action in Keychain.actions:
		display_name = Keychain.actions[action].display_name

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
			if !Keychain.changeable_types[0]:
				return
		"InputEventMouseButton":
			if !Keychain.changeable_types[1]:
				return
		"InputEventJoypadButton":
			if !Keychain.changeable_types[2]:
				return
		"InputEventJoypadMotion":
			if !Keychain.changeable_types[3]:
				return

	var buttons_disabled := false if Keychain.selected_profile.customizable else true
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
		output = tr(MOUSE_BUTTON_NAMES[event.button_index - 1])

	elif event is InputEventJoypadButton:
		var button_index: int = event.button_index
		output = tr("Button")
		if button_index >= JOY_BUTTON_NAMES.size():
			output += " %s" % button_index
		else:
			output += " %s (%s)" % [button_index, tr(JOY_BUTTON_NAMES[button_index])]

	elif event is InputEventJoypadMotion:
		var positive_axis: bool = event.axis_value > 0
		var axis_value: int = event.axis * 2 + int(positive_axis)
		var sign_symbol = "+" if positive_axis else "-"
		output = tr("Axis")
		output += " %s %s %s" % [event.axis, sign_symbol, tr(JOY_AXIS_NAMES[axis_value])]
	return output


func _on_ShortcutTree_button_pressed(item: TreeItem, _column: int, id: int) -> void:
	var action = item.get_metadata(0)
	currently_editing_tree_item = item
	if action is String:
		if id == 0:  # Add
			var rect: Rect2 = tree.get_item_area_rect(item, 0)
			rect.position.x = rect.end.x - 42
			rect.position.y += 42 - tree.get_scroll().y
			rect.position += rect_global_position
			rect.size = Vector2(110, 23 * shortcut_type_menu.get_item_count())
			shortcut_type_menu.popup(rect)
		elif id == 1:  # Delete
			Keychain.action_erase_events(action)
			Keychain.selected_profile.change_action(action)
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
			Keychain.action_erase_event(parent_action, action)
			Keychain.selected_profile.change_action(parent_action)
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


func _on_ProfileOptionButton_item_selected(index: int) -> void:
	Keychain.change_profile(index)
	rename_profile_button.disabled = false if Keychain.selected_profile.customizable else true
	delete_profile_button.disabled = false if Keychain.selected_profile.customizable else true

	# Re-construct the tree
	for group in Keychain.groups:
		Keychain.groups[group].tree_item = null
	tree.clear()
	_construct_tree()
	Keychain.config_file.set_value("shortcuts", "shortcuts_profile", index)
	Keychain.config_file.save(Keychain.config_path)


func _on_NewProfile_pressed() -> void:
	is_editing = false
	profile_name.text = "New Shortcut Profile"
	profile_settings.window_title = "New Shortcut Profile"
	profile_settings.popup_centered()


func _on_RenameProfile_pressed() -> void:
	is_editing = true
	profile_name.text = Keychain.selected_profile.name
	profile_settings.window_title = "Rename Shortcut Profile"
	profile_settings.popup_centered()


func _on_DeleteProfile_pressed() -> void:
	delete_confirmation.popup_centered()


func _on_OpenProfileFolder_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path(Keychain.PROFILES_PATH))


func _on_ProfileSettings_confirmed() -> void:
	var file_name := profile_name.text + ".tres"
	var profile := ShortcutProfile.new()
	profile.name = profile_name.text
	profile.resource_path = Keychain.PROFILES_PATH.plus_file(file_name)
	profile.fill_bindings()
	var saved := profile.save()
	if not saved:
		return

	if is_editing:
		var old_file_name: String = Keychain.selected_profile.resource_path
		if old_file_name != file_name:
			_delete_profile_file(old_file_name)
		Keychain.profiles[Keychain.profile_index] = profile
		profile_option_button.set_item_text(Keychain.profile_index, profile.name)
	else:  # Add new shortcut profile
		Keychain.profiles.append(profile)
		profile_option_button.add_item(profile.name)
		Keychain.profile_index = Keychain.profiles.size() - 1
		profile_option_button.select(Keychain.profile_index)
		_on_ProfileOptionButton_item_selected(Keychain.profile_index)


func _delete_profile_file(file_name: String) -> void:
	var dir := Directory.new()
	dir.remove(file_name)


func _on_DeleteConfirmation_confirmed() -> void:
	_delete_profile_file(Keychain.selected_profile.resource_path)
	profile_option_button.remove_item(Keychain.profile_index)
	Keychain.profiles.remove(Keychain.profile_index)
	Keychain.profile_index -= 1
	if Keychain.profile_index < 0:
		Keychain.profile_index = 0
	profile_option_button.select(Keychain.profile_index)
	_on_ProfileOptionButton_item_selected(Keychain.profile_index)
