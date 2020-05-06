extends AcceptDialog

onready var tree : Tree = $HSplitContainer/Tree
onready var right_side : VBoxContainer = $HSplitContainer/ScrollContainer/VBoxContainer
onready var general = $HSplitContainer/ScrollContainer/VBoxContainer/General
onready var languages = $HSplitContainer/ScrollContainer/VBoxContainer/Languages
onready var themes = $HSplitContainer/ScrollContainer/VBoxContainer/Themes
onready var canvas = $HSplitContainer/ScrollContainer/VBoxContainer/Canvas
onready var image = $HSplitContainer/ScrollContainer/VBoxContainer/Image
onready var shortcuts = $HSplitContainer/ScrollContainer/VBoxContainer/Shortcuts

onready var open_last_project_button = $HSplitContainer/ScrollContainer/VBoxContainer/General/OpenLastProject
onready var smooth_zoom_button = $HSplitContainer/ScrollContainer/VBoxContainer/General/SmoothZoom
onready var sensitivity_option = $HSplitContainer/ScrollContainer/VBoxContainer/General/PressureSentivity/PressureSensitivityOptionButton
onready var left_tool_icon = $HSplitContainer/ScrollContainer/VBoxContainer/General/GridContainer/LeftToolIconCheckbox
onready var right_tool_icon = $HSplitContainer/ScrollContainer/VBoxContainer/General/GridContainer/RightToolIconCheckbox

onready var default_width_value = $HSplitContainer/ScrollContainer/VBoxContainer/Image/ImageOptions/ImageDefaultWidth
onready var default_height_value = $HSplitContainer/ScrollContainer/VBoxContainer/Image/ImageOptions/ImageDefaultHeight
onready var default_fill_color = $HSplitContainer/ScrollContainer/VBoxContainer/Image/ImageOptions/DefaultFillColor

onready var grid_width_value = $HSplitContainer/ScrollContainer/VBoxContainer/Canvas/GridOptions/GridWidthValue
onready var grid_height_value = $HSplitContainer/ScrollContainer/VBoxContainer/Canvas/GridOptions/GridHeightValue
onready var grid_color = $HSplitContainer/ScrollContainer/VBoxContainer/Canvas/GridOptions/GridColor
onready var guide_color = $HSplitContainer/ScrollContainer/VBoxContainer/Canvas/GuideOptions/GuideColor

onready var checker_size_value = $HSplitContainer/ScrollContainer/VBoxContainer/Canvas/CheckerOptions/CheckerSizeValue
onready var checker_color_1 = $HSplitContainer/ScrollContainer/VBoxContainer/Canvas/CheckerOptions/CheckerColor1
onready var checker_color_2 = $HSplitContainer/ScrollContainer/VBoxContainer/Canvas/CheckerOptions/CheckerColor2

# Shortcuts
onready var theme_font_color : Color = $Popups/ShortcutSelector/EnteredShortcut.get_color("font_color")
var default_shortcuts_preset := {}
var custom_shortcuts_preset := {}
var action_being_edited := ""
var shortcut_already_assigned = false
var old_input_event : InputEventKey
var new_input_event : InputEventKey


func _ready() -> void:
	# Disable input until the shortcut selector is displayed
	set_process_input(false)

	# Replace OK with Close since preference changes are being applied immediately, not after OK confirmation
	get_ok().text = tr("Close")

	for child in languages.get_children():
		if child is Button:
			child.connect("pressed", self, "_on_Language_pressed", [child])
			child.hint_tooltip = child.name

	for child in themes.get_children():
		if child is Button:
			child.connect("pressed", self, "_on_Theme_pressed", [child])

	if Global.config_cache.has_section_key("preferences", "theme"):
		var theme_id = Global.config_cache.get_value("preferences", "theme")
		change_theme(theme_id)
		themes.get_child(theme_id).pressed = true
	else:
		change_theme(0)
		themes.get_child(0).pressed = true

	# Set default values for General options
	if Global.config_cache.has_section_key("preferences", "open_last_project"):
		Global.open_last_project = Global.config_cache.get_value("preferences", "open_last_project")
		open_last_project_button.pressed = Global.open_last_project
	if Global.config_cache.has_section_key("preferences", "smooth_zoom"):
		Global.smooth_zoom = Global.config_cache.get_value("preferences", "smooth_zoom")
		smooth_zoom_button.pressed = Global.smooth_zoom
	if Global.config_cache.has_section_key("preferences", "pressure_sensitivity"):
		Global.pressure_sensitivity_mode = Global.config_cache.get_value("preferences", "pressure_sensitivity")
		sensitivity_option.selected = Global.pressure_sensitivity_mode

	if Global.config_cache.has_section_key("preferences", "show_left_tool_icon"):
		Global.show_left_tool_icon = Global.config_cache.get_value("preferences", "show_left_tool_icon")
		left_tool_icon.pressed = Global.show_left_tool_icon
	if Global.config_cache.has_section_key("preferences", "show_right_tool_icon"):
		Global.show_right_tool_icon = Global.config_cache.get_value("preferences", "show_right_tool_icon")
		right_tool_icon.pressed = Global.show_right_tool_icon

	# Get autosave settings
	if Global.config_cache.has_section_key("preferences", "autosave_interval"):
		var autosave_interval = Global.config_cache.get_value("preferences", "autosave_interval")
		OpenSave.set_autosave_interval(autosave_interval)
		general.get_node("AutosaveInterval/AutosaveInterval").value = autosave_interval
	if Global.config_cache.has_section_key("preferences", "enable_autosave"):
		var enable_autosave = Global.config_cache.get_value("preferences", "enable_autosave")
		OpenSave.toggle_autosave(enable_autosave)
		general.get_node("EnableAutosave").pressed = enable_autosave

	# Set default values for Canvas options
	if Global.config_cache.has_section_key("preferences", "grid_size"):
		var grid_size = Global.config_cache.get_value("preferences", "grid_size")
		Global.grid_width = int(grid_size.x)
		Global.grid_height = int(grid_size.y)
		grid_width_value.value = grid_size.x
		grid_height_value.value = grid_size.y

	if Global.config_cache.has_section_key("preferences", "grid_color"):
		Global.grid_color = Global.config_cache.get_value("preferences", "grid_color")
		grid_color.color = Global.grid_color

	if Global.config_cache.has_section_key("preferences", "checker_size"):
		var checker_size = Global.config_cache.get_value("preferences", "checker_size")
		Global.checker_size = int(checker_size)
		checker_size_value.value = checker_size

	if Global.config_cache.has_section_key("preferences", "checker_color_1"):
		Global.checker_color_1 = Global.config_cache.get_value("preferences", "checker_color_1")
		checker_color_1.color = Global.checker_color_1

	if Global.config_cache.has_section_key("preferences", "checker_color_2"):
		Global.checker_color_2 = Global.config_cache.get_value("preferences", "checker_color_2")
		checker_color_2.color = Global.checker_color_2

	Global.transparent_checker._ready()

	if Global.config_cache.has_section_key("preferences", "guide_color"):
		Global.guide_color = Global.config_cache.get_value("preferences", "guide_color")
		for canvas in Global.canvases:
			for guide in canvas.get_children():
				if guide is Guide:
					guide.default_color = Global.guide_color
		guide_color.color = Global.guide_color

	# Set default values for Image
	if Global.config_cache.has_section_key("preferences", "default_width"):
		var default_width = Global.config_cache.get_value("preferences", "default_width")
		Global.default_image_width = int(default_width)
		default_width_value.value = Global.default_image_width

	if Global.config_cache.has_section_key("preferences", "default_height"):
		var default_height = Global.config_cache.get_value("preferences", "default_height")
		Global.default_image_height = int(default_height)
		default_height_value.value = Global.default_image_height

	if Global.config_cache.has_section_key("preferences", "default_fill_color"):
		var fill_color = Global.config_cache.get_value("preferences", "default_fill_color")
		Global.default_fill_color = fill_color
		default_fill_color.color = Global.default_fill_color

	guide_color.get_picker().presets_visible = false
	grid_color.get_picker().presets_visible = false
	checker_color_1.get_picker().presets_visible = false
	checker_color_2.get_picker().presets_visible = false
	default_fill_color.get_picker().presets_visible = false

	# Get default preset for shortcuts from project input map
	# Buttons in shortcuts selector should be called the same as actions
	for shortcut_grid_item in shortcuts.get_node("Shortcuts").get_children():
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
	shortcuts.get_node("HBoxContainer/PresetOptionButton").select(shortcuts_preset)
	_on_PresetOptionButton_item_selected(shortcuts_preset)


func _input(event : InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			if event.scancode == KEY_ESCAPE:
				$Popups/ShortcutSelector.hide()
			else:
				# Check if shortcut was already used
				for action in InputMap.get_actions():
					for input_event in InputMap.get_action_list(action):
						if input_event is InputEventKey:
							if OS.get_scancode_string(input_event.get_scancode_with_modifiers()) == OS.get_scancode_string(event.get_scancode_with_modifiers()):
								$Popups/ShortcutSelector/EnteredShortcut.text = tr("Already assigned")
								$Popups/ShortcutSelector/EnteredShortcut.add_color_override("font_color", Color.crimson)
								get_tree().set_input_as_handled()
								shortcut_already_assigned = true
								return

				# Store new shortcut
				shortcut_already_assigned = false
				old_input_event = InputMap.get_action_list(action_being_edited)[0]
				new_input_event = event
				$Popups/ShortcutSelector/EnteredShortcut.text = OS.get_scancode_string(event.get_scancode_with_modifiers())
				$Popups/ShortcutSelector/EnteredShortcut.add_color_override("font_color", theme_font_color)
			get_tree().set_input_as_handled()


func _on_PreferencesDialog_about_to_show(changed_language := false) -> void:
	var root := tree.create_item()
	var general_button := tree.create_item(root)
	var language_button := tree.create_item(root)
	var theme_button := tree.create_item(root)
	var canvas_button := tree.create_item(root)
	var image_button := tree.create_item(root)
	var shortcuts_button := tree.create_item(root)

	general_button.set_text(0, "  " + tr("General"))
	# We use metadata to avoid being affected by translations
	general_button.set_metadata(0, "General")
	language_button.set_text(0, "  " + tr("Language"))
	language_button.set_metadata(0, "Language")
	theme_button.set_text(0, "  " + tr("Themes"))
	theme_button.set_metadata(0, "Themes")
	canvas_button.set_text(0, "  " + tr("Canvas"))
	canvas_button.set_metadata(0, "Canvas")
	image_button.set_text(0, "  " + tr("Image"))
	image_button.set_metadata(0, "Image")
	shortcuts_button.set_text(0, "  " + tr("Shortcuts"))
	shortcuts_button.set_metadata(0, "Shortcuts")

	if changed_language:
		language_button.select(0)
	else:
		general_button.select(0)

	general.get_node("AutosaveInterval/AutosaveInterval").suffix = tr("minute(s)")


func _on_PreferencesDialog_popup_hide() -> void:
	tree.clear()


func _on_Tree_item_selected() -> void:
	for child in right_side.get_children():
		child.visible = false
	var selected : String = tree.get_selected().get_metadata(0)
	if "General" in selected:
		general.visible = true
	elif "Language" in selected:
		languages.visible = true
	elif "Themes" in selected:
		themes.visible = true
	elif "Canvas" in selected:
		canvas.visible = true
	elif "Image" in selected:
		image.visible = true
	elif "Shortcuts" in selected:
		shortcuts.visible = true


func _on_PressureSensitivityOptionButton_item_selected(id : int) -> void:
	Global.pressure_sensitivity_mode = id
	Global.config_cache.set_value("preferences", "pressure_sensitivity", id)
	Global.config_cache.save("user://cache.ini")


func _on_SmoothZoom_pressed() -> void:
	Global.smooth_zoom = !Global.smooth_zoom
	Global.config_cache.set_value("preferences", "smooth_zoom", Global.smooth_zoom)
	Global.config_cache.save("user://cache.ini")


func _on_Language_pressed(button : Button) -> void:
	var index := 0
	var i := -1
	for child in languages.get_children():
		if child is Button:
			if child == button:
				button.pressed = true
				index = i
			else:
				child.pressed = false
			i += 1
	if index == -1:
		TranslationServer.set_locale(OS.get_locale())
	else:
		TranslationServer.set_locale(Global.loaded_locales[index])

	if "zh" in TranslationServer.get_locale():
		Global.control.theme.default_font = preload("res://assets/fonts/CJK/NotoSansCJKtc-Regular.tres")
	else:
		Global.control.theme.default_font = preload("res://assets/fonts/Roboto-Regular.tres")

	Global.config_cache.set_value("preferences", "locale", TranslationServer.get_locale())
	Global.config_cache.save("user://cache.ini")

	# Update Translations
	Global.update_hint_tooltips()
	_on_PreferencesDialog_popup_hide()
	_on_PreferencesDialog_about_to_show(true)


func _on_Theme_pressed(button : Button) -> void:
	var index := 0
	var i := 0
	for child in themes.get_children():
		if child is Button:
			if child == button:
				button.pressed = true
				index = i
			else:
				child.pressed = false
			i += 1

	change_theme(index)

	Global.config_cache.set_value("preferences", "theme", index)
	Global.config_cache.save("user://cache.ini")


func change_theme(ID : int) -> void:
	var font = Global.control.theme.default_font
	var main_theme : Theme
	var top_menu_style
	var ruler_style
	if ID == 0: # Dark Theme
		Global.theme_type = "Dark"
		VisualServer.set_default_clear_color(Color("2b2b2b"))
		main_theme = preload("res://assets/themes/dark/theme.tres")
		top_menu_style = preload("res://assets/themes/dark/top_menu_style.tres")
		ruler_style = preload("res://assets/themes/dark/ruler_style.tres")
	elif ID == 1: # Gray Theme
		Global.theme_type = "Dark"
		VisualServer.set_default_clear_color(Color("3f3f3f"))
		main_theme = preload("res://assets/themes/gray/theme.tres")
		top_menu_style = preload("res://assets/themes/gray/top_menu_style.tres")
		ruler_style = preload("res://assets/themes/dark/ruler_style.tres")
	elif ID == 2: # Godot's Theme
		Global.theme_type = "Blue"
		VisualServer.set_default_clear_color(Color("3b445c"))
		main_theme = preload("res://assets/themes/godot/theme.tres")
		top_menu_style = preload("res://assets/themes/godot/top_menu_style.tres")
		ruler_style = preload("res://assets/themes/godot/ruler_style.tres")
	elif ID == 3: # Gold Theme
		Global.theme_type = "Gold"
		VisualServer.set_default_clear_color(Color(0.694118, 0.619608, 0.458824))
		main_theme = preload("res://assets/themes/gold/theme.tres")
		top_menu_style = preload("res://assets/themes/gold/top_menu_style.tres")
		ruler_style = preload("res://assets/themes/gold/ruler_style.tres")
	elif ID == 4: # Light Theme
		Global.theme_type = "Light"
		VisualServer.set_default_clear_color(Color("e7e7e7"))
		main_theme = preload("res://assets/themes/light/theme.tres")
		top_menu_style = preload("res://assets/themes/light/top_menu_style.tres")
		ruler_style = preload("res://assets/themes/light/ruler_style.tres")

	Global.control.theme = main_theme
	Global.control.theme.default_font = font
	(Global.animation_timeline.get_stylebox("panel", "Panel") as StyleBoxFlat).bg_color = main_theme.get_stylebox("panel", "Panel").bg_color
	var layer_button_panel_container : PanelContainer = Global.find_node_by_name(Global.animation_timeline, "LayerButtonPanelContainer")
	(layer_button_panel_container.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color = main_theme.get_stylebox("panel", "PanelContainer").bg_color

	Global.top_menu_container.add_stylebox_override("panel", top_menu_style)
	Global.horizontal_ruler.add_stylebox_override("normal", ruler_style)
	Global.horizontal_ruler.add_stylebox_override("pressed", ruler_style)
	Global.horizontal_ruler.add_stylebox_override("hover", ruler_style)
	Global.horizontal_ruler.add_stylebox_override("focus", ruler_style)
	Global.vertical_ruler.add_stylebox_override("normal", ruler_style)
	Global.vertical_ruler.add_stylebox_override("pressed", ruler_style)
	Global.vertical_ruler.add_stylebox_override("hover", ruler_style)
	Global.vertical_ruler.add_stylebox_override("focus", ruler_style)

	var fake_vsplit_grabber : TextureRect = Global.find_node_by_name(Global.animation_timeline, "FakeVSplitContainerGrabber")

	if Global.theme_type == "Dark" or Global.theme_type == "Blue":
		fake_vsplit_grabber.texture = preload("res://assets/themes/dark/icons/vsplit.png")
	else:
		fake_vsplit_grabber.texture = preload("res://assets/themes/light/icons/vsplit.png")

	for button in get_tree().get_nodes_in_group("UIButtons"):
		if button is TextureButton:
			var last_backslash = button.texture_normal.resource_path.get_base_dir().find_last("/")
			var button_category = button.texture_normal.resource_path.get_base_dir().right(last_backslash + 1)
			var normal_file_name = button.texture_normal.resource_path.get_file()
			var theme_type := Global.theme_type
			if theme_type == "Blue":
				theme_type = "Dark"
			button.texture_normal = load("res://assets/graphics/%s_themes/%s/%s" % [theme_type.to_lower(), button_category, normal_file_name])
			if button.texture_pressed:
				var pressed_file_name = button.texture_pressed.resource_path.get_file()
				button.texture_pressed = load("res://assets/graphics/%s_themes/%s/%s" % [theme_type.to_lower(), button_category, pressed_file_name])
			if button.texture_hover:
				var hover_file_name = button.texture_hover.resource_path.get_file()
				button.texture_hover = load("res://assets/graphics/%s_themes/%s/%s" % [theme_type.to_lower(), button_category, hover_file_name])
			if button.texture_disabled:
				var disabled_file_name = button.texture_disabled.resource_path.get_file()
				button.texture_disabled = load("res://assets/graphics/%s_themes/%s/%s" % [theme_type.to_lower(), button_category, disabled_file_name])
		elif button is Button:
			var texture : TextureRect
			for child in button.get_children():
				if child is TextureRect:
					texture = child
					break

			if texture:
				var last_backslash = texture.texture.resource_path.get_base_dir().find_last("/")
				var button_category = texture.texture.resource_path.get_base_dir().right(last_backslash + 1)
				var normal_file_name = texture.texture.resource_path.get_file()
				var theme_type := Global.theme_type
				if theme_type == "Gold" or (theme_type == "Blue" and button_category != "tools"):
					theme_type = "Dark"

				texture.texture = load("res://assets/graphics/%s_themes/%s/%s" % [theme_type.to_lower(), button_category, normal_file_name])

	# Make sure the frame text gets updated
	Global.current_frame = Global.current_frame

	$Popups/ShortcutSelector.theme = main_theme


func apply_shortcuts_preset(preset) -> void:
	for action in preset:
		var old_input_event : InputEventKey = InputMap.get_action_list(action)[0]
		set_action_shortcut(action, old_input_event, preset[action])
		shortcuts.get_node("Shortcuts/" + action).text = OS.get_scancode_string(preset[action].get_scancode_with_modifiers())


func toggle_shortcut_buttons(enabled : bool) -> void:
	for shortcut_grid_item in shortcuts.get_node("Shortcuts").get_children():
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


func _on_GridWidthValue_value_changed(value : float) -> void:
	Global.grid_width = value
	Global.canvas.update()
	Global.config_cache.set_value("preferences", "grid_size", Vector2(value, grid_height_value.value))
	Global.config_cache.save("user://cache.ini")


func _on_GridHeightValue_value_changed(value : float) -> void:
	Global.grid_height = value
	Global.canvas.update()
	Global.config_cache.set_value("preferences", "grid_size", Vector2(grid_width_value.value, value))
	Global.config_cache.save("user://cache.ini")


func _on_GridColor_color_changed(color : Color) -> void:
	Global.grid_color = color
	Global.canvas.update()
	Global.config_cache.set_value("preferences", "grid_color", color)
	Global.config_cache.save("user://cache.ini")


func _on_CheckerSize_value_changed(value : float) -> void:
	Global.checker_size = value
	Global.transparent_checker._ready()
	Global.config_cache.set_value("preferences", "checker_size", value)
	Global.config_cache.save("user://cache.ini")


func _on_CheckerColor1_color_changed(color : Color) -> void:
	Global.checker_color_1 = color
	Global.transparent_checker._ready()
	Global.config_cache.set_value("preferences", "checker_color_1", color)
	Global.config_cache.save("user://cache.ini")


func _on_CheckerColor2_color_changed(color : Color) -> void:
	Global.checker_color_2 = color
	Global.transparent_checker._ready()
	Global.config_cache.set_value("preferences", "checker_color_2", color)
	Global.config_cache.save("user://cache.ini")


func _on_GuideColor_color_changed(color : Color) -> void:
	Global.guide_color = color
	for canvas in Global.canvases:
		for guide in canvas.get_children():
			if guide is Guide:
				guide.default_color = color
	Global.config_cache.set_value("preferences", "guide_color", color)
	Global.config_cache.save("user://cache.ini")


func _on_ImageDefaultWidth_value_changed(value: float) -> void:
	Global.default_image_width = value
	Global.config_cache.set_value("preferences", "default_width", value)
	Global.config_cache.save("user://cache.ini")


func _on_ImageDefaultHeight_value_changed(value: float) -> void:
	Global.default_image_height = value
	Global.config_cache.set_value("preferences", "default_height", value)
	Global.config_cache.save("user://cache.ini")


func _on_DefaultBackground_color_changed(color: Color) -> void:
	Global.default_fill_color = color
	Global.config_cache.set_value("preferences", "default_fill_color", color)
	Global.config_cache.save("user://cache.ini")


func _on_LeftIndicatorCheckbox_toggled(button_pressed : bool) -> void:
	Global.left_square_indicator_visible = button_pressed


func _on_RightIndicatorCheckbox_toggled(button_pressed : bool) -> void:
	Global.right_square_indicator_visible = button_pressed


func _on_LeftToolIconCheckbox_toggled(button_pressed : bool) -> void:
	Global.show_left_tool_icon = button_pressed
	Global.config_cache.set_value("preferences", "show_left_tool_icon", Global.show_left_tool_icon)
	Global.config_cache.save("user://cache.ini")


func _on_RightToolIconCheckbox_toggled(button_pressed : bool) -> void:
	Global.show_right_tool_icon = button_pressed
	Global.config_cache.set_value("preferences", "show_right_tool_icon", Global.show_right_tool_icon)
	Global.config_cache.save("user://cache.ini")


func _on_Shortcut_button_pressed(button : Button) -> void:
	set_process_input(true)
	action_being_edited = button.name
	new_input_event = InputMap.get_action_list(button.name)[0]
	shortcut_already_assigned = true
	$Popups/ShortcutSelector.popup_centered()


func _on_ShortcutSelector_popup_hide() -> void:
	set_process_input(false)
	$Popups/ShortcutSelector/EnteredShortcut.text = ""


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


func _on_ShortcutSelector_confirmed() -> void:
	if not shortcut_already_assigned:
		set_action_shortcut(action_being_edited, old_input_event, new_input_event)
		custom_shortcuts_preset[action_being_edited] = new_input_event
		Global.config_cache.set_value("shortcuts", action_being_edited, new_input_event)
		Global.config_cache.save("user://cache.ini")
		shortcuts.get_node("Shortcuts/" + action_being_edited).text = OS.get_scancode_string(new_input_event.get_scancode_with_modifiers())
		$Popups/ShortcutSelector.hide()


func _on_OpenLastProject_pressed() -> void:
	Global.open_last_project = !Global.open_last_project
	Global.config_cache.set_value("preferences", "open_last_project", Global.open_last_project)
	Global.config_cache.save("user://cache.ini")


func _on_EnableAutosave_toggled(button_pressed : bool) -> void:
	OpenSave.toggle_autosave(button_pressed)
	Global.config_cache.set_value("preferences", "enable_autosave", button_pressed)
	Global.config_cache.save("user://cache.ini")


func _on_AutosaveInterval_value_changed(value : float) -> void:
	OpenSave.set_autosave_interval(value)
	Global.config_cache.set_value("preferences", "autosave_interval", value)
	Global.config_cache.save("user://cache.ini")
