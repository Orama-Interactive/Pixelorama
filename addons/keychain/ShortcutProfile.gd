class_name ShortcutProfile
extends Resource

export(String) var name := ""
export(bool) var customizable := true
export(Dictionary) var bindings := {}


func _init() -> void:
	bindings = bindings.duplicate(true)


func fill_bindings() -> void:
	for action in InputMap.get_actions():
		if not action in bindings:
			bindings[action] = InputMap.get_action_list(action)


func change_action(action: String) -> void:
	if not customizable:
		return
	bindings[action] = InputMap.get_action_list(action)
	save()


func save() -> bool:
	var err := ResourceSaver.save(resource_path, self)
	if err != OK:
		print("Error saving shortcut profile %s. Error code: %s" % [resource_path, err])
		return false
	return true
