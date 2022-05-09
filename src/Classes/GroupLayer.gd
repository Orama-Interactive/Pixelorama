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

# Returns true if this is a direct or indirect parent of layer
func is_a_parent_of(layer: BaseLayer) -> bool:
	if layer.parent == self:
		return true
	elif is_instance_valid(layer.parent):
		return is_a_parent_of(layer.parent)
	return false

# TODO: Consider going backwards in get_children functions, to allow breaking
func get_children_direct() -> Array:
	var children := []
	for i in range(index):
		if project.layers[i].parent == self:
			children.append(project.layers[i])
	return children


func get_children_recursive() -> Array:
	var children := []
	for i in range(index):
		if is_a_parent_of(project.layers[i]):
			children.append(project.layers[i])
	return children


func has_children() -> bool:
	if index == 0:
		return false
	return project.layers[index - 1].parent == self


# Overridden Functions:

func serialize() -> Dictionary:
	var data = .serialize()
	data["type"] = Global.LayerTypes.GROUP
	data["expanded"] = expanded
	return data


func deserialize(dict: Dictionary) -> void:
	.deserialize(dict)
	expanded = dict.expanded


func get_default_name(number: int) -> String:
	return tr("Group") + " %s" % number


func accepts_child(layer: BaseLayer) -> bool:
	return true
