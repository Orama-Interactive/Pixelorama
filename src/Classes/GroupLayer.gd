class_name GroupLayer
extends BaseLayer
# A class for group layer properties

#var children := []
var expanded := true

func _init(_name := "") -> void:
	name = _name


func serialize() -> Dictionary:
	var data = .serialize()
	data["type"] = "group"
	data["expanded"] = expanded
	return data


func deserialize(dict: Dictionary) -> void:
	.deserialize(dict)
	expanded = dict.expanded


func is_expanded_in_hierarchy() -> bool:
	if is_instance_valid(parent) and expanded:
		return parent.is_expanded_in_hierarchy()
	return expanded
