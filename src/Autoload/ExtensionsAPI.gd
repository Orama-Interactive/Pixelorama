extends Node

# legacy enum (This is DEPRECATED and will not be in newer versions)
enum { FILE, EDIT, SELECT, IMAGE, VIEW, WINDOW, HELP }

# use these variables in your extension to access the api
var general := GeneralAPI.new()
var menu := MenuAPI.new()
var dialog := DialogAPI.new()
var panel := PanelAPI.new()
var theme := ThemeAPI.new()
var tools := ToolAPI.new()
var project := ProjectAPI.new()
var exports := ExportAPI.new()
var signals := SignalsAPI.new()

# This fail-safe below is designed to work ONLY if Pixelorama is launched in Godot Editor
var _action_history: Dictionary = {}


func check_sanity(extension_name: String):
	if extension_name in _action_history.keys():
		var extension_history = _action_history[extension_name]
		if extension_history != []:
			var error_msg = str(
				"Extension: ",
				extension_name,
				" contains actons: ",
				extension_history,
				" which are not removed properly"
			)
			print(error_msg)


func clear_history(extension_name: String):
	if extension_name in _action_history.keys():
		_action_history.erase(extension_name)


func add_action(action: String):
	var extension_name = _get_caller_extension_name()
	if extension_name != "Unknown":
		if extension_name in _action_history.keys():
			var extension_history: Array = _action_history[extension_name]
			extension_history.append(action)
		else:  # If the extension history doesn't exist yet, create it
			_action_history[extension_name] = [action]


func remove_action(action: String):
	var extension_name = _get_caller_extension_name()
	if extension_name != "Unknown":
		if extension_name in _action_history.keys():
			_action_history[extension_name].erase(action)


func wait_frame():  # as yield is not available to classes below, so this is the solution
	# use by yield(ExtensionsApi.wait_frame(), "completed")
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")


func _get_caller_extension_name() -> String:
	var stack = get_stack()
	for trace in stack:
		# Get extension name that called the action
		var arr: Array = trace["source"].split("/")
		var idx = arr.find("Extensions")
		if idx != -1:
			return arr[idx + 1]
	return "Unknown"


func _exit_tree():
	for keys in _action_history.keys():
		check_sanity(keys)


# The Api Methods Start Here
func get_api_version() -> int:
	return ProjectSettings.get_setting("application/config/ExtensionsAPI_Version")


class GeneralAPI:
	# Version And Config
	func get_pixelorama_version() -> String:
		return ProjectSettings.get_setting("application/config/Version")

	func get_config_file() -> ConfigFile:
		return Global.config_cache

	# Nodes
	func get_global() -> Global:
		return Global

	func get_drawing_algos() -> DrawingAlgos:
		return DrawingAlgos

	func get_shader_image_effect() -> ShaderImageEffect:
		return ShaderImageEffect.new()

	func get_extensions_node() -> Node:
		# node where the nodes listed in "nodes" from extension.json gets placed
		return Global.control.get_node("Extensions")

	func get_canvas() -> Canvas:
		return Global.canvas


class MenuAPI:
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
		ExtensionsApi.add_action("add_menu")
		return idx

	func remove_menu_item(menu_type: int, item_idx: int) -> void:
		var popup_menu: PopupMenu = _get_popup_menu(menu_type)
		if not popup_menu:
			return
		popup_menu.remove_item(item_idx)
		ExtensionsApi.remove_action("add_menu")


class DialogAPI:
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
	func set_tabs_visible(visible: bool) -> void:
		var dockable := _get_dockable_container_ui()
		dockable.set_tabs_visible(visible)

	func get_tabs_visible() -> bool:
		var dockable := _get_dockable_container_ui()
		return dockable.get_tabs_visible()

	func add_node_as_tab(node: Node) -> void:
		var dockable := _get_dockable_container_ui()
		var top_menu_container = Global.top_menu_container
		var panels_submenu: PopupMenu = top_menu_container.panels_submenu
		# adding the node to the first tab we find, it'll be re-ordered by layout anyway
		var tabs = _get_tabs_in_root(dockable.layout.root)
		if tabs.size() != 0:
			dockable.add_child(node)
			tabs[0].insert_node(0, node)  # Insert at the beginning
		else:
			push_error("No tabs found!")
			return
		top_menu_container.ui_elements.append(node)
		# refreshing Panels submenu
		var new_elements = top_menu_container.ui_elements
		panels_submenu.clear()
		for element in new_elements:
			panels_submenu.add_check_item(element.name)
			var is_hidden: bool = dockable.is_control_hidden(element)
			panels_submenu.set_item_checked(new_elements.find(element), !is_hidden)
		# re-assigning layout
		top_menu_container.set_layout(top_menu_container.selected_layout)
		# we must make tabs_visible = true for a few moments if it is false
		if dockable.tabs_visible == false:
			dockable.tabs_visible = true
			yield(ExtensionsApi.wait_frame(), "completed")
			dockable.tabs_visible = false
		ExtensionsApi.add_action("add_tab")

	func remove_node_from_tab(node: Node) -> void:
		var top_menu_container = Global.top_menu_container
		var dockable = Global.control.find_node("DockableContainer")
		var panels_submenu: PopupMenu = top_menu_container.panels_submenu
		# find the tab that contains the node
		if node == null:
			return
		var tab = _find_tab_with_node(node.name, dockable)
		if not tab:
			push_error("Tab not found")
			return
		# remove node from that tab
		tab.remove_node(node)
		node.get_parent().remove_child(node)
		top_menu_container.ui_elements.erase(node)
		node.queue_free()
		# refreshing Panels submenu
		var new_elements = top_menu_container.ui_elements
		panels_submenu.clear()
		for element in new_elements:
			panels_submenu.add_check_item(element.name)
			var is_hidden: bool = dockable.is_control_hidden(element)
			panels_submenu.set_item_checked(new_elements.find(element), !is_hidden)
		# we must make tabs_visible = true for a few moments if it is false
		if dockable.tabs_visible == false:
			dockable.tabs_visible = true
			yield(ExtensionsApi.wait_frame(), "completed")
			dockable.tabs_visible = false
		ExtensionsApi.remove_action("add_tab")

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

	func _get_tabs_in_root(parent_resource) -> Array:
		var parents := []  # Resources have no get_parent_resource() so this is an alternative
		var scanned := []  # To keep track of already discovered layout_split resources
		var child_number := 0
		parents.append(parent_resource)
		var scan_target = parent_resource
		var tabs := []
		# Get children in the parent, the initial parent is the node we entered as "parent"
		while child_number < 2:
			# If parent isn't a (layout_split) resource then there is no point
			# in continuing (this is just a sanity check and should always pass)
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
		return tabs


class ThemeAPI:
	func add_theme(theme: Theme) -> void:
		var themes: BoxContainer = Global.preferences_dialog.find_node("Themes")
		themes.themes.append(theme)
		themes.add_theme(theme)
		ExtensionsApi.add_action("add_theme")

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
		ExtensionsApi.remove_action("add_theme")


class ToolAPI:
	# Tool methods
	func add_tool(
		tool_name: String,
		display_name: String,
		shortcut: String,
		scene: PackedScene,
		extra_hint := "",
		extra_shortucts := [],
		layer_types: PoolIntArray = []
	) -> void:
		var tool_class := Tools.Tool.new(
			tool_name, display_name, shortcut, scene, layer_types, extra_hint, extra_shortucts
		)
		Tools.tools[tool_name] = tool_class
		Tools.add_tool_button(tool_class)
		ExtensionsApi.add_action("add_tool")

	func remove_tool(tool_name: String) -> void:
		# Re-assigning the tools in case the tool to be removed is also active
		Tools.assign_tool("Pencil", BUTTON_LEFT)
		Tools.assign_tool("Eraser", BUTTON_RIGHT)
		var tool_class: Tools.Tool = Tools.tools[tool_name]
		if tool_class:
			Tools.remove_tool(tool_class)
		ExtensionsApi.remove_action("add_tool")


class ProjectAPI:
	func get_current_project() -> Project:
		return Global.current_project

	func get_project_info(project: Project) -> Dictionary:
		return project.serialize()

	func get_current_cel() -> BaseCel:
		return get_current_project().get_current_cel()

	func get_cel_at(project: Project, frame: int, layer: int) -> BaseCel:
		# frames from left to right, layers from bottom to top
		clamp(frame, 0, project.frames.size() - 1)
		clamp(layer, 0, project.layers.size() - 1)
		return project.frames[frame].cels[layer]

	func set_pixelcel_image(image: Image, frame: int, layer: int) -> void:
		# frames from left to right, layers from bottom to top
		if get_cel_at(get_current_project(), frame, layer).get_class_name() == "PixelCel":
			OpenSave.open_image_at_cel(image, layer, frame)
		else:
			print("cel at frame ", frame, ", layer ", layer, " is not a PixelCel")


class ExportAPI:
	# gdlint: ignore=class-variable-name
	var ExportTab := Export.ExportTab

	func add_export_option(
		format_info: Dictionary, exporter_generator, tab := ExportTab.IMAGE, is_animated := true
	) -> int:
		# separate enum name and file name
		var extension = ""
		var format_name = ""
		if format_info.has("extension"):
			extension = format_info["extension"]
		if format_info.has("description"):
			format_name = format_info["description"].to_upper().replace(" ", "_")
		# change format name if another one uses the same name
		for i in range(Export.FileFormat.size()):
			var test_name = format_name
			if i != 0:
				test_name = str(test_name, "_", i)
			if !Export.FileFormat.keys().has(test_name):
				format_name = test_name
				break
		#  add to FileFormat enum
		var id := Export.FileFormat.size()
		for i in Export.FileFormat.size():  # use an empty id if it's available
			if !Export.FileFormat.values().has(i):
				id = i
		Export.FileFormat.merge({format_name: id})
		#  add exporter generator
		Export.custom_exporter_generators.merge({id: [exporter_generator, extension]})
		#  add to animated (or not)
		if is_animated:
			Export.animated_formats.append(id)
		#  add to export dialog
		match tab:
			ExportTab.IMAGE:
				Global.export_dialog.image_exports.append(id)
			ExportTab.SPRITESHEET:
				Global.export_dialog.spritesheet_exports.append(id)
			_:  # Both
				Global.export_dialog.image_exports.append(id)
				Global.export_dialog.spritesheet_exports.append(id)
		ExtensionsApi.add_action("add_exporter")
		return id

	func remove_export_option(id: int):
		if Export.custom_exporter_generators.has(id):
			# remove enum
			Export.remove_file_format(id)
			# remove exporter generator
			Export.custom_exporter_generators.erase(id)
			#  remove from animated (or not)
			Export.animated_formats.erase(id)
			#  add to export dialog
			Global.export_dialog.image_exports.erase(id)
			Global.export_dialog.spritesheet_exports.erase(id)
			ExtensionsApi.remove_action("add_exporter")


class SignalsAPI:
	# system to auto-adjust texture_changed to the "current cel"
	signal texture_changed
	var _last_cel: BaseCel

	func _init() -> void:
		Global.connect("project_changed", self, "_update_texture_signal")
		Global.connect("cel_changed", self, "_update_texture_signal")

	func _update_texture_signal():
		if _last_cel:
			_last_cel.disconnect("texture_changed", self, "_on_texture_changed")
		if Global.current_project:
			_last_cel = Global.current_project.get_current_cel()
			_last_cel.connect("texture_changed", self, "_on_texture_changed")

	func _on_texture_changed():
		emit_signal("texture_changed")

	# Global signals
	func connect_project_changed(target: Object, method: String):
		Global.connect("project_changed", target, method)
		ExtensionsApi.add_action("project_changed")

	func disconnect_project_changed(target: Object, method: String):
		Global.disconnect("project_changed", target, method)
		ExtensionsApi.remove_action("project_changed")

	func connect_cel_changed(target: Object, method: String):
		Global.connect("cel_changed", target, method)
		ExtensionsApi.add_action("cel_changed")

	func disconnect_cel_changed(target: Object, method: String):
		Global.disconnect("cel_changed", target, method)
		ExtensionsApi.remove_action("cel_changed")

	# Tool Signal
	func connect_tool_color_changed(target: Object, method: String):
		Tools.connect("color_changed", target, method)
		ExtensionsApi.add_action("color_changed")

	func disconnect_tool_color_changed(target: Object, method: String):
		Tools.disconnect("color_changed", target, method)
		ExtensionsApi.remove_action("color_changed")

	# updater signals
	func connect_current_cel_texture_changed(target: Object, method: String):
		connect("texture_changed", target, method)
		ExtensionsApi.add_action("texture_changed")

	func disconnect_current_cel_texture_changed(target: Object, method: String):
		disconnect("texture_changed", target, method)
		ExtensionsApi.remove_action("texture_changed")


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func get_pixelorama_version() -> String:
	return general.get_pixelorama_version()


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func dialog_open(open: bool) -> void:
	dialog.dialog_open(open)


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func get_current_project() -> Project:
	return project.get_current_project()


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func get_global() -> Global:
	return general.get_global()


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func get_extensions_node() -> Node:
	return general.get_extensions_node()


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func get_dockable_container_ui() -> Node:
	# gdlint:ignore = private-method-call
	return panel._get_dockable_container_ui()


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func get_config_file() -> ConfigFile:
	return general.get_config_file()


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func get_canvas() -> Canvas:
	return general.get_canvas()


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func get_dialogs_parent_node() -> Node:
	return dialog.get_dialogs_parent_node()


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func add_node_as_tab(node: Node, _alongside_node: String) -> void:
	panel.add_node_as_tab(node)


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func remove_node_from_tab(node: Node) -> void:
	panel.remove_node_from_tab(node)


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func add_menu_item(menu_type: int, item_name: String, item_metadata, item_id := -1) -> int:
	var idx = menu.add_menu_item(menu_type, item_name, item_metadata, item_id)
	return idx


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func remove_menu_item(menu_type: int, item_idx: int) -> void:
	menu.remove_menu_item(menu_type, item_idx)


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func add_tool(
	tool_name: String,
	display_name: String,
	shortcut: String,
	scene: PackedScene,
	extra_hint := "",
	extra_shortucts := []
) -> void:
	tools.add_tool(
		tool_name, display_name, shortcut, scene, extra_hint, extra_shortucts, PoolIntArray()
	)


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func remove_tool(tool_name: String) -> void:
	tools.remove_tool(tool_name)


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func add_theme(theme_res: Theme) -> void:
	theme.add_theme(theme_res)


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func find_theme_index(theme_res: Theme) -> int:
	return theme.find_theme_index(theme_res)


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func get_theme() -> Theme:
	return theme.get_theme()


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func set_theme(idx: int) -> bool:
	return theme.set_theme(idx)


# legacy method (The methods is DEPRECATED and will not be in newer versions)
func remove_theme(theme_res: Theme) -> void:
	theme.remove_theme(theme_res)
