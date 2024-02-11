extends Control

enum UninstallMode { KEEP_FILE, FILE_TO_BIN, REMOVE_PERMANENT }

const EXTENSIONS_PATH := "user://extensions"
const BUG_EXTENSIONS_PATH := "user://give_in_bug_report"
const BIN_ACTION := "trash"

@export var add_extension_file_dialog: FileDialog

var extensions := {}  ## Extension name: Extension class
var extension_selected := -1
var damaged_extension: String

@onready var extension_list: ItemList = $InstalledExtensions
@onready var enable_button: Button = $HBoxContainer/EnableButton
@onready var uninstall_button: Button = $HBoxContainer/UninstallButton
@onready var extension_parent: Node = Global.control.get_node("Extensions")
@onready var delete_confirmation: ConfirmationDialog = %DeleteConfirmation


class Extension:
	var file_name := ""
	var display_name := ""
	var description := ""
	var author := ""
	var version := ""
	var license := ""
	var nodes := []
	var enabled: bool:
		set(value):
			enabled = value
			enabled_once = true
	var internal := false
	var enabled_once := false

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
	delete_confirmation.add_button(tr("Move to Trash"), false, BIN_ACTION)
	if OS.get_name() == "Web":
		$HBoxContainer/AddExtensionButton.disabled = true
		$HBoxContainer/OpenFolderButton.visible = false

	_add_internal_extensions()

	var file_names: PackedStringArray = []
	var dir := DirAccess.open("user://")
	dir.make_dir(EXTENSIONS_PATH)
	dir = DirAccess.open(EXTENSIONS_PATH)
	if DirAccess.get_open_error() == OK:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			var ext := file_name.to_lower().get_extension()
			if not dir.current_is_dir() and ext in ["pck", "zip"]:
				file_names.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	if file_names.is_empty():
		return

	for file_name in file_names:
		_add_extension(file_name)


func _add_internal_extensions() -> void:
	## at the moment this is an empty function but you should add all internal extensions here
	# for example:
	#read_extension("ExtensionName", true)
	pass


func install_extension(path: String) -> void:
	var file_name := path.get_file()
	var err := DirAccess.copy_absolute(path, EXTENSIONS_PATH.path_join(file_name))
	if err != OK:
		print(err)
		return
	_add_extension(file_name)


func _uninstall_extension(
	file_name := "", remove_mode := UninstallMode.REMOVE_PERMANENT, item := extension_selected
) -> void:
	var err := OK
	match remove_mode:
		UninstallMode.FILE_TO_BIN:
			err = OS.move_to_trash(
				ProjectSettings.globalize_path(EXTENSIONS_PATH).path_join(file_name)
			)
		UninstallMode.REMOVE_PERMANENT:
			err = DirAccess.remove_absolute(EXTENSIONS_PATH.path_join(file_name))
	if remove_mode != UninstallMode.KEEP_FILE:
		if err != OK:
			print(err)
			return

	var extension: Extension = extensions[file_name]
	extension.enabled = false
	_enable_extension(extension, false)

	extensions.erase(file_name)
	extension_list.remove_item(item)
	extension_selected = -1
	enable_button.disabled = true
	uninstall_button.disabled = true


func _add_extension(file_name: String) -> void:
	var tester_file: FileAccess  # For testing and deleting damaged extensions
	# Remove any extension that was proven guilty before this extension is loaded
	if FileAccess.file_exists(EXTENSIONS_PATH.path_join("Faulty.txt")):
		# This code will only run if pixelorama crashed
		var faulty_path := EXTENSIONS_PATH.path_join("Faulty.txt")
		tester_file = FileAccess.open(faulty_path, FileAccess.READ)
		damaged_extension = tester_file.get_as_text()
		tester_file.close()
		# don't delete the extension permanently
		# (so that it may be given to the developer in the bug report)
		DirAccess.make_dir_recursive_absolute(BUG_EXTENSIONS_PATH)
		DirAccess.rename_absolute(
			EXTENSIONS_PATH.path_join(damaged_extension),
			BUG_EXTENSIONS_PATH.path_join(damaged_extension)
		)
		DirAccess.remove_absolute(EXTENSIONS_PATH.path_join("Faulty.txt"))

	# Don't load a deleted extension
	if damaged_extension == file_name:
		# This code will only run if pixelorama crashed
		damaged_extension = ""
		return

	# The new (about to load) extension will be considered guilty till it's proven innocent
	tester_file = FileAccess.open(EXTENSIONS_PATH.path_join("Faulty.txt"), FileAccess.WRITE)
	tester_file.store_string(file_name)  # Guilty till proven innocent ;)
	tester_file.close()

	if extensions.has(file_name):
		var item := -1
		for i in extension_list.get_item_count():
			if extension_list.get_item_metadata(i) == file_name:
				item = i
				break
		if item == -1:
			print("Failed to find %s" % file_name)
			return
		_uninstall_extension(file_name, UninstallMode.KEEP_FILE, item)
		# Wait two frames so the previous nodes can get freed
		await get_tree().process_frame
		await get_tree().process_frame

	var file_path := EXTENSIONS_PATH.path_join(file_name)
	var success := ProjectSettings.load_resource_pack(file_path)
	if !success:
		# Don't delete the extension
		# Context: pixelorama deletes v0.11.x extensions when you open v1.0, this will prevent it.
#		OS.move_to_trash(file_path)
		print("EXTENSION ERROR: Failed loading resource pack %s." % file_name)
		print("	There may be errors in extension code or extension is incompatible")
		# Delete the faulty.txt, (it's fate has already been decided)
		DirAccess.remove_absolute(EXTENSIONS_PATH.path_join("Faulty.txt"))
		return
	read_extension(file_name)


func read_extension(extension_file_or_folder_name: StringName, internal := false):
	var file_name_no_ext := extension_file_or_folder_name.get_basename()
	var extension_path := "res://src/Extensions/%s/" % file_name_no_ext
	var extension_config_file_path := extension_path.path_join("extension.json")
	var extension_config_file := FileAccess.open(extension_config_file_path, FileAccess.READ)
	var err := FileAccess.get_open_error()
	if err != OK:
		print("Error loading config file: ", err, " (", error_string(err), ")")
		extension_config_file.close()
		return

	var test_json_conv := JSON.new()
	test_json_conv.parse(extension_config_file.get_as_text())
	var extension_json = test_json_conv.get_data()
	extension_config_file.close()

	if not extension_json:
		print("No JSON data found.")
		return

	if extension_json.has("supported_api_versions"):
		var supported_api_versions = extension_json["supported_api_versions"]
		if typeof(supported_api_versions) == TYPE_ARRAY:
			supported_api_versions = PackedInt32Array(supported_api_versions)
			if not ExtensionsApi.get_api_version() in supported_api_versions:
				var err_text := (
					"The extension %s will not work on this version of Pixelorama \n"
					% file_name_no_ext
				)
				var required_text := str(
					"Extension works on API versions: %s" % str(supported_api_versions),
					"\n",
					"But Pixelorama's API version is: %s" % ExtensionsApi.get_api_version()
				)
				Global.popup_error(str(err_text, required_text))
				print("Incompatible API")
				if !internal:  # the file isn't created for internal extensions, no need for removal
					# Don't put it in faulty, (it's merely incompatible)
					DirAccess.remove_absolute(EXTENSIONS_PATH.path_join("Faulty.txt"))
				return

	var extension := Extension.new()
	extension.serialize(extension_json)
	extension.internal = internal
	extensions[extension_file_or_folder_name] = extension
	extension_list.add_item(extension.display_name)
	var item_count := extension_list.get_item_count() - 1
	extension_list.set_item_tooltip(item_count, extension.description)
	extension_list.set_item_metadata(item_count, extension_file_or_folder_name)
	if internal:  # enable internal extensions if it is for the first time
		extension.enabled = Global.config_cache.get_value("extensions", extension.file_name, true)
	else:
		extension.enabled = Global.config_cache.get_value("extensions", extension.file_name, false)
	if extension.enabled:
		_enable_extension(extension)

	# If an extension doesn't crash pixelorama then it is proven innocent
	# And we should now delete its "Faulty.txt" file
	if !internal:  # the file isn't created for internal extensions, so no need to remove it
		DirAccess.remove_absolute(EXTENSIONS_PATH.path_join("Faulty.txt"))


func _enable_extension(extension: Extension, save_to_config := true) -> void:
	var extension_path: String = "res://src/Extensions/%s/" % extension.file_name

	# A unique id for the extension (currently set to file_name). More parameters (version etc.)
	# can be easily added using the str() function. for example
	# var id: String = str(extension.file_name, extension.version)
	var id: String = extension.file_name

	if extension.enabled:
		ExtensionsApi.clear_history(extension.file_name)
		for node in extension.nodes:
			var scene_path: String = extension_path.path_join(node)
			var extension_scene: PackedScene = load(scene_path)
			if extension_scene:
				var extension_node: Node = extension_scene.instantiate()
				extension_parent.add_child(extension_node)
				extension_node.add_to_group(id)  # Keep track of what to remove later
			else:
				print("Failed to load extension %s" % id)
	else:
		for ext_node in extension_parent.get_children():
			if ext_node.is_in_group(id):  # Node for extension found
				extension_parent.remove_child(ext_node)
				ext_node.queue_free()
		ExtensionsApi.check_sanity(extension.file_name)

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
	if !extension.internal:
		uninstall_button.disabled = false
	else:
		uninstall_button.disabled = true


func _on_InstalledExtensions_empty_clicked(_position: Vector2, _button_index: int) -> void:
	enable_button.disabled = true
	uninstall_button.disabled = true


func _on_AddExtensionButton_pressed() -> void:
	add_extension_file_dialog.popup_centered()


func _on_EnableButton_pressed() -> void:
	var file_name: String = extension_list.get_item_metadata(extension_selected)
	var extension: Extension = extensions[file_name]
	extension.enabled = !extension.enabled
	# Don't allow disabling internal extensions through this button.
	if extension.internal and extension.enabled_once:
		Global.preferences_dialog.preference_update(true)
	else:
		_enable_extension(extension)

	if extension.enabled:
		enable_button.text = "Disable"
	else:
		enable_button.text = "Enable"


func _on_UninstallButton_pressed() -> void:
	delete_confirmation.popup_centered()


func _on_OpenFolderButton_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path(EXTENSIONS_PATH))


func _on_AddExtensionFileDialog_files_selected(paths: PackedStringArray) -> void:
	for path in paths:
		install_extension(path)


func _on_delete_confirmation_custom_action(action: StringName) -> void:
	if action == BIN_ACTION:
		_uninstall_extension(
			extension_list.get_item_metadata(extension_selected), UninstallMode.FILE_TO_BIN
		)
	delete_confirmation.hide()


func _on_delete_confirmation_confirmed() -> void:
	_uninstall_extension(extension_list.get_item_metadata(extension_selected))
