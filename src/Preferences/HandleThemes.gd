extends Node


func _ready() -> void:
	for child in get_children():
		if child is Button:
			child.connect("pressed", self, "_on_Theme_pressed", [child.get_index()])

	if Global.config_cache.has_section_key("preferences", "theme"):
		var theme_id = Global.config_cache.get_value("preferences", "theme")
		change_theme(theme_id)
		get_child(theme_id).pressed = true
	else:
		change_theme(0)
		get_child(0).pressed = true


func _on_Theme_pressed(index : int) -> void:
	get_child(index).pressed = true
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
		main_theme = preload("res://assets/themes/dark/theme.tres")
		top_menu_style = preload("res://assets/themes/dark/top_menu_style.tres")
		ruler_style = preload("res://assets/themes/dark/ruler_style.tres")
	elif ID == 1: # Gray Theme
		Global.theme_type = "Dark"
		main_theme = preload("res://assets/themes/gray/theme.tres")
		top_menu_style = preload("res://assets/themes/gray/top_menu_style.tres")
		ruler_style = preload("res://assets/themes/dark/ruler_style.tres")
	elif ID == 2: # Godot's Theme
		Global.theme_type = "Blue"
		main_theme = preload("res://assets/themes/blue/theme.tres")
		top_menu_style = preload("res://assets/themes/blue/top_menu_style.tres")
		ruler_style = preload("res://assets/themes/blue/ruler_style.tres")
	elif ID == 3: # Caramel Theme
		Global.theme_type = "Caramel"
		main_theme = preload("res://assets/themes/caramel/theme.tres")
		top_menu_style = preload("res://assets/themes/caramel/top_menu_style.tres")
		ruler_style = preload("res://assets/themes/caramel/ruler_style.tres")
	elif ID == 4: # Light Theme
		Global.theme_type = "Light"
		main_theme = preload("res://assets/themes/light/theme.tres")
		top_menu_style = preload("res://assets/themes/light/top_menu_style.tres")
		ruler_style = preload("res://assets/themes/light/ruler_style.tres")

	Global.control.theme = main_theme
	Global.control.theme.default_font = font
	var default_clear_color : Color = main_theme.get_stylebox("panel", "PanelContainer").bg_color
	VisualServer.set_default_clear_color(Color(default_clear_color))
	(Global.animation_timeline.get_stylebox("panel", "Panel") as StyleBoxFlat).bg_color = main_theme.get_stylebox("panel", "Panel").bg_color
	var layer_button_panel_container : PanelContainer = Global.find_node_by_name(Global.animation_timeline, "LayerButtonPanelContainer")
	(layer_button_panel_container.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color = default_clear_color

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
				if theme_type == "Caramel" or (theme_type == "Blue" and button_category != "tools"):
					theme_type = "Dark"

				texture.texture = load("res://assets/graphics/%s_themes/%s/%s" % [theme_type.to_lower(), button_category, normal_file_name])

	# Make sure the frame text gets updated
	Global.current_frame = Global.current_frame

	Global.preferences_dialog.get_node("Popups/ShortcutSelector").theme = main_theme
