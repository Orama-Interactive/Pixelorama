class_name BaseLayer
extends RefCounted
## Base class for layer properties. Different layer types extend from this class.

var name := ""  ## Name of the layer.
var project: Project  ## Project, the layer belongs to.
var index: int  ##  Index of layer in the timeline.
var parent: BaseLayer  ##  Parent of the layer.
var visible := true  ##  Sets visibility of the layer.
var locked := false  ##  Images of a locked layer won't be overritten.
var new_cels_linked := false  ##  Determins if new cel of the layer should be linked or not.
var cel_link_sets: Array[Dictionary] = []  ## Each Dictionary represents a cel's "link set"


## Returns true if this is a direct or indirect parent of layer
func is_ancestor_of(layer: BaseLayer) -> bool:
	if layer.parent == self:
		return true
	elif is_instance_valid(layer.parent):
		return is_ancestor_of(layer.parent)
	return false


## Returns an [Array] of layers that are children of this layer.
## The process is recursive if [param recursive] is [code]true[/code].
func get_children(recursive: bool) -> Array[BaseLayer]:
	var children: Array[BaseLayer] = []
	if recursive:
		for i in index:
			if is_ancestor_of(project.layers[i]):
				children.append(project.layers[i])
	else:
		for i in index:
			if project.layers[i].parent == self:
				children.append(project.layers[i])
	return children


## Returns the number of child nodes.
## The process is recursive if [param recursive] is [code]true[/code].
func get_child_count(recursive: bool) -> int:
	var count := 0
	if recursive:
		for i in index:
			if is_ancestor_of(project.layers[i]):
				count += 1
	else:
		for i in index:
			if project.layers[i].parent == self:
				count += 1
	return count


## Tells if the layer has child layers ([code]true[/code]) or not ([code]false[/code]).
func has_children() -> bool:
	if index == 0:
		return false
	return project.layers[index - 1].parent == self


## Tells if the layer is expanded ([code]true[/code]) or collapsed ([code]false[/code])
## in the hierarchy.
func is_expanded_in_hierarchy() -> bool:
	if is_instance_valid(parent):
		# "expanded" variable is located in GroupLayer.gd
		return parent.expanded and parent.is_expanded_in_hierarchy()
	return true


## Tells if the layer's content is visible ([code]true[/code]) or hidden ([code]false[/code])
## in the layer tree. This is influenced by the eye button.
func is_visible_in_hierarchy() -> bool:
	if is_instance_valid(parent) and visible:
		return parent.is_visible_in_hierarchy()
	return visible


## Tells if the layer's content is locked ([code]true[/code]) or not ([code]false[/code])
## in the layer tree. This is influenced by the lock button.
func is_locked_in_hierarchy() -> bool:
	if is_instance_valid(parent) and not locked:
		return parent.is_locked_in_hierarchy()
	return locked


## Returns the number of parents above this layer.
func get_hierarchy_depth() -> int:
	if is_instance_valid(parent):
		return parent.get_hierarchy_depth() + 1
	return 0


## Returns the path of the layer in the timeline as a [String]
func get_layer_path() -> String:
	if is_instance_valid(parent):
		return str(parent.get_layer_path(), "/", name)
	return name


## Links a cel to link_set if its a Dictionary, or unlinks if null.
## Content/image_texture are handled separately for undo related reasons
func link_cel(cel: BaseCel, link_set = null) -> void:
	# Erase from the cel's current link_set
	if cel.link_set != null:
		if cel.link_set.has("cels"):
			cel.link_set["cels"].erase(cel)
			if cel.link_set["cels"].is_empty():
				cel_link_sets.erase(cel.link_set)
		else:
			cel_link_sets.erase(cel.link_set)
	# Add to link_set
	cel.link_set = link_set
	if link_set != null:
		if not link_set.has("cels"):
			link_set["cels"] = []
		link_set["cels"].append(cel)
		if not cel_link_sets.has(link_set):
			if not link_set.has("hue"):
				var hues := PackedFloat32Array()
				for other_link_set in cel_link_sets:
					hues.append(other_link_set["hue"])
				if hues.is_empty():
					link_set["hue"] = Color.GREEN.h
				else:  # Calculate the largest gap in hue between existing link sets:
					hues.sort()
					# Start gap between the highest and lowest hues, otherwise its hard to include
					var largest_gap_pos := hues[-1]
					var largest_gap_size := 1.0 - (hues[-1] - hues[0])
					for h in hues.size() - 1:
						var gap_size: float = hues[h + 1] - hues[h]
						if gap_size > largest_gap_size:
							largest_gap_pos = hues[h]
							largest_gap_size = gap_size
					link_set["hue"] = wrapf(largest_gap_pos + largest_gap_size / 2.0, 0, 1)
			cel_link_sets.append(link_set)


# Methods to Override:


## Returns a curated [Dictionary] containing the layer data.
func serialize() -> Dictionary:
	assert(index == project.layers.find(self))
	var dict := {
		"name": name,
		"visible": visible,
		"locked": locked,
		"parent": parent.index if is_instance_valid(parent) else -1
	}
	if not cel_link_sets.is_empty():
		var cels := []  # Cels array for easy finding of the frame index for link_set saving
		for frame in project.frames:
			cels.append(frame.cels[index])
		dict["link_sets"] = []
		for link_set in cel_link_sets:
			dict["link_sets"].append({"cels": [], "hue": link_set["hue"]})
			for cel in link_set["cels"]:
				dict["link_sets"][-1]["cels"].append(cels.find(cel))
	return dict


## Sets the layer data according to a curated [Dictionary] obtained from [method serialize].
func deserialize(dict: Dictionary) -> void:
	name = dict.name
	visible = dict.visible
	locked = dict.locked
	if dict.get("parent", -1) != -1:
		parent = project.layers[dict.parent]
	if dict.has("linked_cels") and not dict["linked_cels"].is_empty():  # Backwards compatibility
		dict["link_sets"] = [{"cels": dict["linked_cels"], "hue": Color.GREEN.h}]
	if dict.has("link_sets"):
		for serialized_link_set in dict["link_sets"]:
			var link_set := {"cels": [], "hue": serialized_link_set["hue"]}
			for linked_cel_index in serialized_link_set["cels"]:
				var cel: BaseCel = project.frames[linked_cel_index].cels[index]
				link_set["cels"].append(cel)
				cel.link_set = link_set
				var linked_cel: BaseCel = link_set["cels"][0]
				cel.set_content(linked_cel.get_content(), linked_cel.image_texture)
			cel_link_sets.append(link_set)


## Returns a layer type that is one of the [param LayerTypes]
## enum in ["src/Autoload/Global.gd"] Autoload.
func get_layer_type() -> int:
	return -1


## Returns a new empty [BaseCel]
func new_empty_cel() -> BaseCel:
	return null


## Sets layer name to the default name followed by [param number].
func set_name_to_default(number: int) -> void:
	name = tr("Layer") + " %s" % number


## Tells if the user is allowed to draw on current layer ([code]true[/code])
## or not ([code]false[/code]).
func can_layer_get_drawn() -> bool:
	return false


## Tells if the layer allows child layers ([code]true[/code]) or not ([code]true[/code])
func accepts_child(_layer: BaseLayer) -> bool:
	return false


## Returns an instance of the layer button that will be added to the timeline.
func instantiate_layer_button() -> Node:
	return null
