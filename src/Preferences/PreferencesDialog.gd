extends AcceptDialog

var preferences: Array[Preference] = [
	Preference.new(
		"open_last_project", "Startup/StartupContainer/OpenLastProject", "button_pressed"
	),
	Preference.new(
		"quit_confirmation", "Startup/StartupContainer/QuitConfirmation", "button_pressed"
	),
	Preference.new("ffmpeg_path", "Startup/StartupContainer/FFMPEGPath", "text"),
	Preference.new("shrink", "%ShrinkSlider", "value"),
	Preference.new("font_size", "Interface/InterfaceOptions/FontSizeSlider", "value"),
	Preference.new("dim_on_popup", "Interface/InterfaceOptions/DimCheckBox", "button_pressed"),
	Preference.new("use_native_file_dialogs", "Interface/InterfaceOptions/NativeFileDialogs", "button_pressed"),
	Preference.new("icon_color_from", "Interface/ButtonOptions/IconColorOptionButton", "selected"),
	Preference.new("custom_icon_color", "Interface/ButtonOptions/IconColorButton", "color"),
	Preference.new("left_tool_color", "Interface/ButtonOptions/LeftToolColorButton", "color"),
	Preference.new("right_tool_color", "Interface/ButtonOptions/RightToolColorButton", "color"),
	Preference.new(
		"tool_button_size", "Interface/ButtonOptions/ToolButtonSizeOptionButton", "selected"
	),
	Preference.new(
		"show_left_tool_icon", "Cursors/CursorsContainer/LeftToolIconCheckbox", "button_pressed"
	),
	Preference.new(
		"show_right_tool_icon", "Cursors/CursorsContainer/RightToolIconCheckbox", "button_pressed"
	),
	Preference.new(
		"left_square_indicator_visible",
		"Cursors/CursorsContainer/LeftIndicatorCheckbox",
		"button_pressed"
	),
	Preference.new(
		"right_square_indicator_visible",
		"Cursors/CursorsContainer/RightIndicatorCheckbox",
		"button_pressed"
	),
	Preference.new(
		"native_cursors", "Cursors/CursorsContainer/NativeCursorsCheckbox", "button_pressed"
	),
	Preference.new(
		"cross_cursor", "Cursors/CursorsContainer/CrossCursorCheckbox", "button_pressed"
	),
	Preference.new("autosave_interval", "Backup/AutosaveContainer/AutosaveInterval", "value"),
	Preference.new("enable_autosave", "Backup/AutosaveContainer/EnableAutosave", "button_pressed"),
	Preference.new("default_width", "Image/ImageOptions/ImageDefaultWidth", "value"),
	Preference.new("default_height", "Image/ImageOptions/ImageDefaultHeight", "value"),
	Preference.new("default_fill_color", "Image/ImageOptions/DefaultFillColor", "color"),
	Preference.new("smooth_zoom", "Canvas/ZoomOptions/SmoothZoom", "button_pressed"),
	Preference.new("integer_zoom", "Canvas/ZoomOptions/IntegerZoom", "button_pressed"),
	Preference.new("snapping_distance", "Canvas/SnappingOptions/DistanceValue", "value"),
	Preference.new("grid_type", "Canvas/GridOptions/GridType", "selected"),
	Preference.new("grid_size", "Canvas/GridOptions/GridSizeValue", "value"),
	Preference.new("isometric_grid_size", "Canvas/GridOptions/IsometricGridSizeValue", "value"),
	Preference.new("grid_offset", "Canvas/GridOptions/GridOffsetValue", "value"),
	Preference.new(
		"grid_draw_over_tile_mode", "Canvas/GridOptions/GridDrawOverTileMode", "button_pressed"
	),
	Preference.new("grid_color", "Canvas/GridOptions/GridColor", "color"),
	Preference.new("pixel_grid_show_at_zoom", "Canvas/PixelGridOptions/ShowAtZoom", "value"),
	Preference.new("pixel_grid_color", "Canvas/PixelGridOptions/GridColor", "color"),
	Preference.new("guide_color", "Canvas/GuideOptions/GuideColor", "color"),
	Preference.new("checker_size", "Canvas/CheckerOptions/CheckerSizeValue", "value"),
	Preference.new("checker_color_1", "Canvas/CheckerOptions/CheckerColor1", "color"),
	Preference.new("checker_color_2", "Canvas/CheckerOptions/CheckerColor2", "color"),
	Preference.new(
		"checker_follow_movement", "Canvas/CheckerOptions/CheckerFollowMovement", "button_pressed"
	),
	Preference.new(
		"checker_follow_scale", "Canvas/CheckerOptions/CheckerFollowScale", "button_pressed"
	),
	Preference.new("tilemode_opacity", "Canvas/CheckerOptions/TileModeOpacity", "value"),
	Preference.new("clear_color_from", "Canvas/BackgroundOptions/ColorOptionButton", "selected"),
	Preference.new("modulate_clear_color", "Canvas/BackgroundOptions/BackgroundColor", "color"),
	Preference.new(
		"select_layer_on_button_click",
		"Timeline/TimelineOptions/SelectLayerOnButton",
		"button_pressed"
	),
	Preference.new(
		"onion_skinning_past_color", "Timeline/TimelineOptions/OnionSkinningPastColor", "color"
	),
	Preference.new(
		"onion_skinning_future_color", "Timeline/TimelineOptions/OnionSkinningFutureColor", "color"
	),
	Preference.new(
		"selection_animated_borders", "Selection/SelectionOptions/Animate", "button_pressed"
	),
	Preference.new("selection_border_color_1", "Selection/SelectionOptions/BorderColor1", "color"),
	Preference.new("selection_border_color_2", "Selection/SelectionOptions/BorderColor2", "color"),
	Preference.new("fps_limit", "Performance/PerformanceContainer/SetFPSLimit", "value"),
	Preference.new(
		"pause_when_unfocused", "Performance/PerformanceContainer/PauseAppFocus", "button_pressed"
	),
	#	Preference.new(
	#		"renderer", "Drivers/DriversContainer/Renderer", "selected", true, OS.VIDEO_DRIVER_GLES2
	#	),
	Preference.new("tablet_driver", "Drivers/DriversContainer/TabletDriver", "selected", true, 0)
]

var content_list := []
var selected_item := 0

@onready var list: ItemList = $HSplitContainer/List
@onready var right_side: VBoxContainer = $"%RightSide"
@onready var autosave_container: Container = right_side.get_node("Backup/AutosaveContainer")
@onready var autosave_interval: SpinBox = autosave_container.get_node("AutosaveInterval")
@onready var shrink_slider: ValueSlider = $"%ShrinkSlider"
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
	var require_restart := false
	var default_value

	func _init(
		_prop_name: String,
		_node_path: String,
		_value_type: String,
		_require_restart := false,
		_default_value = null
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
	# Replace OK since preference changes are being applied immediately, not after OK confirmation
	get_ok_button().text = "Close"
	get_ok_button().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shrink_slider.value = Global.shrink  # In case shrink is not equal to 1

	shortcuts.profile_option_button.item_selected.connect(func(_i): Tools.update_hint_tooltips())
	if shortcuts.profile_option_button.selected != 0:
		# Manually update tooltips if the shortcut profile is not the default
		Tools.update_hint_tooltips()
	for child in shortcuts.get_children():
		if not child is AcceptDialog:
			continue
		child.confirmed.connect(Tools.update_hint_tooltips)

	for child in right_side.get_children():
		content_list.append(child.name)

	if OS.get_name() == "Web":
		content_list.erase("Startup")
		right_side.get_node("Startup").queue_free()
		right_side.get_node("Language").visible = true
		Global.open_last_project = false
	elif OS.get_name() == "Windows":
		tablet_driver_label.visible = true
		tablet_driver.visible = true
		for driver in DisplayServer.tablet_get_driver_count():
			var driver_name := DisplayServer.tablet_get_driver_name(driver)
			tablet_driver.add_item(driver_name, driver)

	for pref in preferences:
		var node := right_side.get_node(pref.node_path)
		var restore_default_button := RestoreDefaultButton.new()
		restore_default_button.setting_name = pref.prop_name
		restore_default_button.value_type = pref.value_type
		restore_default_button.default_value = pref.default_value
		restore_default_button.require_restart = pref.require_restart
		restore_default_button.node = node
		if pref.node_path == "%ShrinkSlider":
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

		var global_value = Global.get(pref.prop_name)
		if Global.config_cache.has_section_key("preferences", pref.prop_name):
			var value = Global.config_cache.get_value("preferences", pref.prop_name)
			Global.set(pref.prop_name, value)
			node.set(pref.value_type, value)
			global_value = Global.get(pref.prop_name)

			# This is needed because color_changed doesn't fire if the color changes in code
			if typeof(value) == TYPE_VECTOR2 or typeof(value) == TYPE_COLOR:
				preference_update(pref.require_restart)
				if typeof(global_value) == TYPE_VECTOR2I:
					disable_restore_default_button(
						restore_default_button, global_value == pref.default_value
					)
				else:
					disable_restore_default_button(
						restore_default_button, global_value.is_equal_approx(pref.default_value)
					)
			elif pref.value_type == "selected":
				preference_update(pref.require_restart)
				disable_restore_default_button(
					restore_default_button, global_value == pref.default_value
				)
		else:
			node.set(pref.value_type, global_value)
			disable_restore_default_button(
				restore_default_button, global_value == pref.default_value
			)


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
		Global.config_cache.save("user://cache.ini")


func _on_List_item_selected(index: int) -> void:
	selected_item = index
	for child in right_side.get_children():
		child.visible = child.name == content_list[index]


func _on_ShrinkApplyButton_pressed() -> void:
	var root := get_tree().root
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.min_size = Vector2(1024, 576)
	root.content_scale_factor = Global.shrink
	Global.control.set_custom_cursor()
	hide()
	popup_centered(Vector2(600, 400))
	Global.dialog_open(true)
	await get_tree().process_frame
	Global.camera.fit_to_frame(Global.current_project.size)
