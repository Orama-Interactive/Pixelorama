class_name Cel3D
extends BaseCel

signal selected_object(object: Cel3DObject)
signal scene_property_changed
signal objects_changed

var size: Vector2i  ## Size of the image rendered by the cel.
var viewport: SubViewport  ## SubViewport used by the cel.
var parent_node: Node3D  ## Parent node of the 3d objects placed in the cel.
var camera: Camera3D  ## Camera that is used to render the Image.
## A [Dictionary] of the scene properties such as [param ambient_light_color] etc...
var scene_properties := {}
## Keys are the ids of all [Cel3DObject]'s present in the scene, and their corresponding values
## point to a [Dictionary] containing the properties of that [Cel3DObject].
var object_properties := {}
## The currently selected [Cel3DObject].
var selected: Cel3DObject = null:
	set(value):
		if value == selected:
			return
		if is_instance_valid(selected):  # Unselect previous object if we selected something else
			selected.deselect()
		selected = value
		if is_instance_valid(selected):  # Select new object
			selected.select()
		selected_object.emit(value)
var current_object_id := 0  ## Its value never decreases.


## Class Constructor (used as [code]Cel3D.new(size, from_pxo, object_prop, scene_prop)[/code])
func _init(_size: Vector2i, from_pxo := false, _object_prop := {}, _scene_prop := {}) -> void:
	size = _size
	object_properties = _object_prop
	scene_properties = _scene_prop
	if scene_properties.is_empty():
		var camera_transform := Transform3D()
		camera_transform.origin = Vector3(0, 0, 3)
		scene_properties = {
			"camera_transform": camera_transform,
			"camera_projection": Camera3D.PROJECTION_PERSPECTIVE,
			"camera_fov": 70.0,
			"camera_size": 1.0,
			"ambient_light_color": Color.BLACK,
			"ambient_light_energy": 1,
		}
	_add_nodes()
	if not from_pxo:
		if object_properties.is_empty():
			var transform := Transform3D()
			transform.origin = Vector3(-2.5, 0, 0)
			object_properties[0] = {"type": Cel3DObject.Type.DIR_LIGHT, "transform": transform}
			_add_object_node(0)
		current_object_id = object_properties.size()


func _add_nodes() -> void:
	viewport = SubViewport.new()
	viewport.size = size
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	var world := World3D.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	viewport.world_3d = world
	parent_node = Node3D.new()
	camera = Camera3D.new()
	camera.current = true
	deserialize_scene_properties()
	viewport.add_child(camera)
	viewport.add_child(parent_node)
	Global.canvas.add_child(viewport)
	for object in object_properties:
		_add_object_node(object)

	image_texture = viewport.get_texture()


func _get_image_texture() -> Texture2D:
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
		"ambient_light_color": viewport.world_3d.environment.ambient_light_color,
		"ambient_light_energy": viewport.world_3d.environment.ambient_light_energy
	}


func deserialize_scene_properties() -> void:
	camera.transform = scene_properties["camera_transform"]
	camera.projection = scene_properties["camera_projection"]
	camera.fov = scene_properties["camera_fov"]
	camera.size = scene_properties["camera_size"]
	viewport.world_3d.environment.ambient_light_color = scene_properties["ambient_light_color"]
	viewport.world_3d.environment.ambient_light_energy = scene_properties["ambient_light_energy"]


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


func size_changed(new_size: Vector2i) -> void:
	size = new_size
	viewport.size = size
	image_texture = viewport.get_texture()


func _scene_property_changed() -> void:  # Called by undo/redo
	deserialize_scene_properties()
	scene_property_changed.emit()


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
	objects_changed.emit()


func _remove_object_node(id: int) -> void:  ## Called by undo/redo
	var object := get_object_from_id(id)
	if is_instance_valid(object):
		if selected == object:
			selected = null
		object.queue_free()
	objects_changed.emit()


# Overridden methods


func get_image() -> Image:
	return viewport.get_texture().get_image()


func serialize() -> Dictionary:
	var dict := super.serialize()
	var scene_properties_str := {}
	for prop in scene_properties:
		scene_properties_str[prop] = var_to_str(scene_properties[prop])
	var object_properties_str := {}
	for prop in object_properties:
		object_properties_str[prop] = var_to_str(object_properties[prop])
	dict["scene_properties"] = scene_properties_str
	dict["object_properties"] = object_properties_str
	return dict


func deserialize(dict: Dictionary) -> void:
	if dict.has("pxo_version"):
		if dict["pxo_version"] == 2:  # It's a 0.x project convert it to 1.0 format
			convert_0x_to_1x(dict)
	super.deserialize(dict)
	scene_properties = {}
	var scene_properties_str: Dictionary = dict["scene_properties"]
	var objects_copy_str: Dictionary = dict["object_properties"]
	for prop in scene_properties_str:
		scene_properties[prop] = str_to_var(scene_properties_str[prop])
	for object_id_as_str in objects_copy_str:
		if typeof(object_id_as_str) != TYPE_STRING:  # failsafe in case something has gone wrong
			return
		var id := int(object_id_as_str)
		if current_object_id < id:
			current_object_id = id
		object_properties[id] = str_to_var(objects_copy_str[object_id_as_str])
	current_object_id += 1
	deserialize_scene_properties()
	for object in object_properties:
		_add_object_node(object)


## Used to convert 3d cels found in projects exported from a 0.x version to 1.x
func convert_0x_to_1x(dict: Dictionary) -> void:
	# Converting the scene dictionary
	var scene_dict: Dictionary = dict["scene_properties"]
	var old_transform_string = scene_dict["camera_transform"]
	scene_dict["camera_transform"] = (
		"Transform3D(" + old_transform_string.replace(" - ", ", ") + ")"
	)
	scene_dict["camera_projection"] = var_to_str(int(scene_dict["camera_projection"]))
	scene_dict["camera_fov"] = var_to_str(scene_dict["camera_fov"])
	scene_dict["camera_size"] = var_to_str(scene_dict["camera_size"])
	scene_dict["ambient_light_color"] = "Color(" + scene_dict["ambient_light_color"] + ")"
	scene_dict["ambient_light_energy"] = var_to_str(scene_dict["ambient_light_energy"])
	# Converting the objects dictionary
	var objects_copy_str: Dictionary = dict["object_properties"]
	for object_id_as_str in objects_copy_str.keys():
		var object_info = objects_copy_str[object_id_as_str]
		for object_property in object_info:
			if object_property == "id" or object_property == "type":
				object_info[object_property] = int(object_info[object_property])
			elif typeof(object_info[object_property]) != TYPE_STRING:
				continue
			elif "color" in object_property:  # Convert a String to a Color
				object_info[object_property] = str_to_var(
					"Color(" + object_info[object_property] + ")"
				)
			elif "transform" in object_property:  # Convert a String to a Transform
				var transform_string: String = object_info[object_property].replace(" - ", ", ")
				object_info[object_property] = str_to_var("Transform3D(" + transform_string + ")")
			elif "v2" in object_property:  # Convert a String to a Vector2
				object_info[object_property] = str_to_var("Vector2" + object_info[object_property])
			elif "size" in object_property or "center_offset" in object_property:
				# Convert a String to a Vector3
				object_info[object_property] = str_to_var("Vector3" + object_info[object_property])
		# Special operations to adjust gizmo
		# take note of origin
		var origin = object_info["transform"].origin
		match object_info["type"]:
			0:  # BOX
				object_info["transform"] = object_info["transform"].scaled(Vector3.ONE * 2)
				object_info["transform"].origin = origin
				object_info["mesh_size"] /= 2
			1:  # SPHERE
				object_info["transform"] = object_info["transform"].scaled(Vector3.ONE * 2)
				object_info["transform"].origin = origin
				object_info["mesh_radius"] /= 2
				object_info["mesh_height"] /= 2
			2:  # CAPSULE
				object_info["transform"] = (
					object_info["transform"]
					. scaled(Vector3.ONE * 2)
					. rotated_local(Vector3.LEFT, deg_to_rad(-90))
				)
				object_info["transform"].origin = origin
				object_info["mesh_radius"] /= 2
				object_info["mesh_height"] = (
					object_info["mesh_mid_height"] + object_info["mesh_radius"]
				)
			3:  # CYLINDER
				object_info["transform"] = object_info["transform"].scaled(Vector3.ONE * 2)
				object_info["transform"].origin = origin
				object_info["mesh_height"] /= 2
				object_info["mesh_bottom_radius"] /= 2
				object_info["mesh_top_radius"] /= 2
			4:  # PRISM
				object_info["transform"] = object_info["transform"].scaled(Vector3.ONE * 2)
				object_info["transform"].origin = origin
				object_info["mesh_size"] /= 2
			6:  # PLANE
				object_info["transform"] = object_info["transform"].scaled(Vector3.ONE * 2)
				object_info["transform"].origin = origin
				object_info["mesh_sizev2"] /= 2
			7:  # TEXT
				object_info["mesh_vertical_alignment"] = VERTICAL_ALIGNMENT_BOTTOM
				object_info["mesh_font_size"] = 12
				object_info["mesh_offset"] = Vector2.UP * 3
		objects_copy_str[object_id_as_str] = var_to_str(objects_copy_str[object_id_as_str])


func on_remove() -> void:
	if is_instance_valid(viewport):
		viewport.queue_free()


func get_class_name() -> String:
	return "Cel3D"
