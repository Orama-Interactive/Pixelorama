class_name Cel3D
extends BaseCel

signal selected_object(object)
signal scene_property_changed
signal objects_changed

var size: Vector2
var viewport: Viewport
var parent_node: Spatial
var camera: Camera
var scene_properties := {}
# Key = Cel3DObject's id, Value = Dictionary containing the properties of the Cel3DObject
var object_properties := {}
var selected: Cel3DObject = null setget _set_selected
var current_object_id := 0  # Its value never decreases


func _init(_size: Vector2, from_pxo := false, _object_prop := {}, _scene_prop := {}) -> void:
	size = _size
	object_properties = _object_prop
	scene_properties = _scene_prop
	if scene_properties.empty():
		var camera_transform := Transform()
		camera_transform.origin = Vector3(0, 0, 3)
		scene_properties = {
			"camera_transform": camera_transform,
			"camera_projection": Camera.PROJECTION_PERSPECTIVE,
			"camera_fov": 70.0,
			"camera_size": 1.0,
			"ambient_light_color": Color.black,
			"ambient_light_energy": 1,
		}
	_add_nodes()
	if not from_pxo:
		if object_properties.empty():
			var transform := Transform()
			transform.origin = Vector3(-2.5, 0, 0)
			object_properties[0] = {"type": Cel3DObject.Type.DIR_LIGHT, "transform": transform}
			_add_object_node(0)
		current_object_id = object_properties.size()


func _add_nodes() -> void:
	viewport = Viewport.new()
	viewport.size = size
	viewport.own_world = true
	viewport.transparent_bg = true
	viewport.render_target_v_flip = true
	var world := World.new()
	var environment := Environment.new()
	world.environment = environment
	viewport.world = world
	parent_node = Spatial.new()
	camera = Camera.new()
	camera.current = true
	deserialize_scene_properties()
	viewport.add_child(camera)
	viewport.add_child(parent_node)
	Global.canvas.add_child(viewport)
	for object in object_properties:
		_add_object_node(object)

	image_texture = viewport.get_texture()


func _get_image_texture() -> Texture:
	if not is_instance_valid(viewport):
		_add_nodes()
	return image_texture


func serialize_scene_properties() -> Dictionary:
	if not is_instance_valid(camera):
		return {}
	return {
		"camera_transform": camera.transform,
		"camera_projection": camera.projection,
		"camera_fov": camera.fov,
		"camera_size": camera.size,
		"ambient_light_color": viewport.world.environment.ambient_light_color,
		"ambient_light_energy": viewport.world.environment.ambient_light_energy
	}


func deserialize_scene_properties() -> void:
	camera.transform = scene_properties["camera_transform"]
	camera.projection = scene_properties["camera_projection"]
	camera.fov = scene_properties["camera_fov"]
	camera.size = scene_properties["camera_size"]
	viewport.world.environment.ambient_light_color = scene_properties["ambient_light_color"]
	viewport.world.environment.ambient_light_energy = scene_properties["ambient_light_energy"]


func _update_objects_transform(id: int) -> void:  # Called by undo/redo
	var properties: Dictionary = object_properties[id]
	var object := get_object_from_id(id)
	if not object:
		print("Object with id %s not found" % id)
		return
	object.deserialize(properties)


func get_object_from_id(id: int) -> Cel3DObject:
	for child in parent_node.get_children():
		if not child is Cel3DObject:
			continue
		if child.id == id:
			return child
	return null


func size_changed(new_size: Vector2) -> void:
	size = new_size
	viewport.size = size
	image_texture = viewport.get_texture()


func _scene_property_changed() -> void:  # Called by undo/redo
	deserialize_scene_properties()
	emit_signal("scene_property_changed")


func _add_object_node(id: int) -> void:
	if not object_properties.has(id):
		print("Object id not found.")
		return
	var node3d := Cel3DObject.new()
	node3d.id = id
	node3d.cel = self
	parent_node.add_child(node3d)
	if object_properties[id].has("id"):
		node3d.deserialize(object_properties[id])
	else:
		if object_properties[id].has("transform"):
			node3d.transform = object_properties[id]["transform"]
		if object_properties[id].has("file_path"):
			node3d.file_path = object_properties[id]["file_path"]
		if object_properties[id].has("type"):
			node3d.type = object_properties[id]["type"]
		object_properties[id] = node3d.serialize()
	emit_signal("objects_changed")


func _remove_object_node(id: int) -> void:  # Called by undo/redo
	var object := get_object_from_id(id)
	if is_instance_valid(object):
		if selected == object:
			self.selected = null
		object.queue_free()
	emit_signal("objects_changed")


func _set_selected(value: Cel3DObject) -> void:
	if value == selected:
		return
	if is_instance_valid(selected):  # Unselect previous object if we selected something else
		selected.unselect()
	selected = value
	if is_instance_valid(selected):  # Select new object
		selected.select()
	emit_signal("selected_object", value)


# Overridden methods


func get_image() -> Image:
	return viewport.get_texture().get_data()


func serialize() -> Dictionary:
	var dict := .serialize()
	dict["scene_properties"] = scene_properties
	dict["object_properties"] = object_properties
	return dict


func deserialize(dict: Dictionary) -> void:
	if dict.has("pxo_version"):
		if dict["pxo_version"] == 3:  # It's a 1.x project convert it to 0.x format
			convert_1x_to_0x(dict)
	.deserialize(dict)
	scene_properties = dict["scene_properties"]
	var objects_copy = dict["object_properties"]
	for object in objects_copy:
		if typeof(object) != TYPE_STRING:
			return
		Global.convert_dictionary_values(objects_copy[object])
		var id := int(object)
		if current_object_id < id:
			current_object_id = id
		object_properties[id] = objects_copy[object]
	current_object_id += 1
	Global.convert_dictionary_values(scene_properties)
	deserialize_scene_properties()
	for object in object_properties:
		_add_object_node(object)


## Used to convert 3d cels found in projects exported from a 0.x version to 1.x
func convert_1x_to_0x(dict: Dictionary) -> void:
	# Converting the scene dictionary
	var scene_dict: Dictionary = dict["scene_properties"]
	scene_dict["camera_transform"] = str2var(
		scene_dict["camera_transform"].replace("Transform3D", "Transform")
	)
	scene_dict["camera_projection"] = str2var(scene_dict["camera_projection"])
	scene_dict["camera_fov"] = str2var(scene_dict["camera_fov"])
	scene_dict["camera_size"] = str2var(scene_dict["camera_size"])
	scene_dict["ambient_light_color"] = str2var(scene_dict["ambient_light_color"])
	scene_dict["ambient_light_energy"] = str2var(scene_dict["ambient_light_energy"])
	# Converting the objects dictionary
	var objects_copy: Dictionary = dict["object_properties"]
	for object_id_as_str in objects_copy.keys():
		objects_copy[object_id_as_str] = str2var(
			objects_copy[object_id_as_str].replace("Transform3D", "Transform")
		)
		# we are using a separate variable to make it easy to write
		var object_info: Dictionary = objects_copy[object_id_as_str]
		# Special operations to adjust gizmo
		# take note of origin
		var origin = object_info["transform"].origin
		match object_info["type"]:
			0:  # BOX
				object_info["transform"] = object_info["transform"].scaled(Vector3.ONE / 2)
				object_info["transform"].origin = origin
				object_info["mesh_size"] *= 2
			1:  # SPHERE
				object_info["transform"] = object_info["transform"].scaled(Vector3.ONE / 2)
				object_info["transform"].origin = origin
				object_info["mesh_radius"] *= 2
				object_info["mesh_height"] *= 2
			2:  # CAPSULE
				object_info["transform"] = object_info["transform"].scaled(-(Vector3.ONE / 2))
				var basis = object_info["transform"].basis
				var new_transform: Transform = Transform(basis.x, -basis.z, -basis.y, origin)
				object_info["transform"] = new_transform
				object_info["transform"].origin = origin
				object_info["mesh_radius"] *= 2
				object_info["mesh_mid_height"] = (
					object_info["mesh_height"]
					- (object_info["mesh_radius"] / 2)
				)
			3:  # CYLINDER
				object_info["transform"] = object_info["transform"].scaled(Vector3.ONE / 2)
				object_info["transform"].origin = origin
				object_info["mesh_height"] *= 2
				object_info["mesh_bottom_radius"] *= 2
				object_info["mesh_top_radius"] *= 2
			4:  # PRISM
				object_info["transform"] = object_info["transform"].scaled(Vector3.ONE / 2)
				object_info["transform"].origin = origin
				object_info["mesh_size"] *= 2
			6:  # PLANE
				object_info["transform"] = object_info["transform"].scaled(Vector3.ONE / 2)
				object_info["transform"].origin = origin
				object_info["mesh_sizev2"] *= 2
			_:
				if not "shadow_color" in object_info.keys():
					object_info["shadow_color"] = Color.black
		objects_copy[object_id_as_str] = objects_copy[object_id_as_str]


func on_remove() -> void:
	if is_instance_valid(viewport):
		viewport.queue_free()


func save_image_data_to_pxo(file: File) -> void:
	file.store_buffer(get_image().get_data())


func load_image_data_from_pxo(file: File, project_size: Vector2) -> void:
	# Don't do anything with it, just read it so that the file can move on
	file.get_buffer(project_size.x * project_size.y * 4)


func instantiate_cel_button() -> Node:
	return Global.cel_3d_button_node.instance()


func get_class_name() -> String:
	return "Cel3D"
