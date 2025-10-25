class_name Layer3D
extends BaseLayer
## A class for 3D layer properties.

signal selected_object_changed(new_selected: Node3D, old_selected: Node3D)
@warning_ignore("unused_signal")
signal object_hovered(new_hovered: Node3D, old_hovered: Node3D, is_selected: bool)
signal node_property_changed(node: Node3D, property_name: StringName, by_undo_redo: bool)

enum ObjectType {
	BOX,
	SPHERE,
	CAPSULE,
	CYLINDER,
	PRISM,
	TORUS,
	PLANE,
	TEXT,
	ARRAY_MESH,
	DIR_LIGHT,
	SPOT_LIGHT,
	OMNI_LIGHT,
}

enum Gizmos { NONE, X_POS, Y_POS, Z_POS, X_ROT, Y_ROT, Z_ROT, X_SCALE, Y_SCALE, Z_SCALE }

const DIR_LIGHT_TEXTURE := preload("res://assets/graphics/gizmos/directional_light.svg")
const SPOT_LIGHT_TEXTURE := preload("res://assets/graphics/gizmos/spot_light.svg")
const OMNI_LIGHT_TEXTURE := preload("res://assets/graphics/gizmos/omni_light.svg")

var viewport: SubViewport  ## SubViewport used by the layer.
var parent_node: Node3D  ## Parent node of the 3D objects placed in the layer.
var camera: Camera3D  ## Camera that is used to render the Image.
## The currently selected [Cel3DObject].
var selected: Node3D = null:
	set(value):
		# If there was a previously selected object, disconnect the tree_exiting signal.
		if is_instance_valid(selected) and selected.tree_exiting.is_connected(unselect):
			selected.tree_exiting.disconnect(unselect)
		selected_object_changed.emit(value, selected)
		selected = value
		# If we selected an object, connect its tree_exiting signal to the unselect method.
		# This is needed in case the selected object gets removed, in which case,
		# we want to unselect that object.
		if is_instance_valid(selected) and not selected.tree_exiting.is_connected(unselect):
			selected.tree_exiting.connect(unselect)
var gizmos_3d: Node2D = Global.canvas.gizmos_3d


func _init(_project: Project, _name := "", from_pxo := false) -> void:
	project = _project
	name = _name
	if not from_pxo:
		_add_nodes(project.size)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(viewport):
			viewport.queue_free()


func _add_nodes(size: Vector2i) -> void:
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
	camera.position.z = 3
	camera.fov = 70
	var dir_light := create_node(ObjectType.DIR_LIGHT)
	dir_light.transform = Transform3D(Basis(), Vector3(-2.5, 0, 0))
	parent_node.add_child(dir_light)
	viewport.add_child(camera)
	viewport.add_child(parent_node)
	Global.canvas.add_child(viewport)


func unselect() -> void:
	selected = null


func create_node(type: ObjectType, custom_mesh: Mesh = null) -> Node3D:
	var node3d: Node3D
	match type:
		ObjectType.BOX:
			node3d = MeshInstance3D.new()
			node3d.mesh = BoxMesh.new()
		ObjectType.SPHERE:
			node3d = MeshInstance3D.new()
			node3d.mesh = SphereMesh.new()
		ObjectType.CAPSULE:
			node3d = MeshInstance3D.new()
			node3d.mesh = CapsuleMesh.new()
		ObjectType.CYLINDER:
			node3d = MeshInstance3D.new()
			node3d.mesh = CylinderMesh.new()
		ObjectType.PRISM:
			node3d = MeshInstance3D.new()
			node3d.mesh = PrismMesh.new()
		ObjectType.PLANE:
			node3d = MeshInstance3D.new()
			node3d.mesh = PlaneMesh.new()
		ObjectType.TORUS:
			node3d = MeshInstance3D.new()
			node3d.mesh = TorusMesh.new()
		ObjectType.TEXT:
			node3d = MeshInstance3D.new()
			var mesh := TextMesh.new()
			mesh.font = Themes.get_font()
			mesh.text = "Sample"
			node3d.mesh = mesh
		ObjectType.ARRAY_MESH:
			node3d = MeshInstance3D.new()
			node3d.mesh = custom_mesh
		ObjectType.DIR_LIGHT:
			node3d = DirectionalLight3D.new()
			gizmos_3d.add_always_visible(node3d, DIR_LIGHT_TEXTURE)
		ObjectType.SPOT_LIGHT:
			node3d = SpotLight3D.new()
			gizmos_3d.add_always_visible(node3d, SPOT_LIGHT_TEXTURE)
		ObjectType.OMNI_LIGHT:
			node3d = OmniLight3D.new()
			node3d.omni_range = 1.0
			gizmos_3d.add_always_visible(node3d, OMNI_LIGHT_TEXTURE)
	return node3d


func node_change_transform(node: Node3D, a: Vector3, b: Vector3, applying_gizmos: Gizmos) -> void:
	var diff := a - b
	match applying_gizmos:
		Gizmos.X_POS:
			node_move_axis(node, diff, node.transform.basis.x)
		Gizmos.Y_POS:
			node_move_axis(node, diff, node.transform.basis.y)
		Gizmos.Z_POS:
			node_move_axis(node, diff, node.transform.basis.z)
		Gizmos.X_ROT:
			node_change_rotation(node, a, b, node.transform.basis.x)
		Gizmos.Y_ROT:
			node_change_rotation(node, a, b, node.transform.basis.y)
		Gizmos.Z_ROT:
			node_change_rotation(node, a, b, node.transform.basis.z)
		Gizmos.X_SCALE:
			node_change_scale(node, diff, node.transform.basis.x, Vector3.RIGHT)
		Gizmos.Y_SCALE:
			node_change_scale(node, diff, node.transform.basis.y, Vector3.UP)
		Gizmos.Z_SCALE:
			node_change_scale(node, diff, node.transform.basis.z, Vector3.BACK)
		_:
			node_move(node, diff)


func node_move(node: Node3D, pos: Vector3) -> void:
	node.position += pos
	node_change_property(node, &"position")


## Move the object in the direction it is facing, and restrict mouse movement in that axis
func node_move_axis(node: Node3D, diff: Vector3, axis: Vector3) -> void:
	var axis_v2 := Vector2(axis.x, axis.y).normalized()
	if axis_v2 == Vector2.ZERO:
		axis_v2 = Vector2(axis.y, axis.z).normalized()
	var diff_v2 := Vector2(diff.x, diff.y).normalized()
	node.position += axis * axis_v2.dot(diff_v2) * diff.length()
	node_change_property(node, &"position")


func node_change_rotation(node: Node3D, a: Vector3, b: Vector3, axis: Vector3) -> void:
	var a_local := a - node.position
	var a_local_v2 := Vector2(a_local.x, a_local.y)
	var b_local := b - node.position
	var b_local_v2 := Vector2(b_local.x, b_local.y)
	var angle := b_local_v2.angle_to(a_local_v2)
	# Rotate the object around a basis axis, instead of a fixed axis, such as
	# Vector3.RIGHT, Vector3.UP or Vector3.BACK
	node.rotate(axis.normalized(), angle)
	node.rotation.x = wrapf(node.rotation.x, -PI, PI)
	node.rotation.y = wrapf(node.rotation.y, -PI, PI)
	node.rotation.z = wrapf(node.rotation.z, -PI, PI)
	node_change_property(node, &"rotation")


## Scale the object in the direction it is facing, and restrict mouse movement in that axis
func node_change_scale(node: Node3D, diff: Vector3, axis: Vector3, dir: Vector3) -> void:
	var axis_v2 := Vector2(axis.x, axis.y).normalized()
	if axis_v2 == Vector2.ZERO:
		axis_v2 = Vector2(axis.y, axis.z).normalized()
	var diff_v2 := Vector2(diff.x, diff.y).normalized()
	node.scale += dir * axis_v2.dot(diff_v2) * diff.length()
	node_change_property(node, &"scale")


func node_change_property(node: Node3D, property := &"", by_undo_redo := false) -> void:
	node_property_changed.emit(node, property, by_undo_redo)


#func type_is_mesh(type: ObjectType) -> bool:
	#if type == ObjectType.DIR_LIGHT or type == ObjectType.SPOT_LIGHT or type == ObjectType.OMNI_LIGHT:
		#return false
	#return true


#func _add_object_node(id: int) -> void:
	#if not object_properties.has(id):
		#print("Object id not found.")
		#return
	#var node3d := Cel3DObject.new()
	#node3d.id = id
	#node3d.cel = self
	#parent_node.add_child(node3d)
	#if object_properties[id].has("id"):
		#node3d.deserialize(object_properties[id])
	#else:
		#if object_properties[id].has("transform"):
			#node3d.transform = object_properties[id]["transform"]
		#if object_properties[id].has("file_path"):
			#node3d.file_path = object_properties[id]["file_path"]
		#if object_properties[id].has("type"):
			#node3d.type = object_properties[id]["type"]
		#object_properties[id] = node3d.serialize()
	#objects_changed.emit()
#
#
#func _remove_object_node(id: int) -> void:  ## Called by undo/redo
	#var object := get_object_from_id(id)
	#if is_instance_valid(object):
		#if selected == object:
			#selected = null
		#object.queue_free()
	#objects_changed.emit()



# Overridden Methods:


func serialize() -> Dictionary:
	var dict := super()
	dict["type"] = get_layer_type()
	return dict


func get_layer_type() -> int:
	return Global.LayerTypes.THREE_D


func new_empty_cel() -> BaseCel:
	return Cel3D.new(viewport)


func can_layer_get_drawn() -> bool:
	return can_layer_be_modified()
