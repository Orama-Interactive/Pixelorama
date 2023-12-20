extends "res://src/Tools/BaseShapeDrawer.gd"


func _get_shape_points_filled(shape_size: Vector2i) -> Array[Vector2i]:
	var array: Array[Vector2i] = []
	var t_of := _thickness - 1

	for y in range(shape_size.y + t_of):
		for x in range(shape_size.x + t_of):
			array.append(Vector2i(x, y))

	return array


func _get_shape_points(shape_size: Vector2i) -> Array[Vector2i]:
	if _thickness == 1:
		return _get_rectangle_points(Vector2(0, 0), shape_size)

	var array: Array[Vector2i] = []
	var t_of := _thickness - 1
	for i in range(_thickness):
		var point_size := shape_size + Vector2i(2, 2) * (t_of - i) - Vector2i.ONE * t_of
		array += _get_rectangle_points(Vector2(i, i), point_size)

	return array


func _get_rectangle_points(pos: Vector2i, shape_size: Vector2i) -> Array[Vector2i]:
	var array: Array[Vector2i] = []

	var y1 := shape_size.y + pos.y - 1
	for x in range(pos.x, shape_size.x + pos.x):
		var t := Vector2i(x, pos.y)
		var b := Vector2i(x, y1)
		array.append(t)
		array.append(b)

	var x1 := shape_size.x + pos.x - 1
	for y in range(pos.y + 1, shape_size.y + pos.y):
		var l := Vector2i(pos.x, y)
		var r := Vector2i(x1, y)
		array.append(l)
		array.append(r)

	return array
