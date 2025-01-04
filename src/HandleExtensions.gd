class_name Extensions
extends Control

signal extension_loaded(extension: Extension, extension_name: String)
signal extension_uninstalled(file_name: String)

enum UninstallMode { KEEP_FILE, FILE_TO_BIN, REMOVE_PERMANENT }

const EXTENSIONS_PATH := "user://extensions"
const BUG_EXTENSIONS_PATH := "user://give_in_bug_report"
const BIN_ACTION := "trash"

var extensions := {}  ## Extension name: Extension class
var extension_selected := -1
var damaged_extension: String
## Extensions built using the versions in this array are considered compatible with the current Api
var legacy_api_versions = [5, 4]


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


## This is an empty function at the moment, but internal extensions here should be added here
## For example:
## [code]_load_extension("ExtensionName", true)[/code]
func _add_internal_extensions() -> void:
	pass


func install_extension(path: String) -> void:
	var file_name := path.get_file()
	var err := DirAccess.copy_absolute(path, EXTENSIONS_PATH.path_join(file_name))
	if err != OK:
		print(err)
		return
	_add_extension(file_name)


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
	tester_file.store_string(file_name)
	tester_file.close()

	if extensions.has(file_name):
		uninstall_extension(file_name, UninstallMode.KEEP_FILE)
		# Wait two frames so the previous nodes can get freed
		await get_tree().process_frame
		await get_tree().process_frame

	var file_path := EXTENSIONS_PATH.path_join(file_name)
	var success := ProjectSettings.load_resource_pack(file_path)
	if !success:
		# Don't delete the extension
		# Context: pixelorama deletes v0.11.x extensions when you open v1.0, this will prevent it.
		print("EXTENSION ERROR: Failed loading resource pack %s." % file_name)
		print("There may be errors in extension code or extension is incompatible")
		# Delete the faulty.txt, its fate has already been decided
		DirAccess.remove_absolute(EXTENSIONS_PATH.path_join("Faulty.txt"))
		return
	_load_extension(file_name)


func _load_extension(extension_file_or_folder_name: StringName, internal := false) -> void:
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
		var current_api_version = ExtensionsApi.get_api_version()
		if typeof(supported_api_versions) == TYPE_ARRAY:
			supported_api_versions = PackedInt32Array(supported_api_versions)
			# Extensions that support API version 4 are backwards compatible with version 5.
			# Version 5 only adds new methods and does not break compatibility.
			# TODO: Find a better way to determine which API versions
			# have backwards compatibility with each other.
			if not current_api_version in supported_api_versions:
				for legacy_version: int in legacy_api_versions:
					if legacy_version in supported_api_versions:
						supported_api_versions.append(current_api_version)
			if not ExtensionsApi.get_api_version() in supported_api_versions:
				var err_text := (
					"The extension %s will not work on this version of Pixelorama \n"
					% file_name_no_ext
				)
				var required_text := str(
					"Extension works on API versions: %s" % str(supported_api_versions),
					"\n",
					"But Pixelorama's API version is: %s" % current_api_version
				)
				Global.popup_error(str(err_text, required_text))
				print("Incompatible API")
				if !internal:  # The file isn't created for internal extensions, no need for removal
					# Don't put it in faulty, it's merely incompatible
					DirAccess.remove_absolute(EXTENSIONS_PATH.path_join("Faulty.txt"))
				return

	var extension := Extension.new()
	extension.serialize(extension_json)
	extension.internal = internal
	extensions[extension_file_or_folder_name] = extension
	extension_loaded.emit(extension, extension_file_or_folder_name)
	# Enable internal extensions if it is the first time they are being loaded
	extension.enabled = Global.config_cache.get_value("extensions", extension.file_name, internal)
	if extension.enabled:
		enable_extension(extension)

	# If an extension doesn't crash pixelorama then it is proven innocent
	# And we should now delete its "Faulty.txt" file
	if !internal:  # the file isn't created for internal extensions, so no need to remove it
		DirAccess.remove_absolute(EXTENSIONS_PATH.path_join("Faulty.txt"))


func enable_extension(extension: Extension, save_to_config := true) -> void:
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
				add_child(extension_node)
				extension_node.add_to_group(id)  # Keep track of what to remove later
			else:
				print("Failed to load extension %s" % id)
	else:
		for ext_node in get_children():
			if ext_node.is_in_group(id):  # Node for extension found
				remove_child(ext_node)
				ext_node.queue_free()
		ExtensionsApi.check_sanity(extension.file_name)

	if save_to_config:
		Global.config_cache.set_value("extensions", extension.file_name, extension.enabled)
		Global.config_cache.save(Global.CONFIG_PATH)


func uninstall_extension(file_name := "", remove_mode := UninstallMode.REMOVE_PERMANENT) -> void:
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
	enable_extension(extension, false)

	extensions.erase(file_name)
	extension_selected = -1
	extension_uninstalled.emit(file_name)
