extends "res://src/Tools/ShapeDrawer.gd"


func _get_shape_points_filled(shape_size: Vector2) -> PackedVector2Array:
	var array := []
	var t_of := _thickness - 1

	for y in range(shape_size.y + t_of):
		for x in range(shape_size.x + t_of):
			array.append(Vector2(x, y))

	return PackedVector2Array(array)


func _get_shape_points(shape_size: Vector2) -> PackedVector2Array:
	if _thickness == 1:
		return PackedVector2Array(_get_rectangle_points(Vector2(0, 0), shape_size))

	var array := []
	var t_of := _thickness - 1
	for i in range(_thickness):
		var point_size := shape_size + Vector2(2, 2) * (t_of - i) - Vector2.ONE * t_of
		array += _get_rectangle_points(Vector2(i, i), point_size)

	return PackedVector2Array(array)


func _get_rectangle_points(pos: Vector2, shape_size: Vector2) -> Array:
	var array := []

	var y1 = shape_size.y + pos.y - 1
	for x in range(pos.x, shape_size.x + pos.x):
		var t := Vector2(x, pos.y)
		var b := Vector2(x, y1)
		array.append(t)
		array.append(b)

	var x1 = shape_size.x + pos.x - 1
	for y in range(pos.y + 1, shape_size.y + pos.y):
		var l := Vector2(pos.x, y)
		var r := Vector2(x1, y)
		array.append(l)
		array.append(r)

	return array
