class_name LayerButton
extends Button

const HIERARCHY_DEPTH_PIXEL_SHIFT = 8

var layer := 0

onready var expand_button: BaseButton = find_node("ExpandButton")
onready var visibility_button: BaseButton = find_node("VisibilityButton")
onready var lock_button: BaseButton = find_node("LockButton")
onready var label: Label = find_node("Label")
onready var line_edit: LineEdit = find_node("LineEdit")
onready var hierarchy_spacer: Control = find_node("HierarchySpacer")
onready var linked_button: BaseButton = find_node("LinkButton")

export var hide_expand_button := true

func _ready() -> void:
	rect_min_size.y = Global.animation_timeline.cel_size

	label.text = Global.current_project.layers[layer].name
	line_edit.text = Global.current_project.layers[layer].name

	var layer_buttons = find_node("LayerButtons")
	for child in layer_buttons.get_children():
		var texture = child.get_child(0)
		texture.modulate = Global.modulate_icon_color

	# Visualize how deep into the hierarchy the layer is
	var hierarchy_depth: int = Global.current_project.layers[layer].get_hierarchy_depth()
	hierarchy_spacer.rect_min_size.x = hierarchy_depth * HIERARCHY_DEPTH_PIXEL_SHIFT

	if Global.control.theme.get_color("font_color", "Button").v > 0.5: # Light text is dark theme
		self_modulate.v = 1 + hierarchy_depth * 0.4
	else: # Dark text should be light theme
		self_modulate.v = 1 - hierarchy_depth * 0.075

	_update_buttons()


func _update_buttons() -> void:
	if hide_expand_button:
		expand_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		expand_button.get_child(0).visible = false  # Hide the TextureRect
	else:
		if Global.current_project.layers[layer].expanded:
			Global.change_button_texturerect(expand_button.get_child(0), "group_expanded.png")
		else:
			Global.change_button_texturerect(expand_button.get_child(0), "group_collapsed.png")

	if Global.current_project.layers[layer].visible:
		Global.change_button_texturerect(visibility_button.get_child(0), "layer_visible.png")
	else:
		Global.change_button_texturerect(visibility_button.get_child(0), "layer_invisible.png")

	if Global.current_project.layers[layer].locked:
		Global.change_button_texturerect(lock_button.get_child(0), "lock.png")
	else:
		Global.change_button_texturerect(lock_button.get_child(0), "unlock.png")

	if linked_button:
		if Global.current_project.layers[layer].new_cels_linked:  # If new layers will be linked
			Global.change_button_texturerect(linked_button.get_child(0), "linked_layer.png")
		else:
			Global.change_button_texturerect(linked_button.get_child(0), "unlinked_layer.png")

	visibility_button.modulate.a = 1
	lock_button.modulate.a = 1
	if is_instance_valid(Global.current_project.layers[layer].parent):
		if not Global.current_project.layers[layer].parent.is_visible_in_hierarchy():
			visibility_button.modulate.a = 0.33
		if Global.current_project.layers[layer].parent.is_locked_in_hierarchy():
			lock_button.modulate.a = 0.33


func _update_buttons_all_layers() -> void:
	# TODO R: would it be better to have specified range? (if so rename all_layers to for_layers)
	#			Maybe update_buttons_recursive (including children) is all we need?
	for layer_button in Global.layers_container.get_children():
		layer_button._update_buttons()
		var expanded = Global.current_project.layers[layer_button.layer].is_expanded_in_hierarchy()
		layer_button.visible = expanded
		Global.frames_container.get_child(layer_button.get_index()).visible = expanded


func _draw() -> void:
	if hierarchy_spacer.rect_size.x > 0.1:
		var color := Color(1, 1, 1, 0.33)
		color.v = round(Global.control.theme.get_color("font_color", "Button").v)
		var x =  hierarchy_spacer.rect_global_position.x - rect_global_position.x + hierarchy_spacer.rect_size.x
		draw_line(Vector2(x, 0), Vector2(x, rect_size.y), color)


func _input(event: InputEvent) -> void:
	if (
		(event.is_action_released("ui_accept") or event.is_action_released("ui_cancel"))
		and line_edit.visible
		and event.scancode != KEY_SPACE
	):
		_save_layer_name(line_edit.text)


func _on_LayerContainer_gui_input(event: InputEvent) -> void:
	var project = Global.current_project

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		Global.canvas.selection.transform_content_confirm()
		var prev_curr_layer: int = project.current_layer
		if Input.is_action_pressed("shift"):
			var layer_diff_sign = sign(layer - prev_curr_layer)
			if layer_diff_sign == 0:
				layer_diff_sign = 1
			for i in range(0, project.frames.size()):
				for j in range(prev_curr_layer, layer + layer_diff_sign, layer_diff_sign):
					var frame_layer := [i, j]
					if !project.selected_cels.has(frame_layer):
						project.selected_cels.append(frame_layer)
			project.current_layer = layer
		elif Input.is_action_pressed("ctrl"):
			for i in range(0, project.frames.size()):
				var frame_layer := [i, layer]
				if !project.selected_cels.has(frame_layer):
					project.selected_cels.append(frame_layer)
			project.current_layer = layer
		else:  # If the button is pressed without Shift or Control
			_select_current_layer()

		if event.doubleclick:
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
	Global.layers_changed_skip = true
	Global.current_project.layers[layer].name = new_name


func _on_ExpandButton_pressed():
	# TODO L: What should happen when the current_layer or selected_cels are children of a layer you collapse?
	#		Should the current_layer/selection move to ones aren't collapsed? Maybe add to github list of possible later changes
	Global.current_project.layers[layer].expanded = !Global.current_project.layers[layer].expanded
	_update_buttons_all_layers()


func _on_VisibilityButton_pressed() -> void:
	Global.canvas.selection.transform_content_confirm()
	Global.current_project.layers[layer].visible = !Global.current_project.layers[layer].visible
	Global.canvas.update()
	_select_current_layer()
	_update_buttons_all_layers()


func _on_LockButton_pressed() -> void:
	Global.canvas.selection.transform_content_confirm()
	Global.current_project.layers[layer].locked = !Global.current_project.layers[layer].locked
	_select_current_layer()
	_update_buttons_all_layers()


func _on_LinkButton_pressed() -> void:
	Global.canvas.selection.transform_content_confirm()
	var layer_class: PixelLayer = Global.current_project.layers[layer]
	layer_class.new_cels_linked = !layer_class.new_cels_linked
	if layer_class.new_cels_linked && !layer_class.linked_cels:
		# If button is pressed and there are no linked cels in the layer
		layer_class.linked_cels.append(
			Global.current_project.frames[Global.current_project.current_frame]
		)
		var container = Global.frames_container.get_child(Global.current_project.current_layer)
		container.get_child(Global.current_project.current_frame).button_setup()

	Global.current_project.layers = Global.current_project.layers  # Call the setter
	_update_buttons()


func _select_current_layer() -> void:
	Global.current_project.selected_cels.clear()
	var frame_layer := [Global.current_project.current_frame, layer]
	if !Global.current_project.selected_cels.has(frame_layer):
		Global.current_project.selected_cels.append(frame_layer)

	Global.current_project.current_layer = layer


func get_drag_data(_position) -> Array:
	var button := Button.new()
	button.rect_size = rect_size
	button.theme = Global.control.theme
	button.text = label.text
	set_drag_preview(button)

	return ["Layer", layer]


func can_drop_data(_pos, data) -> bool:
	if typeof(data) == TYPE_ARRAY:
		if data[0] == "Layer":
			var curr_layer: BaseLayer = Global.current_project.layers[layer]
			var drag_layer: BaseLayer = Global.current_project.layers[data[1]]

			if curr_layer == drag_layer:
				Global.animation_timeline.drag_highlight.visible = false
				return false

			var region: Rect2
			var depth: int = Global.current_project.layers[layer].get_hierarchy_depth()

			if Input.is_action_pressed("ctrl"): # Swap layers
				if drag_layer.is_a_parent_of(curr_layer) or curr_layer.is_a_parent_of(drag_layer):
					Global.animation_timeline.drag_highlight.visible = false
					return false
				region = get_global_rect()

			else: # Shift layers
				if drag_layer.is_a_parent_of(curr_layer):
					Global.animation_timeline.drag_highlight.visible = false
					return false
				# If accepted as a child, is it in the center region?
				if (Global.current_project.layers[layer].accepts_child(data[1])
							and _get_region_rect(0.25, 0.75).has_point(get_global_mouse_position())
						):
						# Drawn regions are adusted a bit from actual to clearify drop position
						region = _get_region_rect(0.15, 0.85)
						depth += 1
				else:
					# Top or bottom region?
					if _get_region_rect(0, 0.5).has_point(get_global_mouse_position()):
						region =  _get_region_rect(-0.1, 0.15)
					else:
						region =  _get_region_rect(0.85, 1.1)
			# Shift drawn region to the right a bit for hierarchy depth visualization:
			region.position.x += depth * HIERARCHY_DEPTH_PIXEL_SHIFT
			region.size.x -= depth * HIERARCHY_DEPTH_PIXEL_SHIFT
			Global.animation_timeline.drag_highlight.rect_global_position = region.position
			Global.animation_timeline.drag_highlight.rect_size = region.size
			Global.animation_timeline.drag_highlight.visible = true
			return true
	Global.animation_timeline.drag_highlight.visible = false
	return false


func drop_data(_pos, data) -> void:
	var drop_layer: int = data[1]
	var project = Global.current_project # TODO L: perhaps having a project variable for the enitre class would be nice (also for cel/frame buttons)

	project.undo_redo.create_action("Change Layer Order")
	var new_layers: Array = project.layers.duplicate()
	var temp: BaseLayer = new_layers[layer]
	if Input.is_action_pressed("ctrl"): # Swap layers
		pass # TODO R: Figure out swapping
#		new_layers[layer] = new_layers[drop_layer]
#		new_layers[drop_layer] = temp
#
#		# TODO R: Make sure to swap parents too
#
#		for f in Global.current_project.frames:
#			var new_cels: Array = f.cels.duplicate()
#			var temp_canvas = new_cels[layer]
#			new_cels[layer] = new_cels[drop_layer]
#			new_cels[drop_layer] = temp_canvas
#			project.undo_redo.add_do_property(f, "cels", new_cels)
#			project.undo_redo.add_undo_property(f, "cels", f.cels)
	# TODO R: Having "SourceLayers/OldLayers (that you don't change) and new_layers would make this less confusing
	else:
		# from_indices should be in order of the layer indices, starting from the lowest
		# TODO R: can this code be made easier to read?
		var from_indices := []
		for c in new_layers[drop_layer].get_children_recursive():
			from_indices.append(c.index)
		from_indices.append(drop_layer)

		var to_index: int # the index where the LOWEST shifted layer should end up
		var to_parent: BaseLayer

		# If accepted as a child, is it in the center region?
		if (new_layers[layer].accepts_child(data[1])
				and _get_region_rect(0.25, 0.75).has_point(get_global_mouse_position())
			):
			to_index = layer
			to_parent = new_layers[layer]
		else:
			# Top or bottom region?
			if _get_region_rect(0, 0.5).has_point(get_global_mouse_position()):
				to_index = layer + 1
				to_parent = new_layers[layer].parent
			else:
				# Place under the layer, if it has children, place after its lowest child
				if new_layers[layer].has_children():
					to_index = new_layers[layer].get_children_recursive()[0].index

					if new_layers[layer].is_a_parent_of(new_layers[drop_layer]):
						to_index += from_indices.size()
				else:
					to_index = layer
				to_parent = new_layers[layer].parent

		if drop_layer < layer:
			to_index -= from_indices.size()
		print("to_index = ", to_index)

		var to_indices := []
		var from_parents := []
		for i in range(from_indices.size()):
			to_indices.append(to_index + i)
			from_parents.append(new_layers[from_indices[i]].parent)
		var to_parents := from_parents.duplicate()
		to_parents[-1] = to_parent

		project.undo_redo.add_do_method(
			project, "move_layers", from_indices, to_indices, to_parents
		)
		project.undo_redo.add_undo_method(
			project, "move_layers", to_indices, from_indices, from_parents
		)
	if project.current_layer == drop_layer:
		project.undo_redo.add_do_property(project, "current_layer", layer)
	else:
		project.undo_redo.add_do_property(project, "current_layer", project.current_layer)
	project.undo_redo.add_undo_property(project, "current_layer", project.current_layer)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.commit_action()


func _get_region_rect(y_begin: float, y_end: float) -> Rect2:
	var rect := get_global_rect()
	rect.position.y += rect.size.y * y_begin
	rect.size.y *= y_end - y_begin
	return rect
