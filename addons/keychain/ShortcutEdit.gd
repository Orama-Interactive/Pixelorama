extends Control

enum { KEYBOARD, MOUSE, JOY_BUTTON, JOY_AXIS }

const MOUSE_BUTTON_NAMES: PackedStringArray = [
	"Left Button",
	"Right Button",
	"Middle Button",
	"Wheel Up Button",
	"Wheel Down Button",
	"Wheel Left Button",
	"Wheel Right Button",
	"Mouse Thumb Button 1",
	"Mouse Thumb Button 2",
]

const JOY_BUTTON_NAMES: PackedStringArray = [
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

const JOY_AXIS_NAMES: PackedStringArray = [
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
var currently_editing_mouse_movement_action: Keychain.MouseMovementInputAction
var is_editing := false
var current_name_filter := ""
var current_event_filter: InputEvent
var filter_by_shortcut_line_edit_has_focus := false
# Textures taken from Godot https://github.com/godotengine/godot/tree/master/editor/icons
var add_tex: Texture2D = preload("assets/add.svg")
var edit_tex: Texture2D = preload("assets/edit.svg")
var delete_tex: Texture2D = preload("assets/close.svg")
var joy_axis_tex: Texture2D = preload("assets/joy_axis.svg")
var joy_button_tex: Texture2D = preload("assets/joy_button.svg")
var key_tex: Texture2D = preload("assets/keyboard.svg")
var key_phys_tex: Texture2D = preload("assets/keyboard_physical.svg")
var mouse_tex: Texture2D = preload("assets/mouse.svg")
var shortcut_tex: Texture2D = preload("assets/shortcut.svg")
var folder_tex: Texture2D = preload("assets/folder.svg")

@onready var filter_by_name_line_edit: LineEdit = %FilterByNameLineEdit
@onready var filter_by_shortcut_line_edit: LineEdit = %FilterByShortcutLineEdit
@onready var tree: Tree = $VBoxContainer/ShortcutTree
@onready var profile_option_button: OptionButton = find_child("ProfileOptionButton")
@onready var rename_profile_button: Button = find_child("RenameProfile")
@onready var delete_profile_button: Button = find_child("DeleteProfile")

@onready var mouse_movement_options: HBoxContainer = $VBoxContainer/MouseMovementOptions
@onready var mm_top_left: Button = %MMTopLeft
@onready var mm_top: Button = %MMTop
@onready var mm_top_right: Button = %MMTopRight
@onready var mm_left: Button = %MMLeft
@onready var mm_center: Button = %MMCenter
@onready var mm_right: Button = %MMRight
@onready var mm_bottom_left: Button = %MMBottomLeft
@onready var mm_bottom: Button = %MMBottom
@onready var mm_bottom_right: Button = %MMBottomRight
@onready var sensitivity_range: SpinBox = $VBoxContainer/MouseMovementOptions/SensitivityRange

@onready var shortcut_type_menu: PopupMenu = $ShortcutTypeMenu
@onready var keyboard_shortcut_selector: ConfirmationDialog = $KeyboardShortcutSelectorDialog
@onready var mouse_shortcut_selector: ConfirmationDialog = $MouseShortcutSelectorDialog
@onready var joy_key_shortcut_selector: ConfirmationDialog = $JoyKeyShortcutSelectorDialog
@onready var joy_axis_shortcut_selector: ConfirmationDialog = $JoyAxisShortcutSelectorDialog
@onready var profile_settings: ConfirmationDialog = $ProfileSettings
@onready var profile_name: LineEdit = $ProfileSettings/ProfileName
@onready var delete_confirmation: ConfirmationDialog = $DeleteConfirmation
@onready var reset_confirmation: ConfirmationDialog = $ResetConfirmation


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
	mm_top_left.button_group.pressed.connect(_on_mouse_movement_angle_changed)
	if OS.get_name() == "Web":
		$VBoxContainer/HBoxContainer/OpenProfileFolder.queue_free()


func _construct_tree() -> void:
	var tree_root: TreeItem = tree.create_item()
	for group in Keychain.groups:  # Create groups
		var input_group: Keychain.InputGroup = Keychain.groups[group]
		_create_group_tree_item(input_group, group)

	for action in InputMap.get_actions():  # Fill the tree with actions and their events
		if action in Keychain.ignore_actions:
			continue
		if Keychain.ignore_ui_actions and (action as String).begins_with("ui_"):
			continue

		var display_name := get_action_name(action)
		var group_name := ""
		if action in Keychain.actions:
			var input_action: Keychain.InputAction = Keychain.actions[action]
			group_name = input_action.group

		var tree_item: TreeItem
		if not group_name.is_empty() and group_name in Keychain.groups:
			var input_group: Keychain.InputGroup = Keychain.groups[group_name]
			var group_root: TreeItem = input_group.tree_item
			tree_item = tree.create_item(group_root)

		else:
			tree_item = tree.create_item(tree_root)

		tree_item.set_text(0, display_name)
		tree_item.set_metadata(0, action)
		tree_item.set_icon(0, shortcut_tex)
		for event in InputMap.action_get_events(action):
			add_event_tree_item(event, tree_item)

		var buttons_disabled := false if Keychain.selected_profile.customizable else true
		tree_item.add_button(0, add_tex, 0, buttons_disabled, "Add")
		tree_item.add_button(0, delete_tex, 1, buttons_disabled, "Delete")
		tree_item.collapsed = true
	mouse_movement_options.hide()


func _fill_selector_options() -> void:
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
		var sign_symbol := "+" if floori(i) != i else "-"
		var text: String = tr("Axis") + " %s %s %s" % [floori(i), sign_symbol, tr(option)]
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

	if display_name.is_empty():
		display_name = Keychain.humanize_snake_case(action)
	return display_name


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
			var scancode: int = event.get_keycode_with_modifiers()
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
	var output := event.as_text()
	# event.as_text() could be used for these event types as well, but this gives more control
	# to the developer as to what strings will be printed
	if event is InputEventJoypadButton:
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


func _on_filter_by_name_line_edit_text_changed(new_text: String) -> void:
	current_name_filter = new_text.strip_edges()
	apply_search_filters()


func _on_filter_by_shortcut_line_edit_gui_input(event: InputEvent) -> void:
	if (
		not event is InputEventKey
		and not event is InputEventMouseButton
		and not event is InputEventJoypadButton
	):
		return
	if event.pressed:
		if event is InputEventMouseButton:
			if not filter_by_shortcut_line_edit_has_focus:
				return
			if event.position.x >= filter_by_shortcut_line_edit.get_rect().size.x - 30:
				return
		current_event_filter = event
		filter_by_shortcut_line_edit.set_deferred(&"text", event.as_text())
		apply_search_filters()


func _on_filter_by_shortcut_line_edit_text_changed(new_text: String) -> void:
	if not new_text.is_empty():
		return
	current_event_filter = null
	apply_search_filters()


func _on_clear_all_filters_pressed() -> void:
	filter_by_name_line_edit.text = ""
	filter_by_shortcut_line_edit.text = ""
	current_name_filter = ""
	current_event_filter = null
	apply_search_filters()


func apply_search_filters() -> void:
	var tree_item: TreeItem = tree.get_root().get_first_child()
	var results: Array[TreeItem] = []
	var should_reset := (
		not is_instance_valid(current_event_filter) and current_name_filter.is_empty()
	)
	while tree_item != null:  # Loop through Tree's TreeItems.
		if is_instance_valid(current_event_filter):
			var metadata = tree_item.get_metadata(0)
			if metadata is InputEvent:
				if current_event_filter.is_match(metadata):
					if current_name_filter.is_empty():
						results.append(tree_item)
					else:
						var parent := tree_item.get_parent()
						if current_name_filter.is_subsequence_ofn(parent.get_text(0)):
							results.append(tree_item)
		elif not current_name_filter.is_empty():
			var metadata = tree_item.get_metadata(0)
			if metadata is StringName:
				if current_name_filter.is_subsequence_ofn(tree_item.get_text(0)):
					results.append(tree_item)
			elif metadata is InputEvent:
				tree_item = tree_item.get_next_in_tree()
				continue

		if should_reset:
			tree_item.visible = true
		else:
			tree_item.collapsed = true
			tree_item.visible = false
		tree_item = tree_item.get_next_in_tree()
	var expanded: Array[TreeItem] = []
	for result in results:
		var item: TreeItem = result
		while item.get_parent():
			if expanded.has(item):
				break
			item.collapsed = false
			item.visible = true
			expanded.append(item)
			item = item.get_parent()
	if not results.is_empty():
		tree.scroll_to_item(results[0])


func _on_shortcut_tree_button_clicked(item: TreeItem, _column: int, id: int, _mbi: int) -> void:
	var action = item.get_metadata(0)
	currently_editing_tree_item = item
	if action is StringName:
		if id == 0:  # Add
			var rect: Rect2 = tree.get_item_area_rect(item, 0)
			rect.position.x = rect.end.x - 42
			rect.position.y += 42 - tree.get_scroll().y
			rect.position += global_position
			rect.size = Vector2(110, 23 * shortcut_type_menu.get_item_count())
			shortcut_type_menu.popup_on_parent(rect)
		elif id == 1:  # Delete
			Keychain.action_erase_events(action)
			Keychain.change_action(action)
			for child in item.get_children():
				child.free()

	elif action is InputEvent:
		var parent_action = item.get_parent().get_metadata(0)
		if id == 0:  # Edit
			if action is InputEventKey:
				keyboard_shortcut_selector.popup_centered_clamped()
			elif action is InputEventMouseButton:
				mouse_shortcut_selector.popup_centered_clamped()
			elif action is InputEventJoypadButton:
				joy_key_shortcut_selector.popup_centered_clamped()
			elif action is InputEventJoypadMotion:
				joy_axis_shortcut_selector.popup_centered_clamped()
		elif id == 1:  # Delete
			if not parent_action is StringName:
				return
			Keychain.action_erase_event(parent_action, action)
			Keychain.change_action(parent_action)
			item.free()


func _on_shortcut_tree_item_selected() -> void:
	var selected_item: TreeItem = tree.get_selected()
	var action = selected_item.get_metadata(0)
	if action is StringName:
		if not Keychain.actions.has(action):
			mouse_movement_options.visible = false
			return
		var keychain_action := Keychain.actions[action]
		if keychain_action is Keychain.MouseMovementInputAction:
			mouse_movement_options.visible = true
			currently_editing_mouse_movement_action = keychain_action
			_press_mouse_movement_angle_button()
			sensitivity_range.set_value_no_signal(
				currently_editing_mouse_movement_action.sensitivity
			)
		else:
			mouse_movement_options.visible = false


func _on_ShortcutTree_item_activated() -> void:
	var selected_item: TreeItem = tree.get_selected()
	if selected_item.get_button_count(0) > 0 and !selected_item.is_button_disabled(0, 0):
		_on_shortcut_tree_button_clicked(tree.get_selected(), 0, 0, 0)
	elif selected_item.get_button_count(0) == 0:  # Group item
		selected_item.collapsed = not selected_item.collapsed


func _on_ShortcutTypeMenu_id_pressed(id: int) -> void:
	if id == KEYBOARD:
		keyboard_shortcut_selector.popup_centered_clamped()
	elif id == MOUSE:
		mouse_shortcut_selector.popup_centered_clamped()
	elif id == JOY_BUTTON:
		joy_key_shortcut_selector.popup_centered_clamped()
	elif id == JOY_AXIS:
		joy_axis_shortcut_selector.popup_centered_clamped()


func _on_mouse_movement_angle_changed(button: BaseButton) -> void:
	match button:
		mm_top_left:
			currently_editing_mouse_movement_action.mouse_dir = Vector2(-1, -1)
		mm_top:
			currently_editing_mouse_movement_action.mouse_dir = Vector2.UP
		mm_top_right:
			currently_editing_mouse_movement_action.mouse_dir = Vector2(1, -1)
		mm_left:
			currently_editing_mouse_movement_action.mouse_dir = Vector2.LEFT
		mm_right:
			currently_editing_mouse_movement_action.mouse_dir = Vector2.RIGHT
		mm_bottom_left:
			currently_editing_mouse_movement_action.mouse_dir = Vector2(-1, 1)
		mm_bottom:
			currently_editing_mouse_movement_action.mouse_dir = Vector2.DOWN
		mm_bottom_right:
			currently_editing_mouse_movement_action.mouse_dir = Vector2(1, 1)
	Keychain.change_mouse_movement_action_settings(currently_editing_mouse_movement_action)


func _press_mouse_movement_angle_button() -> void:
	var dir := currently_editing_mouse_movement_action.mouse_dir
	match dir:
		Vector2(-1, -1):
			mm_top_left.button_pressed = true
		Vector2.UP:
			mm_top.button_pressed = true
		Vector2(1, -1):
			mm_top_right.button_pressed = true
		Vector2.LEFT:
			mm_left.button_pressed = true
		Vector2.RIGHT:
			mm_right.button_pressed = true
		Vector2(-1, 1):
			mm_bottom_left.button_pressed = true
		Vector2.DOWN:
			mm_bottom.button_pressed = true
		Vector2(1, 1):
			mm_bottom_right.button_pressed = true


func _on_sensitivity_range_value_changed(value: float) -> void:
	currently_editing_mouse_movement_action.sensitivity = value
	Keychain.change_mouse_movement_action_settings(currently_editing_mouse_movement_action)


func _on_ProfileOptionButton_item_selected(index: int) -> void:
	Keychain.change_profile(index)
	rename_profile_button.disabled = false if Keychain.selected_profile.customizable else true
	delete_profile_button.disabled = false if Keychain.selected_profile.customizable else true
	if Keychain.profiles.size() == 1:
		delete_profile_button.disabled = true

	_reconstruct_tree()
	Keychain.config_file.set_value("shortcuts", "shortcuts_profile", index)
	Keychain.config_file.save(Keychain.config_path)


func _on_NewProfile_pressed() -> void:
	is_editing = false
	profile_name.text = "New Shortcut Profile"
	profile_settings.title = "New Shortcut Profile"
	profile_settings.popup_centered_clamped()


func _on_reset_profile_pressed() -> void:
	reset_confirmation.popup_centered_clamped()


func _on_RenameProfile_pressed() -> void:
	is_editing = true
	profile_name.text = Keychain.selected_profile.name
	profile_settings.title = "Rename Shortcut Profile"
	profile_settings.popup_centered_clamped()


func _on_DeleteProfile_pressed() -> void:
	delete_confirmation.popup_centered_clamped()


func _on_OpenProfileFolder_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path(Keychain.PROFILES_PATH))


func _on_ProfileSettings_confirmed() -> void:
	var file_name := profile_name.text + ".tres"
	var profile := ShortcutProfile.new()
	profile.name = profile_name.text
	profile.resource_path = Keychain.PROFILES_PATH.path_join(file_name)
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
	var dir := DirAccess.open(file_name.get_base_dir())
	var err := DirAccess.get_open_error()
	if err != OK:
		print("Error deleting shortcut profile %s. Error code: %s" % [file_name, err])
		return
	dir.remove(file_name)


func _on_DeleteConfirmation_confirmed() -> void:
	_delete_profile_file(Keychain.selected_profile.resource_path)
	profile_option_button.remove_item(Keychain.profile_index)
	Keychain.profiles.remove_at(Keychain.profile_index)
	Keychain.profile_index -= 1
	if Keychain.profile_index < 0:
		Keychain.profile_index = 0
	profile_option_button.select(Keychain.profile_index)
	_on_ProfileOptionButton_item_selected(Keychain.profile_index)


func _on_reset_confirmation_confirmed() -> void:
	Keychain.selected_profile.copy_bindings_from(Keychain.DEFAULT_PROFILE)
	Keychain.change_profile(Keychain.profile_index)
	_reconstruct_tree()


func _reconstruct_tree() -> void:
	for group in Keychain.groups:
		Keychain.groups[group].tree_item = null
	tree.clear()
	_construct_tree()


func _on_filter_by_shortcut_line_edit_focus_entered() -> void:
	set_deferred(&"filter_by_shortcut_line_edit_has_focus", true)


func _on_filter_by_shortcut_line_edit_focus_exited() -> void:
	filter_by_shortcut_line_edit_has_focus = false
