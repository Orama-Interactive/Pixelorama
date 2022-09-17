class_name BaseLayer
extends Reference
# Base class for layer properties. Different layer types extend from this class.

var name := ""
var visible := true
var locked := false
var parent: BaseLayer
var project
var index: int

# Returns true if this is a direct or indirect parent of layer
func is_a_parent_of(layer: BaseLayer) -> bool:
	if layer.parent == self:
		return true
	elif is_instance_valid(layer.parent):
		return is_a_parent_of(layer.parent)
	return false


func get_children(recursive: bool) -> Array:
	var children := []
	if recursive:
		for i in index:
			if is_a_parent_of(project.layers[i]):
				children.append(project.layers[i])
	else:
		for i in index:
			if project.layers[i].parent == self:
				children.append(project.layers[i])
	return children


func get_child_count(recursive: bool) -> int:
	var count := 0
	if recursive:
		for i in index:
			if is_a_parent_of(project.layers[i]):
				count += 1
	else:
		for i in index:
			if project.layers[i].parent == self:
				count += 1
	return count


func has_children() -> bool:
	if index == 0:
		return false
	return project.layers[index - 1].parent == self


func is_expanded_in_hierarchy() -> bool:
	if is_instance_valid(parent):
		return parent.expanded and parent.is_expanded_in_hierarchy()
	return true


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


func get_layer_path() -> String:
	if is_instance_valid(parent):
		return str(parent.get_layer_path(), "/", name)
	return name

# Methods to Override:

func serialize() -> Dictionary:
	assert(index == project.layers.find(self))
	return {
		"name": name,
		"visible": visible,
		"locked": locked,
		"parent": parent.index if is_instance_valid(parent) else -1
	}


func deserialize(dict: Dictionary) -> void:
	name = dict.name
	visible = dict.visible
	locked = dict.locked
	if dict.get("parent", -1) != -1:
		parent = project.layers[dict.parent]


func copy() -> BaseLayer:
	var copy = get_script().new(project)
	copy.project = project
	copy.index = index
	copy.deserialize(serialize())
	return copy


func new_empty_cel() -> BaseCel:
	return null


func copy_cel(_frame: int, _linked: bool) -> BaseCel:
	return null

# Used to copy all cels with cel linking properly set up between this set of copies:
func copy_all_cels() -> Array:
	return []


func set_name_to_default(number: int) -> void:
	name = tr("Layer") + " %s" % number


func can_layer_get_drawn() -> bool:
	return false


func accepts_child(_layer: BaseLayer) -> bool:
	return false


func instantiate_layer_button() -> Node:
	return null
