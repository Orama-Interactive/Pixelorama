@tool
class_name DockableLayoutNode
extends Resource
## Base class for DockableLayout tree nodes

var parent: DockableLayoutSplit:
	get:
		return _parent_ref.get_ref()
	set(value):
		_parent_ref = weakref(value)

var _parent_ref := WeakRef.new()


func emit_tree_changed() -> void:
	var node := self
	while node:
		node.emit_changed()
		node = node.parent


## Returns whether there are any nodes
func is_empty() -> bool:
	return true


## Returns all tab names in this node
func get_names() -> PackedStringArray:
	return PackedStringArray()
