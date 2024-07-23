extends Node

const PROFILES_PATH := "user://shortcut_profiles"

## [Array] of [ShortcutProfile]s.
var profiles: Array[ShortcutProfile] = [preload("profiles/default.tres")]
var selected_profile := profiles[0]  ## The currently selected [ShortcutProfile].
var profile_index := 0  ## The index of the currently selected [ShortcutProfile].
## [Dictionary] of [String] and [InputAction].
## Syntax: "action_name": InputAction.new("Action Display Name", "Group", true)
## Note that "action_name" must already exist in the Project's Input Map.
var actions := {}
## [Dictionary] of [String] and [InputGroup].
## Syntax: "Group Name": InputGroup.new("Parent Group Name")
var groups := {}
var ignore_actions: Array[StringName] = []  ## [Array] of [StringName] input map actions to ignore.
## If [code]true[/code], ignore Godot's default "ui_" input map actions.
var ignore_ui_actions := true
## A [PackedByteArray] of [bool]s with a fixed length of 4. Used for developers to allow or
## forbid setting certain types of InputEvents. The first element is for [InputEventKey]s,
## the second for [InputEventMouseButton]s, the third for [InputEventJoypadButton]s
## and the fourth for [InputEventJoypadMotion]s.
var changeable_types: PackedByteArray = [true, true, true, true]
## The file path of the [code]config_file[/code].
var config_path := "user://config.ini"
## Used to store the settings to the filesystem.
var config_file: ConfigFile


class InputAction:
	var display_name := ""
	var group := ""
	var global := true

	func _init(_display_name := "", _group := "", _global := true):
		display_name = _display_name
		group = _group
		global = _global


class InputGroup:
	var parent_group := ""
	var folded := true
	var tree_item: TreeItem

	func _init(_parent_group := "", _folded := true) -> void:
		parent_group = _parent_group
		folded = _folded


func _init() -> void:
	for locale in TranslationServer.get_loaded_locales():
		load_translation(locale)


func _ready() -> void:
	if !config_file:
		config_file = ConfigFile.new()
		if !config_path.is_empty():
			config_file.load(config_path)

	# Load shortcut profiles
	DirAccess.make_dir_recursive_absolute(PROFILES_PATH)
	var profile_dir := DirAccess.open(PROFILES_PATH)
	profile_dir.list_dir_begin()
	var file_name := profile_dir.get_next()
	while file_name != "":
		if !profile_dir.current_is_dir():
			if file_name.get_extension() == "tres":
				var file := load(PROFILES_PATH.path_join(file_name))
				if file is ShortcutProfile:
					profiles.append(file)
		file_name = profile_dir.get_next()

	# If there are no profiles besides the default, create one custom
	if profiles.size() == 1:
		var profile := ShortcutProfile.new()
		profile.name = "Custom"
		profile.resource_path = PROFILES_PATH.path_join("custom.tres")
		var saved := profile.save()
		if saved:
			profiles.append(profile)

	for profile in profiles:
		profile.fill_bindings()

	profile_index = config_file.get_value("shortcuts", "shortcuts_profile", 0)
	change_profile(profile_index)


func change_profile(index: int) -> void:
	if index >= profiles.size():
		index = profiles.size() - 1
	profile_index = index
	selected_profile = profiles[index]
	for action in selected_profile.bindings:
		action_erase_events(action)
		for event in selected_profile.bindings[action]:
			action_add_event(action, event)


func action_add_event(action: StringName, event: InputEvent) -> void:
	InputMap.action_add_event(action, event)


func action_erase_event(action: StringName, event: InputEvent) -> void:
	InputMap.action_erase_event(action, event)


func action_erase_events(action: StringName) -> void:
	InputMap.action_erase_events(action)


func load_translation(locale: String) -> void:
	var translation_file_path := "res://addons/keychain/translations".path_join(locale + ".po")
	if not ResourceLoader.exists(translation_file_path, "Translation"):
		return
	var translation := load(translation_file_path)
	if is_instance_valid(translation) and translation is Translation:
		TranslationServer.add_translation(translation)


## Converts a [param text] with snake case to a more readable format, by replacing
## underscores with spaces. If [param capitalize_first_letter] is [code]true[/code],
## the first letter of the text is capitalized.
## E.g, "snake_case" would be converted to "Snake case" if
## [param capitalize_first_letter] is [code]true[/code], else it would be converted to
## "snake case".
func humanize_snake_case(text: String, capitalize_first_letter := true) -> String:
	text = text.replace("_", " ")
	if capitalize_first_letter:
		var first_letter := text.left(1)
		first_letter = first_letter.capitalize()
		text = text.right(-1)
		text = text.insert(0, first_letter)
	return text
