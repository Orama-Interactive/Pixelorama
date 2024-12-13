extends AcceptDialog

var preferences: Array[Preference] = [
	Preference.new(
		"open_last_project", "Startup/StartupContainer/OpenLastProject", "button_pressed", false
	),
	Preference.new(
		"quit_confirmation", "Startup/StartupContainer/QuitConfirmation", "button_pressed", false
	),
	Preference.new("ffmpeg_path", "Startup/StartupContainer/FFMPEGPath", "text", ""),
	Preference.new("shrink", "%ShrinkSlider", "value", 1.0),
	Preference.new("theme_font_index", "%FontOptionButton", "selected", 1),
	Preference.new("font_size", "%FontSizeSlider", "value", 16),
	Preference.new(
		"dim_on_popup", "Interface/InterfaceOptions/DimCheckBox", "button_pressed", true
	),
	Preference.new(
		"use_native_file_dialogs",
		"Interface/InterfaceOptions/NativeFileDialogs",
		"button_pressed",
		false
	),
	Preference.new(
		"single_window_mode",
		"Interface/InterfaceOptions/SingleWindowMode",
		"button_pressed",
		true,
		true
	),
	Preference.new(
		"icon_color_from",
		"Interface/ButtonOptions/IconColorOptionButton",
		"selected",
		Global.ColorFrom.THEME
	),
	Preference.new(
		"custom_icon_color", "Interface/ButtonOptions/IconColorButton", "color", Color.GRAY
	),
	Preference.new(
		"share_options_between_tools",
		"Tools/ToolOptions/ShareOptionsCheckBox",
		"button_pressed",
		false
	),
	Preference.new(
		"left_tool_color", "Tools/ToolOptions/LeftToolColorButton", "color", Color("0086cf")
	),
	Preference.new(
		"right_tool_color", "Tools/ToolOptions/RightToolColorButton", "color", Color("fd6d14")
	),
	Preference.new(
		"tool_button_size",
		"Interface/ButtonOptions/ToolButtonSizeOptionButton",
		"selected",
		Global.ButtonSize.SMALL
	),
	Preference.new(
		"show_left_tool_icon",
		"Cursors/CursorsContainer/LeftToolIconCheckbox",
		"button_pressed",
		true
	),
	Preference.new(
		"show_right_tool_icon",
		"Cursors/CursorsContainer/RightToolIconCheckbox",
		"button_pressed",
		true
	),
	Preference.new(
		"left_square_indicator_visible",
		"Cursors/CursorsContainer/LeftIndicatorCheckbox",
		"button_pressed",
		true
	),
	Preference.new(
		"right_square_indicator_visible",
		"Cursors/CursorsContainer/RightIndicatorCheckbox",
		"button_pressed",
		true
	),
	Preference.new(
		"native_cursors", "Cursors/CursorsContainer/NativeCursorsCheckbox", "button_pressed", false
	),
	Preference.new(
		"cross_cursor", "Cursors/CursorsContainer/CrossCursorCheckbox", "button_pressed", true
	),
	Preference.new("autosave_interval", "Backup/AutosaveContainer/AutosaveInterval", "value", 1.0),
	Preference.new(
		"enable_autosave", "Backup/AutosaveContainer/EnableAutosave", "button_pressed", true
	),
	Preference.new("default_width", "Image/ImageOptions/ImageDefaultWidth", "value", 64),
	Preference.new("default_height", "Image/ImageOptions/ImageDefaultHeight", "value", 64),
	Preference.new("default_fill_color", "Image/ImageOptions/DefaultFillColor", "color", Color(0)),
	Preference.new("smooth_zoom", "Canvas/ZoomOptions/SmoothZoom", "button_pressed", true),
	Preference.new("integer_zoom", "Canvas/ZoomOptions/IntegerZoom", "button_pressed", false),
	Preference.new("snapping_distance", "Canvas/SnappingOptions/DistanceValue", "value", 32.0),
	Preference.new(
		"pixel_grid_show_at_zoom", "Canvas/PixelGridOptions/ShowAtZoom", "value", 1500.0
	),
	Preference.new(
		"pixel_grid_color", "Canvas/PixelGridOptions/GridColor", "color", Color("21212191")
	),
	Preference.new("guide_color", "Canvas/GuideOptions/GuideColor", "color", Color.PURPLE),
	Preference.new("checker_size", "Canvas/CheckerOptions/CheckerSizeValue", "value", 10),
	Preference.new(
		"checker_color_1",
		"Canvas/CheckerOptions/CheckerColor1",
		"color",
		Color(0.47, 0.47, 0.47, 1)
	),
	Preference.new(
		"checker_color_2",
		"Canvas/CheckerOptions/CheckerColor2",
		"color",
		Color(0.34, 0.35, 0.34, 1)
	),
	Preference.new(
		"checker_follow_movement",
		"Canvas/CheckerOptions/CheckerFollowMovement",
		"button_pressed",
		false
	),
	Preference.new(
		"checker_follow_scale", "Canvas/CheckerOptions/CheckerFollowScale", "button_pressed", false
	),
	Preference.new("tilemode_opacity", "Canvas/CheckerOptions/TileModeOpacity", "value", 1.0),
	Preference.new(
		"clear_color_from",
		"Canvas/BackgroundOptions/ColorOptionButton",
		"selected",
		Global.ColorFrom.THEME
	),
	Preference.new(
		"modulate_clear_color", "Canvas/BackgroundOptions/BackgroundColor", "color", Color.GRAY
	),
	Preference.new(
		"select_layer_on_button_click",
		"Timeline/TimelineOptions/SelectLayerOnButton",
		"button_pressed",
		false
	),
	Preference.new(
		"onion_skinning_past_color",
		"Timeline/TimelineOptions/OnionSkinningPastColor",
		"color",
		Color.RED
	),
	Preference.new(
		"onion_skinning_future_color",
		"Timeline/TimelineOptions/OnionSkinningFutureColor",
		"color",
		Color.BLUE
	),
	Preference.new(
		"selection_animated_borders", "Selection/SelectionOptions/Animate", "button_pressed", true
	),
	Preference.new(
		"selection_border_color_1", "Selection/SelectionOptions/BorderColor1", "color", Color.WHITE
	),
	Preference.new(
		"selection_border_color_2", "Selection/SelectionOptions/BorderColor2", "color", Color.BLACK
	),
	Preference.new("fps_limit", "Performance/PerformanceContainer/SetFPSLimit", "value", 0),
	Preference.new("max_undo_steps", "Performance/PerformanceContainer/MaxUndoSteps", "value", 0),
	Preference.new(
		"pause_when_unfocused",
		"Performance/PerformanceContainer/PauseAppFocus",
		"button_pressed",
		true
	),
	Preference.new(
		"update_continuously",
		"Performance/PerformanceContainer/UpdateContinuously",
		"button_pressed",
		false
	),
	Preference.new(
		"window_transparency",
		"Performance/PerformanceContainer/WindowTransparency",
		"button_pressed",
		false,
		true
	),
	Preference.new(
		"dummy_audio_driver",
		"Performance/PerformanceContainer/DummyAudioDriver",
		"button_pressed",
		false,
		true
	),
	Preference.new("tablet_driver", "Drivers/DriversContainer/TabletDriver", "selected", 0)
]

var content_list := PackedStringArray([])
var selected_item := 0

@onready var list: ItemList = $HSplitContainer/List
@onready var right_side: VBoxContainer = $"%RightSide"
@onready var language: VBoxContainer = %Language
@onready var system_language := language.get_node(^"System Language") as CheckBox
@onready var autosave_container: Container = right_side.get_node("Backup/AutosaveContainer")
@onready var autosave_interval: SpinBox = autosave_container.get_node("AutosaveInterval")
@onready var themes: BoxContainer = right_side.get_node("Interface/Themes")
@onready var shortcuts: Control = right_side.get_node("Shortcuts/ShortcutEdit")
@onready var tablet_driver_label: Label = $"%TabletDriverLabel"
@onready var tablet_driver: OptionButton = $"%TabletDriver"
@onready var extensions: BoxContainer = right_side.get_node("Extensions")
@onready var must_restart: BoxContainer = $"%MustRestart"


class Preference:
	var prop_name: String
	var node_path: String
	var value_type: String
	var default_value
	var require_restart := false

	func _init(
		_prop_name: String,
		_node_path: String,
		_value_type: String,
		_default_value = null,
		_require_restart := false
	) -> void:
		prop_name = _prop_name
		node_path = _node_path
		value_type = _value_type
		require_restart = _require_restart
		if _default_value != null:
			default_value = _default_value
		else:
			default_value = Global.get(prop_name)


func _ready() -> void:
	Global.font_loaded.connect(_add_fonts)
	# Replace OK since preference changes are being applied immediately, not after OK confirmation
	get_ok_button().text = "Close"
	get_ok_button().size_flags_horizontal = Control.SIZE_EXPAND_FILL

	shortcuts.profile_option_button.item_selected.connect(func(_i): Tools.update_hint_tooltips())
	if shortcuts.profile_option_button.selected != 0:
		# Manually update tooltips if the shortcut profile is not the default
		Tools.update_hint_tooltips()
	for child in shortcuts.get_children():
		if not child is AcceptDialog:
			continue
		child.confirmed.connect(Tools.update_hint_tooltips)

	if OS.get_name() == "Web":
		var startup := right_side.get_node(^"Startup")
		right_side.remove_child(startup)
		startup.queue_free()
		right_side.get_node(^"Language").visible = true
		Global.open_last_project = false
		%ClearRecentFiles.hide()
	if OS.get_name() == "Windows":
		tablet_driver_label.visible = true
		tablet_driver.visible = true
		for driver in DisplayServer.tablet_get_driver_count():
			var driver_name := DisplayServer.tablet_get_driver_name(driver)
			tablet_driver.add_item(driver_name, driver)
	else:
		var drivers := right_side.get_node(^"Drivers")
		right_side.remove_child(drivers)
		drivers.queue_free()
	if OS.is_sandboxed():
		get_tree().call_group(&"NoSandbox", &"free")
	if not OS.has_feature("pc"):
		get_tree().call_group(&"DesktopOnly", &"free")

	for child in right_side.get_children():
		content_list.append(child.name)

	# Create buttons for each language
	var button_group: ButtonGroup = system_language.button_group
	for locale in Global.loaded_locales:  # Create radiobuttons for each language
		var button := CheckBox.new()
		button.text = Global.LANGUAGES_DICT[locale][0] + " [%s]" % [locale]
		button.name = Global.LANGUAGES_DICT[locale][1]
		button.tooltip_text = Global.LANGUAGES_DICT[locale][1]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.button_group = button_group
		if locale == TranslationServer.get_locale():
			button.button_pressed = true
		language.add_child(button)
		button.pressed.connect(_on_language_pressed.bind(button.get_index()))

	_add_fonts()

	for pref in preferences:
		if not right_side.has_node(pref.node_path):
			continue
		var node := right_side.get_node(pref.node_path)
		var restore_default_button := RestoreDefaultButton.new()
		restore_default_button.setting_name = pref.prop_name
		restore_default_button.value_type = pref.value_type
		restore_default_button.default_value = pref.default_value
		restore_default_button.require_restart = pref.require_restart
		restore_default_button.node = node
		if pref.node_path in ["%ShrinkSlider", "%FontSizeSlider"]:
			# Add the default button to the shrink slider's grandparent
			var node_position := node.get_parent().get_index()
			node.get_parent().get_parent().add_child(restore_default_button)
			node.get_parent().get_parent().move_child(restore_default_button, node_position)
		else:
			var node_position := node.get_index()
			node.get_parent().add_child(restore_default_button)
			node.get_parent().move_child(restore_default_button, node_position)

		match pref.value_type:
			"button_pressed":
				node.toggled.connect(
					_on_Preference_value_changed.bind(pref, restore_default_button)
				)
			"value":
				node.value_changed.connect(
					_on_Preference_value_changed.bind(pref, restore_default_button)
				)
			"color":
				node.get_picker().presets_visible = false
				node.color_changed.connect(
					_on_Preference_value_changed.bind(pref, restore_default_button)
				)
			"selected":
				node.item_selected.connect(
					_on_Preference_value_changed.bind(pref, restore_default_button)
				)
			"text":
				node.text_changed.connect(
					_on_Preference_value_changed.bind(pref, restore_default_button)
				)

		var value = Global.get(pref.prop_name)
		node.set(pref.value_type, value)
		var is_default: bool = value == pref.default_value
		# This is needed because color_changed doesn't fire if the color changes in code
		if typeof(value) == TYPE_VECTOR2 or typeof(value) == TYPE_COLOR:
			is_default = value.is_equal_approx(pref.default_value)
		disable_restore_default_button(restore_default_button, is_default)
	SteamManager.set_achievement("ACH_PREFERENCES")


func _on_Preference_value_changed(value, pref: Preference, button: RestoreDefaultButton) -> void:
	var prop := pref.prop_name
	var default_value = pref.default_value
	Global.set(prop, value)
	if not pref.require_restart:
		Global.config_cache.set_value("preferences", prop, value)
	preference_update(pref.require_restart)
	var disable: bool = Global.get(prop) == default_value
	if typeof(value) == TYPE_COLOR:
		disable = Global.get(prop).is_equal_approx(default_value)
	disable_restore_default_button(button, disable)


## Add fonts to the font option button.
func _add_fonts() -> void:
	%FontOptionButton.clear()
	for font_name in Global.get_available_font_names():
		%FontOptionButton.add_item(font_name)
	%FontOptionButton.select(Global.theme_font_index)


func preference_update(require_restart := false) -> void:
	if require_restart:
		must_restart.visible = true
		return


func disable_restore_default_button(button: RestoreDefaultButton, disable: bool) -> void:
	button.disabled = disable
	if disable:
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW
		button.tooltip_text = ""
	else:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = "Restore default value"


func _on_PreferencesDialog_about_to_show() -> void:
	add_tabs(false)


func add_tabs(changed_language := false) -> void:
	for item in content_list:
		list.add_item(" " + tr(item))

	var language_index := content_list.find("Language")
	list.select(language_index if changed_language else selected_item)
	autosave_interval.suffix = tr("minute(s)")


func _on_PreferencesDialog_visibility_changed() -> void:
	if not visible:
		list.clear()
		Global.dialog_open(false)
		Global.config_cache.save(Global.CONFIG_PATH)


func _on_List_item_selected(index: int) -> void:
	selected_item = index
	for child in right_side.get_children():
		child.visible = child.name == content_list[index]


func _on_shrink_apply_button_pressed() -> void:
	Global.control.set_display_scale()
	hide()
	popup_centered(Vector2(600, 400))
	Global.dialog_open(true)
	await get_tree().process_frame
	Global.camera.fit_to_frame(Global.current_project.size)


func _on_font_size_apply_button_pressed() -> void:
	Global.control.theme.default_font_size = Global.font_size
	Global.control.theme.set_font_size("font_size", "HeaderSmall", Global.font_size + 2)


func _on_language_pressed(index: int) -> void:
	var locale := OS.get_locale()
	if index > 1:
		locale = Global.loaded_locales[index - 2]
	Global.set_locale(locale)
	Global.config_cache.set_value("preferences", "locale", TranslationServer.get_locale())
	Global.config_cache.save(Global.CONFIG_PATH)

	# Update some UI elements with the new translations
	Tools.update_hint_tooltips()
	list.clear()
	add_tabs(true)


func _on_reset_button_pressed() -> void:
	$ResetOptionsConfirmation.popup_centered()


func _on_reset_options_confirmation_confirmed() -> void:
	# Clear preferences
	if %ResetPreferences.button_pressed:
		system_language.button_pressed = true
		_on_language_pressed(0)
		themes.buttons_container.get_child(0).button_pressed = true
		Themes.change_theme(0)
		for pref in preferences:
			var property_name := pref.prop_name
			var default_value = pref.default_value
			var node := right_side.get_node(pref.node_path)
			if is_instance_valid(node):
				node.set(pref.value_type, default_value)
			Global.set(property_name, default_value)
		_on_shrink_apply_button_pressed()
		_on_font_size_apply_button_pressed()
		Global.config_cache.erase_section("preferences")
	# Clear timeline options
	if %ResetTimelineOptions.button_pressed:
		Global.animation_timeline.reset_settings()
		Global.config_cache.erase_section("timeline")
	# Clear tool options
	if %ResetAllToolOptions.button_pressed:
		Global.config_cache.erase_section("color_picker")
		Global.config_cache.erase_section("tools")
		Global.config_cache.erase_section("left_tool")
		Global.config_cache.erase_section("right_tool")
		Tools.options_reset.emit()
	# Remove all extensions
	if %RemoveAllExtensions.button_pressed:
		var extensions_node := Global.control.get_node("Extensions") as Extensions
		var extensions_list := extensions_node.extensions.duplicate()
		for extension in extensions_list:
			extensions_node.uninstall_extension(extension)
		Global.config_cache.erase_section("extensions")
	# Clear recent files list
	if %ClearRecentFiles.button_pressed:
		Global.config_cache.erase_section_key("data", "last_project_path")
		Global.config_cache.erase_section_key("data", "recent_projects")
		Global.top_menu_container.recent_projects_submenu.clear()

	Global.config_cache.save(Global.CONFIG_PATH)
