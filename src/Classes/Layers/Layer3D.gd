class_name Layer3D
extends BaseLayer
## A class for 3D layer properties.

signal selected_object_changed(new_selected: Node3D, old_selected: Node3D)
@warning_ignore("unused_signal")
signal object_hovered(new_hovered: Node3D, old_hovered: Node3D, is_selected: bool)
signal node_property_changed(node: Node, property_name: StringName, frame_index: int)

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
var world_environment: WorldEnvironment
var camera: Camera3D  ## Camera that is used to render the Image.
var animation_player: AnimationPlayer
var animation: Animation
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

static var properties_to_exclude: Array[String] = [
	"process_mode",
	"process_priority",
	"process_physics_priority",
	"process_thread_group",
	"physics_interpolation_mode",
	"auto_translate_mode",
	"editor_description",
	"rotation_edit_mode",
	"top_level",
	"current",
	"resource_local_to_scene",
	"resource_name",
	"resource_path",
	"editor_only",
	"language",
]


func _init(_project: Project, _name := "", from_pxo := false) -> void:
	project = _project
	name = _name
	if not from_pxo:
		_add_nodes(project.size)
	node_property_changed.connect(_on_node_property_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(viewport):
			viewport.queue_free()


func _add_nodes(size: Vector2i) -> void:
	viewport = SubViewport.new()
	viewport.size = size
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_environment = WorldEnvironment.new()
	world_environment.environment = Environment.new()
	world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	parent_node = Node3D.new()
	camera = Camera3D.new()
	camera.current = true
	camera.position.z = 3
	camera.fov = 70
	animation_player = AnimationPlayer.new()
	var animation_library := AnimationLibrary.new()
	animation = Animation.new()
	animation_library.add_animation(&"__pxo_anim", animation)
	animation_player.add_animation_library(&"__pxo_anim_lib", animation_library)
	animation_player.current_animation = "__pxo_anim_lib/__pxo_anim"
	animation_player.speed_scale = project.fps
	animation.length = project.frames.size()
	var dir_light := create_node(ObjectType.DIR_LIGHT)
	dir_light.transform = Transform3D(Basis(), Vector3(-2.5, 0, 0))
	parent_node.add_child(dir_light)
	viewport.add_child(animation_player)
	viewport.add_child(camera)
	viewport.add_child(world_environment)
	viewport.add_child(parent_node)
	Global.canvas.add_child(viewport)


func unselect() -> void:
	selected = null


static func create_node(type: ObjectType, custom_mesh: Mesh = null) -> Node3D:
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
			Global.canvas.gizmos_3d.add_always_visible(node3d, DIR_LIGHT_TEXTURE)
		ObjectType.SPOT_LIGHT:
			node3d = SpotLight3D.new()
			Global.canvas.gizmos_3d.add_always_visible(node3d, SPOT_LIGHT_TEXTURE)
		ObjectType.OMNI_LIGHT:
			node3d = OmniLight3D.new()
			node3d.omni_range = 1.0
			Global.canvas.gizmos_3d.add_always_visible(node3d, OMNI_LIGHT_TEXTURE)
	if node3d is MeshInstance3D and not is_instance_valid(node3d.mesh.surface_get_material(0)):
		var material := StandardMaterial3D.new()
		node3d.mesh.surface_set_material(0, material)
		#print(node3d.mesh.get_property_list())
		#print(material.get_property_list())
	#print(node3d.get_property_list())
	return node3d


static func get_object_property_list(object: Object) -> Array[Dictionary]:
	var property_list := object.get_property_list()
	property_list = property_list.filter(filter_object_properties)
	if object is MeshInstance3D:
		if is_instance_valid(object.mesh):
			var mesh := object.mesh as Mesh
			var mesh_property_list := get_object_property_list(mesh)
			for mesh_prop in mesh_property_list:
				mesh_prop["name"] = "mesh:%s" % mesh_prop["name"]
			property_list.append_array(mesh_property_list)
			if is_instance_valid(mesh.surface_get_material(0)):
				var material := mesh.surface_get_material(0) as BaseMaterial3D
				var material_property_list := get_object_property_list(material)
				for mat_prop in material_property_list:
					mat_prop["name"] = "mesh:material:%s" % mat_prop["name"]
				property_list.append_array(material_property_list)
	elif object is WorldEnvironment:
		if is_instance_valid(object.environment):
			var env_property_list := get_object_property_list(object.environment)
			for env_prop in env_property_list:
				env_prop["name"] = "environment:%s" % env_prop["name"]
			property_list = env_property_list
	return property_list


static func filter_object_properties(dict: Dictionary) -> bool:
	var prop_name := dict["name"] as String
	if prop_name in properties_to_exclude:
		return false
	var usage := dict["usage"] as int
	var type := dict["type"] as Variant.Type
	var usage_editor := usage & PROPERTY_USAGE_EDITOR == PROPERTY_USAGE_EDITOR
	var is_type := type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_COLOR, TYPE_STRING_NAME]
	return usage_editor and is_type


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
	var prev_pos := node.position
	node.position += pos
	update_animation_track(node, &"position", node.position, prev_pos, project.current_frame)


## Move the object in the direction it is facing, and restrict mouse movement in that axis
func node_move_axis(node: Node3D, diff: Vector3, axis: Vector3) -> void:
	var prev_pos := node.position
	var axis_v2 := Vector2(axis.x, axis.y).normalized()
	if axis_v2 == Vector2.ZERO:
		axis_v2 = Vector2(axis.y, axis.z).normalized()
	var diff_v2 := Vector2(diff.x, diff.y).normalized()
	node.position += axis * axis_v2.dot(diff_v2) * diff.length()
	update_animation_track(node, &"position", node.position, prev_pos, project.current_frame)


func node_change_rotation(node: Node3D, a: Vector3, b: Vector3, axis: Vector3) -> void:
	var prev_rot := node.rotation
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
	update_animation_track(node, &"rotation", node.rotation, prev_rot, project.current_frame)


## Scale the object in the direction it is facing, and restrict mouse movement in that axis
func node_change_scale(node: Node3D, diff: Vector3, axis: Vector3, dir: Vector3) -> void:
	var prev_scale := node.scale
	var axis_v2 := Vector2(axis.x, axis.y).normalized()
	if axis_v2 == Vector2.ZERO:
		axis_v2 = Vector2(axis.y, axis.z).normalized()
	var diff_v2 := Vector2(diff.x, diff.y).normalized()
	node.scale += dir * axis_v2.dot(diff_v2) * diff.length()
	update_animation_track(node, &"scale", node.scale, prev_scale, project.current_frame)


func update_animation_track(object: Node, property: StringName, current_value: Variant, prev_value: Variant, frame_index: int) -> void:
	var undo_redo := project.undo_redo
	var property_path := NodePath(String(viewport.get_path_to(object)) + ":" + property)
	var track_idx := animation.find_track(property_path, Animation.TYPE_VALUE)

	if track_idx == -1:
		undo_redo.create_action("Create 3D animation track")
		track_idx = animation.get_track_count()
		undo_redo.add_do_method(animation.add_track.bind(Animation.TYPE_VALUE))
		undo_redo.add_do_method(animation.track_set_path.bind(track_idx, property_path))
		undo_redo.add_undo_method(animation.remove_track.bind(track_idx))
		undo_redo.add_do_method(Global.undo_or_redo.bind(false))
		undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
		undo_redo.commit_action()

	var key_idx := animation.track_find_key(track_idx, frame_index, Animation.FIND_MODE_APPROX)
	if key_idx == -1:
		undo_redo.create_action("Create 3D animation key")
		key_idx = animation.track_get_key_count(track_idx)
		undo_redo.add_do_method(animation.track_insert_key.bind(track_idx, frame_index, prev_value))
		undo_redo.add_undo_method(animation.track_remove_key.bind(track_idx, key_idx))
		undo_redo.add_do_method(Global.undo_or_redo.bind(false))
		undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
		undo_redo.commit_action()
	undo_redo.create_action("Change 3D object %s" % property, UndoRedo.MERGE_ENDS)
	undo_redo.add_do_method(animation.track_set_key_value.bind(track_idx, key_idx, current_value))
	undo_redo.add_undo_method(animation.track_set_key_value.bind(track_idx, key_idx, prev_value))
	undo_redo.add_do_method(emit_signal.bind(&"node_property_changed", object, property, frame_index))
	undo_redo.add_undo_method(emit_signal.bind(&"node_property_changed", object, property, frame_index))
	undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	undo_redo.commit_action()


func _on_node_property_changed(_node: Node, _property: StringName, frame_index: int) -> void:
	animation_player.seek(frame_index, true)
	#await RenderingServer.frame_post_draw
	project.frames[frame_index].cels[index].update_texture()
	if frame_index != project.current_frame:
		animation_player.seek(project.current_frame, true)
	#Global.canvas.queue_redraw()


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
