extends "res://src/Tools/BaseShapeDrawer.gd"


func _get_shape_points_filled(shape_size: Vector2i) -> Array[Vector2i]:
	return DrawingAlgos.get_ellipse_points_filled(Vector2i.ZERO, shape_size, 1)


func _get_shape_points(shape_size: Vector2i) -> Array[Vector2i]:
	return DrawingAlgos.get_ellipse_points(Vector2i.ZERO, shape_size)
