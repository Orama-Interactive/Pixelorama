class_name Layer3D
extends BaseLayer

signal property_changed
signal objects_changed

var properties := {}  # Key = property name, Value = property
var objects := {}  # Key = id, Value = Cel3DObject.Type
var current_object_id := 0  # Its value never decreases


func _init(_project, _name := "") -> void:
	project = _project
	name = _name
	var camera_transform := Transform()
	camera_transform.origin = Vector3(0, 0, 3)
	properties = {
		"camera_transform": camera_transform,
		"camera_projection": Camera.PROJECTION_PERSPECTIVE,
		"ambient_light_color": Color.black,
		"ambient_light_energy": 1,
	}
	add_object(Cel3DObject.Type.DIR_LIGHT, false)
	add_object(Cel3DObject.Type.BOX, false)


func add_object(type: int, undoredo := true, file_path := "") -> void:
	if undoredo:
		var id := current_object_id
		var new_objects := objects.duplicate()
		new_objects[id] = type
		var undo_redo: UndoRedo = project.undo_redo
		undo_redo.create_action("Add 3D object")
		undo_redo.add_do_property(self, "objects", new_objects)
		undo_redo.add_undo_property(self, "objects", objects)
		for frame in project.frames:
			var cel: Cel3D = frame.cels[index]
			var new_properties := cel.object_properties.duplicate()
			new_properties[id] = {"file_path": file_path}
			undo_redo.add_do_property(cel, "object_properties", new_properties)
			undo_redo.add_undo_property(cel, "object_properties", cel.object_properties)
		undo_redo.add_do_method(self, "add_object_in_cels", id)
		undo_redo.add_undo_method(self, "remove_object_from_cels", id)
		undo_redo.add_do_method(Global, "undo_or_redo", false)
		undo_redo.add_undo_method(Global, "undo_or_redo", true)
		undo_redo.commit_action()
	else:
		objects[current_object_id] = type

	current_object_id += 1


func add_object_in_cels(id: int) -> void:
	for frame in project.frames:
		var cel: Cel3D = frame.cels[index]
		cel.add_object(id)
	emit_signal("objects_changed")


func remove_object(id: int) -> void:
	var new_objects := objects.duplicate()
	new_objects.erase(id)
	var undo_redo: UndoRedo = project.undo_redo
	undo_redo.create_action("Remove 3D object")
	undo_redo.add_do_property(self, "objects", new_objects)
	undo_redo.add_undo_property(self, "objects", objects)
	# Store object_properties in undoredo memory to keep previous transforms
	for frame in project.frames:
		var cel: Cel3D = frame.cels[index]
		var new_properties := cel.object_properties.duplicate()
		new_properties.erase(id)
		undo_redo.add_do_property(cel, "object_properties", new_properties)
		undo_redo.add_undo_property(cel, "object_properties", cel.object_properties)
	undo_redo.add_do_method(self, "remove_object_from_cels", id)
	undo_redo.add_undo_method(self, "add_object_in_cels", id)
	undo_redo.add_do_method(Global, "undo_or_redo", false)
	undo_redo.add_undo_method(Global, "undo_or_redo", true)
	undo_redo.commit_action()


func remove_object_from_cels(id: int) -> void:
	for frame in project.frames:
		var cel: Cel3D = frame.cels[index]
		cel.remove_object(id)
	emit_signal("objects_changed")


func change_properties(new_properties: Dictionary) -> void:
	var undo_redo: UndoRedo = project.undo_redo
	undo_redo.create_action("Change 3D layer properties")
	undo_redo.add_do_property(self, "properties", new_properties)
	undo_redo.add_undo_property(self, "properties", properties)
	for frame in project.frames:
		var cel: Cel3D = frame.cels[index]
		undo_redo.add_do_method(cel, "deserialize_layer_properties")
		undo_redo.add_undo_method(cel, "deserialize_layer_properties")
	undo_redo.add_do_method(self, "_property_changed")
	undo_redo.add_undo_method(self, "_property_changed")
	undo_redo.add_do_method(Global, "undo_or_redo", false)
	undo_redo.add_undo_method(Global, "undo_or_redo", true)
	undo_redo.commit_action()


func _property_changed() -> void:
	emit_signal("property_changed")


# Overridden Methods:


func serialize() -> Dictionary:
	var dict = .serialize()
	dict["type"] = get_layer_type()
	dict["properties"] = properties
	dict["objects"] = objects
#	dict["new_cels_linked"] = new_cels_linked
	return dict


func deserialize(dict: Dictionary) -> void:
	.deserialize(dict)
	properties = dict["properties"]
	objects = dict["objects"]
#	new_cels_linked = dict.new_cels_linked
	current_object_id = objects.size()
	Global.convert_dictionary_values(properties)


func get_layer_type() -> int:
	return Global.LayerTypes.THREE_D


func new_empty_cel() -> BaseCel:
	return Cel3D.new(self, project.size)


func can_layer_get_drawn() -> bool:
	return is_visible_in_hierarchy() && !is_locked_in_hierarchy()


func instantiate_layer_button() -> Node:
	return Global.base_layer_button_node.instance()
