extends AcceptDialog

onready var tree : Tree = $HSplitContainer/Tree
onready var right_side : VBoxContainer = $HSplitContainer/ScrollContainer/VBoxContainer
onready var languages = $HSplitContainer/ScrollContainer/VBoxContainer/Languages
onready var themes = $HSplitContainer/ScrollContainer/VBoxContainer/Themes
onready var grid_guides = $"HSplitContainer/ScrollContainer/VBoxContainer/Grid&Guides"
onready var image = $HSplitContainer/ScrollContainer/VBoxContainer/Image

onready var default_width_value = $HSplitContainer/ScrollContainer/VBoxContainer/Image/ImageOptions/ImageDefaultWidth
onready var default_height_value = $HSplitContainer/ScrollContainer/VBoxContainer/Image/ImageOptions/ImageDefaultHeight
onready var default_fill_color = $HSplitContainer/ScrollContainer/VBoxContainer/Image/ImageOptions/DefaultFillColor

onready var grid_width_value = $"HSplitContainer/ScrollContainer/VBoxContainer/Grid&Guides/GridOptions/GridWidthValue"
onready var grid_height_value = $"HSplitContainer/ScrollContainer/VBoxContainer/Grid&Guides/GridOptions/GridHeightValue"
onready var grid_color = $"HSplitContainer/ScrollContainer/VBoxContainer/Grid&Guides/GridOptions/GridColor"
onready var guide_color = $"HSplitContainer/ScrollContainer/VBoxContainer/Grid&Guides/GridOptions/GuideColor"

func _ready() -> void:
	for child in languages.get_children():
		if child is Button:
			child.connect("pressed", self, "_on_Language_pressed", [child])

	for child in themes.get_children():
		if child is Button:
			child.connect("pressed", self, "_on_Theme_pressed", [child])

	if Global.config_cache.has_section_key("preferences", "theme"):
		var theme_id = Global.config_cache.get_value("preferences", "theme")
		change_theme(theme_id)
		themes.get_child(theme_id + 1).pressed = true
	else:
		change_theme(0)
		themes.get_child(1).pressed = true

	# Set default values for Grid & Guide options
	if Global.config_cache.has_section_key("preferences", "grid_size"):
		var grid_size = Global.config_cache.get_value("preferences", "grid_size")
		Global.grid_width = int(grid_size.x)
		Global.grid_height = int(grid_size.y)
		grid_width_value.value = grid_size.x
		grid_height_value.value = grid_size.y

	if Global.config_cache.has_section_key("preferences", "grid_color"):
		Global.grid_color = Global.config_cache.get_value("preferences", "grid_color")
		grid_color.color = Global.grid_color

	if Global.config_cache.has_section_key("preferences", "guide_color"):
		Global.guide_color = Global.config_cache.get_value("preferences", "guide_color")
		for canvas in Global.canvases:
			for guide in canvas.get_children():
				if guide is Guide:
					guide.default_color = Global.guide_color
		guide_color.color = Global.guide_color
	
	# Set default values for Image
	if Global.config_cache.has_section_key("preferences", "default_width") && Global.config_cache.has_section_key("preferences", "default_height"):
		var default_width = Global.config_cache.get_value("preferences", "default_width")
		var default_height = Global.config_cache.get_value("preferences", "default_height")
		Global.default_image_width = int(default_width)
		Global.default_image_height = int(default_height)
		default_width_value.value = Global.default_image_width
		default_height_value.value = Global.default_image_height
	
	if Global.config_cache.has_section_key("preferences", "default_fill_color"):
		var fill_color = Global.config_cache.get_value("preferences", "default_fill_color")
		Global.default_fill_color = fill_color
		default_fill_color.color = Global.default_fill_color

func _on_PreferencesDialog_about_to_show() -> void:
	var root := tree.create_item()
	var language_button := tree.create_item(root)
	var theme_button := tree.create_item(root)
	var grid_button := tree.create_item(root)
	var image_button := tree.create_item(root)

	language_button.set_text(0, "  " + tr("Language"))
	# We use metadata to avoid being affected by translations
	language_button.set_metadata(0, "Language")
	language_button.select(0)
	theme_button.set_text(0, "  " + tr("Themes"))
	theme_button.set_metadata(0, "Themes")
	grid_button.set_text(0, "  " + tr("Guides & Grid"))
	grid_button.set_metadata(0, "Guides & Grid")
	image_button.set_text(0, "  " + tr("Image"))
	image_button.set_metadata(0, "Image")


func _on_PreferencesDialog_popup_hide() -> void:
	tree.clear()

func _on_Tree_item_selected() -> void:
	for child in right_side.get_children():
		child.visible = false
	var selected : String = tree.get_selected().get_metadata(0)
	if "Language" in selected:
		languages.visible = true
	elif "Themes" in selected:
		themes.visible = true
	elif "Guides & Grid" in selected:
		grid_guides.visible = true
	elif "Image" in selected:
		image.visible = true

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
		Global.control.theme.default_font = preload("res://Assets/Fonts/CJK/NotoSansCJKtc-Regular.tres")
	else:
		Global.control.theme.default_font = preload("res://Assets/Fonts/Roboto-Regular.tres")

	Global.config_cache.set_value("preferences", "locale", TranslationServer.get_locale())
	Global.config_cache.save("user://cache.ini")

	# Update Translations
	_on_PreferencesDialog_popup_hide()
	_on_PreferencesDialog_about_to_show()

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
	var main_theme
	var top_menu_style
	var ruler_style
	if ID == 0: #Dark Theme
		Global.theme_type = "Dark"
		Global.transparent_background.create_from_image(preload("res://Assets/Graphics/Canvas Backgrounds/Transparent Background Dark.png"), 0)
		VisualServer.set_default_clear_color(Color(0.247059, 0.25098, 0.247059))
		main_theme = preload("res://Themes & Styles/Dark Theme/Dark Theme.tres")
		top_menu_style = preload("res://Themes & Styles/Dark Theme/DarkTopMenuStyle.tres")
		ruler_style = preload("res://Themes & Styles/Dark Theme/DarkRulerStyle.tres")
	elif ID == 1: #Gray Theme
		Global.theme_type = "Dark"
		Global.transparent_background.create_from_image(preload("res://Assets/Graphics/Canvas Backgrounds/Transparent Background Gray.png"), 0)
		VisualServer.set_default_clear_color(Color(0.301961, 0.301961, 0.301961))
		main_theme = preload("res://Themes & Styles/Gray Theme/Gray Theme.tres")
		top_menu_style = preload("res://Themes & Styles/Gray Theme/GrayTopMenuStyle.tres")
		ruler_style = preload("res://Themes & Styles/Dark Theme/DarkRulerStyle.tres")
	elif ID == 2: #Godot's Theme
		Global.theme_type = "Dark"
		Global.transparent_background.create_from_image(preload("res://Assets/Graphics/Canvas Backgrounds/Transparent Background Godot.png"), 0)
		VisualServer.set_default_clear_color(Color(0.27451, 0.278431, 0.305882))
		main_theme = preload("res://Themes & Styles/Godot\'s Theme/Godot\'s Theme.tres")
		top_menu_style = preload("res://Themes & Styles/Godot\'s Theme/TopMenuStyle.tres")
		ruler_style = preload("res://Themes & Styles/Godot\'s Theme/RulerStyle.tres")
	elif ID == 3: #Gold Theme
		Global.theme_type = "Gold"
		Global.transparent_background.create_from_image(preload("res://Assets/Graphics/Canvas Backgrounds/Transparent Background Gold.png"), 0)
		VisualServer.set_default_clear_color(Color(0.694118, 0.619608, 0.458824))
		main_theme = preload("res://Themes & Styles/Gold Theme/Gold Theme.tres")
		top_menu_style = preload("res://Themes & Styles/Gold Theme/GoldTopMenuStyle.tres")
		ruler_style = preload("res://Themes & Styles/Gold Theme/GoldRulerStyle.tres")
	elif ID == 4: #Light Theme
		Global.theme_type = "Light"
		Global.transparent_background.create_from_image(preload("res://Assets/Graphics/Canvas Backgrounds/Transparent Background Light.png"), 0)
		VisualServer.set_default_clear_color(Color(0.705882, 0.705882, 0.705882))
		main_theme = preload("res://Themes & Styles/Light Theme/Light Theme.tres")
		top_menu_style = preload("res://Themes & Styles/Light Theme/LightTopMenuStyle.tres")
		ruler_style = preload("res://Themes & Styles/Light Theme/LightRulerStyle.tres")

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

		# Make sure the frame text gets updated
		Global.current_frame = Global.current_frame

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

