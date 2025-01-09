extends Node
# NOTE: Goto File-->Save then type "ExtensionsApi" in "Search Help" to read the
# curated documentation of the Api.
# If it still doesn't show try again after doing Project-->Reload current project

## The Official ExtensionsAPI for pixelorama.
##
## This Api gives you the essentials to develop a working extension for Pixelorama.[br]
## The Api consists of many smaller Apis, each giving access to different areas of the Software.
## [br][br]
## Keep in mind that this API is targeted towards users who are not fully familiar with Pixelorama's
## source code. If you need to do something more complicated and more low-level, you would need to
## interact directly with the source code.
## [br][br]
## To access this anywhere in the extension use [code]get_node_or_null("/root/ExtensionsApi")[/code]
##
## @tutorial(Add Tutorial here):            https://the/tutorial1/url.com

## Gives access to the general, app related functions of pixelorama
## such as Autoloads, Software Version, Config file etc...
var general := GeneralAPI.new()
var menu := MenuAPI.new()  ## Gives ability to add/remove items from menus in the top bar.
var dialog := DialogAPI.new()  ## Gives access to Dialog related functions.
var panel := PanelAPI.new()  ## Gives access to Tabs and Dockable Container related functions.
var theme := ThemeAPI.new()  ## Gives access to theme related functions.
var tools := ToolAPI.new()  ## Gives ability to add/remove tools.
var selection := SelectionAPI.new()  ## Gives access to pixelorama's selection system.
var project := ProjectAPI.new()  ## Gives access to project manipulation.
var export := ExportAPI.new()  ## Gives access to adding custom exporters.
var import := ImportAPI.new()  ## Gives access to adding custom import options.
var palette := PaletteAPI.new()  ## Gives access to palettes.
var signals := SignalsAPI.new()  ## Gives access to the basic commonly used signals.

## This fail-safe below is designed to work ONLY if Pixelorama is launched in Godot Editor
var _action_history: Dictionary = {}


## [code]This function is used internally and not meant to be used by extensions.[/code]
func check_sanity(extension_name: String) -> void:
	if extension_name in _action_history.keys():
		var extension_history: Array = _action_history[extension_name]
		if extension_history != []:
			var error_msg := str(
				"Extension: ",
				extension_name,
				" contains actons: ",
				extension_history,
				" which are not removed properly"
			)
			push_warning(error_msg)


## [code]This function is used internally and not meant to be used by extensions.[/code]
func clear_history(extension_name: String) -> void:
	if extension_name in _action_history.keys():
		_action_history.erase(extension_name)


## [code]This function is used internally and not meant to be used by extensions.[/code]
func add_action(section: String, key: String) -> void:
	var action := str(section, "/", key)
	var extension_name := _get_caller_extension_name()
	if extension_name != "Unknown":
		if extension_name in _action_history.keys():
			var extension_history: Array = _action_history[extension_name]
			extension_history.append(action)
		else:  # If the extension history doesn't exist yet, create it
			_action_history[extension_name] = [action]


## [code]This function is used internally and not meant to be used by extensions.[/code]
func remove_action(section: String, key: String) -> void:
	var action := str(section, "/", key)
	var extension_name := _get_caller_extension_name()
	if extension_name != "Unknown":
		if extension_name in _action_history.keys():
			_action_history[extension_name].erase(action)


## [code]This function is used internally and not meant to be used by extensions.[/code]
func wait_frame() -> void:  # Await is not available to classes below, so this is the solution
	# use by {await ExtensionsApi.wait_frame()}
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


func _exit_tree() -> void:
	for keys in _action_history.keys():
		check_sanity(keys)


# The API Methods Start Here
## Returns the version of the ExtensionsApi.
func get_api_version() -> int:
	return ProjectSettings.get_setting("application/config/ExtensionsAPI_Version")


## Returns the initial nodes of an extension named [param extension_name].
## initial nodes are the nodes whose paths are in the [code]nodes[/code] key of an
## extension.json file.
func get_main_nodes(extension_name: StringName) -> Array[Node]:
	var extensions_node = Global.control.get_node("Extensions")
	var nodes: Array[Node] = []
	for child: Node in extensions_node.get_children():
		if child.is_in_group(extension_name):
			nodes.append(child)
	return nodes


## Gives Access to the general stuff.
##
## This part of Api provides stuff like commonly used Autoloads, App's version info etc
## the most basic (but important) stuff.
class GeneralAPI:
	## Returns the current version of pixelorama.
	func get_pixelorama_version() -> String:
		return ProjectSettings.get_setting("application/config/version")

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

	## Returns a new ValueSlider. Useful for editing floating values
	func create_value_slider() -> ValueSlider:
		return ValueSlider.new()

	## Returns a new ValueSliderV2. Useful for editing 2D vectors.
	func create_value_slider_v2() -> ValueSliderV2:
		return preload("res://src/UI/Nodes/Sliders/ValueSliderV2.tscn").instantiate()

	## Returns a new ValueSliderV3. Useful for editing 3D vectors.
	func create_value_slider_v3() -> ValueSliderV3:
		return preload("res://src/UI/Nodes/Sliders/ValueSliderV3.tscn").instantiate()


## Gives ability to add/remove items from menus in the top bar.
class MenuAPI:
	enum { FILE, EDIT, SELECT, IMAGE, EFFECTS, VIEW, WINDOW, HELP }

	# Menu methods
	func _get_popup_menu(menu_type: int) -> PopupMenu:
		match menu_type:
			FILE:
				return Global.top_menu_container.file_menu
			EDIT:
				return Global.top_menu_container.edit_menu
			SELECT:
				return Global.top_menu_container.select_menu
			IMAGE:
				return Global.top_menu_container.image_menu
			EFFECTS:
				return Global.top_menu_container.effects_menu
			VIEW:
				return Global.top_menu_container.view_menu
			WINDOW:
				return Global.top_menu_container.window_menu
			HELP:
				return Global.top_menu_container.help_menu
		return null

	## Adds a menu item of title [param item_name] to the [param menu_type] defined by
	## [enum @unnamed_enums].
	## [br][param item_metadata] is usually a window node you want to appear when you click the
	## [param item_name]. That window node should also have a [param menu_item_clicked]
	## function inside its script.[br]
	## Index of the added item is returned (which can be used to remove menu item later on).
	func add_menu_item(menu_type: int, item_name: String, item_metadata, item_id := -1) -> int:
		var popup_menu := _get_popup_menu(menu_type)
		if not popup_menu:
			push_error("Menu of type: ", menu_type, " does not exist.")
			return -1
		popup_menu.add_item(item_name, item_id)
		var idx := item_id
		if item_id == -1:
			idx = popup_menu.get_item_count() - 1
		popup_menu.set_item_metadata(idx, item_metadata)
		ExtensionsApi.add_action("MenuAPI", "add_menu")
		return idx

	## Removes a menu item at index [param item_idx] from the [param menu_type] defined by
	## [enum @unnamed_enums].
	func remove_menu_item(menu_type: int, item_idx: int) -> void:
		var popup_menu := _get_popup_menu(menu_type)
		if not popup_menu:
			push_error("Menu of type: ", menu_type, " does not exist.")
			return
		popup_menu.remove_item(item_idx)
		ExtensionsApi.remove_action("MenuAPI", "add_menu")


## Gives access to common dialog related functions.
class DialogAPI:
	## Shows an alert dialog with the given [param text].
	## Useful for displaying messages like "Incompatible API" etc...
	func show_error(text: String) -> void:
		Global.popup_error(text)

	## Returns the node that is the parent of dialogs used in pixelorama.
	func get_dialogs_parent_node() -> Node:
		return Global.control.get_node("Dialogs")

	## Informs Pixelorama that some dialog is about to open or close.
	func dialog_open(open: bool) -> void:
		Global.dialog_open(open)


## Gives access to Tabs and Dockable Container related functions.
class PanelAPI:
	## Sets the visibility of dockable tabs.
	var tabs_visible: bool:
		set(value):
			var dockable := _get_dockable_container_ui()
			dockable.tabs_visible = value
		get:
			var dockable := _get_dockable_container_ui()
			return dockable.tabs_visible

	## Adds the [param node] as a tab. Initially it's placed on the same panel as the tools tab,
	## but it's position can be changed through editing a layout.
	func add_node_as_tab(node: Node) -> void:
		var dockable := _get_dockable_container_ui()
		var top_menu_container := Global.top_menu_container
		var panels_submenu: PopupMenu = top_menu_container.panels_submenu
		# adding the node to the first tab we find, it'll be re-ordered by layout anyway
		var tabs := _get_tabs_in_root(dockable.layout.root)
		if tabs.size() != 0:
			dockable.add_child(node)
			tabs[0].insert_node(0, node)  # Insert at the beginning
		else:
			push_error("No suitable tab found for node placement.")
			return
		top_menu_container.ui_elements.append(node)
		# refreshing Panels submenu
		var new_elements = top_menu_container.ui_elements
		panels_submenu.clear()
		for element in new_elements:
			panels_submenu.add_check_item(element.name)
			var is_hidden := dockable.is_control_hidden(element)
			panels_submenu.set_item_checked(new_elements.find(element), !is_hidden)
		# re-assigning layout
		top_menu_container.set_layout(top_menu_container.selected_layout)
		# we must make tabs_visible = true for a few moments if it is false
		if dockable.tabs_visible == false:
			dockable.tabs_visible = true
			await ExtensionsApi.wait_frame()
			dockable.tabs_visible = false
		ExtensionsApi.add_action("PanelAPI", "add_tab")

	## Removes the [param node] from the DockableContainer.
	func remove_node_from_tab(node: Node) -> void:
		var top_menu_container := Global.top_menu_container
		var dockable := _get_dockable_container_ui()
		var panels_submenu: PopupMenu = top_menu_container.panels_submenu
		# find the tab that contains the node
		if node == null:
			return
		var tab := _find_tab_with_node(node.name, dockable)
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
		ExtensionsApi.remove_action("PanelAPI", "add_tab")

	# PRIVATE METHODS
	func _get_dockable_container_ui() -> DockableContainer:
		return Global.control.find_child("DockableContainer")

	func _find_tab_with_node(
		node_name: String, dockable_container: DockableContainer
	) -> DockableLayoutPanel:
		var root := dockable_container.layout.root
		var tabs := _get_tabs_in_root(root)
		for tab in tabs:
			var idx := tab.find_name(node_name)
			if idx != -1:
				return tab
		push_error("Tab containing node: %s not found" % node_name)
		return null

	func _get_tabs_in_root(parent_resource: DockableLayoutNode) -> Array[DockableLayoutPanel]:
		var parents := []  # Resources have no get_parent_resource() so this is an alternative
		var scanned := []  # To keep track of already discovered layout_split resources
		var child_number := 0
		parents.append(parent_resource)
		var scan_target := parent_resource
		var tabs: Array[DockableLayoutPanel] = []
		# Get children in the parent, the initial parent is the node we entered as "parent"
		while child_number < 2:
			# If parent isn't a (layout_split) resource then there is no point
			# in continuing (this is just a sanity check and should always pass)
			if !scan_target is DockableLayoutSplit:
				break

			var child_resource: DockableLayoutNode
			if child_number == 0:
				child_resource = (scan_target as DockableLayoutSplit).get_first()  # First child
			elif child_number == 1:
				child_resource = (scan_target as DockableLayoutSplit).get_second()  # Second child

			# If the child resource is a tab and it wasn't discovered before, add it to "paths"
			if child_resource is DockableLayoutPanel:
				if !tabs.has(child_resource):
					tabs.append(child_resource)
			# If "child_resource" is another layout_split resource then we need to scan it too
			elif child_resource is DockableLayoutSplit and !scanned.has(child_resource):
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


## Gives access to theme related functions.
class ThemeAPI:
	## Returns the Themes autoload. Allows interacting with themes on a more deeper level.
	func autoload() -> Themes:
		return Themes

	## Adds the [param theme] to [code]Edit -> Preferences -> Interface -> Themes[/code].
	func add_theme(theme: Theme) -> void:
		Themes.add_theme(theme)
		ExtensionsApi.add_action("ThemeAPI", "add_theme")

	## Returns index of the [param theme] in preferences.
	func find_theme_index(theme: Theme) -> int:
		return Themes.themes.find(theme)

	## Returns the current theme resource.
	func get_theme() -> Theme:
		return Global.control.theme

	## Sets a theme located at a given [param idx] in preferences. If theme set successfully then
	## return [code]true[/code], else [code]false[/code].
	func set_theme(idx: int) -> bool:
		if idx >= 0 and idx < Themes.themes.size():
			Themes.change_theme(idx)
			return true
		else:
			push_error("No theme found at index: ", idx)
			return false

	## Removes the [param theme] from preferences.
	func remove_theme(theme: Theme) -> void:
		Themes.remove_theme(theme)
		ExtensionsApi.remove_action("ThemeAPI", "add_theme")

	## Adds a new font.
	func add_font(font: Font) -> void:
		Global.loaded_fonts.append(font)
		Global.font_loaded.emit()

	## Removes a loaded font.
	## If that font is the current one of the interface, set it back to Roboto.
	func remove_font(font: Font) -> void:
		var font_index := Global.loaded_fonts.find(font)
		if font_index == -1:
			return
		if Global.theme_font_index == font_index:
			Global.theme_font_index = 1
		Global.loaded_fonts.remove_at(font_index)
		Global.font_loaded.emit()

	## Sets a font as the current one for the interface. The font must have been
	## added beforehand by [method add_font].
	func set_font(font: Font) -> void:
		var font_index := Global.loaded_fonts.find(font)
		if font_index > -1:
			Global.theme_font_index = font_index


## Gives ability to add/remove tools.
class ToolAPI:
	# gdlint: ignore=constant-name
	const LayerTypes := Global.LayerTypes

	## Returns the Tools autoload. Allows interacting with tools on a more deeper level.
	func autoload() -> Tools:
		return Tools

	## Adds a tool to pixelorama with name [param tool_name] (without spaces),
	## display name [param display_name], tool scene [param scene], layers that the tool works
	## on [param layer_types] defined by [constant LayerTypes],
	## [param extra_hint] (text that appears when mouse havers tool icon), primary shortcut
	## name [param shortcut] and any extra shortcuts [param extra_shortcuts].
	## [br][br]At the moment extensions can't make their own shortcuts so you can leave
	## [param shortcut] and [param extra_shortcuts] as [code][][/code].
	## [br] To determine the position of tool in tool list, use [param insert_point]
	## (if you leave it empty then the added tool will be placed at bottom)
	func add_tool(
		tool_name: String,
		display_name: String,
		scene: String,
		layer_types: PackedInt32Array = [],
		extra_hint := "",
		shortcut: String = "",
		extra_shortcuts: PackedStringArray = [],
		insert_point := -1
	) -> void:
		var tool_class := Tools.Tool.new(
			tool_name, display_name, shortcut, scene, layer_types, extra_hint, extra_shortcuts
		)
		Tools.tools[tool_name] = tool_class
		Tools.add_tool_button(tool_class, insert_point)
		ExtensionsApi.add_action("ToolAPI", "add_tool")

	## Removes a tool with name [param tool_name]
	## and assign Pencil as left tool, Eraser as right tool.
	func remove_tool(tool_name: String) -> void:
		# Re-assigning the tools in case the tool to be removed is also active
		Tools.assign_tool("Pencil", MOUSE_BUTTON_LEFT)
		Tools.assign_tool("Eraser", MOUSE_BUTTON_RIGHT)
		var tool_class: Tools.Tool = Tools.tools[tool_name]
		if tool_class:
			Tools.remove_tool(tool_class)
		ExtensionsApi.remove_action("ToolAPI", "add_tool")


## Gives access to pixelorama's selection system.
class SelectionAPI:
	## Clears the selection.
	func clear_selection() -> void:
		Global.canvas.selection.clear_selection(true)

	## Select the entire region of current cel.
	func select_all() -> void:
		Global.canvas.selection.select_all()

	## Selects a portion defined by [param rect] of the current cel.
	## [param operation] influences it's behaviour with previous selection rects
	## (0 for adding, 1 for subtracting, 2 for intersection).
	func select_rect(rect: Rect2i, operation := 0) -> void:
		Global.canvas.selection.transform_content_confirm()
		var undo_data_tmp = Global.canvas.selection.get_undo_data(false)
		Global.canvas.selection.select_rect(rect, operation)
		Global.canvas.selection.commit_undo("Select", undo_data_tmp)

	## Moves a selection to [param destination],
	## with content if [param with_content] is [code]true[/code].
	## If [param transform_standby] is [code]true[/code] then the transformation will not be
	## applied immediately unless [kbd]Enter[/kbd] is pressed.
	func move_selection(
		destination: Vector2i, with_content := true, transform_standby := false
	) -> void:
		if not with_content:
			Global.canvas.selection.transform_content_confirm()
			Global.canvas.selection.move_borders_start()
		else:
			Global.canvas.selection.transform_content_start()
		var selection_rectangle: Rect2i = Global.canvas.selection.big_bounding_rectangle
		var rel_direction := destination - selection_rectangle.position
		Global.canvas.selection.move_content(rel_direction)
		Global.canvas.selection.move_borders_end()
		if not transform_standby and with_content:
			Global.canvas.selection.transform_content_confirm()

	## Resizes the selection to [param new_size],
	## with content if [param with_content] is [code]true[/code].
	## If [param transform_standby] is [code]true[/code] then the transformation will not be
	## applied immediately unless [kbd]Enter[/kbd] is pressed.
	func resize_selection(
		new_size: Vector2i, with_content := true, transform_standby := false
	) -> void:
		if not with_content:
			Global.canvas.selection.transform_content_confirm()
			Global.canvas.selection.move_borders_start()
		else:
			Global.canvas.selection.transform_content_start()

		if Global.canvas.selection.original_bitmap.is_empty():  # To avoid copying twice.
			Global.canvas.selection.original_bitmap.copy_from(Global.current_project.selection_map)

		Global.canvas.selection.big_bounding_rectangle.size = new_size
		Global.canvas.selection.resize_selection()
		Global.canvas.selection.move_borders_end()
		if not transform_standby and with_content:
			Global.canvas.selection.transform_content_confirm()

	## Inverts the selection.
	func invert() -> void:
		Global.canvas.selection.invert()

	## Makes a project brush out of the current selection's content.
	func make_brush() -> void:
		Global.canvas.selection.new_brush()

	## Returns the portion of current cel's image enclosed by the selection.
	## It's similar to [method make_brush] but it returns the image instead.
	func get_enclosed_image() -> Image:
		return Global.canvas.selection.get_enclosed_image()

	## Copies the selection content (works in or between pixelorama instances only).
	func copy() -> void:
		Global.canvas.selection.copy()

	## Pastes the selection content.
	func paste(in_place := false) -> void:
		Global.canvas.selection.paste(in_place)

	## Erases the drawing on current cel enclosed within the selection's area.
	func delete_content(selected_cels := true) -> void:
		Global.canvas.selection.delete(selected_cels)


## Gives access to basic project manipulation functions.
class ProjectAPI:
	## The project currently in focus.
	var current_project: Project:
		set(value):
			Global.tabs.current_tab = Global.projects.find(value)
		get:
			return Global.current_project

	## Creates a new project in a new tab with one starting layer and frame,
	## name [param name], size [param size], fill color [param fill_color] and
	## frames [param frames]. The created project also gets returned.[br][br]
	## [param frames] is an [Array] of type [Frame]. Usually it can be left as [code][][/code].
	func new_project(
		frames: Array[Frame] = [],
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

	## Creates and returns a new [Project] in a new tab, with an optional [param name].
	## Unlike [method new_project], no starting frame/layer gets created.
	## Useful if you want to deserialize project data.
	func new_empty_project(name := tr("untitled")) -> Project:
		var new_proj := Project.new([], name)
		Global.projects.append(new_proj)
		return new_proj

	## Returns a dictionary containing all the project information.
	func get_project_info(project: Project) -> Dictionary:
		return project.serialize()

	## Selects the cels and makes the last entry of [param selected_array] as the current cel.
	## [param selected_array] is an [Array] of [Arrays] of 2 integers (frame & layer respectively).
	## [br]Frames are counted from left to right, layers are counted from bottom to top.
	## Frames/layers start at "0" and end at [param project.frames.size() - 1] and
	## [param project.layers.size() - 1] respectively.
	func select_cels(selected_array := [[0, 0]]) -> void:
		var project := Global.current_project
		project.selected_cels.clear()
		for cel_position in selected_array:
			if typeof(cel_position) == TYPE_ARRAY and cel_position.size() == 2:
				var frame := clampi(cel_position[0], 0, project.frames.size() - 1)
				var layer := clampi(cel_position[1], 0, project.layers.size() - 1)
				if not [frame, layer] in project.selected_cels:
					project.selected_cels.append([frame, layer])
		project.change_cel(project.selected_cels[-1][0], project.selected_cels[-1][1])

	## Returns the current cel.
	## Cel type can be checked using function [method get_class_name] inside the cel
	## type can be GroupCel, PixelCel, Cel3D, CelTileMap, AudioCel or BaseCel.
	func get_current_cel() -> BaseCel:
		return current_project.get_current_cel()

	## Frames are counted from left to right, layers are counted from bottom to top.
	## Frames/layers start at "0" and end at [param project.frames.size() - 1] and
	## [param project.layers.size() - 1] respectively.
	func get_cel_at(project: Project, frame: int, layer: int) -> BaseCel:
		frame = clampi(frame, 0, project.frames.size() - 1)
		layer = clampi(layer, 0, project.layers.size() - 1)
		return project.frames[frame].cels[layer]

	## Sets an [param image] at [param frame] and [param layer] on the current project.
	## Frames are counted from left to right, layers are counted from bottom to top.
	func set_pixelcel_image(image: Image, frame: int, layer: int) -> void:
		if get_cel_at(current_project, frame, layer).get_class_name() == "PixelCel":
			OpenSave.open_image_at_cel(image, layer, frame)
		else:
			push_error("cel at frame ", frame, ", layer ", layer, " is not a PixelCel")

	## Adds a new frame in the current project after frame [param after_frame].
	func add_new_frame(after_frame: int) -> void:
		var project := Global.current_project
		if after_frame < project.frames.size() and after_frame >= 0:
			var old_current := project.current_frame
			project.current_frame = after_frame  # temporary assignment
			Global.animation_timeline.add_frame()
			project.current_frame = old_current
		else:
			push_error("invalid (after_frame): ", after_frame)

	## Adds a new Layer of name [param name] in the current project above layer [param above_layer]
	## ([param above_layer] = 0 is the bottom-most layer and so on).
	## [br][param type] = 0 --> PixelLayer,
	## [br][param type] = 1 --> GroupLayer,
	## [br][param type] = 2 --> 3DLayer
	func add_new_layer(above_layer: int, name := "", type := Global.LayerTypes.PIXEL) -> void:
		var project := ExtensionsApi.project.current_project
		if above_layer < project.layers.size() and above_layer >= 0:
			var old_current := project.current_layer
			project.current_layer = above_layer  # temporary assignment
			if type >= 0 and type < Global.LayerTypes.size():
				Global.animation_timeline.on_add_layer_list_id_pressed(type)
				if name != "":
					project.layers[above_layer + 1].name = name
					var l_idx := Global.layer_vbox.get_child_count() - (above_layer + 2)
					Global.layer_vbox.get_child(l_idx).label.text = name
				project.current_layer = old_current
			else:
				push_error("invalid (type): ", type)
		else:
			push_error("invalid (above_layer) ", above_layer)


## Gives access to adding custom exporters.
class ExportAPI:
	# gdlint: ignore=constant-name
	const ExportTab := Export.ExportTab

	## Returns the Export autoload.
	## Allows interacting with the export workflow on a more deeper level.
	func autoload() -> Export:
		return Export

	## [param format_info] has keys: [code]extension[/code] and [code]description[/code]
	## whose values are of type [String] e.g:[codeblock]
	## format_info = {"extension": ".gif", "description": "GIF Image"}
	## [/codeblock]
	## [param exporter_generator] is a node with a script containing the method
	## [method override_export] which takes 1 argument of type Dictionary which is automatically
	## passed to [method override_export] at time of export and contains
	## keys: [code]processed_images[/code], [code]export_dialog[/code],
	## [code]export_paths[/code], [code]project[/code][br]
	## (Note: [code]processed_images[/code] is an array of ProcessedImage resource which further
	## has parameters [param image] and [param duration])[br]
	## If the value of [param tab] is not in [constant ExportTab] then the format will be added to
	## both tabs.
	## [br]Returns the index of exporter, which can be used to remove exporter later.
	func add_export_option(
		format_info: Dictionary,
		exporter_generator: Object,
		tab := ExportTab.IMAGE,
		is_animated := true
	) -> int:
		# Separate enum name and file name
		var extension := ""
		var format_name := ""
		if format_info.has("extension"):
			extension = format_info["extension"]
		if format_info.has("description"):
			format_name = format_info["description"].strip_edges().to_upper().replace(" ", "_")
		# Change format name if another one uses the same name
		var existing_format_names := Export.FileFormat.keys() + Export.custom_file_formats.keys()
		for i in range(existing_format_names.size()):
			var test_name := format_name
			if i != 0:
				test_name = str(test_name, "_", i)
			if !existing_format_names.has(test_name):
				format_name = test_name
				break
		# Setup complete, add the exporter
		var id := Export.add_custom_file_format(
			format_name, extension, exporter_generator, tab, is_animated
		)
		ExtensionsApi.add_action("ExportAPI", "add_exporter")
		return id

	## Removes the exporter with [param id] from Pixelorama.
	func remove_export_option(id: int) -> void:
		if Export.custom_exporter_generators.has(id):
			Export.remove_custom_file_format(id)
			ExtensionsApi.remove_action("ExportAPI", "add_exporter")


## Gives access to adding custom import options.
class ImportAPI:
	## Returns the OpenSave autoload. Contains code to handle file loading.
	## It also contains code to handle project saving (.pxo)
	func open_save_autoload() -> OpenSave:
		return OpenSave

	## Returns the Import autoload. Manages import of brushes and patterns.
	func import_autoload() -> Import:
		return Import

	## [param import_scene] is a scene preload that will be instanced and added to "import options"
	## section of pixelorama's import dialogs and will appear whenever [param import_name] is
	## chosen from import menu.
	## [br]
	## [param import_scene] must have a script containing:[br]
	## 1. An optional variable named [code]import_preview_dialog[/code] of type [ConfirmationDialog],
	## If present, it will automatically be assigned a reference to the relevant import dialog's
	## [code]ImportPreviewDialog[/code] class so that you can easily access variables and
	## methods of that class. (This variable is meant to be read-only)[br]
	## 2. The method [method initiate_import], which takes 2 arguments: [code]path[/code],
	## [code]image[/code]. Values will automatically be passed to these arguments at the
	## time of import.[br]Returns the id of the importer.
	func add_import_option(import_name: StringName, import_scene_preload: PackedScene) -> int:
		var id := OpenSave.add_import_option(import_name, import_scene_preload)
		ExtensionsApi.add_action("ImportAPI", "add_import_option")
		return id

	## Removes the import option with [param id] from Pixelorama.
	func remove_import_option(id: int) -> void:
		var import_name = OpenSave.custom_import_names.find_key(id)
		OpenSave.custom_import_names.erase(import_name)
		OpenSave.custom_importer_scenes.erase(id)
		ExtensionsApi.remove_action("ImportAPI", "add_import_option")


## Gives access to palette related stuff.
class PaletteAPI:
	## Returns the Palettes autoload. Allows interacting with palettes on a more deeper level.
	func autoload() -> Palettes:
		return Palettes

	## Creates and adds a new [Palette] with name [param palette_name] containing [param data].
	## [param data] is a [Dictionary] containing the palette information.
	## An example of [code]data[/code] will be:[codeblock]
	## {
	## "colors": [
	##  {
	##   "color": "(0, 0, 0, 1)",
	##   "index": 0
	##  },
	##  {
	##   "color": "(0.1294, 0.1216, 0.2039, 1)",
	##   "index": 1
	##  },
	##  {
	##   "color": "(0.2667, 0.1569, 0.2314, 1)",
	##   "index": 2
	##  }
	## ],
	## "comment": "Place comment here",
	## "height": 4,
	## "width": 8
	## }
	## [/codeblock]
	func create_palette_from_data(palette_name: String, data: Dictionary) -> void:
		var palette := Palette.new(palette_name)
		palette.deserialize_from_dictionary(data)
		Palettes.save_palette(palette)
		Palettes.palettes[palette_name] = palette
		Palettes.select_palette(palette_name)
		Palettes.new_palette_created.emit()


## Gives access to the basic commonly used signals.
##
## Gives access to the basic commonly used signals.
## Some less common signals are not mentioned in Api but could be accessed through source directly.
class SignalsAPI:
	# system to auto-adjust texture_changed to the "current cel"
	## This signal is not meant to be used directly.
	## Use [method signal_current_cel_texture_changed] instead
	signal texture_changed
	var _last_cel: BaseCel

	func _init() -> void:
		Global.project_switched.connect(_update_texture_signal)
		Global.cel_switched.connect(_update_texture_signal)

	func _update_texture_signal() -> void:
		if _last_cel:
			_last_cel.texture_changed.disconnect(_on_texture_changed)
		if Global.current_project:
			_last_cel = Global.current_project.get_current_cel()
			_last_cel.texture_changed.connect(_on_texture_changed)

	func _on_texture_changed() -> void:
		texture_changed.emit()

	func _connect_disconnect(
		signal_class: Signal, callable: Callable, is_disconnecting := false
	) -> void:
		if !is_disconnecting:
			signal_class.connect(callable)
			ExtensionsApi.add_action("SignalsAPI", signal_class.get_name())
		else:
			signal_class.disconnect(callable)
			ExtensionsApi.remove_action("SignalsAPI", signal_class.get_name())

	# APP RELATED SIGNALS
	## Connects/disconnects a signal to [param callable], that emits
	## when pixelorama is just opened.
	func signal_pixelorama_opened(callable: Callable, is_disconnecting := false) -> void:
		_connect_disconnect(Global.pixelorama_opened, callable, is_disconnecting)

	## Connects/disconnects a signal to [param callable], that emits
	## when pixelorama is about to close.
	func signal_pixelorama_about_to_close(callable: Callable, is_disconnecting := false) -> void:
		_connect_disconnect(Global.pixelorama_about_to_close, callable, is_disconnecting)

	# PROJECT RELATED SIGNALS
	## Connects/disconnects a signal to [param callable], that emits
	## whenever a new project is created.[br]
	## [b]Binds: [/b]It has one bind of type [code]Project[/code] which is the newly
	## created project.
	func signal_project_created(callable: Callable, is_disconnecting := false) -> void:
		_connect_disconnect(Global.project_created, callable, is_disconnecting)

	## Connects/disconnects a signal to [param callable], that emits
	## after a project is saved.
	func signal_project_saved(callable: Callable, is_disconnecting := false) -> void:
		_connect_disconnect(OpenSave.project_saved, callable, is_disconnecting)

	## Connects/disconnects a signal to [param callable], that emits
	## whenever you switch to some other project.
	func signal_project_switched(callable: Callable, is_disconnecting := false) -> void:
		_connect_disconnect(Global.project_switched, callable, is_disconnecting)

	## Connects/disconnects a signal to [param callable], that emits
	## whenever you select a different cel.
	func signal_cel_switched(callable: Callable, is_disconnecting := false) -> void:
		_connect_disconnect(Global.cel_switched, callable, is_disconnecting)

	## Connects/disconnects a signal to [param callable], that emits
	## whenever the project data are being modified.
	func signal_project_data_changed(callable: Callable, is_disconnecting := false) -> void:
		_connect_disconnect(Global.project_data_changed, callable, is_disconnecting)

	# TOOL RELATED SIGNALS
	## Connects/disconnects a signal to [param callable], that emits
	## whenever a tool changes color.[br]
	## [b]Binds: [/b] It has two bind of type [Color] (a dictionary with keys "color" and "index")
	## and [int] (Indicating button that tool is assigned to, see [enum @GlobalScope.MouseButton])
	func signal_tool_color_changed(callable: Callable, is_disconnecting := false) -> void:
		_connect_disconnect(Tools.color_changed, callable, is_disconnecting)

	# TIMELINE RELATED SIGNALS
	## Connects/disconnects a signal to [param callable], that emits
	## whenever timeline animation starts.[br]
	## [b]Binds: [/b] It has one bind of type [bool] which indicated if animation is in
	## forward direction ([code]true[/code]) or backward direction ([code]false[/code])
	func signal_timeline_animation_started(callable: Callable, is_disconnecting := false) -> void:
		_connect_disconnect(Global.animation_timeline.animation_started, callable, is_disconnecting)

	## Connects/disconnects a signal to [param callable], that emits
	## whenever timeline animation stops.
	func signal_timeline_animation_finished(callable: Callable, is_disconnecting := false) -> void:
		_connect_disconnect(
			Global.animation_timeline.animation_finished, callable, is_disconnecting
		)

	# UPDATER SIGNALS
	## Connects/disconnects a signal to [param callable], that emits
	## whenever texture of the currently focused cel changes.
	func signal_current_cel_texture_changed(callable: Callable, is_disconnecting := false) -> void:
		_connect_disconnect(texture_changed, callable, is_disconnecting)

	## Connects/disconnects a signal to [param callable], that emits
	## whenever preview is about to be drawn.[br]
	## [b]Binds: [/b]It has one bind of type [Dictionary] with keys: [code]exporter_id[/code],
	## [code]export_tab[/code], [code]preview_images[/code], [code]durations[/code].[br]
	## Use this if you plan on changing preview of export.
	func signal_export_about_to_preview(callable: Callable, is_disconnecting := false) -> void:
		_connect_disconnect(Global.export_dialog.about_to_preview, callable, is_disconnecting)
