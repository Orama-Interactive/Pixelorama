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

@onready var new_object_menu_button := $"%NewObjectMenuButton" as MenuButton
@onready var remove_object_button := $"%RemoveObject" as Button
@onready var load_model_dialog := $LoadModelDialog as FileDialog


func sprite_changed_this_frame() -> void:
	layer_3d.project.get_current_cel().update_texture()
	Global.canvas.sprite_changed_this_frame = true


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
		layer_3d.node_change_transform(
			layer_3d.selected, proj_mouse_pos, proj_prev_mouse_pos, Global.canvas.gizmos_3d.applying_gizmos
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
	layer_3d.animation_player.speed_scale = layer_3d.project.fps
	layer_3d.animation.length = layer_3d.project.frames.size()
	layer_3d.animation_player.seek(layer_3d.project.current_frame, true)
	var selected := layer_3d.selected
	layer_3d.selected = null
	layer_3d.selected_object_changed.connect(_on_selected_object)
	layer_3d.node_property_changed.connect(_object_property_changed)
	sprite_changed_this_frame()
	if is_instance_valid(selected):
		layer_3d.selected = selected
	else:
		get_tree().call_group(FOLDABLE_CONTAINER_GROUP_NAME, &"queue_free")
		_show_node_property_nodes()


func _new_object_popup_id_pressed(id: Layer3D.ObjectType) -> void:
	if id == Layer3D.ObjectType.ARRAY_MESH:
		load_model_dialog.popup_centered_clamped()
		Global.dialog_open(true, true)
	else:
		_add_object(id)


func _add_object(type: Layer3D.ObjectType, custom_mesh: Mesh = null) -> void:
	var node3d := Layer3D.create_node(type, custom_mesh)
	var undo_redo := layer_3d.project.undo_redo
	undo_redo.create_action("Add 3D object")
	undo_redo.add_do_method(layer_3d.parent_node.add_child.bind(node3d))
	undo_redo.add_do_reference(node3d)
	undo_redo.add_undo_method(layer_3d.parent_node.remove_child.bind(node3d))
	undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	undo_redo.commit_action()
	sprite_changed_this_frame()


func _on_RemoveObject_pressed() -> void:
	if not is_instance_valid(layer_3d.selected):
		return
	var undo_redo := layer_3d.project.undo_redo
	undo_redo.create_action("Remove 3D object")
	undo_redo.add_do_method(layer_3d.parent_node.remove_child.bind(layer_3d.selected))
	undo_redo.add_undo_method(layer_3d.parent_node.add_child.bind(layer_3d.selected))
	undo_redo.add_undo_reference(layer_3d.selected)
	undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	undo_redo.commit_action()
	sprite_changed_this_frame()


func _object_property_changed(object: Node, property: String, frame_index: int) -> void:
	if frame_index != layer_3d.project.current_frame:
		return
	var curr_value = object.get_indexed(property)
	for foldable in get_tree().get_nodes_in_group(FOLDABLE_CONTAINER_GROUP_NAME):
		if foldable.get_meta(&"object") != object:
			continue
		var grid_container := foldable.get_child(0)
		for property_editor_node in grid_container.get_children():
			var property_node_name := property.replace(":", "_")
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


func _on_selected_object(object: Node3D, old_object: Node3D) -> void:
	if object == old_object:
		return
	get_tree().call_group(FOLDABLE_CONTAINER_GROUP_NAME, &"queue_free")
	if is_instance_valid(object):
		remove_object_button.disabled = false
		var node_foldable := _create_object_property_nodes(object)
		node_foldable.set_meta("object", object)
		node_foldable.title = "Node"
		#if object is MeshInstance3D:
			#if is_instance_valid(object.mesh):
				#var mesh := object.mesh as Mesh
				#var mesh_foldable := _create_object_property_nodes(mesh)
				#mesh_foldable.set_meta("object", mesh)
				#mesh_foldable.title = "Mesh"
				#mesh_foldable.fold()
				#if is_instance_valid(mesh.surface_get_material(0)):
					#var mat := mesh.surface_get_material(0) as BaseMaterial3D
					#var mat_foldable := _create_object_property_nodes(mat)
					#mat_foldable.set_meta("object", mat)
					#mat_foldable.title = "Material"
					#mat_foldable.fold()
	else:
		_show_node_property_nodes()


func _show_node_property_nodes() -> void:
	var camera_foldable := _create_object_property_nodes(layer_3d.camera)
	camera_foldable.set_meta("object", layer_3d.camera)
	camera_foldable.title = "Camera"
	var environment := layer_3d.world_environment
	var environment_foldable := _create_object_property_nodes(environment)
	environment_foldable.set_meta("object", environment)
	environment_foldable.title = "Environment"
	environment_foldable.fold()
	remove_object_button.disabled = true


func _create_object_property_nodes(object: Node) -> FoldableContainer:
	var foldable_container := FoldableContainer.new()
	foldable_container.add_to_group(FOLDABLE_CONTAINER_GROUP_NAME)
	add_child(foldable_container)
	var grid_container := GridContainer.new()
	grid_container.columns = 2
	foldable_container.add_child(grid_container)
	var property_list := Layer3D.get_object_property_list(object)
	for prop in property_list:
		var prop_name: String = prop["name"]
		var curr_value = object.get_indexed(prop_name)
		var prop_name_nodepath := NodePath(prop_name)
		var subname_count := prop_name_nodepath.get_subname_count() - 1
		var string_to_humanize := prop_name
		if subname_count >= 0:
			string_to_humanize = prop_name_nodepath.get_subname(subname_count)
		var humanized_name := Keychain.humanize_snake_case(string_to_humanize, true)
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
				check_box.button_pressed = curr_value == true
				check_box.button_down.connect(func(): _undo_data = _get_undo_data(object))
				check_box.toggled.connect(_set_value_from_node.bind(object, prop_name))
				grid_container.add_child(label)
				grid_container.add_child(check_box)
			TYPE_INT, TYPE_FLOAT:
				if hint == PROPERTY_HINT_FLAGS:
					continue
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
					slider.value = curr_value
					slider.drag_started.connect(func(): _undo_data = _get_undo_data(object))
					slider.value_changed.connect(_set_value_from_node.bind(object, prop_name))
					grid_container.add_child(label)
					grid_container.add_child(slider)
			TYPE_VECTOR2, TYPE_VECTOR2I:
				var label := Label.new()
				label.text = humanized_name
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var slider := VALUE_SLIDER_V2_TSCN.instantiate() as ValueSliderV2
				slider.name = prop_name
				slider.show_ratio = true
				if type == TYPE_VECTOR2:
					slider.step = 0.01
				slider.allow_lesser = true
				slider.allow_greater = true
				slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				slider.value = curr_value
				slider.drag_started.connect(func(): _undo_data = _get_undo_data(object))
				slider.value_changed.connect(_set_value_from_node.bind(object, prop_name))
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
				slider.value = curr_value
				slider.drag_started.connect(func(): _undo_data = _get_undo_data(object))
				slider.value_changed.connect(_set_value_from_node.bind(object, prop_name))
				grid_container.add_child(label)
				grid_container.add_child(slider)
			TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_COLOR:
				var label := Label.new()
				label.text = humanized_name
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var color_picker_button := ColorPickerButton.new()
				color_picker_button.name = prop_name
				color_picker_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				color_picker_button.color = curr_value
				color_picker_button.button_down.connect(func(): _undo_data = _get_undo_data(object))
				color_picker_button.color_changed.connect(_set_value_from_node.bind(object, prop_name))
				grid_container.add_child(label)
				grid_container.add_child(color_picker_button)
	return foldable_container


func _set_value_from_node(value, to_edit: Node, prop: String) -> void:
	if not is_instance_valid(to_edit):
		return
	if prop not in _undo_data:
		print(prop, " not found in undo data.")
		return
	#if "font" in prop and not "font_" in prop:
		#value = Global.find_font_from_name(%MeshFont.get_item_text(value))
	var frame_index := layer_3d.project.current_frame
	var prev_value = _undo_data[prop]
	layer_3d.update_animation_track(to_edit, prop, value, prev_value, frame_index)


func _on_LoadModelDialog_files_selected(paths: PackedStringArray) -> void:
	for path in paths:
		var mesh := ObjParse.from_path(path)
		_add_object(Layer3D.ObjectType.ARRAY_MESH, mesh)


func _on_load_model_dialog_visibility_changed() -> void:
	Global.dialog_open(false, true)
