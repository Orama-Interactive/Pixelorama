extends Node2D

enum { X, Y, Z }

const ARROW_LENGTH := 14
const LIGHT_ARROW_LENGTH := 25
const GIZMO_WIDTH := 1.1
const SCALE_CIRCLE_LENGTH := 8
const SCALE_CIRCLE_RADIUS := 1
const CHAR_SCALE := 0.16

var always_visible := {}  # Key = Cel3DObject, Value = Texture
var points_per_object := {}  # Key = Cel3DObject, Value = PoolVector2Array
var selected_color := Color.white
var hovered_color := Color.gray

var gizmos_origin: Vector2
var proj_right_local: Vector2
var proj_up_local: Vector2
var proj_back_local: Vector2
# Same vectors as `proj_x_local`, but with a smaller length, for the rotation & scale gizmos
var proj_right_local_scale: Vector2
var proj_up_local_scale: Vector2
var proj_back_local_scale: Vector2
var gizmo_pos_x := PoolVector2Array()
var gizmo_pos_y := PoolVector2Array()
var gizmo_pos_z := PoolVector2Array()
var gizmo_rot_x := PoolVector2Array()
var gizmo_rot_y := PoolVector2Array()
var gizmo_rot_z := PoolVector2Array()


func _ready() -> void:
	set_process_input(false)
	Global.connect("cel_changed", self, "_cel_changed")
	Global.camera.connect("zoom_changed", self, "update")


func get_hovering_gizmo(pos: Vector2) -> int:
	var draw_scale := Global.camera.zoom * 10
	pos -= gizmos_origin
	# Scale the position based on the zoom, has the same effect as enlarging the shapes
	pos /= draw_scale
	# Inflate the rotation polylines by one to make them easier to click
	var rot_x_offset: PoolVector2Array = Geometry.offset_polyline_2d(gizmo_rot_x, 1)[0]
	var rot_y_offset: PoolVector2Array = Geometry.offset_polyline_2d(gizmo_rot_y, 1)[0]
	var rot_z_offset: PoolVector2Array = Geometry.offset_polyline_2d(gizmo_rot_z, 1)[0]

	if Geometry.point_is_inside_triangle(pos, gizmo_pos_x[0], gizmo_pos_x[1], gizmo_pos_x[2]):
		return Cel3DObject.Gizmos.X_POS
	elif Geometry.point_is_inside_triangle(pos, gizmo_pos_y[0], gizmo_pos_y[1], gizmo_pos_y[2]):
		return Cel3DObject.Gizmos.Y_POS
	elif Geometry.point_is_inside_triangle(pos, gizmo_pos_z[0], gizmo_pos_z[1], gizmo_pos_z[2]):
		return Cel3DObject.Gizmos.Z_POS
	elif Geometry.is_point_in_circle(pos, proj_right_local_scale, SCALE_CIRCLE_RADIUS):
		return Cel3DObject.Gizmos.X_SCALE
	elif Geometry.is_point_in_circle(pos, proj_up_local_scale, SCALE_CIRCLE_RADIUS):
		return Cel3DObject.Gizmos.Y_SCALE
	elif Geometry.is_point_in_circle(pos, proj_back_local_scale, SCALE_CIRCLE_RADIUS):
		return Cel3DObject.Gizmos.Z_SCALE
	elif Geometry.is_point_in_polygon(pos, rot_x_offset):
		return Cel3DObject.Gizmos.X_ROT
	elif Geometry.is_point_in_polygon(pos, rot_y_offset):
		return Cel3DObject.Gizmos.Y_ROT
	elif Geometry.is_point_in_polygon(pos, rot_z_offset):
		return Cel3DObject.Gizmos.Z_ROT
	return Cel3DObject.Gizmos.NONE


func _cel_changed() -> void:
	update()
	set_process_input(Global.current_project.get_current_cel() is Cel3D)


func _find_selected_object() -> Cel3DObject:
	for object in points_per_object:
		if is_instance_valid(object) and object.selected:
			return object
	return null


func add_always_visible(object3d: Cel3DObject, texture: Texture) -> void:
	always_visible[object3d] = texture
	update()


func remove_always_visible(object3d: Cel3DObject) -> void:
	always_visible.erase(object3d)
	update()


func get_points(camera: Camera, object3d: Cel3DObject) -> void:
	var debug_mesh := object3d.box_shape.get_debug_mesh()
	var arrays := debug_mesh.surface_get_arrays(0)
	var points := PoolVector2Array()
	for vertex in arrays[ArrayMesh.ARRAY_VERTEX]:
		var x_vertex: Vector3 = object3d.transform.xform(vertex)
		var point := camera.unproject_position(x_vertex)
		if not camera.is_position_behind(x_vertex):
			points.append(point)
	points_per_object[object3d] = points
	if object3d.selected:
		gizmos_origin = camera.unproject_position(object3d.translation)

		var right: Vector3 = object3d.translation + object3d.transform.basis.x
		var left: Vector3 = object3d.translation - object3d.transform.basis.x
		var up: Vector3 = object3d.translation + object3d.transform.basis.y
		var down: Vector3 = object3d.translation - object3d.transform.basis.y
		var back: Vector3 = object3d.translation + object3d.transform.basis.z
		var front: Vector3 = object3d.translation - object3d.transform.basis.z

		var proj_right: Vector2 = object3d.camera.unproject_position(right)
		var proj_up: Vector2 = object3d.camera.unproject_position(up)
		var proj_back: Vector2 = object3d.camera.unproject_position(back)

		proj_right_local = proj_right - gizmos_origin
		proj_up_local = proj_up - gizmos_origin
		proj_back_local = proj_back - gizmos_origin

		var curve_right_local := proj_right_local
		var curve_up_local := proj_up_local
		var curve_back_local := proj_back_local
		if right.distance_to(camera.translation) > left.distance_to(camera.translation):
			curve_right_local = object3d.camera.unproject_position(left) - gizmos_origin
		if up.distance_to(camera.translation) > down.distance_to(camera.translation):
			curve_up_local = object3d.camera.unproject_position(down) - gizmos_origin
		if back.distance_to(camera.translation) > front.distance_to(camera.translation):
			curve_back_local = object3d.camera.unproject_position(front) - gizmos_origin

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

	update()


func clear_points(object3d: Cel3DObject) -> void:
	points_per_object.erase(object3d)
	update()


func _draw() -> void:
	var draw_scale := Global.camera.zoom * 10
	for object in always_visible:
		if not always_visible[object]:
			continue
		if not object.find_cel():
			continue
		var texture: Texture = always_visible[object]
		var center := Vector2(8, 8)
		var pos: Vector2 = object.camera.unproject_position(object.translation)
		var back: Vector3 = object.translation - object.transform.basis.z
		var back_proj: Vector2 = object.camera.unproject_position(back) - pos
		back_proj = _resize_vector(back_proj, LIGHT_ARROW_LENGTH)
		draw_set_transform(pos, 0, draw_scale / 4)
		draw_texture(texture, -center)
		draw_set_transform(pos, 0, draw_scale / 2)
		if object.type == Cel3DObject.Type.DIR_LIGHT:
			draw_line(Vector2.ZERO, back_proj, Color.white)
			var arrow := _find_arrow(back_proj)
			_draw_arrow(arrow, Color.white)
		draw_set_transform_matrix(Transform2D())

	if points_per_object.empty():
		return
	for object in points_per_object:
		if not object.find_cel():
			if object.selected:
				object.unselect()
			continue
		var points: PoolVector2Array = points_per_object[object]
		if points.empty():
			continue
		if object.selected:
			# Draw bounding box outline
			draw_multiline(points, selected_color, 1.0, true)
			if object.applying_gizmos == Cel3DObject.Gizmos.X_ROT:
				draw_line(gizmos_origin, Global.canvas.current_pixel, Color.red)
				continue
			elif object.applying_gizmos == Cel3DObject.Gizmos.Y_ROT:
				draw_line(gizmos_origin, Global.canvas.current_pixel, Color.green)
				continue
			elif object.applying_gizmos == Cel3DObject.Gizmos.Z_ROT:
				draw_line(gizmos_origin, Global.canvas.current_pixel, Color.blue)
				continue
			draw_set_transform(gizmos_origin, 0, draw_scale)
			# Draw position arrows
			draw_line(Vector2.ZERO, proj_right_local, Color.red)
			draw_line(Vector2.ZERO, proj_up_local, Color.green)
			draw_line(Vector2.ZERO, proj_back_local, Color.blue)
			_draw_arrow(gizmo_pos_x, Color.red)
			_draw_arrow(gizmo_pos_y, Color.green)
			_draw_arrow(gizmo_pos_z, Color.blue)

			# Draw rotation curves
			draw_polyline(gizmo_rot_x, Color.red, GIZMO_WIDTH)
			draw_polyline(gizmo_rot_y, Color.green, GIZMO_WIDTH)
			draw_polyline(gizmo_rot_z, Color.blue, GIZMO_WIDTH)

			# Draw scale circles
			draw_circle(proj_right_local_scale, SCALE_CIRCLE_RADIUS, Color.red)
			draw_circle(proj_up_local_scale, SCALE_CIRCLE_RADIUS, Color.green)
			draw_circle(proj_back_local_scale, SCALE_CIRCLE_RADIUS, Color.blue)

			# Draw X, Y, Z characters on top of the scale circles
			var font: Font = Global.control.theme.default_font
			var font_height := font.get_height()
			var char_position := Vector2(-font_height, font_height) * CHAR_SCALE / 4 * draw_scale
			draw_set_transform(gizmos_origin + char_position, 0, draw_scale * CHAR_SCALE)
			draw_char(font, proj_right_local_scale / CHAR_SCALE, "X", "")
			draw_char(font, proj_up_local_scale / CHAR_SCALE, "Y", "")
			draw_char(font, proj_back_local_scale / CHAR_SCALE, "Z", "")
			draw_set_transform_matrix(Transform2D())
		elif object.hovered:
			draw_multiline(points, hovered_color, 1.0, true)


func _resize_vector(v: Vector2, l: float) -> Vector2:
	return (v.normalized() * l).limit_length(v.length())


func _find_curve(a: Vector2, b: Vector2) -> PoolVector2Array:
	var curve2d := Curve2D.new()
	curve2d.bake_interval = 1
	var control := b.linear_interpolate(a, 0.5)
	a = _resize_vector(a, SCALE_CIRCLE_LENGTH)
	b = _resize_vector(b, SCALE_CIRCLE_LENGTH)
	control = control.normalized() * sqrt(pow(a.length() / 4, 2) * 2)  # Thank you Pythagoras
	curve2d.add_point(a, Vector2.ZERO, control)
	curve2d.add_point(b, control)
	return curve2d.get_baked_points()


func _find_arrow(a: Vector2, tilt := 0.5) -> PoolVector2Array:
	var b := a + Vector2(-tilt, 1).rotated(a.angle() + PI / 2) * 2
	var c := a + Vector2(tilt, 1).rotated(a.angle() + PI / 2) * 2
	return PoolVector2Array([a, b, c])


func _draw_arrow(triangle: PoolVector2Array, color: Color) -> void:
	draw_primitive(triangle, [color, color, color], [])
