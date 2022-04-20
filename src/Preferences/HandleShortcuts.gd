extends Node

var default_shortcuts_preset := {}
var custom_shortcuts_preset := {}
var action_being_edited := ""
var shortcut_already_assigned = false
var old_input_event: InputEventKey
var new_input_event: InputEventKey

onready var shortcut_selector_popup = Global.preferences_dialog.get_node("Popups/ShortcutSelector")
onready var theme_font_color: Color = shortcut_selector_popup.get_node("EnteredShortcut").get_color(
	"font_color"
)


func _ready() -> void:
	# Disable input until the shortcut selector is displayed
	set_process_input(false)

	# Get default preset for shortcuts from project input map
	# Buttons in shortcuts selector should be called the same as actions
	for shortcut_grid_item in get_node("Shortcuts").get_children():
		if shortcut_grid_item is Button:
			var input_events = InputMap.get_action_list(shortcut_grid_item.name)
			if input_events.size() > 1:
				printerr(
					"Every shortcut action should have just one input event assigned in input map"
				)
			shortcut_grid_item.text = (input_events[0] as InputEventKey).as_text()
			shortcut_grid_item.connect(
				"pressed", self, "_on_Shortcut_button_pressed", [shortcut_grid_item]
			)
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


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			if event.scancode == KEY_ESCAPE:
				shortcut_selector_popup.hide()
			else:
				# Check if shortcut was already used
				for action in InputMap.get_actions():
					for input_event in InputMap.get_action_list(action):
						if input_event is InputEventKey:
							if (
								OS.get_scancode_string(input_event.get_scancode_with_modifiers())
								== OS.get_scancode_string(event.get_scancode_with_modifiers())
							):
								shortcut_selector_popup.get_node("EnteredShortcut").text = tr(
									"Already assigned"
								)
								shortcut_selector_popup.get_node("EnteredShortcut").add_color_override(
									"font_color", Color.crimson
								)
								get_tree().set_input_as_handled()
								shortcut_already_assigned = true
								return

				# Store new shortcut
				shortcut_already_assigned = false
				old_input_event = InputMap.get_action_list(action_being_edited)[0]
				new_input_event = event
				shortcut_selector_popup.get_node("EnteredShortcut").text = OS.get_scancode_string(
					event.get_scancode_with_modifiers()
				)
				shortcut_selector_popup.get_node("EnteredShortcut").add_color_override(
					"font_color", theme_font_color
				)
			get_tree().set_input_as_handled()


func _on_PresetOptionButton_item_selected(id: int) -> void:
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
		var preset_old_input_event: InputEventKey = InputMap.get_action_list(action)[0]
		set_action_shortcut(action, preset_old_input_event, preset[action])
		get_node("Shortcuts/" + action).text = OS.get_scancode_string(
			preset[action].get_scancode_with_modifiers()
		)
	Global.update_hint_tooltips()


func toggle_shortcut_buttons(enabled: bool) -> void:
	for shortcut_grid_item in get_node("Shortcuts").get_children():
		if shortcut_grid_item is Button:
			shortcut_grid_item.disabled = not enabled
			if shortcut_grid_item.disabled:
				shortcut_grid_item.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
			else:
				shortcut_grid_item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_action_shortcut(action: String, oldinput: InputEventKey, newinput: InputEventKey) -> void:
	# Only updates the InputMap
	InputMap.action_erase_event(action, oldinput)
	InputMap.action_add_event(action, newinput)
	update_ui_shortcuts(action)


func update_ui_shortcuts(action: String):
	# Updates UI elements according to InputMap (Tool shortcuts are updated from a seperate function)
	# Set shortcut to switch colors button
	if action == "switch_colors":
		var color_switch: BaseButton = Global.control.find_node("ColorSwitch")
		color_switch.shortcut.shortcut = InputMap.get_action_list(action)[0]
	# Set timeline shortcuts
	if action == "go_to_first_frame":
		var first_frame: BaseButton = Global.control.find_node("FirstFrame")
		first_frame.shortcut.shortcut = InputMap.get_action_list(action)[0]
	if action == "go_to_previous_frame":
		var previous_frame: BaseButton = Global.control.find_node("PreviousFrame")
		previous_frame.shortcut.shortcut = InputMap.get_action_list(action)[0]
	if action == "play_backwards":
		var play_backwards: BaseButton = Global.control.find_node("PlayBackwards")
		play_backwards.shortcut.shortcut = InputMap.get_action_list(action)[0]
	if action == "play_forward":
		var play_forward: BaseButton = Global.control.find_node("PlayForward")
		play_forward.shortcut.shortcut = InputMap.get_action_list(action)[0]
	if action == "go_to_next_frame":
		var next_frame: BaseButton = Global.control.find_node("NextFrame")
		next_frame.shortcut.shortcut = InputMap.get_action_list(action)[0]
	if action == "go_to_last_frame":
		var last_frame: BaseButton = Global.control.find_node("LastFrame")
		last_frame.shortcut.shortcut = InputMap.get_action_list(action)[0]
	# Set shortcuts for Menu Options
	var top_menu: Panel = Global.control.find_node("TopMenuContainer")
	var file_menu: PopupMenu = top_menu.file_menu_button.get_popup()
	var edit_menu: PopupMenu = top_menu.edit_menu_button.get_popup()
	var select_menu: PopupMenu = top_menu.select_menu_button.get_popup()
	var view_menu: PopupMenu = top_menu.view_menu_button.get_popup()
	var window_menu: PopupMenu = top_menu.window_menu_button.get_popup()
	var help_menu: PopupMenu = top_menu.help_menu_button.get_popup()
	if action == "new_file":
		update_menu_option(file_menu, "New...", action)
	if action == "open_file":
		update_menu_option(file_menu, "Open...", action)
	if action == "save_file":
		update_menu_option(file_menu, "Save...", action)
	if action == "save_file_as":
		update_menu_option(file_menu, "Save as...", action)
	if action == "export_file":
		update_menu_option(file_menu, "Export...", action)
	if action == "export_file_as":
		update_menu_option(file_menu, "Export as...", action)
	if action == "quit":
		update_menu_option(file_menu, "Quit", action)
	if action == "undo":
		update_menu_option(edit_menu, "Undo", action)
	if action == "redo":
		update_menu_option(edit_menu, "Redo", action)
	if action == "copy":
		update_menu_option(edit_menu, "Copy", action)
	if action == "cut":
		update_menu_option(edit_menu, "Cut", action)
	if action == "paste":
		update_menu_option(edit_menu, "Paste", action)
	if action == "delete":
		update_menu_option(edit_menu, "Delete", action)
	if action == "new_brush":
		update_menu_option(edit_menu, "New Brush", action)
	if action == "select_all":
		update_menu_option(select_menu, "All", action)
	if action == "clear_selection":
		update_menu_option(select_menu, "Clear", action)
	if action == "invert_selection":
		update_menu_option(select_menu, "Invert", action)
	if action == "mirror_view":
		update_menu_option(view_menu, "Mirror View", action)
	if action == "show_grid":
		update_menu_option(view_menu, "Show Grid", action)
	if action == "show_pixel_grid":
		update_menu_option(view_menu, "Show Pixel Grid", action)
	if action == "show_rulers":
		update_menu_option(view_menu, "Show Rulers", action)
	if action == "show_guides":
		update_menu_option(view_menu, "Show Guides", action)
	if action == "edit_mode":
		for child in window_menu.get_children():
			if child.name == "panels_submenu":
				update_menu_option(child, "Moveable Panels", action)
	if action == "zen_mode":
		update_menu_option(window_menu, "Zen Mode", action)
	if action == "toggle_fullscreen":
		update_menu_option(window_menu, "Fullscreen Mode", action)
	if action == "open_docs":
		update_menu_option(help_menu, "Online Docs", action)


func update_menu_option(menu :PopupMenu, name :String, action):
	for idx in menu.get_item_count():
		if menu.get_item_text(idx) == name:
			var accel: int = InputMap.get_action_list(action)[0].get_scancode_with_modifiers()
			menu.set_item_accelerator(idx, accel)


func _on_Shortcut_button_pressed(button: Button) -> void:
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
		Global.update_hint_tooltips()
		custom_shortcuts_preset[action_being_edited] = new_input_event
		Global.config_cache.set_value("shortcuts", action_being_edited, new_input_event)
		Global.config_cache.save("user://cache.ini")
		get_node("Shortcuts/" + action_being_edited).text = OS.get_scancode_string(
			new_input_event.get_scancode_with_modifiers()
		)
		shortcut_selector_popup.hide()
