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
var cel_link_sets := []  # 2D Array of Cels (Each Array inside this represents a "link set")

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

# Links a cel to link_set if its an array, or unlinks if null. Just handles changing cel_link_sets
# and cel.link_set. Content/image_texture are handled seperately for undo/redo related reasons
func link_cel(cel: BaseCel, link_set = null) -> void:
	if cel.link_set == link_set:
		return  # TODO: This shouldn't be required, so verify if this will actually compare correctly
	# Erase from the cel's current link_set
	if cel.link_set != null:
		cel.link_set.erase(cel)
		if cel.link_set.empty():
			cel_link_sets.erase(cel.link_set)
	# Add to link_set
	cel.link_set = link_set
	if link_set != null:
		link_set.append(cel)
		if not cel_link_sets.has(link_set):
			cel_link_sets.append(link_set)


# Methods to Override:


func serialize() -> Dictionary:
	assert(index == project.layers.find(self))
	# TODO H0: Figure out why saving my test project is resulting in a .pxo1 failed save (though changing it to .pxo and opening seems to work?)
	var dict := {
		"name": name,
		"visible": visible,
		"locked": locked,
		"parent": parent.index if is_instance_valid(parent) else -1
	}
	if not cel_link_sets.empty():
		var cels := []  # Cels array for easy finding of the frame index for link_set saving
		for frame in project.frames:
			cels.append(frame.cels[index])
		dict["link_sets"] = []
		for link_set in cel_link_sets:
			dict["link_sets"].append([])
			for cel in link_set:
				dict["link_sets"][-1].append(cels.find(cel))
	return dict


func deserialize(dict: Dictionary) -> void:
	name = dict.name
	visible = dict.visible
	locked = dict.locked
	if dict.get("parent", -1) != -1:
		parent = project.layers[dict.parent]
	if dict.has("link_sets"):
		for link_set in dict["link_sets"]:
			cel_link_sets.append([])
			for linked_cel_index in link_set:
				var linked_cel: BaseCel = project.frames[linked_cel_index].cels[index]
				cel_link_sets[-1].append(linked_cel)
				linked_cel.link_set = cel_link_sets[-1]
				linked_cel.set_content(cel_link_sets[-1][0].get_content())
				linked_cel.image_texture = cel_link_sets[-1][0].image_texture


func copy() -> BaseLayer:
	var copy = get_script().new(project)
	copy.project = project
	copy.index = index
	copy.deserialize(serialize())
	return copy


func new_empty_cel() -> BaseCel:
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
