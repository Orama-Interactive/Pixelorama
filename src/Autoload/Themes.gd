extends Node

signal theme_added(theme: Theme)
signal theme_removed(theme: Theme)
## Emitted when the theme is switched. Unlike [signal Control.theme_changed],
## this doesn't get emitted when a stylebox of a control changes, only when the
## main theme gets switched to another.
signal theme_switched

const MAIN_THEME := preload("uid://dog5j8wjiwikc")

var themes: Array[ThemeVariation] = [
	ThemeVariation.new(MAIN_THEME, "Dark"),
	ThemeVariation.new(MAIN_THEME, "Gray", Color("333333"), Color("a7b2ea")),
	ThemeVariation.new(MAIN_THEME, "Blue", Color("47526e"), Color("92a8e0")),
	ThemeVariation.new(MAIN_THEME, "Caramel", Color("b16832"), Color("ffcd86")),
	ThemeVariation.new(MAIN_THEME, "Light", Color("e7f1f7"), Color("484b68")),
	ThemeVariation.new(MAIN_THEME, "Purple", Color("433057"), Color("d093dd")),
	ThemeVariation.new(MAIN_THEME, "Rose", Color("a53753"), Color("f69bb2")),
	ThemeVariation.new(MAIN_THEME, "Black (OLED)", Color.BLACK, Color("7c8dbf"), 0.0),
]


class ThemeVariation:
	var theme: Theme
	var name := ""
	var base_color: Color
	var accent_color: Color
	var contrast := 0.3

	func _init(
		_theme: Theme,
		_name: String,
		_base_color := Color.TRANSPARENT,
		_accent_color := Color.TRANSPARENT,
		_contrast := 0.3
	) -> void:
		theme = _theme
		name = _name
		base_color = _base_color
		accent_color = _accent_color
		contrast = _contrast

	func get_name() -> String:
		if name.is_empty():
			return theme.resource_name
		return name

	func get_base_color() -> Color:
		if base_color.is_equal_approx(Color.TRANSPARENT):
			var panel_stylebox := theme.get_stylebox(&"panel", &"Panel")
			if panel_stylebox is StyleBoxFlat:
				return Color(panel_stylebox.bg_color, 1.0)
			elif panel_stylebox is StyleBoxTexture:
				var sub_region := (panel_stylebox as StyleBoxTexture).region_rect
				var image := (panel_stylebox as StyleBoxTexture).texture.get_image()
				image = image.get_region(sub_region)
				return Color(image.get_pixel(0, 0), 1.0)
		return base_color

	func get_accent_color() -> Color:
		if accent_color.is_equal_approx(Color.TRANSPARENT):
			var button_stylebox := theme.get_stylebox(&"pressed", &"Button")
			if button_stylebox is StyleBoxFlat:
				return button_stylebox.border_color
			elif button_stylebox is StyleBoxTexture:
				var sub_region := (button_stylebox as StyleBoxTexture).region_rect
				var image := (button_stylebox as StyleBoxTexture).texture.get_image()
				image = image.get_region(sub_region)
				return image.get_pixel(0, 0)
		return accent_color

	func has_custom_colors() -> bool:
		return not (
			base_color.is_equal_approx(Color.TRANSPARENT)
			or accent_color.is_equal_approx(Color.TRANSPARENT)
		)


func _ready() -> void:
	var theme_id: int = Global.config_cache.get_value("preferences", "theme_preset_index", 0)
	## Wait so that extensions are loaded
	await Global.pixelorama_opened
	if theme_id >= themes.size():
		theme_id = 0
	Global.theme_preset_index = theme_id


func add_theme(
	theme: Theme,
	theme_name := "",
	base_color := Color.TRANSPARENT,
	accent_color := Color.TRANSPARENT,
	contrast := 0.3
) -> void:
	var theme_var := ThemeVariation.new(theme, theme_name, base_color, accent_color, contrast)
	themes.append(theme_var)
	theme_added.emit(theme)


func remove_theme(theme: Theme) -> void:
	for i in themes.size():
		var theme_var := themes[i]
		if theme_var.theme == theme:
			if i == Global.theme_preset_index:
				Global.theme_preset_index = 0
			themes.erase(theme_var)
	theme_removed.emit(theme)


func change_theme(id: int) -> void:
	var theme := ThemeUtils.generate_theme(themes[id])
	Global.theme_font_index = Global.theme_font_index  # Trigger the setter
	if theme.default_font != Global.theme_font:
		theme.default_font = Global.theme_font
	theme.default_font_size = Global.font_size
	theme.set_font_size("font_size", "HeaderSmall", Global.font_size + 2)
	var icon_color := theme.get_color("modulate_color", "Icons")
	if Global.icon_color_from == Global.ColorFrom.THEME:
		Global.modulate_icon_color = icon_color

	Global.control.theme = theme
	change_clear_color()
	change_icon_colors()
	Global.config_cache.set_value("preferences", "theme", id)
	Global.config_cache.save(Global.CONFIG_PATH)
	theme_switched.emit()


func change_clear_color() -> void:
	var clear_color: Color = Global.control.theme.get_color("clear_color", "Misc")
	if not clear_color:
		var panel_stylebox: StyleBox = Global.control.theme.get_stylebox("panel", "PanelContainer")
		if panel_stylebox is StyleBoxFlat:
			clear_color = panel_stylebox.bg_color
		else:
			clear_color = Color.GRAY
	if Global.clear_color_from == Global.ColorFrom.THEME:
		RenderingServer.set_default_clear_color(clear_color)
	else:
		RenderingServer.set_default_clear_color(Global.modulate_clear_color)


func change_icon_colors() -> void:
	for node in get_tree().get_nodes_in_group("UIButtons"):
		if node is TextureRect or node is Sprite2D:
			node.modulate = Global.modulate_icon_color
		elif node is TextureButton:
			node.modulate = Global.modulate_icon_color
			if node.disabled and not ("RestoreDefaultButton" in node.name):
				node.modulate.a = 0.5
		elif node is Button:
			var texture: TextureRect
			for child in node.get_children():
				if child is TextureRect and child.name != "Background":
					texture = child
					break
			if is_instance_valid(texture):
				texture.modulate = Global.modulate_icon_color
				if node.disabled:
					texture.modulate.a = 0.5


func get_font() -> Font:
	if Global.control.theme.has_default_font():
		return Global.control.theme.default_font
	return ThemeDB.fallback_font


func get_font_size() -> int:
	if Global.control.theme.has_default_font_size():
		return Global.control.theme.default_font_size
	return ThemeDB.fallback_font_size
