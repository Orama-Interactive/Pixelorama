class_name Layer3D
extends BaseLayer
## A class for 3D layer properties.

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
var selected: Node3D = null
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
	var dir_light := DirectionalLight3D.new()
	dir_light.transform = Transform3D(Basis(), Vector3(-2.5, 0, 0))
	parent_node.add_child(dir_light)
	viewport.add_child(camera)
	viewport.add_child(parent_node)
	Global.canvas.add_child(viewport)


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
			gizmos_3d.add_always_visible(self, DIR_LIGHT_TEXTURE)
		ObjectType.SPOT_LIGHT:
			node3d = SpotLight3D.new()
			gizmos_3d.add_always_visible(self, SPOT_LIGHT_TEXTURE)
		ObjectType.OMNI_LIGHT:
			node3d = OmniLight3D.new()
			gizmos_3d.add_always_visible(self, OMNI_LIGHT_TEXTURE)
	#parent_node.add_child(node3d)
	return node3d


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
