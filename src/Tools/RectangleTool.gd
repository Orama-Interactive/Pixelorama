extends "res://src/Tools/ShapeDrawer.gd"


func _get_shape_points_filled(size: Vector2) -> PoolVector2Array:
	var array := []
	var t_of := _thickness - 1

	for y in range(size.y + t_of * 2):
		for x in range(size.x + t_of * 2):
			array.append(Vector2(x, y))

	return PoolVector2Array(array)


func _get_shape_points(size: Vector2) -> PoolVector2Array:
	if _thickness == 1:
		return PoolVector2Array(_get_rectangle_points(Vector2(0, 0), size))
	else:
		var array := []
		var t_of := _thickness - 1
		for i in range(1 + 2 * t_of):
			array += _get_rectangle_points(Vector2(i, i), size + Vector2(2, 2) * (t_of - i))

		return PoolVector2Array(array)


func _get_rectangle_points(pos: Vector2, size: Vector2) -> Array:
	var array := []

	var y1 = size.y + pos.y - 1
	for x in range(pos.x, size.x + pos.x):
		var t := Vector2(x, pos.y)
		var b := Vector2(x, y1)
		array.append(t)
		array.append(b)

	var x1 = size.x + pos.x - 1
	for y in range(pos.y + 1, size.y + pos.y):
		var l := Vector2(pos.x, y)
		var r := Vector2(x1, y)
		array.append(l)
		array.append(r)

	return array
