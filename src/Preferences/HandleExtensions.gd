extends Control

const EXTENSIONS_PATH := "user://extensions"

var extensions := {}  # Extension name : Extension class
var extension_selected := -1

onready var extension_list: ItemList = $InstalledExtensions
onready var enable_button: Button = $HBoxContainer/EnableButton
onready var uninstall_button: Button = $HBoxContainer/UninstallButton
onready var extension_parent: Node = Global.control.get_node("Extensions")


class Extension:
	var file_name := ""
	var display_name := ""
	var description := ""
	var author := ""
	var version := ""
	var license := ""
	var nodes := []
	var enabled := false

	func serialize(dict: Dictionary) -> void:
		if dict.has("name"):
			file_name = dict["name"]
		if dict.has("display_name"):
			display_name = dict["display_name"]
		if dict.has("description"):
			description = dict["description"]
		if dict.has("author"):
			author = dict["author"]
		if dict.has("version"):
			version = dict["version"]
		if dict.has("license"):
			license = dict["license"]
		if dict.has("nodes"):
			nodes = dict["nodes"]


func _ready() -> void:
	if OS.get_name() == "HTML5":
		$HBoxContainer/AddExtensionButton.disabled = true
		$HBoxContainer/OpenFolderButton.visible = false

	var dir := Directory.new()
	var file_names := []  # Array of String(s)
	dir.make_dir(EXTENSIONS_PATH)
	if dir.open(EXTENSIONS_PATH) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var ext: String = file_name.to_lower().get_extension()
			if !dir.current_is_dir() and ext in ["pck", "zip"]:
				file_names.append(file_name)
			file_name = dir.get_next()

	if file_names.empty():
		return

	for file_name in file_names:
		_add_extension(file_name)


func install_extension(path: String) -> void:
	var dir := Directory.new()
	var file_name: String = path.get_file()
	dir.copy(path, EXTENSIONS_PATH.plus_file(file_name))
	_add_extension(file_name)


func _add_extension(file_name: String) -> void:
	if extensions.has(file_name):
		return
	var file_name_no_ext: String = file_name.get_basename()
	var file_path: String = EXTENSIONS_PATH.plus_file(file_name)
	var success := ProjectSettings.load_resource_pack(file_path)
	if !success:
		print("Failed loading resource pack.")
		var dir := Directory.new()
		dir.remove(file_path)
		return

	var extension_path: String = "res://src/Extensions/%s/" % file_name_no_ext
	var extension_config_file_path: String = extension_path.plus_file("extension.json")
	var extension_config_file := File.new()
	var err := extension_config_file.open(extension_config_file_path, File.READ)
	if err != OK:
		print("Error loading config file: ", err)
		extension_config_file.close()
		return

	var extension_json = parse_json(extension_config_file.get_as_text())
	extension_config_file.close()

	if !extension_json:
		print("No JSON data found.")
		return

	var extension := Extension.new()
	extension.serialize(extension_json)
	extensions[file_name] = extension
	extension_list.add_item(extension.display_name)
	var item_count: int = extension_list.get_item_count() - 1
	extension_list.set_item_tooltip(item_count, extension.description)
	extension_list.set_item_metadata(item_count, file_name)
	extension.enabled = Global.config_cache.get_value("extensions", extension.file_name, false)
	if extension.enabled:
		_enable_extension(extension)


func _enable_extension(extension: Extension, save_to_config := true) -> void:
	var extension_path: String = "res://src/Extensions/%s/" % extension.file_name

	# A unique id for the extension (currently set to file_name). More parameters (version etc.)
	# can be easily added using the str() function. for example
	# var id: String = str(extension.file_name, extension.version)
	var id: String = extension.file_name

	if extension.enabled:
		for node in extension.nodes:
			var scene_path: String = extension_path.plus_file(node)
			var extension_scene: PackedScene = load(scene_path)
			if extension_scene:
				var extension_node: Node = extension_scene.instance()
				extension_parent.add_child(extension_node)
				extension_node.add_to_group(id)  # Keep track of what to remove later
	else:
		for ext_node in extension_parent.get_children():
			if ext_node.is_in_group(id):  # Node for extention found
				extension_parent.remove_child(ext_node)
				ext_node.queue_free()

	if save_to_config:
		Global.config_cache.set_value("extensions", extension.file_name, extension.enabled)
		Global.config_cache.save("user://cache.ini")


func _on_InstalledExtensions_item_selected(index: int) -> void:
	extension_selected = index
	var file_name: String = extension_list.get_item_metadata(extension_selected)
	var extension: Extension = extensions[file_name]
	if extension.enabled:
		enable_button.text = "Disable"
	else:
		enable_button.text = "Enable"
	enable_button.disabled = false
	uninstall_button.disabled = false


func _on_InstalledExtensions_nothing_selected() -> void:
	enable_button.disabled = true
	uninstall_button.disabled = true


func _on_AddExtensionButton_pressed() -> void:
	Global.preferences_dialog.get_node("Popups/AddExtensionFileDialog").popup_centered()


func _on_EnableButton_pressed() -> void:
	var file_name: String = extension_list.get_item_metadata(extension_selected)
	var extension: Extension = extensions[file_name]
	extension.enabled = !extension.enabled
	_enable_extension(extension)
	if extension.enabled:
		enable_button.text = "Disable"
	else:
		enable_button.text = "Enable"


func _on_UninstallButton_pressed() -> void:
	var dir := Directory.new()
	var file_name: String = extension_list.get_item_metadata(extension_selected)
	var err := dir.remove(EXTENSIONS_PATH.plus_file(file_name))
	if err != OK:
		print(err)
		return

	var extension: Extension = extensions[file_name]
	extension.enabled = false
	_enable_extension(extension, false)

	extensions.erase(file_name)
	extension_list.remove_item(extension_selected)
	extension_selected = -1
	enable_button.disabled = true
	uninstall_button.disabled = true


func _on_OpenFolderButton_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path(EXTENSIONS_PATH))


func _on_AddExtensionFileDialog_files_selected(paths: PoolStringArray) -> void:
	for path in paths:
		install_extension(path)
