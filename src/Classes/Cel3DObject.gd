class_name Cel3DObject
extends Node3D

signal property_changed

enum Type {
	BOX,
	SPHERE,
	CAPSULE,
	CYLINDER,
	PRISM,
	TORUS,
	PLANE,
	TEXT,
	DIR_LIGHT,
	SPOT_LIGHT,
	OMNI_LIGHT,
	IMPORTED
}
enum Gizmos { NONE, X_POS, Y_POS, Z_POS, X_ROT, Y_ROT, Z_ROT, X_SCALE, Y_SCALE, Z_SCALE }

var cel
var id := -1
var type := Type.BOX:
	set = _set_type
var selected := false
var hovered := false
var box_shape: BoxShape3D
var camera: Camera3D
var file_path := "":
	set = _set_file_path
var applying_gizmos: int = Gizmos.NONE
var node3d_type: VisualInstance3D

var dir_light_texture := preload("res://assets/graphics/gizmos/directional_light.svg")
var spot_light_texture := preload("res://assets/graphics/gizmos/spot_light.svg")
var omni_light_texture := preload("res://assets/graphics/gizmos/omni_light.svg")

@onready var gizmos_3d: Node2D = Global.canvas.gizmos_3d


func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	var static_body := StaticBody3D.new()
	var collision_shape := CollisionShape3D.new()
	box_shape = BoxShape3D.new()
	box_shape.size = scale
	collision_shape.shape = box_shape
	static_body.add_child(collision_shape)
	add_child(static_body)


func find_cel() -> bool:
	var project := Global.current_project
	return cel == project.frames[project.current_frame].cels[project.current_layer]


func serialize() -> Dictionary:
	var dict := {
		"id": id, "type": type, "transform": transform, "visible": visible, "file_path": file_path
	}
	if _is_mesh():
		var mesh: Mesh = node3d_type.mesh
		match type:
			Type.BOX:
				dict["mesh_size"] = mesh.size
			Type.PLANE:
				dict["mesh_sizev2"] = mesh.size
				dict["mesh_center_offset"] = mesh.center_offset
			Type.PRISM:
				dict["mesh_size"] = mesh.size
				dict["mesh_left_to_right"] = mesh.left_to_right
			Type.SPHERE:
				dict["mesh_radius"] = mesh.radius
				dict["mesh_height"] = mesh.height
				dict["mesh_radial_segments"] = mesh.radial_segments
				dict["mesh_rings"] = mesh.rings
				dict["mesh_is_hemisphere"] = mesh.is_hemisphere
			Type.CAPSULE:
				dict["mesh_radius"] = mesh.radius
				dict["mesh_height"] = mesh.height
				dict["mesh_radial_segments"] = mesh.radial_segments
				dict["mesh_rings"] = mesh.rings
			Type.CYLINDER:
				dict["mesh_bottom_radius"] = mesh.bottom_radius
				dict["mesh_top_radius"] = mesh.top_radius
				dict["mesh_height"] = mesh.height
				dict["mesh_radial_segments"] = mesh.radial_segments
				dict["mesh_rings"] = mesh.rings
			Type.TORUS:
				dict["mesh_inner_radius"] = mesh.inner_radius
				dict["mesh_outer_radius"] = mesh.outer_radius
				dict["mesh_ring_segments"] = mesh.ring_segments
				dict["mesh_rings"] = mesh.rings
			Type.TEXT:
				dict["mesh_font_name"] = mesh.font.get_font_name()
				dict["mesh_text"] = mesh.text
				dict["mesh_pixel_size"] = mesh.pixel_size
				dict["mesh_font_size"] = mesh.font_size
				dict["mesh_depth"] = mesh.depth
				dict["mesh_offset"] = mesh.offset
				dict["mesh_curve_step"] = mesh.curve_step
				dict["mesh_horizontal_alignment"] = mesh.horizontal_alignment
				dict["mesh_vertical_alignment"] = mesh.vertical_alignment
				dict["mesh_line_spacing"] = mesh.line_spacing
	else:
		dict["light_color"] = node3d_type.light_color
		dict["light_energy"] = node3d_type.light_energy
		dict["light_negative"] = node3d_type.light_negative
		dict["shadow_enabled"] = node3d_type.shadow_enabled
		match type:
			Type.OMNI_LIGHT:
				dict["omni_range"] = node3d_type.omni_range
			Type.SPOT_LIGHT:
				dict["spot_range"] = node3d_type.spot_range
				dict["spot_angle"] = node3d_type.spot_angle
	return dict


func deserialize(dict: Dictionary) -> void:
	id = dict["id"]
	file_path = dict["file_path"]
	type = dict["type"]
	transform = dict["transform"]
	visible = dict["visible"]
	if _is_mesh():
		var mesh: Mesh = node3d_type.mesh
		match type:
			Type.BOX:
				mesh.size = dict["mesh_size"]
			Type.PLANE:
				mesh.size = dict["mesh_sizev2"]
				mesh.center_offset = dict["mesh_center_offset"]
			Type.PRISM:
				mesh.size = dict["mesh_size"]
				mesh.left_to_right = dict["mesh_left_to_right"]
			Type.SPHERE:
				mesh.radius = dict["mesh_radius"]
				mesh.height = dict["mesh_height"]
				mesh.radial_segments = dict["mesh_radial_segments"]
				mesh.rings = dict["mesh_rings"]
				mesh.is_hemisphere = dict["mesh_is_hemisphere"]
			Type.CAPSULE:
				mesh.radius = dict["mesh_radius"]
				mesh.height = dict["mesh_height"]
				mesh.radial_segments = dict["mesh_radial_segments"]
				mesh.rings = dict["mesh_rings"]
			Type.CYLINDER:
				mesh.bottom_radius = dict["mesh_bottom_radius"]
				mesh.top_radius = dict["mesh_top_radius"]
				mesh.height = dict["mesh_height"]
				mesh.radial_segments = dict["mesh_radial_segments"]
				mesh.rings = dict["mesh_rings"]
			Type.TORUS:
				mesh.inner_radius = dict["mesh_inner_radius"]
				mesh.outer_radius = dict["mesh_outer_radius"]
				mesh.ring_segments = dict["mesh_ring_segments"]
				mesh.rings = dict["mesh_rings"]
			Type.TEXT:
				mesh.font = Global.find_font_from_name(dict["mesh_font_name"])
				mesh.text = dict["mesh_text"]
				mesh.pixel_size = dict["mesh_pixel_size"]
				mesh.font_size = dict["mesh_font_size"]
				mesh.depth = dict["mesh_depth"]
				mesh.offset = dict["mesh_offset"]
				mesh.curve_step = dict["mesh_curve_step"]
				mesh.horizontal_alignment = dict["mesh_horizontal_alignment"]
				mesh.vertical_alignment = dict["mesh_vertical_alignment"]
				mesh.line_spacing = dict["mesh_line_spacing"]
	else:
		node3d_type.light_color = dict["light_color"]
		node3d_type.light_energy = dict["light_energy"]
		node3d_type.light_negative = dict["light_negative"]
		node3d_type.shadow_enabled = dict["shadow_enabled"]
		match type:
			Type.OMNI_LIGHT:
				node3d_type.omni_range = dict["omni_range"]
			Type.SPOT_LIGHT:
				node3d_type.spot_range = dict["spot_range"]
				node3d_type.spot_angle = dict["spot_angle"]
	change_property()


func _is_mesh() -> bool:
	return node3d_type is MeshInstance3D


func _set_type(value: Type) -> void:
	if type == value and is_instance_valid(node3d_type):  # No reason to set the same type twice
		return
	type = value
	if is_instance_valid(node3d_type):
		node3d_type.queue_free()
	match type:
		Type.BOX:
			node3d_type = MeshInstance3D.new()
			node3d_type.mesh = BoxMesh.new()
		Type.SPHERE:
			node3d_type = MeshInstance3D.new()
			node3d_type.mesh = SphereMesh.new()
		Type.CAPSULE:
			node3d_type = MeshInstance3D.new()
			node3d_type.mesh = CapsuleMesh.new()
		Type.CYLINDER:
			node3d_type = MeshInstance3D.new()
			node3d_type.mesh = CylinderMesh.new()
		Type.PRISM:
			node3d_type = MeshInstance3D.new()
			node3d_type.mesh = PrismMesh.new()
		Type.PLANE:
			node3d_type = MeshInstance3D.new()
			node3d_type.mesh = PlaneMesh.new()
		Type.TORUS:
			node3d_type = MeshInstance3D.new()
			node3d_type.mesh = TorusMesh.new()
		Type.TEXT:
			node3d_type = MeshInstance3D.new()
			var mesh := TextMesh.new()
			mesh.font = Themes.get_font()
			mesh.text = "Sample"
			node3d_type.mesh = mesh
		Type.DIR_LIGHT:
			node3d_type = DirectionalLight3D.new()
			gizmos_3d.add_always_visible(self, dir_light_texture)
		Type.SPOT_LIGHT:
			node3d_type = SpotLight3D.new()
			gizmos_3d.add_always_visible(self, spot_light_texture)
		Type.OMNI_LIGHT:
			node3d_type = OmniLight3D.new()
			gizmos_3d.add_always_visible(self, omni_light_texture)
		Type.IMPORTED:
			node3d_type = MeshInstance3D.new()
			var mesh: Mesh
			if not file_path.is_empty():
				mesh = ObjParse.load_obj(file_path)
			node3d_type.mesh = mesh
	add_child(node3d_type)


func _set_file_path(value: String) -> void:
	if file_path == value:
		return
	file_path = value
	if file_path.is_empty():
		return
	if type == Type.IMPORTED:
		node3d_type.mesh = ObjParse.load_obj(file_path)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		deselect()
		gizmos_3d.remove_always_visible(self)


func select() -> void:
	selected = true
	gizmos_3d.get_points(camera, self)


func deselect() -> void:
	selected = false
	gizmos_3d.clear_points(self)


func hover() -> void:
	if hovered:
		return
	hovered = true
	if selected:
		return
	gizmos_3d.get_points(camera, self)


func unhover() -> void:
	if not hovered:
		return
	hovered = false
	if selected:
		return
	gizmos_3d.clear_points(self)


func change_transform(a: Vector3, b: Vector3) -> void:
	var diff := a - b
	match applying_gizmos:
		Gizmos.X_POS:
			move_axis(diff, transform.basis.x)
		Gizmos.Y_POS:
			move_axis(diff, transform.basis.y)
		Gizmos.Z_POS:
			move_axis(diff, transform.basis.z)
		Gizmos.X_ROT:
			change_rotation(a, b, transform.basis.x)
		Gizmos.Y_ROT:
			change_rotation(a, b, transform.basis.y)
		Gizmos.Z_ROT:
			change_rotation(a, b, transform.basis.z)
		Gizmos.X_SCALE:
			change_scale(diff, transform.basis.x, Vector3.RIGHT)
		Gizmos.Y_SCALE:
			change_scale(diff, transform.basis.y, Vector3.UP)
		Gizmos.Z_SCALE:
			change_scale(diff, transform.basis.z, Vector3.BACK)
		_:
			move(diff)


func move(pos: Vector3) -> void:
	position += pos
	change_property()


## Move the object in the direction it is facing, and restrict mouse movement in that axis
func move_axis(diff: Vector3, axis: Vector3) -> void:
	var axis_v2 := Vector2(axis.x, axis.y).normalized()
	if axis_v2 == Vector2.ZERO:
		axis_v2 = Vector2(axis.y, axis.z).normalized()
	var diff_v2 := Vector2(diff.x, diff.y).normalized()
	position += axis * axis_v2.dot(diff_v2) * diff.length()
	change_property()


func change_rotation(a: Vector3, b: Vector3, axis: Vector3) -> void:
	var a_local := a - position
	var a_local_v2 := Vector2(a_local.x, a_local.y)
	var b_local := b - position
	var b_local_v2 := Vector2(b_local.x, b_local.y)
	var angle := b_local_v2.angle_to(a_local_v2)
	# Rotate the object around a basis axis, instead of a fixed axis, such as
	# Vector3.RIGHT, Vector3.UP or Vector3.BACK
	rotate(axis.normalized(), angle)
	rotation.x = wrapf(rotation.x, -PI, PI)
	rotation.y = wrapf(rotation.y, -PI, PI)
	rotation.z = wrapf(rotation.z, -PI, PI)
	change_property()


## Scale the object in the direction it is facing, and restrict mouse movement in that axis
func change_scale(diff: Vector3, axis: Vector3, dir: Vector3) -> void:
	var axis_v2 := Vector2(axis.x, axis.y).normalized()
	if axis_v2 == Vector2.ZERO:
		axis_v2 = Vector2(axis.y, axis.z).normalized()
	var diff_v2 := Vector2(diff.x, diff.y).normalized()
	scale += dir * axis_v2.dot(diff_v2) * diff.length()
	change_property()


func change_property() -> void:
	if selected:
		select()
	else:
		# Check is needed in case this runs before _ready(), and thus onready variables
		if is_instance_valid(gizmos_3d):
			gizmos_3d.queue_redraw()
	property_changed.emit()
