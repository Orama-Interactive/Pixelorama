extends BaseTool

var layer_3d: Layer3D
var _undo_data: Dictionary[StringName, Variant] = {}
var _cel: Cel3D
var _can_start_timer := true
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
@onready var cel_options := $"%CelOptions" as Container
@onready var object_options := $"%ObjectOptions" as Container
@onready var mesh_options := $"%MeshOptions" as FoldableContainer
@onready var light_options := $"%LightOptions" as FoldableContainer
@onready var undo_redo_timer := $UndoRedoTimer as Timer
@onready var load_model_dialog := $LoadModelDialog as FileDialog

@onready var cel_properties: Dictionary[NodePath, Control] = {
	"camera:projection": $"%ProjectionOptionButton",
	"camera:rotation_degrees": $"%CameraRotation",
	"camera:fov": $"%CameraFOV",
	"camera:size": $"%CameraSize",
	"viewport:world_3d:environment:ambient_light_color": $"%AmbientColorPickerButton",
	"viewport:world_3d:environment:ambient_light_energy": $"%AmbientEnergy",
}

@onready var object_properties: Dictionary[NodePath, Control] = {
	"visible": $"%VisibleCheckBox",
	"position": $"%ObjectPosition",
	"rotation_degrees": $"%ObjectRotation",
	"scale": $"%ObjectScale",
	"mesh:size": $"%MeshSize",
	"mesh:sizev2": $"%MeshSizeV2",
	"mesh:left_to_right": $"%MeshLeftToRight",
	"mesh:radius": $"%MeshRadius",
	"mesh:height": $"%MeshHeight",
	"mesh:radial_segments": $"%MeshRadialSegments",
	"mesh:rings": $"%MeshRings",
	"mesh:is_hemisphere": $"%MeshIsHemisphere",
	"mesh:top_radius": $"%MeshTopRadius",
	"mesh:bottom_radius": $"%MeshBottomRadius",
	"mesh:text": $"%MeshText",
	"mesh:font": $"%MeshFont",
	"mesh:pixel_size": $"%MeshPixelSize",
	"mesh:font_size": $"%MeshFontSize",
	"mesh:offset": $"%MeshOffsetV2",
	"mesh:depth": $"%MeshDepth",
	"mesh:curve_step": $"%MeshCurveStep",
	"mesh:horizontal_alignment": $"%MeshHorizontalAlignment",
	"mesh:vertical_alignment": $"%MeshVerticalAlignment",
	"mesh:line_spacing": $"%MeshLineSpacing",
	"light_color": $"%LightColor",
	"light_energy": $"%LightEnergy",
	"light_negative": $"%LightNegative",
	"shadow_enabled": $"%ShadowEnabled",
	"omni_range": $"%OmniRange",
	"spot_range": $"%SpotRange",
	"spot_angle": $"%SpotAngle",
}


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
	# Load font names
	for font_name in Global.get_available_font_names():
		$"%MeshFont".add_item(font_name)
	# Connect the signals of the cel property nodes
	for prop in cel_properties:
		var node := cel_properties[prop]
		if node is ValueSliderV3:
			node.value_changed.connect(_cel_property_vector3_changed.bind(prop))
		elif node is Range:
			node.value_changed.connect(_cel_property_value_changed.bind(prop))
		elif node is OptionButton:
			node.item_selected.connect(_cel_property_item_selected.bind(prop))
		elif node is ColorPickerButton:
			node.color_changed.connect(_cel_property_color_changed.bind(prop))
	# Connect the signals of the object property nodes
	for prop in object_properties:
		var node: Control = object_properties[prop]
		if node is ValueSliderV3:
			node.value_changed.connect(_object_property_vector3_changed.bind(prop))
		elif node is ValueSliderV2:
			var property_path: String = prop
			if property_path.ends_with("v2"):
				property_path = property_path.replace("v2", "")
			node.value_changed.connect(_object_property_vector2_changed.bind(property_path))
		elif node is Range:
			node.value_changed.connect(_object_property_value_changed.bind(prop))
		elif node is OptionButton:
			node.item_selected.connect(_object_property_item_selected.bind(prop))
		elif node is ColorPickerButton:
			node.color_changed.connect(_object_property_color_changed.bind(prop))
		elif node is CheckBox:
			node.toggled.connect(_object_property_toggled.bind(prop))
		elif node is TextEdit:
			node.text_changed.connect(_object_property_text_changed.bind(node, prop))


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


func _get_undo_data(node: Node3D) -> Dictionary[StringName, Variant]:
	var data: Dictionary[StringName, Variant]
	data[&"position"] = node.position
	data[&"rotation"] = node.rotation
	data[&"scale"] = node.scale
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
	cel_options.visible = true
	object_options.visible = false
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
	var node3d := layer_3d.create_node(type, custom_mesh)
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


func _object_property_changed(object: Node3D, property: StringName, by_undo_redo: bool) -> void:
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


func _on_selected_object(object: Node3D, _old_object: Node3D) -> void:
	if is_instance_valid(object):
		cel_options.visible = false
		object_options.visible = true
		remove_object_button.disabled = false
		for prop in object_properties:  # Hide irrelevant nodes
			var node: Control = object_properties[prop]
			var property_path: String = prop
			if property_path.ends_with("v2"):
				property_path = property_path.replace("v2", "")
			var property = object.get_indexed(property_path)
			var property_exists: bool = property != null
			# Differentiate between the mesh size of a box/prism (Vector3) and a plane (Vector2)
			if node is ValueSliderV3 and typeof(property) != TYPE_VECTOR3:
				property_exists = false
			elif node is ValueSliderV2 and typeof(property) != TYPE_VECTOR2:
				property_exists = false
			if node.get_index() > 0:
				_get_previous_node(node).visible = property_exists
			node.visible = property_exists
		mesh_options.visible = object is MeshInstance3D
		light_options.visible = object is Light3D
		_set_object_node_values()
		#if not object.property_changed.is_connected(_set_object_node_values):
			#object.property_changed.connect(_set_object_node_values)
		#object_option_button.select(object_option_button.get_item_index(object.id + 1))
	else:
		cel_options.visible = true
		object_options.visible = false
		remove_object_button.disabled = true
		object_option_button.select(0)


func _set_cel_node_values() -> void:
	return
	if layer_3d.camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		_get_previous_node(cel_properties[^"camera:fov"]).visible = true
		_get_previous_node(cel_properties[^"camera:size"]).visible = false
		cel_properties[^"camera:fov"].visible = true
		cel_properties[^"camera:size"].visible = false
	else:
		_get_previous_node(cel_properties[^"camera:size"]).visible = true
		_get_previous_node(cel_properties[^"camera:fov"]).visible = false
		cel_properties[^"camera:size"].visible = true
		cel_properties[^"camera:fov"].visible = false
	_can_start_timer = false
	_set_node_values(_cel, cel_properties)
	_can_start_timer = true


func _set_object_node_values() -> void:
	return
	var object := layer_3d.selected
	if not is_instance_valid(object):
		return
	_can_start_timer = false
	_set_node_values(object, object_properties)
	_can_start_timer = true


func _set_node_values(to_edit: Object, properties: Dictionary[NodePath, Control]) -> void:
	for prop in properties:
		var property_path: String = prop
		if property_path.ends_with("v2"):
			property_path = property_path.replace("v2", "")
		var value = to_edit.get_indexed(property_path)
		if value == null:
			continue
		if "scale" in property_path:
			value *= 100
		if value is Font:
			var font_name: String = value.get_font_name()
			value = 0
			for i in %MeshFont.item_count:
				var item_name: String = %MeshFont.get_item_text(i)
				if font_name == item_name:
					value = i
		var node := properties[prop]
		if node is Range or node is ValueSliderV3 or node is ValueSliderV2:
			if typeof(node.value) != typeof(value) and typeof(value) != TYPE_INT:
				continue
			node.value = value
		elif node is OptionButton:
			node.selected = value
		elif node is ColorPickerButton:
			node.color = value
		elif node is CheckBox:
			node.button_pressed = value
		elif node is TextEdit:
			if node.text != value:
				node.text = value


func _get_previous_node(node: Node) -> Node:
	return node.get_parent().get_child(node.get_index() - 1)


func _set_value_from_node(to_edit: Object, value, prop: String) -> void:
	if not is_instance_valid(to_edit):
		return
	if "mesh_" in prop:
		prop = prop.replace("mesh_", "")
		to_edit = to_edit.node3d_type.mesh
	if "scale" in prop:
		value /= 100
	if "font" in prop and not "font_" in prop:
		value = Global.find_font_from_name(%MeshFont.get_item_text(value))
	to_edit.set_indexed(prop, value)


func _cel_property_vector3_changed(value: Vector3, prop: String) -> void:
	_set_value_from_node(_cel, value, prop)
	_value_handle_change()
	Global.canvas.gizmos_3d.queue_redraw()


func _cel_property_value_changed(value: float, prop: String) -> void:
	_set_value_from_node(_cel, value, prop)
	_value_handle_change()
	Global.canvas.gizmos_3d.queue_redraw()


func _cel_property_item_selected(value: int, prop: String) -> void:
	_set_value_from_node(_cel, value, prop)
	_value_handle_change()
	Global.canvas.gizmos_3d.queue_redraw()


func _cel_property_color_changed(value: Color, prop: String) -> void:
	_set_value_from_node(_cel, value, prop)
	_value_handle_change()
	Global.canvas.gizmos_3d.queue_redraw()


func _object_property_vector3_changed(value: Vector3, prop: String) -> void:
	_set_value_from_node(layer_3d.selected, value, prop)
	_value_handle_change()


func _object_property_vector2_changed(value: Vector2, prop: String) -> void:
	_set_value_from_node(layer_3d.selected, value, prop)
	_value_handle_change()


func _object_property_value_changed(value: float, prop: String) -> void:
	_set_value_from_node(layer_3d.selected, value, prop)
	_value_handle_change()


func _object_property_item_selected(value: int, prop: String) -> void:
	_set_value_from_node(layer_3d.selected, value, prop)
	_value_handle_change()


func _object_property_color_changed(value: Color, prop: String) -> void:
	_set_value_from_node(layer_3d.selected, value, prop)
	_value_handle_change()


func _object_property_toggled(value: bool, prop: String) -> void:
	_set_value_from_node(layer_3d.selected, value, prop)
	_value_handle_change()


func _object_property_text_changed(text_edit: TextEdit, prop: String) -> void:
	_set_value_from_node(layer_3d.selected, text_edit.text, prop)
	_value_handle_change()


func _value_handle_change() -> void:
	if _can_start_timer:
		undo_redo_timer.start()


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
