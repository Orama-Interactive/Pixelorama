extends AcceptDialog

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
	var main_theme
	var top_menu_style
	var ruler_style
	if ID == 0: #Dark Theme
		main_theme = preload("res://Themes & Styles/Dark Theme/Dark Theme.tres")
		top_menu_style = preload("res://Themes & Styles/Dark Theme/DarkTopMenuStyle.tres")
		ruler_style = preload("res://Themes & Styles/Dark Theme/DarkRulerStyle.tres")
	elif ID == 1: #Gray Theme
		main_theme = preload("res://Themes & Styles/Gray Theme/Gray Theme.tres")
		top_menu_style = preload("res://Themes & Styles/Gray Theme/GrayTopMenuStyle.tres")
		ruler_style = preload("res://Themes & Styles/Dark Theme/DarkRulerStyle.tres")
	elif ID == 2: #Godot's Theme
		main_theme = preload("res://Themes & Styles/Godot\'s Theme/Godot\'s Theme.tres")
		top_menu_style = preload("res://Themes & Styles/Godot\'s Theme/TopMenuStyle.tres")
		ruler_style = preload("res://Themes & Styles/Godot\'s Theme/RulerStyle.tres")
	elif ID == 3: #Light Theme
		main_theme = preload("res://Themes & Styles/Light Theme/Light Theme.tres")
		top_menu_style = preload("res://Themes & Styles/Light Theme/LightTopMenuStyle.tres")
		ruler_style = preload("res://Themes & Styles/Light Theme/LightRulerStyle.tres")

	Global.control.theme = main_theme
	Global.top_menu_container.add_stylebox_override("panel", top_menu_style)
	Global.horizontal_ruler.add_stylebox_override("normal", ruler_style)
	Global.horizontal_ruler.add_stylebox_override("pressed", ruler_style)
	Global.horizontal_ruler.add_stylebox_override("hover", ruler_style)
	Global.horizontal_ruler.add_stylebox_override("focus", ruler_style)
	Global.vertical_ruler.add_stylebox_override("normal", ruler_style)
	Global.vertical_ruler.add_stylebox_override("pressed", ruler_style)
	Global.vertical_ruler.add_stylebox_override("hover", ruler_style)
	Global.vertical_ruler.add_stylebox_override("focus", ruler_style)

func _on_GridWidthValue_value_changed(value : float) -> void:
	Global.grid_width = value

func _on_GridHeightValue_value_changed(value : float) -> void:
	Global.grid_height = value

func _on_GridColor_color_changed(color : Color) -> void:
	Global.grid_color = color
