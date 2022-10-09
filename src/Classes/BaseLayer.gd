class_name BaseLayer
extends Reference
# Base class for layer properties. Different layer types extend from this class.

var name := ""
var project
var index: int
var parent: BaseLayer
var visible := true
var locked := false
var new_cels_linked := false
var cel_link_groups := []  # 2D Array of Cels (Each Array inside this represents a "link group")

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

# Links a cel to link_group. Just handles changing cel_link_groups and cel.link_group.
# Content and image_texture should be handled seperately for undo/redo related reasons.
func link_cel(cel: BaseCel, link_group: Array) -> void:
	# TODO: Should this handle a null link group (combining with unlink_cel, or be kept seperated?)
	# TODO: What if link group is equal tocurrent link group of cel to link?
	# Erase from the cel's current link_group
	if cel.link_group != null:
		cel.link_group.erase(cel)
		if cel.link_group.empty():
			cel_link_groups.erase(cel.link_group)
	# Add to link_group
	cel.link_group = link_group
	link_group.append(cel)
	if not cel_link_groups.has(link_group):
		cel_link_groups.append(link_group)

# Unlnks a cel from its link_group. Just handles changing cel_link_groups and cel.link_group.
# Content and image_texture should be handled seperately for undo/redo related reasons.
func unlink_cel(cel: BaseCel) -> void:
	if cel.link_group == null:
		return
	cel.link_group.erase(cel)
	if cel.link_group.empty():
		cel_link_groups.erase(cel.link_group)
	cel.link_group = null


# Methods to Override:


func serialize() -> Dictionary:
	assert(index == project.layers.find(self))
	# TODO H0: Serialize cel_link_groups
	return {
		"name": name,
		"visible": visible,
		"locked": locked,
		"parent": parent.index if is_instance_valid(parent) else -1
	}


func deserialize(dict: Dictionary) -> void:
	# TODO H0: Deserialize cel_link_groups
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
