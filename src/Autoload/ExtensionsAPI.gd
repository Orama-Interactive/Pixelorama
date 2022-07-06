# gdlint: ignore=max-public-methods
extends Node

enum { FILE, EDIT, SELECT, IMAGE, VIEW, WINDOW, HELP }


func get_current_project() -> Project:
	return Global.current_project


func dialog_open(open: bool) -> void:
	Global.dialog_open(open)


func get_extensions_node() -> Node:
	return Global.control.get_node("Extensions")


func get_config_file() -> ConfigFile:
	return Global.config_cache


func get_canvas() -> Canvas:
	return Global.canvas


func _get_popup_menu(menu_type: int) -> PopupMenu:
	match menu_type:
		FILE:
			return Global.top_menu_container.file_menu_button.get_popup()
		EDIT:
			return Global.top_menu_container.edit_menu_button.get_popup()
		SELECT:
			return Global.top_menu_container.select_menu_button.get_popup()
		IMAGE:
			return Global.top_menu_container.image_menu_button.get_popup()
		VIEW:
			return Global.top_menu_container.view_menu_button.get_popup()
		WINDOW:
			return Global.top_menu_container.window_menu_button.get_popup()
		HELP:
			return Global.top_menu_container.help_menu_button.get_popup()
	return null


func add_menu_item(menu_type: int, item_name: String, item_metadata, item_id := -1) -> int:
	var image_menu: PopupMenu = _get_popup_menu(menu_type)
	if not image_menu:
		return -1
	image_menu.add_item(item_name, item_id)
	var idx := item_id
	if item_id == -1:
		idx = image_menu.get_item_count() - 1
	image_menu.set_item_metadata(idx, item_metadata)

	return idx


func remove_menu_item(menu_type: int, item_idx: int) -> void:
	var image_menu: PopupMenu = _get_popup_menu(menu_type)
	if not image_menu:
		return
	image_menu.remove_item(item_idx)


func add_tool(
	tool_name: String,
	display_name: String,
	shortcut: String,
	scene: PackedScene,
	extra_hint := "",
	extra_shortucts := []
) -> void:
	var tool_class := Tools.Tool.new(
		tool_name, display_name, shortcut, scene, extra_hint, extra_shortucts
	)
	Tools.tools[tool_name] = tool_class
	Tools.add_tool_button(tool_class)


func remove_tool(tool_name: String) -> void:
	var tool_class: Tools.Tool = Tools.tools[tool_name]
	if tool_class:
		Tools.remove_tool(tool_class)


func add_theme(theme: Theme) -> void:
	var themes: BoxContainer = Global.preferences_dialog.find_node("Themes")
	themes.themes.append(theme)
	themes.add_theme(theme)


func get_theme() -> Theme:
	return Global.control.theme


func remove_theme(theme: Theme) -> void:
	Global.preferences_dialog.themes.remove_theme(theme)
