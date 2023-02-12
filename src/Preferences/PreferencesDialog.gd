extends AcceptDialog

# Array of Preference(s)
var preferences := [
	Preference.new("open_last_project", "Startup/StartupContainer/OpenLastProject", "pressed"),
	Preference.new("quit_confirmation", "Startup/StartupContainer/QuitConfirmation", "pressed"),
	Preference.new("shrink", "%ShrinkSlider", "value"),
	Preference.new("dim_on_popup", "Interface/InterfaceOptions/DimCheckBox", "pressed"),
	Preference.new("icon_color_from", "Interface/ButtonOptions/IconColorOptionButton", "selected"),
	Preference.new("custom_icon_color", "Interface/ButtonOptions/IconColorButton", "color"),
	Preference.new("left_tool_color", "Interface/ButtonOptions/LeftToolColorButton", "color"),
	Preference.new("right_tool_color", "Interface/ButtonOptions/RightToolColorButton", "color"),
	Preference.new(
		"tool_button_size", "Interface/ButtonOptions/ToolButtonSizeOptionButton", "selected"
	),
	Preference.new(
		"show_left_tool_icon", "Cursors/CursorsContainer/LeftToolIconCheckbox", "pressed"
	),
	Preference.new(
		"show_right_tool_icon", "Cursors/CursorsContainer/RightToolIconCheckbox", "pressed"
	),
	Preference.new(
		"left_square_indicator_visible", "Cursors/CursorsContainer/LeftIndicatorCheckbox", "pressed"
	),
	Preference.new(
		"right_square_indicator_visible",
		"Cursors/CursorsContainer/RightIndicatorCheckbox",
		"pressed"
	),
	Preference.new("native_cursors", "Cursors/CursorsContainer/NativeCursorsCheckbox", "pressed"),
	Preference.new("cross_cursor", "Cursors/CursorsContainer/CrossCursorCheckbox", "pressed"),
	Preference.new("autosave_interval", "Backup/AutosaveContainer/AutosaveInterval", "value"),
	Preference.new("enable_autosave", "Backup/AutosaveContainer/EnableAutosave", "pressed"),
	Preference.new("default_width", "Image/ImageOptions/ImageDefaultWidth", "value"),
	Preference.new("default_height", "Image/ImageOptions/ImageDefaultHeight", "value"),
	Preference.new("default_fill_color", "Image/ImageOptions/DefaultFillColor", "color"),
	Preference.new("smooth_zoom", "Canvas/ZoomOptions/SmoothZoom", "pressed"),
	Preference.new("grid_type", "Canvas/GridOptions/GridType", "selected"),
	Preference.new("grid_width", "Canvas/GridOptions/GridWidthValue", "value"),
	Preference.new("grid_height", "Canvas/GridOptions/GridHeightValue", "value"),
	Preference.new(
		"grid_isometric_cell_bounds_width",
		"Canvas/GridOptions/IsometricCellBoundsWidthValue",
		"value"
	),
	Preference.new(
		"grid_isometric_cell_bounds_height",
		"Canvas/GridOptions/IsometricCellBoundsHeightValue",
		"value"
	),
	Preference.new("grid_offset_x", "Canvas/GridOptions/GridOffsetXValue", "value"),
	Preference.new("grid_offset_y", "Canvas/GridOptions/GridOffsetYValue", "value"),
	Preference.new(
		"grid_draw_over_tile_mode", "Canvas/GridOptions/GridDrawOverTileMode", "pressed"
	),
	Preference.new("grid_color", "Canvas/GridOptions/GridColor", "color"),
	Preference.new("pixel_grid_show_at_zoom", "Canvas/PixelGridOptions/ShowAtZoom", "value"),
	Preference.new("pixel_grid_color", "Canvas/PixelGridOptions/GridColor", "color"),
	Preference.new("guide_color", "Canvas/GuideOptions/GuideColor", "color"),
	Preference.new("checker_size", "Canvas/CheckerOptions/CheckerSizeValue", "value"),
	Preference.new("checker_color_1", "Canvas/CheckerOptions/CheckerColor1", "color"),
	Preference.new("checker_color_2", "Canvas/CheckerOptions/CheckerColor2", "color"),
	Preference.new(
		"checker_follow_movement", "Canvas/CheckerOptions/CheckerFollowMovement", "pressed"
	),
	Preference.new("checker_follow_scale", "Canvas/CheckerOptions/CheckerFollowScale", "pressed"),
	Preference.new("tilemode_opacity", "Canvas/CheckerOptions/TileModeOpacity", "value"),
	Preference.new("clear_color_from", "Canvas/BackgroundOptions/ColorOptionButton", "selected"),
	Preference.new("modulate_clear_color", "Canvas/BackgroundOptions/BackgroundColor", "color"),
	Preference.new("selection_animated_borders", "Selection/SelectionOptions/Animate", "pressed"),
	Preference.new("selection_border_color_1", "Selection/SelectionOptions/BorderColor1", "color"),
	Preference.new("selection_border_color_2", "Selection/SelectionOptions/BorderColor2", "color"),
	Preference.new("fps_limit", "Performance/PerformanceContainer/SetFPSLimit", "value"),
	Preference.new(
		"pause_when_unfocused", "Performance/PerformanceContainer/PauseAppFocus", "pressed"
	),
	Preference.new(
		"renderer", "Drivers/DriversContainer/Renderer", "selected", true, OS.VIDEO_DRIVER_GLES2
	),
	Preference.new("tablet_driver", "Drivers/DriversContainer/TabletDriver", "selected", true, 0)
]

var content_list := []
var selected_item := 0
var restore_default_button_tcsn := preload("res://src/Preferences/RestoreDefaultButton.tscn")

onready var list: ItemList = $HSplitContainer/List
onready var right_side: VBoxContainer = $"%RightSide"
onready var autosave_container: Container = right_side.get_node("Backup/AutosaveContainer")
onready var autosave_interval: SpinBox = autosave_container.get_node("AutosaveInterval")
onready var shrink_slider: ValueSlider = $"%ShrinkSlider"
onready var themes: BoxContainer = right_side.get_node("Interface/Themes")
onready var shortcuts: Control = right_side.get_node("Shortcuts/ShortcutEdit")
onready var tablet_driver_label: Label = $"%TabletDriverLabel"
onready var tablet_driver: OptionButton = $"%TabletDriver"
onready var extensions: BoxContainer = right_side.get_node("Extensions")
onready var must_restart: BoxContainer = $"%MustRestart"


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
	get_ok().text = "Close"
	get_ok().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shrink_slider.value = Global.shrink  # In case shrink is not equal to 1

	for child in shortcuts.get_children():
		if not child is AcceptDialog:
			continue
		child.connect("confirmed", Global, "update_hint_tooltips")

	for child in right_side.get_children():
		content_list.append(child.name)

	if OS.get_name() == "HTML5":
		content_list.erase("Startup")
		right_side.get_node("Startup").queue_free()
		right_side.get_node("Language").visible = true
		Global.open_last_project = false
	elif OS.get_name() == "Windows":
		tablet_driver_label.visible = true
		tablet_driver.visible = true
		for driver in OS.get_tablet_driver_count():
			var driver_name := OS.get_tablet_driver_name(driver)
			tablet_driver.add_item(driver_name, driver)

	for pref in preferences:
		var node: Node = right_side.get_node(pref.node_path)
		var restore_default_button: BaseButton = restore_default_button_tcsn.instance()
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
			"pressed":
				node.connect(
					"toggled", self, "_on_Preference_value_changed", [pref, restore_default_button]
				)
			"value":
				node.connect(
					"value_changed",
					self,
					"_on_Preference_value_changed",
					[pref, restore_default_button]
				)
			"color":
				node.get_picker().presets_visible = false
				node.connect(
					"color_changed",
					self,
					"_on_Preference_value_changed",
					[pref, restore_default_button]
				)
			"selected":
				node.connect(
					"item_selected",
					self,
					"_on_Preference_value_changed",
					[pref, restore_default_button]
				)

		var global_value = Global.get(pref.prop_name)
		if Global.config_cache.has_section_key("preferences", pref.prop_name):
			var value = Global.config_cache.get_value("preferences", pref.prop_name)
			Global.set(pref.prop_name, value)
			node.set(pref.value_type, value)
			global_value = Global.get(pref.prop_name)

			# This is needed because color_changed doesn't fire if the color changes in code
			if pref.value_type == "color":
				preference_update(pref.prop_name, pref.require_restart)
				disable_restore_default_button(
					restore_default_button, global_value.is_equal_approx(pref.default_value)
				)
			elif pref.value_type == "selected":
				preference_update(pref.prop_name, pref.require_restart)
				disable_restore_default_button(
					restore_default_button, global_value == pref.default_value
				)
		else:
			node.set(pref.value_type, global_value)
			disable_restore_default_button(
				restore_default_button, global_value == pref.default_value
			)


func _on_Preference_value_changed(value, pref: Preference, restore_default: BaseButton) -> void:
	var prop := pref.prop_name
	var default_value = pref.default_value
	Global.set(prop, value)
	if not pref.require_restart:
		Global.config_cache.set_value("preferences", prop, value)
	preference_update(prop, pref.require_restart)
	var disable: bool = Global.get(prop) == default_value
	if typeof(value) == TYPE_COLOR:
		disable = Global.get(prop).is_equal_approx(default_value)
	disable_restore_default_button(restore_default, disable)


func preference_update(prop: String, require_restart := false) -> void:
	if require_restart:
		must_restart.visible = true
		return
	if prop in ["autosave_interval", "enable_autosave"]:
		OpenSave.update_autosave()
		autosave_interval.editable = Global.enable_autosave
		if autosave_interval.editable:
			autosave_interval.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			autosave_interval.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN

	elif "grid" in prop:
		Global.canvas.grid.update()

	elif prop in ["pixel_grid_show_at_zoom", "pixel_grid_color"]:
		Global.canvas.pixel_grid.update()

	elif "checker" in prop:
		Global.transparent_checker.update_rect()

	elif prop in ["guide_color"]:
		for guide in Global.canvas.get_children():
			if guide is SymmetryGuide:
				# Add a subtle difference to the normal guide color by mixing in some blue
				guide.default_color = Global.guide_color.linear_interpolate(Color(.2, .2, .65), .6)
			elif guide is Guide:
				guide.default_color = Global.guide_color

	elif prop in ["fps_limit"]:
		Engine.set_target_fps(Global.fps_limit)

	elif "selection" in prop:
		var marching_ants: Sprite = Global.canvas.selection.marching_ants_outline
		marching_ants.material.set_shader_param("animated", Global.selection_animated_borders)
		marching_ants.material.set_shader_param("first_color", Global.selection_border_color_1)
		marching_ants.material.set_shader_param("second_color", Global.selection_border_color_2)
		Global.canvas.selection.update()

	elif prop in ["icon_color_from", "custom_icon_color"]:
		if Global.icon_color_from == Global.ColorFrom.THEME:
			var current_theme: Theme = themes.themes[themes.theme_index]
			Global.modulate_icon_color = current_theme.get_color("modulate_color", "Icons")
		else:
			Global.modulate_icon_color = Global.custom_icon_color
		themes.change_icon_colors()

	elif prop in ["modulate_clear_color", "clear_color_from"]:
		themes.change_clear_color()

	elif prop == "left_tool_color":
		for child in Tools._tool_buttons.get_children():
			var left_background: NinePatchRect = child.get_node("BackgroundLeft")
			left_background.modulate = Global.left_tool_color
		Tools._slots[BUTTON_LEFT].tool_node.color_rect.color = Global.left_tool_color

	elif prop == "right_tool_color":
		for child in Tools._tool_buttons.get_children():
			var left_background: NinePatchRect = child.get_node("BackgroundRight")
			left_background.modulate = Global.right_tool_color
		Tools._slots[BUTTON_RIGHT].tool_node.color_rect.color = Global.right_tool_color

	elif prop == "tool_button_size":
		Tools.set_button_size(Global.tool_button_size)

	elif prop == "native_cursors":
		if Global.native_cursors:
			Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS, Vector2(15, 15))
		else:
			Global.control.set_custom_cursor()

	elif prop == "cross_cursor":
		if Global.cross_cursor:
			Global.main_viewport.mouse_default_cursor_shape = Control.CURSOR_CROSS
		else:
			Global.main_viewport.mouse_default_cursor_shape = Control.CURSOR_ARROW

	Global.config_cache.save("user://cache.ini")


func disable_restore_default_button(button: BaseButton, disable: bool) -> void:
	button.disabled = disable
	if disable:
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW
		button.hint_tooltip = ""
	else:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.hint_tooltip = "Restore default value"


func _on_PreferencesDialog_about_to_show() -> void:
	add_tabs(false)


func add_tabs(changed_language := false) -> void:
	for item in content_list:
		list.add_item(" " + tr(item))

	var language_index := content_list.find("Language")
	list.select(language_index if changed_language else selected_item)
	autosave_interval.suffix = tr("minute(s)")


func _on_PreferencesDialog_popup_hide() -> void:
	list.clear()


func _on_List_item_selected(index: int) -> void:
	selected_item = index
	for child in right_side.get_children():
		child.visible = child.name == content_list[index]


func _on_ShrinkApplyButton_pressed() -> void:
	get_tree().set_screen_stretch(
		SceneTree.STRETCH_MODE_DISABLED,
		SceneTree.STRETCH_ASPECT_IGNORE,
		Vector2(1024, 576),
		Global.shrink
	)
	Global.control.set_custom_cursor()
	hide()
	popup_centered(Vector2(600, 400))
	Global.dialog_open(true)
	yield(get_tree(), "idle_frame")
	Global.camera.fit_to_frame(Global.current_project.size)
