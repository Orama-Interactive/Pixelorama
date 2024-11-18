extends Node

signal theme_added(theme: Theme)
signal theme_removed(theme: Theme)
## Emitted when the theme is switched. Unlike [signal Control.theme_changed],
## this doesn't get emitted when a stylebox of a control changes, only when the
## main theme gets switched to another.
signal theme_switched

var theme_index := 0
var themes: Array[Theme] = [
	preload("res://assets/themes/dark/theme.tres"),
	preload("res://assets/themes/gray/theme.tres"),
	preload("res://assets/themes/blue/theme.tres"),
	preload("res://assets/themes/caramel/theme.tres"),
	preload("res://assets/themes/light/theme.tres"),
	preload("res://assets/themes/purple/theme.tres"),
	preload("res://assets/themes/rose/theme.tres"),
]


func _ready() -> void:
	var theme_id: int = Global.config_cache.get_value("preferences", "theme", 0)
	if theme_id >= themes.size():
		theme_id = 0
	if theme_id != 0:
		change_theme(theme_id)
	else:
		change_clear_color()
		change_icon_colors()


func add_theme(theme: Theme) -> void:
	themes.append(theme)
	theme_added.emit(theme)


func remove_theme(theme: Theme) -> void:
	themes.erase(theme)
	theme_removed.emit(theme)


func change_theme(id: int) -> void:
	theme_index = id
	var theme := themes[id]
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
