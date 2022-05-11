class_name BaseLayer
extends Reference
# Base class for layer properties. Different layer types extend from this class.

var name := ""
var visible := true
var locked := false
var blend_mode := 0
var parent: BaseLayer
var project
var index: int

# TODO: Search for layer visbility/locked checks that should be changed to the hierarchy ones:
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


func is_visible_in_hierarchy() -> bool:
	if is_instance_valid(parent) and visible:
		return parent.is_visible_in_hierarchy()
	return visible


func is_locked_in_hierarchy() -> bool:
	if is_instance_valid(parent) and not locked:
		return parent.is_locked_in_hierarchy()
	return locked


func get_hierarchy_depth() -> int:
	if is_instance_valid(parent):
		return parent.get_hierarchy_depth() + 1
	return 0


# Functions to Override:

func serialize() -> Dictionary:
	assert(index == project.layers.find(self)) # TODO: remove once sure index is synced properly
	return {
		"name": name,
		"visible": visible,
		"locked": locked,
		"blend_mode": blend_mode,
		"parent": parent.index if is_instance_valid(parent) else -1
	}


func deserialize(dict: Dictionary) -> void:
	name = dict.name
	visible = dict.visible
	locked = dict.locked
	blend_mode = dict.get("blend_mode", 0)
	if dict.get("parent", -1) != -1:
		parent = project.layers[dict.parent]


func get_default_name(number: int) -> String:
	return tr("Layer") + " %s" % number


func can_layer_get_drawn() -> bool:
	return false


func accepts_child(_layer: BaseLayer) -> bool:
	return false
