extends Node

var default_shortcuts_preset := {}
var custom_shortcuts_preset := {}
var action_being_edited := ""
var shortcut_already_assigned = false
var old_input_event : InputEventKey
var new_input_event : InputEventKey

onready var shortcut_selector_popup = Global.preferences_dialog.get_node("Popups/ShortcutSelector")
onready var theme_font_color : Color = Global.preferences_dialog.get_node("Popups/ShortcutSelector/EnteredShortcut").get_color("font_color")


func _ready() -> void:
	# Disable input until the shortcut selector is displayed
	set_process_input(false)

	# Get default preset for shortcuts from project input map
	# Buttons in shortcuts selector should be called the same as actions
	for shortcut_grid_item in get_node("Shortcuts").get_children():
		if shortcut_grid_item is Button:
			var input_events = InputMap.get_action_list(shortcut_grid_item.name)
			if input_events.size() > 1:
				printerr("Every shortcut action should have just one input event assigned in input map")
			shortcut_grid_item.text = (input_events[0] as InputEventKey).as_text()
			shortcut_grid_item.connect("pressed", self, "_on_Shortcut_button_pressed", [shortcut_grid_item])
			default_shortcuts_preset[shortcut_grid_item.name] = input_events[0]

	# Load custom shortcuts from the config file
	custom_shortcuts_preset = default_shortcuts_preset.duplicate()
	for action in default_shortcuts_preset:
		var saved_input_event = Global.config_cache.get_value("shortcuts", action, 0)
		if saved_input_event is InputEventKey:
			custom_shortcuts_preset[action] = saved_input_event

	var shortcuts_preset = Global.config_cache.get_value("shortcuts", "shortcuts_preset", 0)
	get_node("HBoxContainer/PresetOptionButton").select(shortcuts_preset)
	_on_PresetOptionButton_item_selected(shortcuts_preset)


func _input(event : InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			if event.scancode == KEY_ESCAPE:
				shortcut_selector_popup.hide()
			else:
				# Check if shortcut was already used
				for action in InputMap.get_actions():
					for input_event in InputMap.get_action_list(action):
						if input_event is InputEventKey:
							if OS.get_scancode_string(input_event.get_scancode_with_modifiers()) == OS.get_scancode_string(event.get_scancode_with_modifiers()):
								shortcut_selector_popup.get_node("EnteredShortcut").text = tr("Already assigned")
								shortcut_selector_popup.get_node("EnteredShortcut").add_color_override("font_color", Color.crimson)
								get_tree().set_input_as_handled()
								shortcut_already_assigned = true
								return

				# Store new shortcut
				shortcut_already_assigned = false
				old_input_event = InputMap.get_action_list(action_being_edited)[0]
				new_input_event = event
				shortcut_selector_popup.get_node("EnteredShortcut").text = OS.get_scancode_string(event.get_scancode_with_modifiers())
				shortcut_selector_popup.get_node("EnteredShortcut").add_color_override("font_color", theme_font_color)
			get_tree().set_input_as_handled()


func _on_PresetOptionButton_item_selected(id : int) -> void:
	# Only custom preset which is modifiable
	toggle_shortcut_buttons(true if id == 1 else false)
	match id:
		0:
			apply_shortcuts_preset(default_shortcuts_preset)
		1:
			apply_shortcuts_preset(custom_shortcuts_preset)
	Global.config_cache.set_value("shortcuts", "shortcuts_preset", id)
	Global.config_cache.save("user://cache.ini")


func apply_shortcuts_preset(preset) -> void:
	for action in preset:
		var old_input_event : InputEventKey = InputMap.get_action_list(action)[0]
		set_action_shortcut(action, old_input_event, preset[action])
		get_node("Shortcuts/" + action).text = OS.get_scancode_string(preset[action].get_scancode_with_modifiers())


func toggle_shortcut_buttons(enabled : bool) -> void:
	for shortcut_grid_item in get_node("Shortcuts").get_children():
		if shortcut_grid_item is Button:
			shortcut_grid_item.disabled = not enabled
			if shortcut_grid_item.disabled:
				shortcut_grid_item.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
			else:
				shortcut_grid_item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_action_shortcut(action : String, old_input : InputEventKey, new_input : InputEventKey) -> void:
	InputMap.action_erase_event(action, old_input)
	InputMap.action_add_event(action, new_input)
	Global.update_hint_tooltips()
	# Set shortcut to switch colors button
	if action == "switch_colors":
		Global.color_switch_button.shortcut.shortcut = InputMap.get_action_list("switch_colors")[0]


func _on_Shortcut_button_pressed(button : Button) -> void:
	set_process_input(true)
	action_being_edited = button.name
	new_input_event = InputMap.get_action_list(button.name)[0]
	shortcut_already_assigned = true
	shortcut_selector_popup.popup_centered()


func _on_ShortcutSelector_popup_hide() -> void:
	set_process_input(false)
	shortcut_selector_popup.get_node("EnteredShortcut").text = ""


func _on_ShortcutSelector_confirmed() -> void:
	if not shortcut_already_assigned:
		set_action_shortcut(action_being_edited, old_input_event, new_input_event)
		custom_shortcuts_preset[action_being_edited] = new_input_event
		Global.config_cache.set_value("shortcuts", action_being_edited, new_input_event)
		Global.config_cache.save("user://cache.ini")
		get_node("Shortcuts/" + action_being_edited).text = OS.get_scancode_string(new_input_event.get_scancode_with_modifiers())
		shortcut_selector_popup.hide()
