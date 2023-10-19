extends Node
# NOTE: Type "ExtensionsApi" in Search Help to read the curated documentation of the Api

## The Official ExtensionAPI for pixelorama.
##
## This Api gives you the essentials eo develop a working extension for Pixelorama.[br]
## The Api consists of many smaller Apis, each giving access to different areas of the Software.
## [br][br]
## Keep in mind that this API is targeted towards users who are not fully familiar with Pixelorama's
## source code. If you need to do something more complicated and more low-level, you would need to
## interact directly with the source code.
##
## @tutorial(Add Tutorial here):            https://the/tutorial1/url.com

## Gives access to the general, app related functions of pixelorama itself
## such as Autoloads, Software Version, Config file etc...
var general := GeneralAPI.new()
## Gives ability to add/remove items from menus in the top bar.
var menu := MenuAPI.new()
## Gives access to Dialog related functions.
var dialog := DialogAPI.new()
## Gives access to Tabs and Dockable Container related functions.
var panel := PanelAPI.new()
## Gives access to theme related functions.
var theme := ThemeAPI.new()
## Gives ability to add/remove tools.
var tools := ToolAPI.new()
## Gives access to pixelorama's selection system.
var selection := SelectionAPI.new()
## Gives access to project manipulation.
var project := ProjectAPI.new()
## Gives access to adding custom exporters.
var exports := ExportAPI.new()
## Gives access to the basic commonly used signals.
## Some less common signals are not mentioned in api but could be accessed through source directly.
var signals := SignalsAPI.new()

## This fail-safe below is designed to work ONLY if Pixelorama is launched in Godot Editor
var _action_history: Dictionary = {}


## [code]This function is used internally and not meant to be used by extensions.[/code]
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


## [code]This function is used internally and not meant to be used by extensions.[/code]
func clear_history(extension_name: String):
	if extension_name in _action_history.keys():
		_action_history.erase(extension_name)


## [code]This function is used internally and not meant to be used by extensions.[/code]
func add_action(action: String):
	var extension_name = _get_caller_extension_name()
	if extension_name != "Unknown":
		if extension_name in _action_history.keys():
			var extension_history: Array = _action_history[extension_name]
			extension_history.append(action)
		else:  # If the extension history doesn't exist yet, create it
			_action_history[extension_name] = [action]


## [code]This function is used internally and not meant to be used by extensions.[/code]
func remove_action(action: String):
	var extension_name = _get_caller_extension_name()
	if extension_name != "Unknown":
		if extension_name in _action_history.keys():
			_action_history[extension_name].erase(action)


## [code]This function is used internally and not meant to be used by extensions.[/code]
func wait_frame():  # as yield is not available to classes below, so this is the solution
	# use by yield(ExtensionsApi.wait_frame(), "completed")
	await get_tree().process_frame
	await get_tree().process_frame


func _get_caller_extension_name() -> String:
	var stack := get_stack()
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
## Returns the version of the ExtensionsApi.
func get_api_version() -> int:
	return ProjectSettings.get_setting("application/config/ExtensionsAPI_Version")


## Gives Access to the general stuff.
##
## This part of Api provides stuff like commonly used Autoloads, App's version info etc
## the most basic (but important) stuff.
class GeneralAPI:
	## Returns the current version of pixelorama.
	func get_pixelorama_version() -> String:
		return ProjectSettings.get_setting("application/config/Version")

	## Returns the [ConfigFile] contains all the settings (Brushes, sizes, preferences, etc...).
	func get_config_file() -> ConfigFile:
		return Global.config_cache

	## Returns the Global autoload used by Pixelorama.[br]
	## Contains references to almost all UI Elements, Variables that indicate different
	## settings etc..., In short it is the most important autoload of Pixelorama.
	func get_global() -> Global:
		return Global

	## Returns the DrawingAlgos autoload, contains different drawing algorithms used by Pixelorama.
	func get_drawing_algos() -> DrawingAlgos:
		return DrawingAlgos

	## Gives you a new ShaderImageEffect class. this class can apply shader to an image.[br]
	## It contains method:
	## [code]generate_image(img: Image, shader: Shader, params: Dictionary, size: Vector2)[/code]
	## [br]Whose parameters are identified as:
	## [br][param img] --> image that the shader will be pasted to (Empty Image of size same as
	## project).
	## [br][param shader] --> preload of the shader.
	## [br][param params] --> a dictionary of params used by the shader.
	## [br][param size] --> It is the project's size.
	func get_new_shader_image_effect() -> ShaderImageEffect:
		return ShaderImageEffect.new()

	## Returns parent of the nodes listed in extension.json -> "nodes".
	func get_extensions_node() -> Node:
		return Global.control.get_node("Extensions")

	## Returns the main [code]Canvas[/code] node,
	## normally used to add a custom preview to the canvas.
	func get_canvas() -> Canvas:
		return Global.canvas


## Gives ability to add/remove items from menus in the top bar.
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

	## Adds a menu item of title [param item_name] to the [param menu_type] defined by
	## [enum @unnamed_enums].
	## [br][param item_metadata] is usually a window node you want to appear when you click the
	## [param item_name]. That window node should also have a [param menu_item_clicked]
	## function inside its script.[br]
	## Index of the added item is returned (which can be used to remove menu item later on).
	func add_menu_item(menu_type: int, item_name: String, item_metadata, item_id := -1) -> int:
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

	## Removes a menu item at index [param item_idx] from the [param menu_type] defined by
	## [enum @unnamed_enums].
	func remove_menu_item(menu_type: int, item_idx: int) -> void:
		var popup_menu: PopupMenu = _get_popup_menu(menu_type)
		if not popup_menu:
			return
		popup_menu.remove_item(item_idx)
		ExtensionsApi.remove_action("add_menu")


## Gives access to common dialog related functions.
class DialogAPI:
	## Shows an alert dialog with the given [param text]
	## Useful for displaying messages like "Incompatible API" etc...
	func show_error(text: String) -> void:
		Global.error_dialog.set_text(text)
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)

	## Returns the node that is the parent of dialogs used in pixelorama.
	func get_dialogs_parent_node() -> Node:
		return Global.control.get_node("Dialogs")

	## Tells pixelorama that some dialog is about to open or close.
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
			await ExtensionsApi.wait_frame()
			dockable.tabs_visible = false
		ExtensionsApi.add_action("add_tab")

	func remove_node_from_tab(node: Node) -> void:
		var top_menu_container = Global.top_menu_container
		var dockable = Global.control.find_child("DockableContainer")
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
			await ExtensionsApi.wait_frame()
			dockable.tabs_visible = false
		ExtensionsApi.remove_action("add_tab")

	# PRIVATE METHODS
	func _get_dockable_container_ui() -> Node:
		return Global.control.find_child("DockableContainer")

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
		var themes: BoxContainer = Global.preferences_dialog.find_child("Themes")
		themes.themes.append(theme)
		themes.add_theme(theme)
		ExtensionsApi.add_action("add_theme")

	func find_theme_index(theme: Theme) -> int:
		var themes: BoxContainer = Global.preferences_dialog.find_child("Themes")
		return themes.themes.find(theme)

	func get_theme() -> Theme:
		return Global.control.theme

	func set_theme(idx: int) -> bool:
		var themes: BoxContainer = Global.preferences_dialog.find_child("Themes")
		if idx >= 0 and idx < themes.themes.size():
			themes.buttons_container.get_child(idx).pressed.emit()
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
		scene: String,
		extra_hint := "",
		extra_shortucts := [],
		layer_types: PackedInt32Array = []
	) -> void:
		var tool_class := Tools.Tool.new(
			tool_name, display_name, shortcut, scene, layer_types, extra_hint, extra_shortucts
		)
		Tools.tools[tool_name] = tool_class
		Tools.add_tool_button(tool_class)
		ExtensionsApi.add_action("add_tool")

	func remove_tool(tool_name: String) -> void:
		# Re-assigning the tools in case the tool to be removed is also active
		Tools.assign_tool("Pencil", MOUSE_BUTTON_LEFT)
		Tools.assign_tool("Eraser", MOUSE_BUTTON_RIGHT)
		var tool_class: Tools.Tool = Tools.tools[tool_name]
		if tool_class:
			Tools.remove_tool(tool_class)
		ExtensionsApi.remove_action("add_tool")


class SelectionAPI:
	func clear_selection() -> void:
		Global.canvas.selection.clear_selection(true)

	func select_all() -> void:
		Global.canvas.selection.select_all()

	func select_rect(rect: Rect2i, operation := 0) -> void:
		# 0 for adding, 1 for subtracting, 2 for intersection
		Global.canvas.selection.transform_content_confirm()
		var undo_data_tmp = Global.canvas.selection.get_undo_data(false)
		Global.canvas.selection.select_rect(rect, operation)
		Global.canvas.selection.commit_undo("Select", undo_data_tmp)

	func move_selection(destination: Vector2, with_content := true, transform_standby := false):
		if not with_content:
			Global.canvas.selection.transform_content_confirm()
			Global.canvas.selection.move_borders_start()
		else:
			Global.canvas.selection.transform_content_start()
		var rel_direction = destination - Global.canvas.selection.big_bounding_rectangle.position
		Global.canvas.selection.move_content(rel_direction.floor())
		Global.canvas.selection.move_borders_end()
		if not transform_standby and with_content:
			Global.canvas.selection.transform_content_confirm()

	func resize_selection(new_size: Vector2, with_content := true, transform_standby := false):
		if not with_content:
			Global.canvas.selection.transform_content_confirm()
			Global.canvas.selection.move_borders_start()
		else:
			Global.canvas.selection.transform_content_start()
		Global.canvas.selection.big_bounding_rectangle.size = new_size
		Global.canvas.selection.resize_selection()
		Global.canvas.selection.move_borders_end()
		if not transform_standby and with_content:
			Global.canvas.selection.transform_content_confirm()

	func invert() -> void:
		Global.canvas.selection.invert()

	func make_brush() -> void:
		Global.canvas.selection.new_brush()

	func copy() -> void:
		Global.canvas.selection.copy()

	func paste(in_place := false) -> void:
		Global.canvas.selection.paste(in_place)

	func delete_content() -> void:
		Global.canvas.selection.delete()


class ProjectAPI:
	func new_project(
		frames := [],
		name := tr("untitled"),
		size := Vector2(64, 64),
		fill_color := Color.TRANSPARENT
	) -> Project:
		if !name.is_valid_filename():
			name = tr("untitled")
		if size.x <= 0 or size.y <= 0:
			size.x = 1
			size.y = 1
		var new_proj := Project.new(frames, name, size.floor())
		new_proj.layers.append(PixelLayer.new(new_proj))
		new_proj.fill_color = fill_color
		new_proj.frames.append(new_proj.new_empty_frame())
		Global.projects.append(new_proj)
		return new_proj

	func switch_to(project: Project):
		Global.tabs.current_tab = Global.projects.find(project)

	func get_current_project() -> Project:
		return Global.current_project

	func get_project_info(project: Project) -> Dictionary:
		return project.serialize()

	func get_current_cel() -> BaseCel:
		return get_current_project().get_current_cel()

	func get_cel_at(project: Project, frame: int, layer: int) -> BaseCel:
		# frames from left to right, layers from bottom to top
		clampi(frame, 0, project.frames.size() - 1)
		clampi(layer, 0, project.layers.size() - 1)
		return project.frames[frame].cels[layer]

	func set_pixelcel_image(image: Image, frame: int, layer: int) -> void:
		# frames from left to right, layers from bottom to top
		if get_cel_at(get_current_project(), frame, layer).get_class_name() == "PixelCel":
			OpenSave.open_image_at_cel(image, layer, frame)
		else:
			print("cel at frame ", frame, ", layer ", layer, " is not a PixelCel")

	func add_new_frame(after_frame: int):
		var project := Global.current_project
		if after_frame < project.frames.size() and after_frame >= 0:
			var old_current = project.current_frame
			project.current_frame = after_frame  # temporary assignment
			Global.animation_timeline.add_frame()
			project.current_frame = old_current
		else:
			print("invalid (after_frame)")

	func add_new_layer(above_layer: int, name := "", type := Global.LayerTypes.PIXEL):
		# type = 0 --> PixelLayer, type = 1 --> GroupLayer, type = 2 --> 3DLayer
		# above_layer = 0 is the bottom-most layer and so on
		var project = ExtensionsApi.project.get_current_project()
		if above_layer < project.layers.size() and above_layer >= 0:
			var old_current = project.current_layer
			project.current_layer = above_layer  # temporary assignment
			if type >= 0 and type < Global.LayerTypes.size():
				Global.animation_timeline.add_layer(type)
				if name != "":
					project.layers[above_layer + 1].name = name
					var l_idx = Global.layer_vbox.get_child_count() - (above_layer + 2)
					Global.layer_vbox.get_child(l_idx).label.text = name
				project.current_layer = old_current
			else:
				print("invalid (type)")
		else:
			print("invalid (above_layer)")


class ExportAPI:
	# gdlint: ignore=class-variable-name
	var ExportTab := Export.ExportTab

	func add_export_option(
		format_info: Dictionary,
		exporter_generator: Object,
		tab := ExportTab.IMAGE,
		is_animated := true
	) -> int:
		# Separate enum name and file name
		var extension = ""
		var format_name = ""
		if format_info.has("extension"):
			extension = format_info["extension"]
		if format_info.has("description"):
			format_name = format_info["description"].strip_edges().to_upper().replace(" ", "_")
		# Change format name if another one uses the same name
		var existing_format_names = Export.FileFormat.keys() + Export.custom_file_formats.keys()
		for i in range(existing_format_names.size()):
			var test_name = format_name
			if i != 0:
				test_name = str(test_name, "_", i)
			if !existing_format_names.has(test_name):
				format_name = test_name
				break
		# Setup complete, add the exporter
		var id = Export.add_custom_file_format(
			format_name, extension, exporter_generator, tab, is_animated
		)
		ExtensionsApi.add_action("add_exporter")
		return id

	func remove_export_option(id: int):
		if Export.custom_exporter_generators.has(id):
			Export.remove_custom_file_format(id)
			ExtensionsApi.remove_action("add_exporter")


class SignalsAPI:
	# system to auto-adjust texture_changed to the "current cel"
	signal texture_changed
	var _last_cel: BaseCel

	func _init() -> void:
		Global.project_changed.connect(_update_texture_signal)
		Global.cel_changed.connect(_update_texture_signal)

	func _update_texture_signal():
		if _last_cel:
			_last_cel.texture_changed.disconnect(_on_texture_changed)
		if Global.current_project:
			_last_cel = Global.current_project.get_current_cel()
			_last_cel.texture_changed.connect(_on_texture_changed)

	func _on_texture_changed():
		texture_changed.emit()

	# GLOBAL SIGNALS
	# pixelorama_opened
	func connect_pixelorama_opened(callable: Callable):
		Global.pixelorama_opened.connect(callable)
		ExtensionsApi.add_action("pixelorama_opened")

	func disconnect_pixelorama_opened(callable: Callable):
		Global.pixelorama_opened.disconnect(callable)
		ExtensionsApi.remove_action("pixelorama_opened")

	# pixelorama_about_to_close
	func connect_pixelorama_about_to_close(callable: Callable):
		Global.pixelorama_about_to_close.connect(callable)
		ExtensionsApi.add_action("pixelorama_about_to_close")

	func disconnect_pixelorama_about_to_close(callable: Callable):
		Global.pixelorama_about_to_close.disconnect(callable)
		ExtensionsApi.remove_action("pixelorama_about_to_close")

	# project_created -> signal has argument of type "Project"
	func connect_project_created(callable: Callable):
		Global.project_created.connect(callable)
		ExtensionsApi.add_action("project_created")

	func disconnect_project_created(callable: Callable):
		Global.project_created.disconnect(callable)
		ExtensionsApi.remove_action("project_created")

	# project_saved
	func connect_project_about_to_save(callable: Callable):
		Global.project_saved.connect(callable)
		ExtensionsApi.add_action("project_saved")

	func disconnect_project_saved(callable: Callable):
		Global.project_saved.disconnect(callable)
		ExtensionsApi.remove_action("project_saved")

	# project_changed
	func connect_project_changed(callable: Callable):
		Global.project_changed.connect(callable)
		ExtensionsApi.add_action("project_changed")

	func disconnect_project_changed(callable: Callable):
		Global.project_changed.disconnect(callable)
		ExtensionsApi.remove_action("project_changed")

	# cel_changed
	func connect_cel_changed(callable: Callable):
		Global.cel_changed.connect(callable)
		ExtensionsApi.add_action("cel_changed")

	func disconnect_cel_changed(callable: Callable):
		Global.cel_changed.disconnect(callable)
		ExtensionsApi.remove_action("cel_changed")

	# TOOL SIGNALs
	# cel_changed
	func connect_tool_color_changed(callable: Callable):
		Tools.color_changed.connect(callable)
		ExtensionsApi.add_action("color_changed")

	func disconnect_tool_color_changed(callable: Callable):
		Tools.color_changed.disconnect(callable)
		ExtensionsApi.remove_action("color_changed")

	# UPDATER SIGNALS
	# current_cel_texture_changed
	func connect_current_cel_texture_changed(callable: Callable):
		texture_changed.connect(callable)
		ExtensionsApi.add_action("texture_changed")

	func disconnect_current_cel_texture_changed(callable: Callable):
		texture_changed.disconnect(callable)
		ExtensionsApi.remove_action("texture_changed")

	# Export dialog signals
	func connect_export_about_to_preview(target: Object, method: String):
		Global.export_dialog.about_to_preview.connect(Callable(target, method))
		ExtensionsApi.add_action("export_about_to_preview")

	func disconnect_export_about_to_preview(target: Object, method: String):
		Global.export_dialog.about_to_preview.disconnect(Callable(target, method))
		ExtensionsApi.remove_action("export_about_to_preview")
