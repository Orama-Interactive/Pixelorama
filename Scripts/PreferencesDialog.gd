extends AcceptDialog

func _ready() -> void:
	if Global.config_cache.has_section_key("preferences", "theme"):
		var theme_id = Global.config_cache.get_value("preferences", "theme")
		change_theme(theme_id)
		$VBoxContainer/OptionsContainer/ThemeOption.selected = theme_id

func _on_LanguageOption_item_selected(ID : int) -> void:
	if ID == 0:
		TranslationServer.set_locale(OS.get_locale())
	else:
		TranslationServer.set_locale(Global.loaded_locales[ID - 1])
		if Global.loaded_locales[ID - 1] == "zh_TW":
			Global.control.theme.default_font = preload("res://Assets/Fonts/NotoSansCJKtc-Regular.tres")
		else:
			Global.control.theme.default_font = preload("res://Assets/Fonts/Roboto-Regular.tres")

	Global.config_cache.set_value("preferences", "locale", TranslationServer.get_locale())
	Global.config_cache.save("user://cache.ini")

func _on_ThemeOption_item_selected(ID : int) -> void:
	change_theme(ID)

	Global.config_cache.set_value("preferences", "theme", ID)
	Global.config_cache.save("user://cache.ini")

func change_theme(ID : int) -> void:
	var font = Global.control.theme.default_font
	var main_theme
	var top_menu_style
	var ruler_style
	if ID == 0: #Dark Theme
		Global.theme_type = "Dark"
		main_theme = preload("res://Themes & Styles/Dark Theme/Dark Theme.tres")
		top_menu_style = preload("res://Themes & Styles/Dark Theme/DarkTopMenuStyle.tres")
		ruler_style = preload("res://Themes & Styles/Dark Theme/DarkRulerStyle.tres")
	elif ID == 1: #Gray Theme
		Global.theme_type = "Dark"
		main_theme = preload("res://Themes & Styles/Gray Theme/Gray Theme.tres")
		top_menu_style = preload("res://Themes & Styles/Gray Theme/GrayTopMenuStyle.tres")
		ruler_style = preload("res://Themes & Styles/Dark Theme/DarkRulerStyle.tres")
	elif ID == 2: #Godot's Theme
		Global.theme_type = "Dark"
		main_theme = preload("res://Themes & Styles/Godot\'s Theme/Godot\'s Theme.tres")
		top_menu_style = preload("res://Themes & Styles/Godot\'s Theme/TopMenuStyle.tres")
		ruler_style = preload("res://Themes & Styles/Godot\'s Theme/RulerStyle.tres")
	elif ID == 3: #Gold Theme
		Global.theme_type = "Light"
		main_theme = preload("res://Themes & Styles/Gold Theme/Gold Theme.tres")
		top_menu_style = preload("res://Themes & Styles/Gold Theme/GoldTopMenuStyle.tres")
		ruler_style = preload("res://Themes & Styles/Gold Theme/GoldRulerStyle.tres")

	Global.control.theme = main_theme
	Global.control.theme.default_font = font
	Global.top_menu_container.add_stylebox_override("panel", top_menu_style)
	Global.horizontal_ruler.add_stylebox_override("normal", ruler_style)
	Global.horizontal_ruler.add_stylebox_override("pressed", ruler_style)
	Global.horizontal_ruler.add_stylebox_override("hover", ruler_style)
	Global.horizontal_ruler.add_stylebox_override("focus", ruler_style)
	Global.vertical_ruler.add_stylebox_override("normal", ruler_style)
	Global.vertical_ruler.add_stylebox_override("pressed", ruler_style)
	Global.vertical_ruler.add_stylebox_override("hover", ruler_style)
	Global.vertical_ruler.add_stylebox_override("focus", ruler_style)
	for button in get_tree().get_nodes_in_group("LayerButtons"):
		button.texture_normal = load("res://Assets/Graphics/%s Themes/Layers/%s.png" % [Global.theme_type, button.name])
		button.texture_hover = load("res://Assets/Graphics/%s Themes/Layers/%s_Hover.png" % [Global.theme_type, button.name])
		if button.texture_disabled:
			button.texture_disabled = load("res://Assets/Graphics/%s Themes/Layers/%s_Disabled.png" % [Global.theme_type, button.name])

func _on_GridWidthValue_value_changed(value : float) -> void:
	Global.grid_width = value

func _on_GridHeightValue_value_changed(value : float) -> void:
	Global.grid_height = value

func _on_GridColor_color_changed(color : Color) -> void:
	Global.grid_color = color
