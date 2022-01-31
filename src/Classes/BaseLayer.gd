class_name BaseLayer
extends Reference
# Base class for layer properties. Different layer types extend from this class.

var project
var name := ""
var visible := true
var locked := false
var parent: BaseLayer


func serialize() -> Dictionary:
	return {
		"name": name,
		"visible": visible,
		"locked": locked,
		"parent": project.layers.find(parent) if is_instance_valid(parent) else -1
	}


func deserialize(dict: Dictionary) -> void:
	name = dict.name
	visible = dict.visible
	locked = dict.locked
	if dict.get("parent", -1) != -1:
		parent = project.layers[dict.parent]


func can_layer_get_drawn() -> bool:
	return false


# TODO: Search for layer visbility/locked checks that should be changed to the hierarchy ones:
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
