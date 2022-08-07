# gdlint: ignore=max-public-methods
extends Node

enum { FILE, EDIT, SELECT, IMAGE, VIEW, WINDOW, HELP }


func dialog_open(open: bool) -> void:
	Global.dialog_open(open)


func get_current_project() -> Project:
	return Global.current_project


func get_global() -> Global:
	return Global


func get_extensions_node() -> Node:
	return Global.control.get_node("Extensions")


func get_dockable_container_ui() -> Node:
	return Global.control.find_node("DockableContainer")


func get_config_file() -> ConfigFile:
	return Global.config_cache


func get_canvas() -> Canvas:
	return Global.canvas


func get_dialogs_parent_node() -> Node:
	return Global.control.get_node("Dialogs")


# Dockable container methods
# Adds a node as a tab next to an already existing panel to the dockable container
func add_node_as_tab(node: Node, alongside_node: String) -> void:
	var dockable := get_dockable_container_ui()
	dockable.add_child(node)
	var tab = _find_tab_with_node(alongside_node, dockable)
	if not tab:
		push_error("Tab not found")
		return

	tab.insert_node(0, node)  # Insert at the beginning
	if !dockable.get_tabs_visible():
		dockable.set_tabs_visible(true)
		# A hacky way to fix tabs that sometimes are not visible when an extension is loaded
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
		dockable.set_tabs_visible(false)


# Removes a node from the dockable container
func remove_node_from_tab(node: Node) -> void:
	var dockable = Global.control.find_node("DockableContainer")
	var tab = _find_tab_with_node(node.name, dockable)
	if not tab:
		push_error("Tab not found")
		return
	tab.remove_node(node)
	node.get_parent().remove_child(node)
	node.queue_free()


func _find_tab_with_node(node_name: String, dockable_container):
	var root = dockable_container.layout.root
	var tabs = _get_tabs_in_root(root)
	for tab in tabs:
		var idx = tab.find_name(node_name)
		if idx != -1:
			return tab
	return null


# Returns all existing tabs inside Split resource
func _get_tabs_in_root(parent_resource):
	var parents := []  # Resources have no get_parent_resource() so this is an alternative
	var scanned := []  # To keep track of already discovered layout_split resources
	var child_number := 0
	parents.append(parent_resource)
	var scan_target = parent_resource

	var tabs := []

	# Get children in the parent, the initial parent is the node we entered as "parent"
	while child_number < 2:
		# If parent isn't a (layout_split) resource then there is no point
		# in continuing (This is just a Sanity Check and should always pass)
		if !scan_target.has_method("get_first"):
			break

		var child_resource
		if child_number == 0:
			child_resource = scan_target.get_first()  # First child
		elif child_number == 1:
			child_resource = scan_target.get_second()  # Second child

		# If the child resource is a tab and it wasn't discovered before, add it to "paths"
		if child_resource.has_method("get_current_tab"):
			if !tabs.has(child_resource):
				tabs.append(child_resource)
		# If "child_resource" is another layout_split resource then we need to scan it too
		elif child_resource.has_method("get_first") and !scanned.has(child_resource):
			scanned.append(child_resource)
			parents.append(child_resource)
			scan_target = parents[-1]  # Set this as the next scan target
			# Reset child_number by setting it to -1, because later it will
			# get added by "child_number += 1" to make it 0
			child_number = -1
		child_number += 1
		# If we have reached the bottom, then make the child's parent as
		# the next parent and move on to the next child in the parent
		if child_number == 2:
			scan_target = parents.pop_back()
			child_number = 0
			# If there is no parent left to get scanned
			if scan_target == null:
				return tabs


# Menu methods
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
	var popup_menu: PopupMenu = _get_popup_menu(menu_type)
	if not popup_menu:
		return -1
	popup_menu.add_item(item_name, item_id)
	var idx := item_id
	if item_id == -1:
		idx = popup_menu.get_item_count() - 1
	popup_menu.set_item_metadata(idx, item_metadata)

	return idx


func remove_menu_item(menu_type: int, item_idx: int) -> void:
	var popup_menu: PopupMenu = _get_popup_menu(menu_type)
	if not popup_menu:
		return
	popup_menu.remove_item(item_idx)


# Tool methods
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


# Theme methods
func add_theme(theme: Theme) -> void:
	var themes: BoxContainer = Global.preferences_dialog.find_node("Themes")
	themes.themes.append(theme)
	themes.add_theme(theme)


func find_theme(theme :Theme) -> int:
	var themes: BoxContainer = Global.preferences_dialog.find_node("Themes")
	return themes.themes.find(theme)


func get_theme() -> Theme:
	return Global.control.theme


func set_theme(idx: int) -> int:
	var themes: BoxContainer = Global.preferences_dialog.find_node("Themes")
	if idx >= 0 and idx < themes.themes.size():
		themes.buttons_container.get_child(idx).emit_signal("pressed")
		return OK
	else:
		return -1


func remove_theme(theme: Theme) -> void:
	Global.preferences_dialog.themes.remove_theme(theme)
