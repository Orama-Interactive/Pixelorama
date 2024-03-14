extends Button

## The entire purpose of this script is to handle layer drag and dropping.

var layer_index := 0
var hierarchy_depth_pixel_shift := 16


func _get_drag_data(_position: Vector2) -> Variant:
	var layer := Global.current_project.layers[layer_index]
	var layers := range(layer_index - layer.get_child_count(true), layer_index + 1)
	var box := VBoxContainer.new()
	for i in layers.size():
		var button := Button.new()
		button.custom_minimum_size = size
		button.theme = Global.control.theme
		button.text = Global.current_project.layers[layers[-1 - i]].name
		box.add_child(button)
	set_drag_preview(box)

	return ["Layer", layer_index]


func _can_drop_data(_pos: Vector2, data) -> bool:
	if typeof(data) != TYPE_ARRAY:
		Global.animation_timeline.drag_highlight.visible = false
		return false
	if data[0] != "Layer":
		Global.animation_timeline.drag_highlight.visible = false
		return false
	var curr_layer: BaseLayer = Global.current_project.layers[layer_index]
	var drag_layer: BaseLayer = Global.current_project.layers[data[1]]
	if curr_layer == drag_layer:
		Global.animation_timeline.drag_highlight.visible = false
		return false

	var region: Rect2
	var depth := curr_layer.get_hierarchy_depth()
	if Input.is_action_pressed(&"ctrl"):  # Swap layers
		if drag_layer.is_ancestor_of(curr_layer) or curr_layer.is_ancestor_of(drag_layer):
			Global.animation_timeline.drag_highlight.visible = false
			return false
		region = get_global_rect()
	else:  # Shift layers
		if drag_layer.is_ancestor_of(curr_layer):
			Global.animation_timeline.drag_highlight.visible = false
			return false
		# If accepted as a child, is it in the center region?
		if (
			curr_layer.accepts_child(drag_layer)
			and _get_region_rect(0.25, 0.75).has_point(get_global_mouse_position())
		):
			# Drawn regions are adjusted a bit from actual to clarify drop position
			region = _get_region_rect(0.15, 0.85)
			depth += 1
		else:
			# Top or bottom region?
			if _get_region_rect(0, 0.5).has_point(get_global_mouse_position()):
				region = _get_region_rect(-0.1, 0.15)
			else:
				region = _get_region_rect(0.85, 1.1)
	# Shift drawn region to the right a bit for hierarchy depth visualization:
	region.position.x += depth * hierarchy_depth_pixel_shift
	region.size.x -= depth * hierarchy_depth_pixel_shift
	Global.animation_timeline.drag_highlight.global_position = region.position
	Global.animation_timeline.drag_highlight.size = region.size
	Global.animation_timeline.drag_highlight.visible = true
	return true


func _drop_data(_pos: Vector2, data) -> void:
	var drop_layer: int = data[1]
	var project := Global.current_project
	project.undo_redo.create_action("Change Layer Order")
	var layers: Array = project.layers  # This shouldn't be modified directly
	var drop_from_indices := range(
		drop_layer - layers[drop_layer].get_child_count(true), drop_layer + 1
	)
	var drop_from_parents := []
	for i in range(drop_from_indices.size()):
		drop_from_parents.append(layers[drop_from_indices[i]].parent)

	if Input.is_action_pressed("ctrl"):  # Swap layers
		# a and b both need "from", "to", and "to_parents"
		# a is this layer (and children), b is the dropped layers
		var a := {
			"from": range(layer_index - layers[layer_index].get_child_count(true), layer_index + 1)
		}
		var b := {"from": drop_from_indices}

		if a.from[0] < b.from[0]:
			a["to"] = range(b.from[-1] + 1 - a.from.size(), b.from[-1] + 1)  # Size of a, start from end of b
			b["to"] = range(a.from[0], a.from[0] + b.from.size())  # Size of b, start from beginning of a
		else:
			a["to"] = range(b.from[0], b.from[0] + a.from.size())  # Size of a, start from beginning of b
			b["to"] = range(a.from[-1] + 1 - b.from.size(), a.from[-1] + 1)  # Size of b, start from end of a

		var a_from_parents := []
		for l in a.from:
			a_from_parents.append(layers[l].parent)

		# to_parents starts as a dulpicate of from_parents, set the root layer's (with one layer or
		# group with its children, this will always be the last layer [-1]) parent to the other
		# root layer's parent
		a["to_parents"] = a_from_parents.duplicate()
		b["to_parents"] = drop_from_parents.duplicate()
		a.to_parents[-1] = drop_from_parents[-1]
		b.to_parents[-1] = a_from_parents[-1]

		project.undo_redo.add_do_method(project.swap_layers.bind(a, b))
		project.undo_redo.add_undo_method(
			project.swap_layers.bind(
				{"from": a.to, "to": a.from, "to_parents": a_from_parents},
				{"from": b.to, "to": drop_from_indices, "to_parents": drop_from_parents}
			)
		)

	else:  # Move layers
		var to_index: int  # the index where the LOWEST moved layer should end up
		var to_parent: BaseLayer
		# If accepted as a child, is it in the center region?
		if (
			layers[layer_index].accepts_child(layers[drop_layer])
			and _get_region_rect(0.25, 0.75).has_point(get_global_mouse_position())
		):
			to_index = layer_index
			to_parent = layers[layer_index]
		else:
			# Top or bottom region?
			if _get_region_rect(0, 0.5).has_point(get_global_mouse_position()):
				to_index = layer_index + 1
				to_parent = layers[layer_index].parent
			else:
				# Place under the layer, if it has children, place after its lowest child
				if layers[layer_index].has_children():
					to_index = layers[layer_index].get_children(true)[0].index

					if layers[layer_index].is_ancestor_of(layers[drop_layer]):
						to_index += drop_from_indices.size()
				else:
					to_index = layer_index
				to_parent = layers[layer_index].parent

		if drop_layer < layer_index:
			to_index -= drop_from_indices.size()

		var drop_to_indices := range(to_index, to_index + drop_from_indices.size())
		var to_parents := drop_from_parents.duplicate()
		to_parents[-1] = to_parent

		project.undo_redo.add_do_method(
			project.move_layers.bind(drop_from_indices, drop_to_indices, to_parents)
		)
		project.undo_redo.add_undo_method(
			project.move_layers.bind(drop_to_indices, drop_from_indices, drop_from_parents)
		)
	if project.current_layer == drop_layer:
		project.undo_redo.add_do_method(project.change_cel.bind(-1, layer_index))
	else:
		project.undo_redo.add_do_method(project.change_cel.bind(-1, project.current_layer))
	project.undo_redo.add_undo_method(project.change_cel.bind(-1, project.current_layer))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.commit_action()


func _get_region_rect(y_begin: float, y_end: float) -> Rect2:
	var rect := get_global_rect()
	rect.position.y += rect.size.y * y_begin
	rect.size.y *= y_end - y_begin
	return rect
