extends Node


onready var themes := [
	[preload("res://assets/themes/dark/theme.tres"), "Dark"],
	[preload("res://assets/themes/gray/theme.tres"), "Gray"],
	[preload("res://assets/themes/blue/theme.tres"), "Blue"],
	[preload("res://assets/themes/caramel/theme.tres"), "Caramel"],
	[preload("res://assets/themes/light/theme.tres"), "Light"],
	[preload("res://assets/themes/purple/theme.tres"), "Purple"],
]
onready var buttons_container : BoxContainer = $ThemeButtons
onready var colors_container : BoxContainer = $ThemeColorsSpacer/ThemeColors
onready var theme_color_preview_scene = preload("res://src/Preferences/ThemeColorPreview.tscn")


func _ready() -> void:
	var button_group = ButtonGroup.new()
	for theme in themes:
		var button := CheckBox.new()
		button.name = theme[1]
		button.text = theme[1]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.group = button_group
		buttons_container.add_child(button)
		button.connect("pressed", self, "_on_Theme_pressed", [button.get_index()])

		var theme_color_preview : ColorRect = theme_color_preview_scene.instance()
		var color1 = theme[0].get_stylebox("panel", "Panel").bg_color
		var color2 = theme[0].get_stylebox("panel", "PanelContainer").bg_color
		theme_color_preview.get_child(0).color = color1
		theme_color_preview.get_child(1).color = color2
		colors_container.add_child(theme_color_preview)

	if Global.config_cache.has_section_key("preferences", "theme"):
		var theme_id = Global.config_cache.get_value("preferences", "theme")
		if theme_id >= themes.size():
			theme_id = 0
		change_theme(theme_id)
		buttons_container.get_child(theme_id).pressed = true
	else:
		change_theme(0)
		buttons_container.get_child(0).pressed = true


func _on_Theme_pressed(index : int) -> void:
	buttons_container.get_child(index).pressed = true
	change_theme(index)

	Global.config_cache.set_value("preferences", "theme", index)
	Global.config_cache.save("user://cache.ini")


func change_theme(ID : int) -> void:
	var font = Global.control.theme.default_font
	var main_theme : Theme = themes[ID][0]
	if ID == 0 or ID == 1: # Dark or Gray Theme
		Global.theme_type = Global.ThemeTypes.DARK
	elif ID == 2: # Godot's Theme
		Global.theme_type = Global.ThemeTypes.BLUE
	elif ID == 3: # Caramel Theme
		Global.theme_type = Global.ThemeTypes.CARAMEL
	elif ID == 4: # Light Theme
		Global.theme_type = Global.ThemeTypes.LIGHT
	elif ID == 5: # Purple Theme
		Global.theme_type = Global.ThemeTypes.DARK

	Global.control.theme = main_theme
	Global.control.theme.default_font = font
	Global.default_clear_color = main_theme.get_stylebox("panel", "PanelContainer").bg_color
	VisualServer.set_default_clear_color(Color(Global.default_clear_color))

	(Global.animation_timeline.get_stylebox("panel", "Panel") as StyleBoxFlat).bg_color = main_theme.get_stylebox("panel", "Panel").bg_color
	var fake_vsplit_grabber : TextureRect = Global.find_node_by_name(Global.animation_timeline, "FakeVSplitContainerGrabber")
	fake_vsplit_grabber.texture = main_theme.get_icon("grabber", "VSplitContainer")

	var layer_button_panel_container : PanelContainer = Global.find_node_by_name(Global.animation_timeline, "LayerButtonPanelContainer")
	(layer_button_panel_container.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color = Global.default_clear_color

	var top_menu_style = main_theme.get_stylebox("TopMenu", "Panel")
	var ruler_style = main_theme.get_stylebox("Ruler", "Button")
	Global.top_menu_container.add_stylebox_override("panel", top_menu_style)
	Global.horizontal_ruler.add_stylebox_override("normal", ruler_style)
	Global.horizontal_ruler.add_stylebox_override("pressed", ruler_style)
	Global.horizontal_ruler.add_stylebox_override("hover", ruler_style)
	Global.horizontal_ruler.add_stylebox_override("focus", ruler_style)
	Global.vertical_ruler.add_stylebox_override("normal", ruler_style)
	Global.vertical_ruler.add_stylebox_override("pressed", ruler_style)
	Global.vertical_ruler.add_stylebox_override("hover", ruler_style)
	Global.vertical_ruler.add_stylebox_override("focus", ruler_style)

	for button in get_tree().get_nodes_in_group("UIButtons"):
		if button is TextureButton:
			var last_backslash = button.texture_normal.resource_path.get_base_dir().find_last("/")
			var button_category = button.texture_normal.resource_path.get_base_dir().right(last_backslash + 1)
			var normal_file_name = button.texture_normal.resource_path.get_file()
			var theme_type := Global.theme_type
			if theme_type == Global.ThemeTypes.BLUE:
				theme_type = Global.ThemeTypes.DARK

			var theme_type_string : String = Global.ThemeTypes.keys()[theme_type].to_lower()
			button.texture_normal = load("res://assets/graphics/%s_themes/%s/%s" % [theme_type_string, button_category, normal_file_name])
			if button.texture_pressed:
				var pressed_file_name = button.texture_pressed.resource_path.get_file()
				button.texture_pressed = load("res://assets/graphics/%s_themes/%s/%s" % [theme_type_string, button_category, pressed_file_name])
			if button.texture_hover:
				var hover_file_name = button.texture_hover.resource_path.get_file()
				button.texture_hover = load("res://assets/graphics/%s_themes/%s/%s" % [theme_type_string, button_category, hover_file_name])
			if button.texture_disabled and button.texture_disabled == StreamTexture:
				var disabled_file_name = button.texture_disabled.resource_path.get_file()
				button.texture_disabled = load("res://assets/graphics/%s_themes/%s/%s" % [theme_type_string, button_category, disabled_file_name])
		elif button is Button:
			var texture : TextureRect
			for child in button.get_children():
				if child is TextureRect and child.name != "Background":
					texture = child
					break

			if texture:
				var last_backslash = texture.texture.resource_path.get_base_dir().find_last("/")
				var button_category = texture.texture.resource_path.get_base_dir().right(last_backslash + 1)
				var normal_file_name = texture.texture.resource_path.get_file()
				var theme_type := Global.theme_type
				if theme_type == Global.ThemeTypes.CARAMEL or (theme_type == Global.ThemeTypes.BLUE and button_category != "tools"):
					theme_type = Global.ThemeTypes.DARK

				var theme_type_string : String = Global.ThemeTypes.keys()[theme_type].to_lower()
				texture.texture = load("res://assets/graphics/%s_themes/%s/%s" % [theme_type_string, button_category, normal_file_name])

	# Make sure the frame text gets updated
	Global.current_project.current_frame = Global.current_project.current_frame

	Global.preferences_dialog.get_node("Popups/ShortcutSelector").theme = main_theme

	# Sets disabled theme color on palette swatches
	Global.palette_panel.reset_empty_palette_swatches_color()
