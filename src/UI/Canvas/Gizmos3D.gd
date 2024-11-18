extends Node2D

enum { X, Y, Z }

const ARROW_LENGTH := 14
const LIGHT_ARROW_LENGTH := 25
const GIZMO_WIDTH := 0.4
const SCALE_CIRCLE_LENGTH := 8
const SCALE_CIRCLE_RADIUS := 1
const CHAR_SCALE := 0.16
const DISAPPEAR_THRESHOLD := 1  ## length of arrow below which system won't draw it (for cleaner UI)

var always_visible := {}  ## Key = Cel3DObject, Value = Texture2D
var points_per_object := {}  ## Key = Cel3DObject, Value = PackedVector2Array
var selected_color := Color.WHITE
var hovered_color := Color.GRAY

var gizmos_origin: Vector2
var proj_right_local: Vector2
var proj_up_local: Vector2
var proj_back_local: Vector2
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
	set_process_input(false)
	Global.cel_switched.connect(_cel_switched)
	Global.camera.zoom_changed.connect(queue_redraw)


func get_hovering_gizmo(pos: Vector2) -> int:
	var draw_scale := Vector2(10.0, 10.0) / Global.camera.zoom
	pos -= gizmos_origin
	# Scale the position based on the zoom, has the same effect as enlarging the shapes
	pos /= draw_scale
	# Inflate the rotation polylines by one to make them easier to click
	var rot_x_offset := Geometry2D.offset_polyline(gizmo_rot_x, 1)[0]
	var rot_y_offset := Geometry2D.offset_polyline(gizmo_rot_y, 1)[0]
	var rot_z_offset := Geometry2D.offset_polyline(gizmo_rot_z, 1)[0]

	if Geometry2D.is_point_in_circle(pos, proj_right_local_scale, SCALE_CIRCLE_RADIUS):
		return Cel3DObject.Gizmos.X_SCALE
	elif Geometry2D.is_point_in_circle(pos, proj_up_local_scale, SCALE_CIRCLE_RADIUS):
		return Cel3DObject.Gizmos.Y_SCALE
	elif Geometry2D.is_point_in_circle(pos, proj_back_local_scale, SCALE_CIRCLE_RADIUS):
		return Cel3DObject.Gizmos.Z_SCALE
	elif Geometry2D.point_is_inside_triangle(pos, gizmo_pos_x[0], gizmo_pos_x[1], gizmo_pos_x[2]):
		return Cel3DObject.Gizmos.X_POS
	elif Geometry2D.point_is_inside_triangle(pos, gizmo_pos_y[0], gizmo_pos_y[1], gizmo_pos_y[2]):
		return Cel3DObject.Gizmos.Y_POS
	elif Geometry2D.point_is_inside_triangle(pos, gizmo_pos_z[0], gizmo_pos_z[1], gizmo_pos_z[2]):
		return Cel3DObject.Gizmos.Z_POS
	elif Geometry2D.is_point_in_polygon(pos, rot_x_offset):
		return Cel3DObject.Gizmos.X_ROT
	elif Geometry2D.is_point_in_polygon(pos, rot_y_offset):
		return Cel3DObject.Gizmos.Y_ROT
	elif Geometry2D.is_point_in_polygon(pos, rot_z_offset):
		return Cel3DObject.Gizmos.Z_ROT
	return Cel3DObject.Gizmos.NONE


func _cel_switched() -> void:
	queue_redraw()
	set_process_input(Global.current_project.get_current_cel() is Cel3D)


func _find_selected_object() -> Cel3DObject:
	for object in points_per_object:
		if is_instance_valid(object) and object.selected:
			return object
	return null


func add_always_visible(object3d: Cel3DObject, texture: Texture2D) -> void:
	always_visible[object3d] = texture
	queue_redraw()


func remove_always_visible(object3d: Cel3DObject) -> void:
	always_visible.erase(object3d)
	queue_redraw()


func get_points(camera: Camera3D, object3d: Cel3DObject) -> void:
	var debug_mesh := object3d.box_shape.get_debug_mesh()
	var arrays := debug_mesh.surface_get_arrays(0)
	var points := PackedVector2Array()
	for vertex in arrays[ArrayMesh.ARRAY_VERTEX]:
		var x_vertex: Vector3 = object3d.transform * (vertex)
		var point := camera.unproject_position(x_vertex)
		if not camera.is_position_behind(x_vertex):
			points.append(point)
	points_per_object[object3d] = points
	if object3d.selected:
		gizmos_origin = camera.unproject_position(object3d.position)
		var right := object3d.position + object3d.transform.basis.x
		var left := object3d.position - object3d.transform.basis.x
		var up := object3d.position + object3d.transform.basis.y
		var down := object3d.position - object3d.transform.basis.y
		var back := object3d.position + object3d.transform.basis.z
		var front := object3d.position - object3d.transform.basis.z

		var proj_right := object3d.camera.unproject_position(right)
		var proj_up := object3d.camera.unproject_position(up)
		var proj_back := object3d.camera.unproject_position(back)

		proj_right_local = proj_right - gizmos_origin
		proj_up_local = proj_up - gizmos_origin
		proj_back_local = proj_back - gizmos_origin

		var curve_right_local := proj_right_local
		var curve_up_local := proj_up_local
		var curve_back_local := proj_back_local
		if right.distance_to(camera.position) > left.distance_to(camera.position):
			curve_right_local = object3d.camera.unproject_position(left) - gizmos_origin
		if up.distance_to(camera.position) > down.distance_to(camera.position):
			curve_up_local = object3d.camera.unproject_position(down) - gizmos_origin
		if back.distance_to(camera.position) > front.distance_to(camera.position):
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

	queue_redraw()


func clear_points(object3d: Cel3DObject) -> void:
	points_per_object.erase(object3d)
	queue_redraw()


func _draw() -> void:
	var draw_scale := Vector2(10.0, 10.0) / Global.camera.zoom
	for object in always_visible:
		if not always_visible[object]:
			continue
		if not object.find_cel():
			continue
		var texture: Texture2D = always_visible[object]
		var center := Vector2(8, 8)
		var pos: Vector2 = object.camera.unproject_position(object.position)
		var back: Vector3 = object.position - object.transform.basis.z
		var back_proj: Vector2 = object.camera.unproject_position(back) - pos
		back_proj = _resize_vector(back_proj, LIGHT_ARROW_LENGTH)
		draw_set_transform(pos, 0, draw_scale / 4)
		draw_texture(texture, -center)
		draw_set_transform(pos, 0, draw_scale / 2)
		if object.type == Cel3DObject.Type.DIR_LIGHT:
			draw_line(Vector2.ZERO, back_proj, Color.WHITE)
			var arrow := _find_arrow(back_proj)
			_draw_arrow(arrow, Color.WHITE)
		draw_set_transform_matrix(Transform2D())

	if points_per_object.is_empty():
		return
	for object in points_per_object:
		if not object.find_cel():
			if object.selected:
				object.deselect()
			continue
		var points: PackedVector2Array = points_per_object[object]
		if points.is_empty():
			continue
		if object.selected:
			# Draw bounding box outline
			draw_multiline(points, selected_color, 0.5)
			if object.applying_gizmos == Cel3DObject.Gizmos.X_ROT:
				draw_line(gizmos_origin, canvas.current_pixel, Color.RED)
				continue
			elif object.applying_gizmos == Cel3DObject.Gizmos.Y_ROT:
				draw_line(gizmos_origin, canvas.current_pixel, Color.GREEN)
				continue
			elif object.applying_gizmos == Cel3DObject.Gizmos.Z_ROT:
				draw_line(gizmos_origin, canvas.current_pixel, Color.BLUE)
				continue
			draw_set_transform(gizmos_origin, 0, draw_scale)
			# Draw position arrows
			if proj_right_local.length() > DISAPPEAR_THRESHOLD:
				draw_line(Vector2.ZERO, proj_right_local, Color.RED)
				_draw_arrow(gizmo_pos_x, Color.RED)
			if proj_up_local.length() > DISAPPEAR_THRESHOLD:
				draw_line(Vector2.ZERO, proj_up_local, Color.GREEN)
				_draw_arrow(gizmo_pos_y, Color.GREEN)
			if proj_back_local.length() > DISAPPEAR_THRESHOLD:
				draw_line(Vector2.ZERO, proj_back_local, Color.BLUE)
				_draw_arrow(gizmo_pos_z, Color.BLUE)

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
		elif object.hovered:
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
