extends Node

var theme_button_group := ButtonGroup.new()

@onready var buttons_container: BoxContainer = $ThemeButtons
@onready var colors_container: BoxContainer = $ThemeColors
@onready var theme_color_preview_scene := preload("res://src/Preferences/ThemeColorPreview.tscn")


func _ready() -> void:
	Themes.theme_added.connect(_add_theme)
	Themes.theme_removed.connect(_remove_theme)
	for theme in Themes.themes:
		_add_theme(theme)
	buttons_container.get_child(Themes.theme_index).button_pressed = true


func _on_theme_pressed(index: int) -> void:
	Themes.change_theme(index)


func _add_theme(theme: Theme) -> void:
	var button := CheckBox.new()
	var theme_name := theme.resource_name
	button.name = theme_name
	button.text = theme_name
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.button_group = theme_button_group
	buttons_container.add_child(button)
	button.pressed.connect(_on_theme_pressed.bind(button.get_index()))

	var panel_stylebox: StyleBox = theme.get_stylebox("panel", "Panel")
	var panel_container_stylebox: StyleBox = theme.get_stylebox("panel", "PanelContainer")
	if panel_stylebox is StyleBoxFlat and panel_container_stylebox is StyleBoxFlat:
		var theme_color_preview: ColorRect = theme_color_preview_scene.instantiate()
		var color1: Color = panel_stylebox.bg_color
		var color2: Color = panel_container_stylebox.bg_color
		theme_color_preview.get_child(0).get_child(0).color = color1
		theme_color_preview.get_child(0).get_child(1).color = color2
		colors_container.add_child(theme_color_preview)


func _remove_theme(theme: Theme) -> void:
	var index := Themes.themes.find(theme)
	var theme_button := buttons_container.get_child(index)
	var color_previews := colors_container.get_child(index)
	buttons_container.remove_child(theme_button)
	theme_button.queue_free()
	colors_container.remove_child(color_previews)
	color_previews.queue_free()
