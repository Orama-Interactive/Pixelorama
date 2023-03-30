class_name Cel3D
extends BaseCel

signal selected_object(object)
signal scene_property_changed
signal objects_changed

var layer
var size: Vector2
var viewport: Viewport
var parent_node: Spatial
var camera: Camera
var scene_properties := {}
# Key = Cel3DObject's id, Value = Dictionary containing the properties of the Cel3DObject
var object_properties := {}
var selected: Cel3DObject = null setget _set_selected

var _current_object_id := 0  # Its value never decreases


func _init(
	_layer, _size: Vector2, from_pxo := false, _object_properties := {}, _scene_properties := {}
) -> void:
	layer = _layer
	size = _size
	object_properties = _object_properties
	scene_properties = _scene_properties
	if scene_properties.empty():
		var camera_transform := Transform()
		camera_transform.origin = Vector3(0, 0, 3)
		scene_properties = {
			"camera_transform": camera_transform,
			"camera_projection": Camera.PROJECTION_PERSPECTIVE,
			"ambient_light_color": Color.black,
			"ambient_light_energy": 1,
		}
	_add_nodes()
	if not from_pxo:
		if object_properties.empty():
			add_object(Cel3DObject.Type.DIR_LIGHT, false)
			add_object(Cel3DObject.Type.BOX, false)
		else:
			_current_object_id = object_properties.size()


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


func change_scene_properties() -> void:
	var undo_redo: UndoRedo = layer.project.undo_redo
	undo_redo.create_action("Change 3D layer properties")
	undo_redo.add_do_property(self, "scene_properties", serialize_scene_properties())
	undo_redo.add_undo_property(self, "scene_properties", scene_properties)
	undo_redo.add_do_method(self, "_scene_property_changed")
	undo_redo.add_undo_method(self, "_scene_property_changed")
	undo_redo.add_do_method(Global, "undo_or_redo", false)
	undo_redo.add_undo_method(Global, "undo_or_redo", true)
	undo_redo.commit_action()


func serialize_scene_properties() -> Dictionary:  # To layer
	if not is_instance_valid(camera):
		return {}
	return {
		"camera_transform": camera.transform,
		"camera_projection": camera.projection,
		"ambient_light_color": viewport.world.environment.ambient_light_color,
		"ambient_light_energy": viewport.world.environment.ambient_light_energy
	}


func deserialize_scene_properties() -> void:
	camera.transform = scene_properties["camera_transform"]
	camera.projection = scene_properties["camera_projection"]
	viewport.world.environment.ambient_light_color = scene_properties["ambient_light_color"]
	viewport.world.environment.ambient_light_energy = scene_properties["ambient_light_energy"]


func _object_property_changed(object: Cel3DObject) -> void:
	var undo_redo: UndoRedo = layer.project.undo_redo
	var new_properties := object_properties.duplicate()
	new_properties[object.id] = object.serialize()
	undo_redo.create_action("Change object transform")
	undo_redo.add_do_property(self, "object_properties", new_properties)
	undo_redo.add_undo_property(self, "object_properties", object_properties)
	undo_redo.add_do_method(self, "_update_objects_transform", object.id)
	undo_redo.add_undo_method(self, "_update_objects_transform", object.id)
	undo_redo.add_do_method(Global, "undo_or_redo", false)
	undo_redo.add_undo_method(Global, "undo_or_redo", true)
	undo_redo.commit_action()


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


func add_object(type: int, undoredo := true, file_path := "") -> void:
	var dict := {"type": type, "file_path": file_path}
	if undoredo:
		var new_objects := object_properties.duplicate()
		new_objects[_current_object_id] = dict
		var undo_redo: UndoRedo = layer.project.undo_redo
		undo_redo.create_action("Add 3D object")
		undo_redo.add_do_property(self, "object_properties", new_objects)
		undo_redo.add_undo_property(self, "object_properties", object_properties)
		undo_redo.add_do_method(self, "_add_object_node", _current_object_id)
		undo_redo.add_undo_method(self, "_remove_object_node", _current_object_id)
		undo_redo.add_do_method(Global, "undo_or_redo", false)
		undo_redo.add_undo_method(Global, "undo_or_redo", true)
		undo_redo.commit_action()
	else:
		object_properties[_current_object_id] = dict
		_add_object_node(_current_object_id)

	_current_object_id += 1


func remove_object(id: int) -> void:
	var new_objects := object_properties.duplicate()
	new_objects.erase(id)
	var undo_redo: UndoRedo = layer.project.undo_redo
	undo_redo.create_action("Remove 3D object")
	undo_redo.add_do_property(self, "object_properties", new_objects)
	undo_redo.add_undo_property(self, "object_properties", object_properties)
	undo_redo.add_do_method(self, "_remove_object_node", id)
	undo_redo.add_undo_method(self, "_add_object_node", id)
	undo_redo.add_do_method(Global, "undo_or_redo", false)
	undo_redo.add_undo_method(Global, "undo_or_redo", true)
	undo_redo.commit_action()


func _scene_property_changed() -> void:  # Called by undo/redo
	deserialize_scene_properties()
	emit_signal("scene_property_changed")


func _add_object_node(id: int) -> void:
	var node3d := Cel3DObject.new()
	node3d.id = id
	node3d.cel = self
	node3d.connect("property_finished_changing", self, "_object_property_changed", [node3d])
	parent_node.add_child(node3d)
	node3d.type = object_properties[node3d.id]["type"]
	if _current_object_id == 0:  # Directional light
		node3d.translation = Vector3(-2.5, 0, 0)
		node3d.rotate_y(-PI / 4)
	if object_properties.has(node3d.id) and object_properties[node3d.id].has("id"):
		node3d.deserialize(object_properties[node3d.id])
	else:
		if object_properties.has(node3d.id) and object_properties[node3d.id].has("file_path"):
			node3d.file_path = object_properties[node3d.id]["file_path"]
		object_properties[node3d.id] = node3d.serialize()
	emit_signal("objects_changed")


func _remove_object_node(id: int) -> void:  # Called by undo/redo
	var object := get_object_from_id(id)
	if is_instance_valid(object):
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
	.deserialize(dict)
	scene_properties = dict["scene_properties"]
	var objects_copy = dict["object_properties"]
	for object in objects_copy:
		if typeof(object) != TYPE_STRING:
			return
		Global.convert_dictionary_values(objects_copy[object])
		object_properties[int(object)] = objects_copy[object]
	_current_object_id = object_properties.size()
	Global.convert_dictionary_values(scene_properties)
	deserialize_scene_properties()
	for object in object_properties:
		_add_object_node(object)


func on_remove() -> void:
	if is_instance_valid(viewport):
		viewport.queue_free()


func instantiate_cel_button() -> Node:
	return Global.pixel_cel_button_node.instance()
