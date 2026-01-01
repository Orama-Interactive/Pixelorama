extends Node2D

enum { X, Y, Z }

const ARROW_LENGTH := 14
const LIGHT_ARROW_LENGTH := 25
const GIZMO_WIDTH := 0.4
const SCALE_CIRCLE_LENGTH := 8
const SCALE_CIRCLE_RADIUS := 1
const CHAR_SCALE := 0.10
const DISAPPEAR_THRESHOLD := 1  ## length of arrow below which system won't draw it (for cleaner UI)

const EDGES: Array[Array] = [
	[0,1],[0,2],[1,3],[2,3],  # bottom face
	[4,5],[4,6],[5,7],[6,7],  # top face
	[0,4],[1,5],[2,6],[3,7],  # vertical edges
]

var layer_3d: Layer3D
var applying_gizmos := Layer3D.Gizmos.NONE
var always_visible: Dictionary[Node3D, Texture2D] = {}
var points_per_object: Dictionary[Node3D, PackedVector2Array] = {}
var selected_color := Color.WHITE
var hovered_color := Color.GRAY

var gizmos_origin: Vector2
var proj_right_local: Vector2
var proj_up_local: Vector2
var proj_back_local: Vector2
var right_axis_width: float = 1.0
var up_axis_width: float = 1.0
var back_axis_width: float = 1.0
# Same vectors as `proj_x_local`, but with a smaller length, for the rotation & scale gizmos
var proj_right_local_scale: Vector2
var proj_up_local_scale: Vector2
var proj_back_local_scale: Vector2
var gizmo_pos_x := PackedVector2Array()
var gizmo_pos_y := PackedVector2Array()
var gizmo_pos_z := PackedVector2Array()
var gizmo_rot_x := PackedVector2Array()
var gizmo_rot_y := PackedVector2Array()
var gizmo_rot_z := PackedVector2Array()

@onready var canvas := get_parent() as Canvas


func _ready() -> void:
	Global.cel_switched.connect(_cel_switched)
	Global.camera.zoom_changed.connect(queue_redraw)


func get_hovering_gizmo(pos: Vector2) -> Layer3D.Gizmos:
	var draw_scale := Vector2(10.0, 10.0) / Global.camera.zoom
	pos -= gizmos_origin
	# Scale the position based on the zoom, has the same effect as enlarging the shapes
	pos /= draw_scale
	# Inflate the rotation polylines by one to make them easier to click
	var rot_x_offset := Geometry2D.offset_polyline(gizmo_rot_x, 1)[0]
	var rot_y_offset := Geometry2D.offset_polyline(gizmo_rot_y, 1)[0]
	var rot_z_offset := Geometry2D.offset_polyline(gizmo_rot_z, 1)[0]

	if Geometry2D.is_point_in_circle(pos, proj_right_local_scale, SCALE_CIRCLE_RADIUS):
		return Layer3D.Gizmos.X_SCALE
	elif Geometry2D.is_point_in_circle(pos, proj_up_local_scale, SCALE_CIRCLE_RADIUS):
		return Layer3D.Gizmos.Y_SCALE
	elif Geometry2D.is_point_in_circle(pos, proj_back_local_scale, SCALE_CIRCLE_RADIUS):
		return Layer3D.Gizmos.Z_SCALE
	elif Geometry2D.point_is_inside_triangle(pos, gizmo_pos_x[0], gizmo_pos_x[1], gizmo_pos_x[2]):
		return Layer3D.Gizmos.X_POS
	elif Geometry2D.point_is_inside_triangle(pos, gizmo_pos_y[0], gizmo_pos_y[1], gizmo_pos_y[2]):
		return Layer3D.Gizmos.Y_POS
	elif Geometry2D.point_is_inside_triangle(pos, gizmo_pos_z[0], gizmo_pos_z[1], gizmo_pos_z[2]):
		return Layer3D.Gizmos.Z_POS
	elif Geometry2D.is_point_in_polygon(pos, rot_x_offset):
		return Layer3D.Gizmos.X_ROT
	elif Geometry2D.is_point_in_polygon(pos, rot_y_offset):
		return Layer3D.Gizmos.Y_ROT
	elif Geometry2D.is_point_in_polygon(pos, rot_z_offset):
		return Layer3D.Gizmos.Z_ROT
	return Layer3D.Gizmos.NONE


func get_hovering_light(pos: Vector2) -> Node3D:
	var draw_scale := Vector2(20.0, 20.0) / Global.camera.zoom
	for object in always_visible:
		if not always_visible[object]:
			continue
		var camera := object.get_viewport().get_camera_3d()
		var object_pos := camera.unproject_position(object.position)
		var rect := Rect2(object_pos - draw_scale / 2.0, draw_scale)
		if rect.has_point(pos):
			return object
	return null


func _cel_switched() -> void:
	if is_instance_valid(layer_3d):
		if layer_3d.selected_object_changed.is_connected(_on_selected_object):
			layer_3d.selected_object_changed.disconnect(_on_selected_object)
			layer_3d.object_hovered.disconnect(_on_hovered_object)
			layer_3d.node_property_changed.disconnect(_on_node_property_changed)
	for object in points_per_object:
		clear_points(object)
	if not Global.current_project.get_current_cel() is Cel3D:
		queue_redraw()
		return
	layer_3d = Global.current_project.layers[Global.current_project.current_layer]
	layer_3d.selected_object_changed.connect(_on_selected_object)
	layer_3d.object_hovered.connect(_on_hovered_object)
	layer_3d.node_property_changed.connect(_on_node_property_changed)
	var selected := layer_3d.selected
	if is_instance_valid(selected):
		get_points(selected, true)
	queue_redraw()


func _on_selected_object(new_object: Node3D, old_object: Node3D) -> void:
	if is_instance_valid(new_object) and new_object is VisualInstance3D:
		get_points(new_object, true)
	if is_instance_valid(old_object) and new_object != old_object and old_object is VisualInstance3D:
		clear_points(old_object)


func _on_hovered_object(new_object: Node3D, old_object: Node3D, is_selected: bool) -> void:
	if is_instance_valid(new_object):
		get_points(new_object, is_selected)
	if is_instance_valid(old_object) and new_object != old_object and not is_selected:
		clear_points(old_object)


func _on_node_property_changed(node: Node, _property: StringName, frame_index: int) -> void:
	if frame_index != layer_3d.project.current_frame:
		return
	if node == layer_3d.selected:
		get_points(node, true)
	queue_redraw()


func _find_selected_object() -> Cel3DObject:
	for object in points_per_object:
		if is_instance_valid(object) and object.selected:
			return object
	return null


func add_always_visible(object3d: VisualInstance3D, texture: Texture2D) -> void:
	always_visible[object3d] = texture
	if not object3d.tree_exiting.is_connected(remove_always_visible):
		object3d.tree_exiting.connect(remove_always_visible.bind(object3d))
		object3d.tree_entered.connect(add_always_visible.bind(object3d, texture))
	queue_redraw()


func remove_always_visible(object3d: VisualInstance3D) -> void:
	always_visible.erase(object3d)
	queue_redraw()


func get_points(object3d: VisualInstance3D, selected: bool) -> void:
	if not is_instance_valid(object3d):
		return
	var camera := object3d.get_viewport().get_camera_3d()
	var aabb := object3d.get_aabb()
	var corners := PackedVector2Array()
	var corner_per_dimension := PackedInt32Array([0, 1])
	for x in corner_per_dimension:
		for y in corner_per_dimension:
			for z in corner_per_dimension:
				var local := aabb.position + Vector3(x, y, z) * aabb.size
				var world := object3d.global_transform * local
				#if camera.is_position_behind(world):
					#continue
				corners.append(camera.unproject_position(world))
	var points := PackedVector2Array()
	for edge in EDGES:
		points.append(corners[edge[0]])
		points.append(corners[edge[1]])
	points_per_object[object3d] = points

	if selected:
		gizmos_origin = camera.unproject_position(object3d.position)
		var right := object3d.position + object3d.transform.basis.x.normalized()
		var left := object3d.position - object3d.transform.basis.x.normalized()
		var up := object3d.position + object3d.transform.basis.y.normalized()
		var down := object3d.position - object3d.transform.basis.y.normalized()
		var back := object3d.position + object3d.transform.basis.z.normalized()
		var front := object3d.position - object3d.transform.basis.z.normalized()

		var camera_right := camera.transform.basis.x.normalized()
		right_axis_width = lerpf(0.5, 0.1, (1 + (camera_right - right).z) / 2.0)
		up_axis_width = lerpf(0.5, 0.1, (1 + (camera_right - up).z) / 2.0)
		back_axis_width = lerpf(0.5, 0.1, (1 + (camera_right - back).z) / 2.0)

		var proj_right := camera.unproject_position(right)
		var proj_up := camera.unproject_position(up)
		var proj_back := camera.unproject_position(back)

		proj_right_local = proj_right - gizmos_origin
		proj_up_local = proj_up - gizmos_origin
		proj_back_local = proj_back - gizmos_origin

		var curve_right_local := proj_right_local
		var curve_up_local := proj_up_local
		var curve_back_local := proj_back_local
		if right.distance_to(camera.position) > left.distance_to(camera.position):
			curve_right_local = camera.unproject_position(left) - gizmos_origin
		if up.distance_to(camera.position) > down.distance_to(camera.position):
			curve_up_local = camera.unproject_position(down) - gizmos_origin
		if back.distance_to(camera.position) > front.distance_to(camera.position):
			curve_back_local = camera.unproject_position(front) - gizmos_origin

		proj_right_local = _resize_vector(proj_right_local, ARROW_LENGTH)
		proj_up_local = _resize_vector(proj_up_local, ARROW_LENGTH)
		proj_back_local = _resize_vector(proj_back_local, ARROW_LENGTH)

		proj_right_local_scale = _resize_vector(proj_right_local, SCALE_CIRCLE_LENGTH)
		proj_up_local_scale = _resize_vector(proj_up_local, SCALE_CIRCLE_LENGTH)
		proj_back_local_scale = _resize_vector(proj_back_local, SCALE_CIRCLE_LENGTH)

		# Calculate position gizmos (arrows)
		gizmo_pos_x = _find_arrow(proj_right_local)
		gizmo_pos_y = _find_arrow(proj_up_local)
		gizmo_pos_z = _find_arrow(proj_back_local)
		# Calculate rotation gizmos
		gizmo_rot_x = _find_curve(curve_up_local, curve_back_local)
		gizmo_rot_y = _find_curve(curve_right_local, curve_back_local)
		gizmo_rot_z = _find_curve(curve_right_local, curve_up_local)

	queue_redraw()


func clear_points(object3d: VisualInstance3D) -> void:
	points_per_object.erase(object3d)
	queue_redraw()


func _draw() -> void:
	var layer := Global.current_project.layers[Global.current_project.current_layer]
	if not layer is Layer3D:
		return
	var draw_scale := Vector2(10.0, 10.0) / Global.camera.zoom
	for object in always_visible:
		if not always_visible[object]:
			continue
		var texture: Texture2D = always_visible[object]
		var center := Vector2(8, 8)
		var camera := object.get_viewport().get_camera_3d()
		var pos: Vector2 = camera.unproject_position(object.position)
		draw_set_transform(pos, 0, draw_scale / 4)
		draw_texture(texture, -center)
		draw_set_transform(pos, 0, draw_scale / 2)
		if object is DirectionalLight3D:
			var back: Vector3 = object.position - object.transform.basis.z
			var back_proj: Vector2 = camera.unproject_position(back) - pos
			back_proj = _resize_vector(back_proj, LIGHT_ARROW_LENGTH)
			var line_width := lerpf(0.5, 0.1, (1 + (Vector3.RIGHT - back).z) / 2.0)
			draw_line(Vector2.ZERO, back_proj, Color.WHITE, line_width)
			var arrow := _find_arrow(back_proj)
			_draw_arrow(arrow, Color.WHITE)
		draw_set_transform_matrix(Transform2D())

	if points_per_object.is_empty():
		return
	for object in points_per_object:
		var points: PackedVector2Array = points_per_object[object]
		if points.is_empty():
			continue
		if (layer as Layer3D).selected == object:
			var is_applying_gizmos = false
			# Draw bounding box outline
			draw_multiline(points, selected_color, 0.5)
			if applying_gizmos == Layer3D.Gizmos.X_ROT:
				draw_line(gizmos_origin, canvas.current_pixel, Color.RED)
				is_applying_gizmos = true
			elif applying_gizmos == Layer3D.Gizmos.Y_ROT:
				draw_line(gizmos_origin, canvas.current_pixel, Color.GREEN)
				is_applying_gizmos = true
			elif applying_gizmos == Layer3D.Gizmos.Z_ROT:
				draw_line(gizmos_origin, canvas.current_pixel, Color.BLUE)
				is_applying_gizmos = true
			draw_set_transform(gizmos_origin, 0, draw_scale)
			# Draw position arrows
			if proj_right_local.length() > DISAPPEAR_THRESHOLD:
				draw_line(Vector2.ZERO, proj_right_local, Color.RED, right_axis_width)
				_draw_arrow(gizmo_pos_x, Color.RED)
			if proj_up_local.length() > DISAPPEAR_THRESHOLD:
				draw_line(Vector2.ZERO, proj_up_local, Color.GREEN, up_axis_width)
				_draw_arrow(gizmo_pos_y, Color.GREEN)
			if proj_back_local.length() > DISAPPEAR_THRESHOLD:
				draw_line(Vector2.ZERO, proj_back_local, Color.BLUE, back_axis_width)
				_draw_arrow(gizmo_pos_z, Color.BLUE)
			draw_circle(Vector2.ZERO, 0.4, Color.ORANGE)
			if is_applying_gizmos:
				continue

			# Draw rotation curves
			draw_polyline(gizmo_rot_x, Color.RED, GIZMO_WIDTH)
			draw_polyline(gizmo_rot_y, Color.GREEN, GIZMO_WIDTH)
			draw_polyline(gizmo_rot_z, Color.BLUE, GIZMO_WIDTH)

			# Draw scale circles
			draw_circle(proj_right_local_scale, SCALE_CIRCLE_RADIUS, Color.RED)
			draw_circle(proj_up_local_scale, SCALE_CIRCLE_RADIUS, Color.GREEN)
			draw_circle(proj_back_local_scale, SCALE_CIRCLE_RADIUS, Color.BLUE)

			# Draw X, Y, Z characters on top of the scale circles
			var font := Themes.get_font()
			var font_height := font.get_height()
			var char_position := Vector2(-font_height, font_height) * CHAR_SCALE / 4 * draw_scale
			draw_set_transform(gizmos_origin + char_position, 0, draw_scale * CHAR_SCALE)
			draw_char(font, proj_right_local_scale / CHAR_SCALE, "X")
			draw_char(font, proj_up_local_scale / CHAR_SCALE, "Y")
			draw_char(font, proj_back_local_scale / CHAR_SCALE, "Z")
			draw_set_transform_matrix(Transform2D())
		else:
			draw_multiline(points, hovered_color)


## resizes the vector [param v] by amount [param l] but clamps the resized length to original length
func _resize_vector(v: Vector2, l: float) -> Vector2:
	return (v.normalized() * l).limit_length(v.length())


func _find_curve(a: Vector2, b: Vector2) -> PackedVector2Array:
	var curve2d := Curve2D.new()
	curve2d.bake_interval = 1
	var control := b.lerp(a, 0.5)
	a = _resize_vector(a, SCALE_CIRCLE_LENGTH)
	b = _resize_vector(b, SCALE_CIRCLE_LENGTH)
	control = control.normalized() * sqrt(pow(a.length() / 4, 2) * 2)  # Thank you Pythagoras
	curve2d.add_point(a, Vector2.ZERO, control)
	curve2d.add_point(b, control)
	return curve2d.get_baked_points()


func _find_arrow(a: Vector2, tilt := 0.5) -> PackedVector2Array:
	# The middle point of line between b and c will now touch the
	# starting point instead of the original "a" vector
	a -= Vector2(0, 1).rotated(a.angle() + PI / 2) * 2
	var b := a + Vector2(-tilt, 1).rotated(a.angle() + PI / 2) * 2
	var c := a + Vector2(tilt, 1).rotated(a.angle() + PI / 2) * 2
	return PackedVector2Array([a, b, c])


func _draw_arrow(triangle: PackedVector2Array, color: Color) -> void:
	draw_primitive(triangle, [color, color, color], [])
