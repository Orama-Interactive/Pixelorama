class_name LayerButton
extends Button

const HIERARCHY_DEPTH_PIXEL_SHIFT := 8

var layer_index := 0

@onready var expand_button := %ExpandButton as BaseButton
@onready var visibility_button := %VisibilityButton as BaseButton
@onready var lock_button := %LockButton as BaseButton
@onready var label := %LayerNameLabel as Label
@onready var line_edit := %LayerNameLineEdit as LineEdit
@onready var hierarchy_spacer := %HierarchySpacer as Control
@onready var linked_button := %LinkButton as BaseButton


func _ready() -> void:
	Global.cel_switched.connect(func(): z_index = 1 if button_pressed else 0)
	var layer := Global.current_project.layers[layer_index]
	if layer is PixelLayer:
		linked_button.visible = true
	elif layer is GroupLayer:
		expand_button.visible = true
	custom_minimum_size.y = Global.animation_timeline.cel_size

	label.text = layer.name
	line_edit.text = layer.name

	var layer_buttons := find_child("LayerButtons")
	for child in layer_buttons.get_children():
		var texture = child.get_child(0)
		texture.modulate = Global.modulate_icon_color

	# Visualize how deep into the hierarchy the layer is
	var hierarchy_depth := layer.get_hierarchy_depth()
	hierarchy_spacer.custom_minimum_size.x = hierarchy_depth * HIERARCHY_DEPTH_PIXEL_SHIFT

	if Global.control.theme.get_color("font_color", "Button").v > 0.5:  # Light text is dark theme
		self_modulate.v = 1 + hierarchy_depth * 0.4
	else:  # Dark text should be light theme
		self_modulate.v = 1 - hierarchy_depth * 0.075

	update_buttons()
	await get_tree().process_frame
	queue_redraw()


func update_buttons() -> void:
	var layer := Global.current_project.layers[layer_index]
	if layer is GroupLayer:
		if layer.expanded:
			Global.change_button_texturerect(expand_button.get_child(0), "group_expanded.png")
		else:
			Global.change_button_texturerect(expand_button.get_child(0), "group_collapsed.png")

	if layer.visible:
		Global.change_button_texturerect(visibility_button.get_child(0), "layer_visible.png")
	else:
		Global.change_button_texturerect(visibility_button.get_child(0), "layer_invisible.png")

	if layer.locked:
		Global.change_button_texturerect(lock_button.get_child(0), "lock.png")
	else:
		Global.change_button_texturerect(lock_button.get_child(0), "unlock.png")

	if linked_button:
		if layer.new_cels_linked:  # If new layers will be linked
			Global.change_button_texturerect(linked_button.get_child(0), "linked_layer.png")
		else:
			Global.change_button_texturerect(linked_button.get_child(0), "unlinked_layer.png")

	visibility_button.modulate.a = 1
	lock_button.modulate.a = 1
	if is_instance_valid(layer.parent):
		if not layer.parent.is_visible_in_hierarchy():
			visibility_button.modulate.a = 0.33
		if layer.parent.is_locked_in_hierarchy():
			lock_button.modulate.a = 0.33


## When pressing a button, change the appearance of other layers (ie: expand or visible)
func _update_buttons_all_layers() -> void:
	var layer := Global.current_project.layers[layer_index]
	for layer_button in Global.layer_vbox.get_children():
		layer_button.update_buttons()
		var expanded := layer.is_expanded_in_hierarchy()
		layer_button.visible = expanded
		Global.cel_vbox.get_child(layer_button.get_index()).visible = expanded


func _draw() -> void:
	if hierarchy_spacer.size.x > 0.1:
		var color := Color(1, 1, 1, 0.33)
		color.v = roundf(Global.control.theme.get_color("font_color", "Button").v)
		var x := hierarchy_spacer.global_position.x - global_position.x + hierarchy_spacer.size.x
		draw_line(Vector2(x, 0), Vector2(x, size.y), color)


func _input(event: InputEvent) -> void:
	if (
		(event.is_action_released(&"ui_accept") or event.is_action_released(&"ui_cancel"))
		and line_edit.visible
		and event.keycode != KEY_SPACE
	):
		_save_layer_name(line_edit.text)


func _on_LayerContainer_gui_input(event: InputEvent) -> void:
	var project := Global.current_project

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		Global.canvas.selection.transform_content_confirm()
		var prev_curr_layer := project.current_layer
		if Input.is_action_pressed(&"shift"):
			var layer_diff_sign := signi(layer_index - prev_curr_layer)
			if layer_diff_sign == 0:
				layer_diff_sign = 1
			for i in range(0, project.frames.size()):
				for j in range(prev_curr_layer, layer_index + layer_diff_sign, layer_diff_sign):
					var frame_layer := [i, j]
					if !project.selected_cels.has(frame_layer):
						project.selected_cels.append(frame_layer)
			project.change_cel(-1, layer_index)
		elif Input.is_action_pressed(&"ctrl"):
			for i in range(0, project.frames.size()):
				var frame_layer := [i, layer_index]
				if !project.selected_cels.has(frame_layer):
					project.selected_cels.append(frame_layer)
			project.change_cel(-1, layer_index)
		else:  # If the button is pressed without Shift or Control
			_select_current_layer()

		if event.double_click:
			label.visible = false
			line_edit.visible = true
			line_edit.editable = true
			line_edit.grab_focus()


func _on_LineEdit_focus_exited() -> void:
	_save_layer_name(line_edit.text)


func _save_layer_name(new_name: String) -> void:
	label.visible = true
	line_edit.visible = false
	line_edit.editable = false
	label.text = new_name
	if layer_index < Global.current_project.layers.size():
		Global.current_project.layers[layer_index].name = new_name


func _on_ExpandButton_pressed() -> void:
	var layer := Global.current_project.layers[layer_index]
	layer.expanded = !layer.expanded
	_update_buttons_all_layers()


func _on_VisibilityButton_pressed() -> void:
	Global.canvas.selection.transform_content_confirm()
	var layer := Global.current_project.layers[layer_index]
	layer.visible = !layer.visible
	Global.canvas.update_all_layers = true
	Global.canvas.queue_redraw()
	if Global.select_layer_on_button_click:
		_select_current_layer()
	_update_buttons_all_layers()


func _on_LockButton_pressed() -> void:
	Global.canvas.selection.transform_content_confirm()
	var layer := Global.current_project.layers[layer_index]
	layer.locked = !layer.locked
	if Global.select_layer_on_button_click:
		_select_current_layer()
	_update_buttons_all_layers()


func _on_LinkButton_pressed() -> void:
	Global.canvas.selection.transform_content_confirm()
	var layer := Global.current_project.layers[layer_index]
	if not layer is PixelLayer:
		return
	layer.new_cels_linked = !layer.new_cels_linked
	update_buttons()
	if Global.select_layer_on_button_click:
		_select_current_layer()


func _select_current_layer() -> void:
	Global.current_project.selected_cels.clear()
	var frame_layer := [Global.current_project.current_frame, layer_index]
	if !Global.current_project.selected_cels.has(frame_layer):
		Global.current_project.selected_cels.append(frame_layer)

	Global.current_project.change_cel(-1, layer_index)


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
	region.position.x += depth * HIERARCHY_DEPTH_PIXEL_SHIFT
	region.size.x -= depth * HIERARCHY_DEPTH_PIXEL_SHIFT
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
