extends AcceptDialog

# Preferences table: [Prop name in Global, relative node path, value type]
var preferences = [
	["open_last_project", "Startup/StartupContainer/OpenLastProject", "pressed"],
	["smooth_zoom", "Canvas/SmoothZoom", "pressed"],
	["pressure_sensitivity_mode", "Startup/PressureSentivity/PressureSensitivityOptionButton", "selected"],
	["show_left_tool_icon", "Indicators/IndicatorsContainer/LeftToolIconCheckbox", "pressed"],
	["show_right_tool_icon", "Indicators/IndicatorsContainer/RightToolIconCheckbox", "pressed"],
	["left_square_indicator_visible", "Indicators/IndicatorsContainer/LeftIndicatorCheckbox", "pressed"],
	["right_square_indicator_visible", "Indicators/IndicatorsContainer/RightIndicatorCheckbox", "pressed"],
	["autosave_interval", "Backup/AutosaveContainer/AutosaveInterval", "value"],
	["enable_autosave", "Backup/AutosaveContainer/EnableAutosave", "pressed"],

	["default_image_width", "Image/ImageOptions/ImageDefaultWidth", "value"],
	["default_image_height", "Image/ImageOptions/ImageDefaultHeight", "value"],
	["default_fill_color", "Image/ImageOptions/DefaultFillColor", "color"],

	["grid_width", "Canvas/GridOptions/GridWidthValue", "value"],
	["grid_height", "Canvas/GridOptions/GridHeightValue", "value"],
	["grid_color", "Canvas/GridOptions/GridColor", "color"],
	["guide_color", "Canvas/GuideOptions/GuideColor", "color"],
	["checker_size", "Canvas/CheckerOptions/CheckerSizeValue", "value"],
	["checker_color_1", "Canvas/CheckerOptions/CheckerColor1", "color"],
	["checker_color_2", "Canvas/CheckerOptions/CheckerColor2", "color"],
]

var selected_item := 0

onready var list : ItemList = $HSplitContainer/List
onready var right_side : VBoxContainer = $HSplitContainer/ScrollContainer/VBoxContainer
onready var autosave_interval : SpinBox = $HSplitContainer/ScrollContainer/VBoxContainer/Backup/AutosaveContainer/AutosaveInterval


func _ready() -> void:
	# Replace OK with Close since preference changes are being applied immediately, not after OK confirmation
	get_ok().text = tr("Close")

	if OS.get_name() == "HTML5":
		right_side.get_node("Startup").queue_free()
		right_side.get_node("Languages").visible = true
		Global.open_last_project = false

	for pref in preferences:
		var node = right_side.get_node(pref[1])

		match pref[2]:
			"pressed":
				node.connect("toggled", self, "_on_Preference_toggled", [pref[0]])
			"value":
				node.connect("value_changed", self, "_on_Preference_value_changed", [pref[0]])
			"color":
				node.get_picker().presets_visible = false
				node.connect("color_changed", self, "_on_Preference_color_changed", [pref[0]])
			"selected":
				node.connect("item_selected", self, "_on_Preference_item_selected", [pref[0]])

		if Global.config_cache.has_section_key("preferences", pref[0]):
			var value = Global.config_cache.get_value("preferences", pref[0])
			Global.set(pref[0], value)
			node.set(pref[2], value)


func _on_Preference_toggled(button_pressed : bool, prop : String) -> void:
	Global.set(prop, button_pressed)
	Global.config_cache.set_value("preferences", prop, button_pressed)
	preference_update(prop)


func _on_Preference_value_changed(value : float, prop : String) -> void:
	Global.set(prop, value)
	Global.config_cache.set_value("preferences", prop, value)
	preference_update(prop)


func _on_Preference_color_changed(color : Color, prop : String) -> void:
	Global.set(prop, color)
	Global.config_cache.set_value("preferences", prop, color)
	preference_update(prop)


func _on_Preference_item_selected(id : int, prop : String) -> void:
	Global.set(prop, id)
	Global.config_cache.set_value("preferences", prop, id)
	preference_update(prop)


func preference_update(prop : String) -> void:
	if prop in ["autosave_interval", "enable_autosave"]:
		OpenSave.update_autosave()
		autosave_interval.editable = Global.enable_autosave
		if autosave_interval.editable:
			autosave_interval.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			autosave_interval.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN

	if prop in ["grid_width", "grid_height", "grid_color"]:
		Global.canvas.update()

	if prop in ["checker_size", "checker_color_1", "checker_color_2"]:
		Global.transparent_checker._ready()

	if prop in ["guide_color"]:
		for guide in Global.canvas.get_children():
			if guide is Guide:
				guide.default_color = Global.guide_color

	Global.config_cache.save("user://cache.ini")


func _on_PreferencesDialog_about_to_show(changed_language := false) -> void:
	if OS.get_name() != "HTML5":
		list.add_item("  " + tr("Startup"))
	list.add_item("  " + tr("Language"))
	list.add_item("  " + tr("Themes"))
	list.add_item("  " + tr("Canvas"))
	list.add_item("  " + tr("Image"))
	list.add_item("  " + tr("Shortcuts"))
	list.add_item("  " + tr("Backup"))
	list.add_item("  " + tr("Indicators"))

	list.select(1 if changed_language else selected_item)
	autosave_interval.suffix = tr("minute(s)")


func _on_PreferencesDialog_popup_hide() -> void:
	list.clear()


func _on_List_item_selected(index : int) -> void:
	selected_item = index
	for child in right_side.get_children():
		var content_list = ["Startup", "Languages", "Themes", "Canvas", "Image", "Shortcuts", "Backup", "Indicators"]
		if OS.get_name() == "HTML5":
			content_list.erase("Startup")
		child.visible = child.name == content_list[index]
