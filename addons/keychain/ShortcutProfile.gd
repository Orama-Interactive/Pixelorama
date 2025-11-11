class_name ShortcutProfile
extends Resource

@export var name := ""
@export var customizable := true
@export var bindings: Dictionary[StringName, Array] = {}
@export var mouse_movement_options: Dictionary[StringName, Dictionary] = {}


func _init() -> void:
	bindings = bindings.duplicate(true)
	fill_bindings(false)


func fill_bindings(should_save := true) -> void:
	var unnecessary_actions = bindings.duplicate()  # Checks if the profile has any unused actions
	for action in InputMap.get_actions():
		if not action in bindings:
			bindings[action] = InputMap.action_get_events(action)
		unnecessary_actions.erase(action)
	for action in unnecessary_actions:
		bindings.erase(action)
	if should_save:
		save()


func copy_bindings_from(other_profile: ShortcutProfile) -> void:
	bindings = other_profile.bindings.duplicate(true)
	mouse_movement_options = other_profile.mouse_movement_options.duplicate(true)
	save()


func change_action(action_name: String) -> void:
	if not customizable:
		return
	bindings[action_name] = InputMap.action_get_events(action_name)
	save()


func save() -> bool:
	if !customizable:
		return false
	var err := ResourceSaver.save(self, resource_path)
	if err != OK:
		print("Error saving shortcut profile %s. Error code: %s" % [resource_path, err])
		return false
	return true
