extends BaseTool

const VALUE_SLIDER_V2_TSCN := preload("res://src/UI/Nodes/Sliders/ValueSliderV2.tscn")
const VALUE_SLIDER_V3_TSCN := preload("res://src/UI/Nodes/Sliders/ValueSliderV3.tscn")

var layer_3d: Layer3D
var _undo_data: Dictionary[StringName, Variant] = {}
var _cel: Cel3D
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
var _old_cel_image = null
var _checker_update_qued := false
var _object_names: Dictionary[Layer3D.ObjectType, String] = {
	Layer3D.ObjectType.BOX: "Box",
	Layer3D.ObjectType.SPHERE: "Sphere",
	Layer3D.ObjectType.CAPSULE: "Capsule",
	Layer3D.ObjectType.CYLINDER: "Cylinder",
	Layer3D.ObjectType.PRISM: "Prism",
	Layer3D.ObjectType.TORUS: "Torus",
	Layer3D.ObjectType.PLANE: "Plane",
	Layer3D.ObjectType.TEXT: "Text",
	Layer3D.ObjectType.ARRAY_MESH: "Custom model",
	Layer3D.ObjectType.DIR_LIGHT: "Directional light",
	Layer3D.ObjectType.SPOT_LIGHT: "Spotlight",
	Layer3D.ObjectType.OMNI_LIGHT: "Point light",
}

@onready var object_option_button := $"%ObjectOptionButton" as OptionButton
@onready var new_object_menu_button := $"%NewObjectMenuButton" as MenuButton
@onready var remove_object_button := $"%RemoveObject" as Button
@onready var load_model_dialog := $LoadModelDialog as FileDialog


func sprite_changed_this_frame() -> void:
	Global.canvas.sprite_changed_this_frame = true
	return
	_checker_update_qued = true
	_old_cel_image = _cel.get_image()


func _input(_event: InputEvent) -> void:
	if _checker_update_qued:
		if _old_cel_image != _cel.get_image():
			_checker_update_qued = false
			_cel.update_texture()


func _ready() -> void:
	super._ready()
	load_model_dialog.use_native_dialog = Global.use_native_file_dialogs
	Global.cel_switched.connect(_cel_switched)
	_cel_switched()
	var new_object_popup := new_object_menu_button.get_popup()
	for object in _object_names:
		new_object_popup.add_item(_object_names[object], object)
	new_object_popup.id_pressed.connect(_new_object_popup_id_pressed)


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
		layer_3d.node_change_transform(layer_3d.selected, proj_mouse_pos, proj_prev_mouse_pos, Global.canvas.gizmos_3d.applying_gizmos)
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
	var currently_hovering: Node3D = null
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
		elif intersect_node is Light3D:
			var light_3d := intersect_node as Light3D
			var aabb := light_3d.get_aabb()
			var intersect = aabb.intersects_ray(local_from, local_to)
			if intersect != null:
				return [intersect_node]
	return []


func _get_undo_data(node: Object) -> Dictionary[StringName, Variant]:
	var data: Dictionary[StringName, Variant] = {}
	var property_list := Layer3D.get_object_property_list(node)
	for prop in property_list:
		var prop_name: String = prop["name"]
		data[prop_name] = node.get(prop_name)
	return data


func _on_ObjectOptionButton_item_selected(index: int) -> void:
	if not Global.current_project.get_current_cel() is Cel3D:
		return
	#var id := object_option_button.get_item_id(index) - 1
	#var object := _cel.get_object_from_id(id)
	#if not is_instance_valid(object):
		#layer_3d.selected = null
		#return
	#layer_3d.selected = object


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
	#if not _cel.scene_property_changed.is_connected(_set_cel_node_values):
		#_cel.scene_property_changed.connect(_set_cel_node_values)
		#_cel.objects_changed.connect(_fill_object_option_button)
		#_cel.selected_object.connect(_selected_object)
	_set_cel_node_values()
	_fill_object_option_button()
	sprite_changed_this_frame()
	if is_instance_valid(selected):
		layer_3d.selected = selected


func _new_object_popup_id_pressed(id: Layer3D.ObjectType) -> void:
	if id == Layer3D.ObjectType.ARRAY_MESH:
		load_model_dialog.popup_centered_clamped()
		Global.dialog_open(true, true)
	else:
		_add_object(id)


func _add_object(type: Layer3D.ObjectType, custom_mesh: Mesh = null) -> void:
	var node3d := Layer3D.create_node(type, custom_mesh)
	var undo_redo := Global.current_project.undo_redo
	undo_redo.create_action("Add 3D object")
	undo_redo.add_do_method(layer_3d.parent_node.add_child.bind(node3d))
	undo_redo.add_do_reference(node3d)
	undo_redo.add_undo_method(layer_3d.parent_node.remove_child.bind(node3d))
	undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	undo_redo.commit_action()
	sprite_changed_this_frame()
	#_cel.current_object_id += 1


func _on_RemoveObject_pressed() -> void:
	if not is_instance_valid(layer_3d.selected):
		return
	var undo_redo := Global.current_project.undo_redo
	undo_redo.create_action("Remove 3D object")
	undo_redo.add_do_method(layer_3d.parent_node.remove_child.bind(layer_3d.selected))
	undo_redo.add_undo_method(layer_3d.parent_node.add_child.bind(layer_3d.selected))
	undo_redo.add_undo_reference(layer_3d.selected)
	undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	undo_redo.commit_action()
	sprite_changed_this_frame()


func _object_property_changed(object: Object, property: StringName, by_undo_redo: bool) -> void:
	if by_undo_redo:
		return
	if property not in _undo_data:
		print(property, " not found in undo data.")
		return
	var undo_redo := Global.current_project.undo_redo
	undo_redo.create_action("Change 3D object %s" % property, UndoRedo.MERGE_ENDS)
	undo_redo.add_do_property(object, property, object.get(property))
	undo_redo.add_do_method(layer_3d.emit_signal.bind(&"node_property_changed", object, property, true))
	undo_redo.add_undo_property(object, property, _undo_data[property])
	undo_redo.add_undo_method(layer_3d.emit_signal.bind(&"node_property_changed", object, property, true))
	#undo_redo.add_do_method(_cel._update_objects_transform.bind(object.id))
	#undo_redo.add_undo_method(_cel._update_objects_transform.bind(object.id))
	undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	undo_redo.commit_action()


func _on_selected_object(object: Node3D, old_object: Node3D) -> void:
	if object == old_object:
		return
	get_tree().call_group(&"3DObjectPropertyNodes", &"queue_free")
	if is_instance_valid(object):
		remove_object_button.disabled = false
		_create_object_property_nodes(object)
		if object is MeshInstance3D:
			if is_instance_valid(object.mesh):
				var mesh := object.mesh as Mesh
				_create_object_property_nodes(mesh)
				#var mesh_property_list := get_object_property_list(mesh)
				#for mesh_prop in mesh_property_list:
					#mesh_prop["name"] = "mesh:%s" % mesh_prop["name"]
				#property_list.append_array(mesh_property_list)
				if is_instance_valid(mesh.surface_get_material(0)):
					var mat := mesh.surface_get_material(0) as BaseMaterial3D
					_create_object_property_nodes(mat)
					#var material_property_list := get_object_property_list(material)
					#for mat_prop in material_property_list:
						#mat_prop["name"] = "mesh:material:%s" % mat_prop["name"]
					#property_list.append_array(material_property_list)
		#if not object.property_changed.is_connected(_set_object_node_values):
			#object.property_changed.connect(_set_object_node_values)
		#object_option_button.select(object_option_button.get_item_index(object.id + 1))
	else:
		var camera_foldable := _create_object_property_nodes(layer_3d.camera)
		camera_foldable.title = "Camera"
		var environment_foldable := _create_object_property_nodes(layer_3d.viewport.world_3d.environment)
		environment_foldable.title = "Environment"
		environment_foldable.fold()
		remove_object_button.disabled = true
		object_option_button.select(0)


func _set_cel_node_values() -> void:
	return


func _create_object_property_nodes(object: Object) -> FoldableContainer:
	var foldable_container := FoldableContainer.new()
	foldable_container.add_to_group(&"3DObjectPropertyNodes")
	add_child(foldable_container)
	var grid_container := GridContainer.new()
	grid_container.columns = 2
	foldable_container.add_child(grid_container)
	var property_list := Layer3D.get_object_property_list(object)
	for prop in property_list:
		var prop_name: String = prop["name"]
		var humanized_name := Keychain.humanize_snake_case(prop_name, true)
		var type: Variant.Type = prop["type"]
		var hint: PropertyHint = prop["hint"]
		match type:
			TYPE_BOOL:
				var label := Label.new()
				label.text = humanized_name
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var check_box := CheckBox.new()
				check_box.name = prop_name
				check_box.text = "On"
				check_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				check_box.button_pressed = object.get_indexed(prop_name) == true
				check_box.toggled.connect(_object_property_toggled.bind(object, prop_name))
				grid_container.add_child(label)
				grid_container.add_child(check_box)
			TYPE_INT, TYPE_FLOAT:
				if hint != PROPERTY_HINT_ENUM and hint != PROPERTY_HINT_ENUM_SUGGESTION:
					var label := Label.new()
					label.text = humanized_name
					label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					var slider := ValueSlider.new()
					slider.name = prop_name
					if type == TYPE_FLOAT:
						slider.step = 0.01
					slider.allow_lesser = true
					slider.allow_greater = true
					slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					slider.value = object.get_indexed(prop_name)
					grid_container.add_child(label)
					grid_container.add_child(slider)
			TYPE_VECTOR3, TYPE_VECTOR3I:
				var label := Label.new()
				label.text = humanized_name
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var slider := VALUE_SLIDER_V3_TSCN.instantiate() as ValueSliderV3
				slider.name = prop_name
				slider.show_ratio = true
				if type == TYPE_VECTOR3:
					slider.step = 0.01
				slider.allow_lesser = true
				slider.allow_greater = true
				slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				slider.value = object.get_indexed(prop_name)
				grid_container.add_child(label)
				grid_container.add_child(slider)
				#layer_3d.node_property_changed.connect(_update_property_sliders.bind(slider, object))
	return foldable_container


## TODO: Remove, doesn't work properly.
## Update the value of sliders when an object gets transformed by gizmos.
func _update_property_sliders(
	node_changed: Node3D, property_name: StringName, _by_undo_redo: bool, slider, target_node: Node3D
) -> void:
	if node_changed != target_node:
		return
	if not is_instance_valid(slider):
		return
	var new_value = node_changed.get(property_name)
	slider.set_value_no_signal(new_value)


func _get_previous_node(node: Node) -> Node:
	return node.get_parent().get_child(node.get_index() - 1)


func _set_value_from_node(to_edit: Object, value, prop: String) -> void:
	if not is_instance_valid(to_edit):
		return
	#if "mesh_" in prop:
		#prop = prop.replace("mesh_", "")
		#to_edit = to_edit.node3d_type.mesh
	#if "scale" in prop:
		#value /= 100
	#if "font" in prop and not "font_" in prop:
		#value = Global.find_font_from_name(%MeshFont.get_item_text(value))
	to_edit.set_indexed(prop, value)
	layer_3d.node_property_changed.emit(to_edit, prop, false)


func _object_property_vector3_changed(value: Vector3, prop: String) -> void:
	_set_value_from_node(layer_3d.selected, value, prop)
	#Global.canvas.gizmos_3d.queue_redraw()


func _object_property_vector2_changed(value: Vector2, prop: String) -> void:
	_set_value_from_node(layer_3d.selected, value, prop)


func _object_property_value_changed(value: float, prop: String) -> void:
	_set_value_from_node(layer_3d.selected, value, prop)


func _object_property_item_selected(value: int, prop: String) -> void:
	_set_value_from_node(layer_3d.selected, value, prop)


func _object_property_color_changed(value: Color, prop: String) -> void:
	_set_value_from_node(layer_3d.selected, value, prop)


func _object_property_toggled(value: bool, object: Object, prop: String) -> void:
	_undo_data = _get_undo_data(object)
	_set_value_from_node(object, value, prop)


func _object_property_text_changed(text_edit: TextEdit, prop: String) -> void:
	_set_value_from_node(layer_3d.selected, text_edit.text, prop)


func _fill_object_option_button() -> void:
	if not _cel is Cel3D:
		return
	object_option_button.clear()
	object_option_button.add_item("None", 0)
	var existing_names := {}
	for id in _cel.object_properties:
		var item_name: String = _object_names[_cel.object_properties[id]["type"]]
		if item_name in existing_names:
			# If there is already an object with the same name, under a number next to it
			existing_names[item_name] += 1
			item_name += " (%s)" % existing_names[item_name]
		else:
			existing_names[item_name] = 1
		object_option_button.add_item(item_name, id + 1)


func _on_UndoRedoTimer_timeout() -> void:
	if is_instance_valid(layer_3d.selected):
		pass
		#_object_property_changed(layer_3d.selected)
	else:
		var undo_redo: UndoRedo = Global.current_project.undo_redo
		undo_redo.create_action("Change 3D layer properties")
		undo_redo.add_do_property(_cel, "scene_properties", _cel.serialize_scene_properties())
		undo_redo.add_undo_property(_cel, "scene_properties", _cel.scene_properties)
		undo_redo.add_do_method(_cel._scene_property_changed)
		undo_redo.add_undo_method(_cel._scene_property_changed)
		undo_redo.add_do_method(Global.undo_or_redo.bind(false))
		undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
		undo_redo.commit_action()


func _on_LoadModelDialog_files_selected(paths: PackedStringArray) -> void:
	for path in paths:
		var mesh := ObjParse.load_obj(path)
		_add_object(Layer3D.ObjectType.ARRAY_MESH, mesh)


func _on_load_model_dialog_visibility_changed() -> void:
	Global.dialog_open(false, true)
