class_name ShortcutProfile
extends Resource

export(String) var name := ""
export(bool) var customizable := true
export(Dictionary) var bindings := {}


func _init() -> void:
	bindings = bindings.duplicate(true)


func fill_bindings() -> void:
	var unnecessary_actions = bindings.duplicate()  # Checks if the profile has any unused actions
	for action in InputMap.get_actions():
		if not action in bindings:
			bindings[action] = InputMap.get_action_list(action)
		unnecessary_actions.erase(action)
	for action in unnecessary_actions:
		bindings.erase(action)
	save()


func change_action(action: String) -> void:
	if not customizable:
		return
	bindings[action] = InputMap.get_action_list(action)
	save()


func save() -> bool:
	if !customizable:
		return false
	var err := ResourceSaver.save(resource_path, self)
	if err != OK:
		print("Error saving shortcut profile %s. Error code: %s" % [resource_path, err])
		return false
	return true
