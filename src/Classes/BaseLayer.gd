class_name BaseLayer
extends Reference
# Base class for layer properties. Different layer types extend from this class.

var name := ""
var visible := true
var locked := false
var parent: BaseLayer


func _init(_name := "", _visible := true, _locked := false) -> void:
	name = _name
	visible = _visible
	locked = _locked


func can_layer_get_drawn() -> bool:
	return false


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
