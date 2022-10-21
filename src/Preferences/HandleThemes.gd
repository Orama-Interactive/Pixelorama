extends Node

var theme_index := 0
var theme_button_group := ButtonGroup.new()

onready var themes := [
	preload("res://assets/themes/dark/theme.tres"),
	preload("res://assets/themes/gray/theme.tres"),
	preload("res://assets/themes/blue/theme.tres"),
	preload("res://assets/themes/caramel/theme.tres"),
	preload("res://assets/themes/light/theme.tres"),
	preload("res://assets/themes/purple/theme.tres"),
]

onready var buttons_container: BoxContainer = $ThemeButtons
onready var colors_container: BoxContainer = $ThemeColorsSpacer/ThemeColors
onready var theme_color_preview_scene := preload("res://src/Preferences/ThemeColorPreview.tscn")


func _ready() -> void:
	for theme in themes:
		add_theme(theme)
	yield(get_tree(), "idle_frame")

	var theme_id: int = Global.config_cache.get_value("preferences", "theme", 0)
	if theme_id >= themes.size():
		theme_id = 0
	change_theme(theme_id)
	buttons_container.get_child(theme_id).pressed = true


func _on_Theme_pressed(index: int) -> void:
	buttons_container.get_child(index).pressed = true
	change_theme(index)

	Global.config_cache.set_value("preferences", "theme", index)
	Global.config_cache.save("user://cache.ini")


func add_theme(theme: Theme) -> void:
	var button := CheckBox.new()
	var theme_name: String = theme.resource_name
	button.name = theme_name
	button.text = theme_name
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.group = theme_button_group
	buttons_container.add_child(button)
	button.connect("pressed", self, "_on_Theme_pressed", [button.get_index()])

	var panel_stylebox: StyleBox = theme.get_stylebox("panel", "Panel")
	var panel_container_stylebox: StyleBox = theme.get_stylebox("panel", "PanelContainer")
	if panel_stylebox is StyleBoxFlat and panel_container_stylebox is StyleBoxFlat:
		var theme_color_preview: ColorRect = theme_color_preview_scene.instance()
		var color1: Color = panel_stylebox.bg_color
		var color2: Color = panel_container_stylebox.bg_color
		theme_color_preview.get_child(0).get_child(0).color = color1
		theme_color_preview.get_child(0).get_child(1).color = color2
		colors_container.add_child(theme_color_preview)


func remove_theme(theme: Theme) -> void:
	var index: int = themes.find(theme)
	var theme_button = buttons_container.get_child(index)
	var color_previews = colors_container.get_child(index)
	buttons_container.remove_child(theme_button)
	theme_button.queue_free()
	colors_container.remove_child(color_previews)
	color_previews.queue_free()
	themes.erase(theme)


func change_theme(id: int) -> void:
	theme_index = id
	var theme: Theme = themes[id]
	var icon_color: Color = theme.get_color("modulate_color", "Icons")

	if Global.icon_color_from == Global.ColorFrom.THEME:
		Global.modulate_icon_color = icon_color

	Global.control.theme = theme
	change_clear_color()
	change_icon_colors()

	# Temporary code
	var clear_color: Color = theme.get_color("clear_color", "Misc")
	if !clear_color:
		var panel_stylebox: StyleBox = theme.get_stylebox("panel", "PanelContainer")
		if panel_stylebox is StyleBoxFlat:
			clear_color = panel_stylebox.bg_color
		else:
			clear_color = Color.gray

	for child in Global.preferences_dialog.get_node("Popups").get_children():
		child.theme = theme

	# Sets disabled theme color on palette swatches
	Global.palette_panel.reset_empty_palette_swatches_color()


func change_clear_color() -> void:
	var clear_color: Color = Global.control.theme.get_color("clear_color", "Misc")
	if !clear_color:
		var panel_stylebox: StyleBox = Global.control.theme.get_stylebox("panel", "PanelContainer")
		if panel_stylebox is StyleBoxFlat:
			clear_color = panel_stylebox.bg_color
		else:
			clear_color = Color.gray
	if Global.clear_color_from == Global.ColorFrom.THEME:
		VisualServer.set_default_clear_color(clear_color)
	else:
		VisualServer.set_default_clear_color(Global.modulate_clear_color)


func change_icon_colors() -> void:
	for node in get_tree().get_nodes_in_group("UIButtons"):
		if node is TextureButton:
			node.modulate = Global.modulate_icon_color
			if node.disabled and not ("RestoreDefaultButton" in node.name):
				node.modulate.a = 0.5
		elif node is Button:
			var texture: TextureRect
			for child in node.get_children():
				if child is TextureRect and child.name != "Background":
					texture = child
					break

			if texture:
				texture.modulate = Global.modulate_icon_color
				if node.disabled:
					texture.modulate.a = 0.5
		elif node is TextureRect or node is Sprite:
			node.modulate = Global.modulate_icon_color
