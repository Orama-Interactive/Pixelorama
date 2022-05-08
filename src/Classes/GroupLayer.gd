class_name GroupLayer
extends BaseLayer
# A class for group layer properties

var expanded := true

func _init(_name := "") -> void:
	name = _name


func is_expanded_in_hierarchy() -> bool:
	if is_instance_valid(parent) and expanded:
		return parent.is_expanded_in_hierarchy()
	return expanded


func is_an_ancestor_of(layer: BaseLayer) -> bool:
	if layer.parent == self:
		return true
	elif is_instance_valid(layer.parent):
		return is_an_ancestor_of(layer.parent)
	return false

# Only gets direct children
func get_children() -> Array:
	var children := []
	# TODO: Consider going backwards, to allow breaking
	for i in range(index):
		if project.layers[i].parent == self:
			children.append(project.layers[i])
	return children

# Gets both direct AND indirect children
func get_successors() -> Array:
	var successors := []
	# TODO: Consider going backwards, to allow breaking
	for i in range(index):
		if is_an_ancestor_of(project.layers[i]):
			successors.append(project.layers[i])
	return successors


func has_children() -> bool:
	if index == 0:
		return false
	return project.layers[index - 1].parent == self


# Overridden Functions:

func serialize() -> Dictionary:
	var data = .serialize()
	data["type"] = "group"
	data["expanded"] = expanded
	return data


func deserialize(dict: Dictionary) -> void:
	.deserialize(dict)
	expanded = dict.expanded


func accepts_child(layer: BaseLayer) -> bool:
	return true
