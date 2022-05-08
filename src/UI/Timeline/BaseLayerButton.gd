class_name BaseLayerButton
extends Button

const HIERARCHY_DEPTH_PIXEL_SHIFT = 8

var layer := 0

onready var visibility_button: BaseButton = find_node("VisibilityButton")
onready var lock_button: BaseButton = find_node("LockButton")
onready var label: Label = find_node("Label")
onready var line_edit: LineEdit = find_node("LineEdit")
onready var hierarchy_spacer: Control = find_node("HierarchySpacer")


func _ready() -> void:
	rect_min_size.y = Global.animation_timeline.cel_size

	var layer_buttons = find_node("LayerButtons")
	for child in layer_buttons.get_children():
		var texture = child.get_child(0)
#		var last_backslash = texture.texture.resource_path.get_base_dir().find_last("/")
#		var button_category = texture.texture.resource_path.get_base_dir().right(last_backslash + 1)
#		var normal_file_name = texture.texture.resource_path.get_file()

#		texture.texture = load("res://assets/graphics/%s/%s" % [button_category, normal_file_name])
		texture.modulate = Global.modulate_icon_color

	if Global.current_project.layers[layer].visible:
		Global.change_button_texturerect(visibility_button.get_child(0), "layer_visible.png")
	else:
		Global.change_button_texturerect(visibility_button.get_child(0), "layer_invisible.png")

	if Global.current_project.layers[layer].locked:
		Global.change_button_texturerect(lock_button.get_child(0), "lock.png")
	else:
		Global.change_button_texturerect(lock_button.get_child(0), "unlock.png")

	# Visualize how deep into the hierarchy the layer is
	var hierarchy_depth: int = Global.current_project.layers[layer].get_hierarchy_depth()
	hierarchy_spacer.rect_min_size.x = hierarchy_depth * HIERARCHY_DEPTH_PIXEL_SHIFT
	if Global.control.theme.get_color("font_color", "Button").v > 0.5: # Light text is dark theme
		self_modulate.v += hierarchy_depth * 0.2
	else: # Dark text should be light theme
		self_modulate.v -= hierarchy_depth * 0.075

	if is_instance_valid(Global.current_project.layers[layer].parent):
		if not Global.current_project.layers[layer].parent.is_expanded_in_hierarchy():
			visible = false
		if not Global.current_project.layers[layer].parent.is_visible_in_hierarchy():
			visibility_button.modulate.a = 0.33
		if Global.current_project.layers[layer].parent.is_locked_in_hierarchy():
			lock_button.modulate.a = 0.33


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


func _on_VisibilityButton_pressed() -> void:
	Global.canvas.selection.transform_content_confirm()
	Global.current_project.layers[layer].visible = !Global.current_project.layers[layer].visible
	Global.canvas.update()
	_select_current_layer()


func _on_LockButton_pressed() -> void:
	Global.canvas.selection.transform_content_confirm()
	Global.current_project.layers[layer].locked = !Global.current_project.layers[layer].locked
	_select_current_layer()


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
			var region: Rect2
			var depth: int = Global.current_project.layers[layer].get_hierarchy_depth()
			if Input.is_key_pressed(KEY_CONTROL): # Swap layers
				region = get_global_rect()
			else: # Shift layers
				if Global.current_project.layers[layer].accepts_child(data[1]):
					# Top, center, or bottom region?
					if _get_region_rect(0, 0.25).has_point(get_global_mouse_position()):
						# Drawn regions are shifted up/down a bit from actual for visual clearity
						region = _get_region_rect(-0.1, 0.25)
					elif _get_region_rect(0.25, 0.5).has_point(get_global_mouse_position()):
						region = _get_region_rect(0.15, 0.7)
						depth += 1
					else:
						region = _get_region_rect(0.85, 0.25)
				else:
					# Top or bottom region?
					if _get_region_rect(0, 0.5).has_point(get_global_mouse_position()):
						region =  _get_region_rect(-0.1, 0.25)
					else:
						region =  _get_region_rect(0.85, 0.25)
			# Shift drawn region to the right a bit for hierarchy depth visualization:
			region.position.x += depth * HIERARCHY_DEPTH_PIXEL_SHIFT
			region.size.x -= depth * HIERARCHY_DEPTH_PIXEL_SHIFT
			Global.animation_timeline.drag_highlight.rect_global_position = region.position
			Global.animation_timeline.drag_highlight.rect_size = region.size
			Global.animation_timeline.drag_highlight.show()
			return true
	Global.animation_timeline.drag_highlight.hide()
	return false


func drop_data(_pos, data) -> void:
	var new_layer = data[1]
	if layer == new_layer:
		return

	var new_layers: Array = Global.current_project.layers.duplicate()
	var temp = new_layers[layer]
	new_layers[layer] = new_layers[new_layer]
	new_layers[new_layer] = temp

	Global.current_project.undo_redo.create_action("Change Layer Order")
	for f in Global.current_project.frames:
		var new_cels: Array = f.cels.duplicate()
		var temp_canvas = new_cels[layer]
		new_cels[layer] = new_cels[new_layer]
		new_cels[new_layer] = temp_canvas
		Global.current_project.undo_redo.add_do_property(f, "cels", new_cels)
		Global.current_project.undo_redo.add_undo_property(f, "cels", f.cels)

	if Global.current_project.current_layer == layer:
		Global.current_project.undo_redo.add_do_property(
			Global.current_project, "current_layer", new_layer
		)
		Global.current_project.undo_redo.add_undo_property(
			Global.current_project, "current_layer", Global.current_project.current_layer
		)
	Global.current_project.undo_redo.add_do_property(Global.current_project, "layers", new_layers)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "layers", Global.current_project.layers
	)

	Global.current_project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	Global.current_project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	Global.current_project.undo_redo.commit_action()


func _get_region_rect(y_offset: float, y_size: float) -> Rect2:
	var rect := get_global_rect()
	rect.position.y += rect.size.y * y_offset
	rect.size.y *= y_size
	return rect
