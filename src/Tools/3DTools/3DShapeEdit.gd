extends BaseTool

const VALUE_SLIDER_V2_TSCN := preload("res://src/UI/Nodes/Sliders/ValueSliderV2.tscn")
const VALUE_SLIDER_V3_TSCN := preload("res://src/UI/Nodes/Sliders/ValueSliderV3.tscn")

const FOLDABLE_CONTAINER_GROUP_NAME := &"3DObjectPropertyNodes"
var layer_3d: Layer3D
var _undo_data: Dictionary[StringName, Variant] = {}
var _hovering: Node3D = null:
	set(value):
		var selected := layer_3d.selected == _hovering
		if not is_instance_valid(layer_3d.selected):
			selected = false
		layer_3d.object_hovered.emit(value, _hovering, selected)
		_hovering = value
var _dragging := false
var _has_been_dragged := false
var _prev_mouse_pos := Vector2i.ZERO


func sprite_changed_this_frame() -> void:
	layer_3d.project.get_current_cel().update_texture()
	Global.canvas.sprite_changed_this_frame = true


func _ready() -> void:
	super._ready()
	Global.cel_switched.connect(_cel_switched)
	_cel_switched()


func draw_start(pos: Vector2i) -> void:
	var project := Global.current_project
	if not project.get_current_cel() is Cel3D:
		return
	if not project.layers[project.current_layer].can_layer_be_modified():
		return
	var found_layer := false
	for frame_layer in project.selected_cels:
		if layer_3d == project.layers[frame_layer[1]]:
			found_layer = true
	if not found_layer:
		return

	if DisplayServer.is_touchscreen_available():
		cursor_move(pos)

	if is_instance_valid(layer_3d.selected):
		# Needs canvas.current_pixel, because draw_start()'s position is floored
		Global.canvas.gizmos_3d.applying_gizmos = Global.canvas.gizmos_3d.get_hovering_gizmo(
			Global.canvas.current_pixel
		)
	if is_instance_valid(_hovering):
		layer_3d.selected = _hovering
		Global.canvas.gizmos_3d.get_points(_hovering, true)
		_dragging = true
		_undo_data = _get_undo_data(layer_3d.selected)
		_prev_mouse_pos = pos
	else:  # We're not hovering
		if is_instance_valid(layer_3d.selected):
			# If we're not clicking on a gizmo, unselect
			if Global.canvas.gizmos_3d.applying_gizmos == Layer3D.Gizmos.NONE:
				layer_3d.selected = null
			else:
				_dragging = true
				_undo_data = _get_undo_data(layer_3d.selected)
				_prev_mouse_pos = pos


func draw_move(pos: Vector2i) -> void:
	if not Global.current_project.get_current_cel() is Cel3D:
		return
	var camera := layer_3d.camera
	if _dragging:
		_has_been_dragged = true
		var proj_mouse_pos := camera.project_position(pos, camera.position.z)
		var proj_prev_mouse_pos := camera.project_position(_prev_mouse_pos, camera.position.z)
		layer_3d.node_change_transform(
			layer_3d.selected,
			proj_mouse_pos,
			proj_prev_mouse_pos,
			Global.canvas.gizmos_3d.applying_gizmos
		)
		_prev_mouse_pos = pos
	sprite_changed_this_frame()


func draw_end(_position: Vector2i) -> void:
	if not Global.current_project.get_current_cel() is Cel3D:
		return
	_dragging = false
	if is_instance_valid(layer_3d.selected) and _has_been_dragged:
		Global.canvas.gizmos_3d.applying_gizmos = Layer3D.Gizmos.NONE
		Global.canvas.gizmos_3d.queue_redraw()
	_has_been_dragged = false
	sprite_changed_this_frame()


func cursor_move(pos: Vector2i) -> void:
	super.cursor_move(pos)
	if not Global.current_project.get_current_cel() is Cel3D:
		return
	if _dragging:
		return
	# Hover logic
	var currently_hovering: Node3D = Global.canvas.gizmos_3d.get_hovering_light(
		Global.canvas.current_pixel
	)
	if currently_hovering == null:
		var intersect_info := get_3d_node_at_pos(pos, layer_3d.camera)
		if not intersect_info.is_empty():
			currently_hovering = intersect_info[0]
	_hovering = currently_hovering


func get_3d_node_at_pos(pos: Vector2i, camera: Camera3D, max_distance := 100.0) -> Array:
	var scenario := camera.get_world_3d().scenario
	var ray_from := camera.project_ray_origin(pos)
	var ray_dir := camera.project_ray_normal(pos)
	var ray_to := ray_from + ray_dir * max_distance
	var intersecting_objects := RenderingServer.instances_cull_ray(ray_from, ray_to, scenario)
	for obj in intersecting_objects:
		var intersect_node := instance_from_id(obj)
		if intersect_node is not Node3D:
			continue
		# Convert ray into the node’s local space
		var to_local := (intersect_node as Node3D).global_transform.affine_inverse()
		var local_from := to_local * ray_from
		var local_to := to_local * ray_to
		if intersect_node is MeshInstance3D:
			var mesh_instance := intersect_node as MeshInstance3D
			var mesh := mesh_instance.mesh
			if mesh == null:
				continue
			var tri_mesh := mesh.generate_triangle_mesh()
			if tri_mesh == null:
				continue
			# Intersect ray with local-space triangles
			var intersect := tri_mesh.intersect_ray(local_from, local_to)
			if not intersect.is_empty():
				return [intersect_node, intersect]
	return []


func _get_undo_data(node: Object) -> Dictionary[StringName, Variant]:
	var data: Dictionary[StringName, Variant] = {}
	var property_list := Layer3D.get_object_property_list(node)
	for prop in property_list:
		var prop_name: String = prop["name"]
		data[prop_name] = node.get_indexed(prop_name)
	return data


func _cel_switched() -> void:
	if is_instance_valid(layer_3d):
		if layer_3d.selected_object_changed.is_connected(_on_selected_object):
			layer_3d.selected_object_changed.disconnect(_on_selected_object)
			layer_3d.node_property_changed.disconnect(_object_property_changed)
	if not Global.current_project.get_current_cel() is Cel3D:
		layer_3d = null
		get_child(0).visible = false  # Just to ensure that the content of the tool is hidden
		return
	get_child(0).visible = true
	layer_3d = Global.current_project.layers[Global.current_project.current_layer]
	var selected := layer_3d.selected
	layer_3d.selected = null
	layer_3d.selected_object_changed.connect(_on_selected_object)
	layer_3d.node_property_changed.connect(_object_property_changed)
	if is_instance_valid(selected):
		layer_3d.selected = selected
	else:
		get_tree().call_group(FOLDABLE_CONTAINER_GROUP_NAME, &"queue_free")
		_show_node_property_nodes()


func _object_property_changed(object: Node, property: String, frame_index: int) -> void:
	if frame_index != layer_3d.project.current_frame:
		return
	var curr_value = object.get_indexed(property)
	for foldable in get_tree().get_nodes_in_group(FOLDABLE_CONTAINER_GROUP_NAME):
		if foldable.get_meta(&"object") != object:
			continue
		var grid_container := foldable.get_child(0)
		for property_editor_node in grid_container.get_children():
			var property_node_name := property.replace(":", "_").replace("/", "_")
			if property_editor_node.name == property_node_name:
				if property_editor_node is CheckBox:
					property_editor_node.set_pressed_no_signal(curr_value)
				elif property_editor_node is ValueSlider:
					property_editor_node.set_value_no_signal_update_display(curr_value)
				elif property_editor_node is ValueSliderV2:
					property_editor_node.set_value_no_signal(curr_value)
				elif property_editor_node is ValueSliderV3:
					property_editor_node.set_value_no_signal(curr_value)
				elif property_editor_node is ColorPickerButton:
					property_editor_node.color = curr_value
				elif property_editor_node is LineEdit or property_editor_node is TextEdit:
					property_editor_node.text = curr_value
				elif property_editor_node is OptionButton:
					if curr_value is Font:
						var font_name: String = curr_value.get_font_name()
						for i in property_editor_node.item_count:
							var item_name: String = property_editor_node.get_item_text(i)
							if font_name == item_name:
								property_editor_node.select(i)
								break
					else:
						property_editor_node.select(curr_value)


func _on_selected_object(object: Node3D, old_object: Node3D) -> void:
	if object == old_object:
		return
	get_tree().call_group(FOLDABLE_CONTAINER_GROUP_NAME, &"queue_free")
	if is_instance_valid(object):
		_create_object_property_nodes(object)
	else:
		_show_node_property_nodes()


func _show_node_property_nodes() -> void:
	_create_object_property_nodes(layer_3d.camera, "Camera")
	var environment := layer_3d.world_environment
	var environment_foldable := _create_object_property_nodes(environment, "Environment")[0]
	environment_foldable.fold()


func _create_object_property_nodes(object: Node, title := "Node") -> Array[FoldableContainer]:
	var containers: Array[FoldableContainer] = []
	var foldable_container := _create_foldable_container(object, title)
	containers.append(foldable_container)
	var grid_container: GridContainer = foldable_container.get_child(0)
	var property_list := Layer3D.get_object_property_list(object)
	for prop in property_list:
		var prop_name: String = prop["name"]
		var curr_value = object.get_indexed(prop_name)
		if curr_value == null:
			continue
		var prop_name_nodepath := NodePath(prop_name)
		var subname_count := prop_name_nodepath.get_subname_count()
		var last_subname_index := subname_count - 1
		var string_to_humanize := prop_name
		if subname_count > 0:
			string_to_humanize = prop_name_nodepath.get_subname(last_subname_index)
			var new_title := prop_name_nodepath.get_name(0)
			if subname_count > 1:
				new_title = prop_name_nodepath.get_subname(0)
			new_title = Keychain.humanize_snake_case(new_title)
			if new_title != title:
				var fc := _create_foldable_container(object, new_title)
				fc.fold()
				containers.append(fc)
				title = new_title
				grid_container = fc.get_child(0)
		var humanized_name := Keychain.humanize_snake_case(string_to_humanize, true)
		var hint: PropertyHint = prop["hint"]
		var hint_string: String = prop["hint_string"]
		if curr_value is Font:
			var label := Label.new()
			label.text = humanized_name
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid_container.add_child(label)
			var option_button := OptionButton.new()
			option_button.name = prop_name
			option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var font := curr_value as Font
			var font_name := font.get_font_name()
			for available_font_name in Global.get_available_font_names():
				option_button.add_item(available_font_name)
				if font_name == available_font_name:
					option_button.select(option_button.item_count - 1)

			option_button.button_down.connect(func(): _undo_data = _get_undo_data(object))
			option_button.item_selected.connect(_set_value_from_node.bind(object, prop_name))
			grid_container.add_child(option_button)
			continue

		var min_value: Variant = null
		var max_value: Variant = null
		var step: Variant = null
		var allow_lesser := false
		var allow_greater := false
		var prefix := ""
		var suffix := ""
		if "or_less" in hint_string:
			allow_lesser = true
		if "or_greater" in hint_string:
			allow_greater = true
		var slider_options := hint_string.split(",")
		for i in slider_options.size():
			var option := slider_options[i]
			if i == 0:
				min_value = float(slider_options[0])
			elif i == 1:
				max_value = float(slider_options[1])
			elif i == 2:
				step = float(slider_options[2])
			elif option.begins_with("prefix:"):
				prefix = option.replace("prefix:", "")
			elif option.begins_with("suffix:"):
				suffix = option.replace("suffix:", "")
		var option_button_options := hint_string.split(",")
		var node := Global.create_node_from_variable(
			curr_value,
			_set_value_from_node.bind(object, prop_name),
			func(): _undo_data = _get_undo_data(object),
			min_value,
			max_value,
			step,
			allow_lesser,
			allow_greater,
			prefix,
			suffix,
			hint,
			option_button_options
		)
		if is_instance_valid(node):
			node.name = prop_name
			var label := Label.new()
			label.text = humanized_name
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid_container.add_child(label)
			grid_container.add_child(node)

	return containers


func _on_object_property_line_edit_editing_toggled(toggled_on: bool, object: Node) -> void:
	if toggled_on:
		_undo_data = _get_undo_data(object)


func _create_foldable_container(object: Node, title: String) -> FoldableContainer:
	var foldable_container := FoldableContainer.new()
	foldable_container.title = title
	foldable_container.set_meta("object", object)
	foldable_container.add_to_group(FOLDABLE_CONTAINER_GROUP_NAME)
	add_child(foldable_container)
	var grid_container := GridContainer.new()
	grid_container.columns = 2
	foldable_container.add_child(grid_container)
	return foldable_container


func _set_value_from_node(value, to_edit: Node, prop: String) -> void:
	if not is_instance_valid(to_edit):
		return
	if prop not in _undo_data:
		print(prop, " not found in undo data.")
		return
	if prop == "mesh:font":
		value = Global.find_font_from_name(Global.get_available_font_names()[value])
	var frame_index := layer_3d.project.current_frame
	var prev_value = _undo_data[prop]
	layer_3d.update_animation_track(to_edit, prop, value, prev_value, frame_index)
