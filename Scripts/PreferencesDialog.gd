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
		Global.transparent_background.create_from_image(preload("res://Assets/Graphics/Transparent Background Dark.png"), 0)
		VisualServer.set_default_clear_color(Color(0.247059, 0.25098, 0.247059))
		main_theme = preload("res://Themes & Styles/Dark Theme/Dark Theme.tres")
		top_menu_style = preload("res://Themes & Styles/Dark Theme/DarkTopMenuStyle.tres")
		ruler_style = preload("res://Themes & Styles/Dark Theme/DarkRulerStyle.tres")
	elif ID == 1: #Gray Theme
		Global.theme_type = "Dark"
		Global.transparent_background.create_from_image(preload("res://Assets/Graphics/Transparent Background Gray.png"), 0)
		VisualServer.set_default_clear_color(Color(0.301961, 0.301961, 0.301961))
		main_theme = preload("res://Themes & Styles/Gray Theme/Gray Theme.tres")
		top_menu_style = preload("res://Themes & Styles/Gray Theme/GrayTopMenuStyle.tres")
		ruler_style = preload("res://Themes & Styles/Dark Theme/DarkRulerStyle.tres")
	elif ID == 2: #Godot's Theme
		Global.theme_type = "Dark"
		Global.transparent_background.create_from_image(preload("res://Assets/Graphics/Transparent Background Godot.png"), 0)
		VisualServer.set_default_clear_color(Color(0.27451, 0.278431, 0.305882))
		main_theme = preload("res://Themes & Styles/Godot\'s Theme/Godot\'s Theme.tres")
		top_menu_style = preload("res://Themes & Styles/Godot\'s Theme/TopMenuStyle.tres")
		ruler_style = preload("res://Themes & Styles/Godot\'s Theme/RulerStyle.tres")
	elif ID == 3: #Gold Theme
		Global.theme_type = "Light"
		Global.transparent_background.create_from_image(preload("res://Assets/Graphics/Transparent Background Gold.png"), 0)
		VisualServer.set_default_clear_color(Color(0.694118, 0.619608, 0.458824))
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

	for button in get_tree().get_nodes_in_group("UIButtons"):
		var last_backslash = button.texture_normal.resource_path.get_base_dir().find_last("/")
		var button_category = button.texture_normal.resource_path.get_base_dir().right(last_backslash + 1)
		var normal_file_name = button.texture_normal.resource_path.get_file()
		button.texture_normal = load("res://Assets/Graphics/%s Themes/%s/%s" % [Global.theme_type, button_category, normal_file_name])
		if button.texture_pressed:
			var pressed_file_name = button.texture_pressed.resource_path.get_file()
			button.texture_pressed = load("res://Assets/Graphics/%s Themes/%s/%s" % [Global.theme_type, button_category, pressed_file_name])
		if button.texture_hover:
			var hover_file_name = button.texture_hover.resource_path.get_file()
			button.texture_hover = load("res://Assets/Graphics/%s Themes/%s/%s" % [Global.theme_type, button_category, hover_file_name])
		if button.texture_disabled:
			var disabled_file_name = button.texture_disabled.resource_path.get_file()
			button.texture_disabled = load("res://Assets/Graphics/%s Themes/%s/%s" % [Global.theme_type, button_category, disabled_file_name])

func _on_GridWidthValue_value_changed(value : float) -> void:
	Global.grid_width = value

func _on_GridHeightValue_value_changed(value : float) -> void:
	Global.grid_height = value

func _on_GridColor_color_changed(color : Color) -> void:
	Global.grid_color = color
