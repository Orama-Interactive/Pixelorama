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
var damaged_extensions := PackedStringArray()
var prev_damaged_extensions := PackedStringArray()
## Extensions built using the versions in this array are considered compatible with the current Api
var legacy_api_versions := []
var sane_timer := Timer.new()  # Used to ping that at least one session is alive during Timer's run.


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
	prev_damaged_extensions = initialize_extension_monitor()
	if !prev_damaged_extensions.is_empty():
		if prev_damaged_extensions.size() == 1:
			# gdlint: ignore=max-line-length
			var error_text = "A Faulty extension was found in previous session:\n%s\nIt will be moved to:\n%s"
			var extension_name = prev_damaged_extensions[0]
			Global.popup_error(
				error_text % [extension_name, ProjectSettings.globalize_path(BUG_EXTENSIONS_PATH)]
			)
		else:
			Global.popup_error(
				"Previous session crashed, extensions are automatically disabled as a precausion"
			)

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
	var file_name := path.uri_decode().get_file()
	var err := DirAccess.copy_absolute(path, EXTENSIONS_PATH.path_join(file_name))
	if err != OK:
		var msg := tr("Extension failed to install. Error code %s (%s)") % [err, error_string(err)]
		Global.popup_error(msg)
		return
	_add_extension(file_name)


func _add_extension(file_name: String) -> void:
	add_suspicion(file_name)
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
		clear_suspicion(file_name)
		return
	_load_extension(file_name)


func _load_extension(extension_file_or_folder_name: StringName, internal := false) -> void:
	var file_name_no_ext := extension_file_or_folder_name.uri_decode().get_basename()
	var extension_path := "res://src/Extensions/%s/" % file_name_no_ext
	var extension_config_file_path := extension_path.path_join("extension.json")
	var extension_config_file := FileAccess.open(extension_config_file_path, FileAccess.READ)
	var err := FileAccess.get_open_error()
	if err != OK:
		var msg := (
			tr("Error loading extension config file. Error code %s (%s)") % [err, error_string(err)]
		)
		Global.popup_error(msg)
		if extension_config_file:
			extension_config_file.close()
		return

	var test_json_conv := JSON.new()
	test_json_conv.parse(extension_config_file.get_as_text())
	var extension_json = test_json_conv.get_data()
	extension_config_file.close()

	if not extension_json:
		Global.popup_error(tr("No JSON data found in the extension."))
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
					clear_suspicion(extension_file_or_folder_name)
				return

	var extension := Extension.new()
	extension.serialize(extension_json)
	extension.internal = internal
	extensions[extension_file_or_folder_name] = extension
	extension_loaded.emit(extension, extension_file_or_folder_name)
	# Enable internal extensions if it is the first time they are being loaded
	extension.enabled = Global.config_cache.get_value("extensions", extension.file_name, internal)
	# If this extension was enabled in previous session (which crashed) then disable it.
	if extension_file_or_folder_name in prev_damaged_extensions:
		Global.config_cache.set_value("extensions", extension.file_name, false)
		extension.enabled = false

	if extension.enabled:
		enable_extension(extension)

	# if extension is loaded and enabled successfully then update suspicion
	if !internal:  # the file isn't created for internal extensions, so no need to remove it.
		# At this point the extension has been enabled (and has added it's nodes) successfully
		# If an extension misbehaves at this point, we are certain which on it is so we will
		# quarantine it in the next session.
		clear_suspicion(extension_file_or_folder_name)


func enable_extension(extension: Extension, save_to_config := true) -> void:
	var extension_path: String = "res://src/Extensions/%s/" % extension.file_name

	# If an Extension has nodes, it may still crash pixelorama so it is still not cleared from
	# suspicion, keep an eve on them (When we enable them)
	if !extension.nodes.is_empty():
		await get_tree().process_frame
		# NOTE: await will make sure the below line of code will run AFTER all required extensions
		# are enabled. (At this point we are no longer exactly sure which extension is faulty). so
		# we shall disable All enabled extensions in next session if any of them misbehave.
		add_suspicion(str(extension.file_name, ".pck"))

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
				# Keep an eye on extension nodes, so that they don't misbehave
				extension_node.tree_exited.connect(
					clear_suspicion.bind(str(extension.file_name, ".pck"))
				)
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


func initialize_extension_monitor() -> PackedStringArray:
	var tester_file: FileAccess  # For testing and deleting damaged extensions
	# Remove any extension that was proven guilty before this extension is loaded
	sane_timer.wait_time = 10  # Ping that at least one session is alive during this time
	add_child(sane_timer)
	sane_timer.timeout.connect(update_monitoring_time)
	sane_timer.start()
	if FileAccess.file_exists(EXTENSIONS_PATH.path_join("Monitoring.ini")):
		# This code will decide if pixelorama crashed or not
		var faulty_path := EXTENSIONS_PATH.path_join("Monitoring.ini")
		tester_file = FileAccess.open(faulty_path, FileAccess.READ)
		var last_update_time = str_to_var(tester_file.get_line())
		var damaged_extension_names = str_to_var(tester_file.get_line())
		tester_file.close()
		if typeof(last_update_time) == TYPE_INT:
			if int(Time.get_unix_time_from_system()) - last_update_time <= sane_timer.wait_time:
				return PackedStringArray()  # Assume the file is still in use (session didn't crash)
		# If this line is reached then it's likely that the app crashed last session
		DirAccess.remove_absolute(EXTENSIONS_PATH.path_join("Monitoring.ini"))
		if typeof(damaged_extension_names) == TYPE_PACKED_STRING_ARRAY:
			if damaged_extension_names.size() == 1:  # We are certain which extension crashed
				# NOTE: get_file() is used as a countermeasure towards possible malicious tampering
				# with Monitoring.ini file (to inject paths leading outside EXTENSIONS_PATH using "../")
				var extension_name = damaged_extension_names[0].get_file()
				DirAccess.make_dir_recursive_absolute(BUG_EXTENSIONS_PATH)
				if FileAccess.file_exists(EXTENSIONS_PATH.path_join(extension_name)):
					# don't delete the extension permanently
					# (so that it may be given to the developer in the bug report)
					DirAccess.rename_absolute(
						EXTENSIONS_PATH.path_join(extension_name),
						BUG_EXTENSIONS_PATH.path_join(extension_name)
					)
			return damaged_extension_names
	return PackedStringArray()


func add_suspicion(extension_name: StringName):
	# The new (about to load) extension will be considered guilty till it's proven innocent
	if not extension_name in damaged_extensions:
		var tester_file := FileAccess.open(
			EXTENSIONS_PATH.path_join("Monitoring.ini"), FileAccess.WRITE
		)
		damaged_extensions.append(extension_name)
		tester_file.store_line(var_to_str(int(Time.get_unix_time_from_system())))
		tester_file.store_line(var_to_str(damaged_extensions))
		tester_file.close()


func clear_suspicion(extension_name: StringName):
	if extension_name in damaged_extensions:
		damaged_extensions.remove_at(damaged_extensions.find(extension_name))
	# Delete the faulty.txt, if there are no more damaged extensions, else update it
	if !damaged_extensions.is_empty():
		var tester_file := FileAccess.open(
			EXTENSIONS_PATH.path_join("Monitoring.ini"), FileAccess.WRITE
		)
		tester_file.store_line(var_to_str(int(Time.get_unix_time_from_system())))
		tester_file.store_line(var_to_str(damaged_extensions))
		tester_file.close()
	else:
		DirAccess.remove_absolute(EXTENSIONS_PATH.path_join("Monitoring.ini"))


func update_monitoring_time():
	var tester_file := FileAccess.open(EXTENSIONS_PATH.path_join("Monitoring.ini"), FileAccess.READ)
	var active_extensions_str: String
	if FileAccess.get_open_error() == OK:
		tester_file.get_line()  # Ignore first line
		active_extensions_str = tester_file.get_line()
		tester_file.close()
	tester_file = FileAccess.open(EXTENSIONS_PATH.path_join("Monitoring.ini"), FileAccess.WRITE)
	tester_file.store_line(var_to_str(int(Time.get_unix_time_from_system())))
	tester_file.store_line(active_extensions_str)
	tester_file.close()
