# gdlint: ignore=max-public-methods
extends Node


func get_api_version() -> int:
	return ProjectSettings.get_setting("application/config/ExtensionsAPI_Version")


class GeneralAPI:
	extends Resource

	# Version And Config
	func get_pixelorama_version() -> String:
		return ProjectSettings.get_setting("application/config/Version")

	func get_config_file() -> ConfigFile:
		return Global.config_cache

	# Nodes
	func get_global() -> Global:
		return Global

	func get_extensions_node() -> Node:
		return Global.control.get_node("Extensions")

	func get_canvas() -> Canvas:
		return Global.canvas


class MenuAPI:
	extends Resource

	enum { FILE, EDIT, SELECT, IMAGE, VIEW, WINDOW, HELP }

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
		# item_metadata is usually a popup node you want to appear when you click the item_name
		# that popup should also have an (menu_item_clicked) function inside it's script
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


class DialogAPI:
	extends Resource

	func show_error(text: String) -> void:
		# useful for displaying messages like "Incompatible API" etc...
		Global.error_dialog.set_text(text)
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)

	func get_dialogs_parent_node() -> Node:
		return Global.control.get_node("Dialogs")

	func dialog_open(open: bool) -> void:
		Global.dialog_open(open)


class PanelAPI:
	extends Resource

	func set_tabs_visible(visible: bool) -> void:
		var dockable := _get_dockable_container_ui()
		dockable.set_tabs_visible(visible)

	func get_tabs_visible() -> bool:
		var dockable := _get_dockable_container_ui()
		return dockable.get_tabs_visible()

	func add_node_as_tab(node: Node, alongside_node: String) -> void:
		var dockable := _get_dockable_container_ui()
		dockable.add_child(node)
		var tab = _find_tab_with_node(alongside_node, dockable)
		if not tab:
			push_error("Tab not found")
			return
		tab.insert_node(0, node)  # Insert at the beginning
		# INSTRUCTION
		# After this check if tabs are invisible, if they are, then make tabs visible
		# and after doing yield(get_tree(), "idle_frame") twice make them invisible again

	func remove_node_from_tab(node: Node) -> void:
		if node == null:
			return
		var dockable = Global.control.find_node("DockableContainer")
		var tab = _find_tab_with_node(node.name, dockable)
		if not tab:
			push_error("Tab not found")
			return
		tab.remove_node(node)
		node.get_parent().remove_child(node)
		node.queue_free()

	# PRIVATE METHODS
	func _get_dockable_container_ui() -> Node:
		return Global.control.find_node("DockableContainer")

	func _find_tab_with_node(node_name: String, dockable_container):
		var root = dockable_container.layout.root
		var tabs = _get_tabs_in_root(root)
		for tab in tabs:
			var idx = tab.find_name(node_name)
			if idx != -1:
				return tab
		return null

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


class ThemeApi:
	extends Resource

	func add_theme(theme: Theme) -> void:
		var themes: BoxContainer = Global.preferences_dialog.find_node("Themes")
		themes.themes.append(theme)
		themes.add_theme(theme)

	func find_theme_index(theme: Theme) -> int:
		var themes: BoxContainer = Global.preferences_dialog.find_node("Themes")
		return themes.themes.find(theme)

	func get_theme() -> Theme:
		return Global.control.theme

	func set_theme(idx: int) -> bool:
		var themes: BoxContainer = Global.preferences_dialog.find_node("Themes")
		if idx >= 0 and idx < themes.themes.size():
			themes.buttons_container.get_child(idx).emit_signal("pressed")
			return true
		else:
			return false

	func remove_theme(theme: Theme) -> void:
		Global.preferences_dialog.themes.remove_theme(theme)


class ToolAPI:
	extends Resource

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
		# Re-assigning the tools in case the tool to be removed is also Active
		Tools.assign_tool("Pencil", BUTTON_LEFT)
		Tools.assign_tool("Eraser", BUTTON_RIGHT)
		var tool_class: Tools.Tool = Tools.tools[tool_name]
		if tool_class:
			Tools.remove_tool(tool_class)


class ProjectAPI:
	extends Resource

	func get_current_project() -> Project:
		return Global.current_project

	func get_current_cel_info() -> Dictionary:
		# As types of cel are added to Pixelorama,
		# then the old extension would have no idea how to identify the types they use
		# E.g the extension may try to use a GroupCel as a PixelCel (if it doesn't know the difference)
		# So it's encouraged to use this function to access cels
		var project = get_current_project()
		var cel = project.get_current_cel()
		# Add cel types as we have more and more cels
		if cel is PixelCel:
			return {"cel": cel, "type": "PixelCel"}
		elif cel is GroupCel:
			return {"cel": cel, "type": "GroupCel"}
		else:
			return {"cel": cel, "type": "BaseCel"}
