class_name Tiles
extends Reference

enum MODE { NONE, BOTH, X_AXIS, Y_AXIS }

var mode: int = MODE.NONE
var x_basis: Vector2
var y_basis: Vector2
var tile_size: Vector2


func _init(size: Vector2):
	x_basis = Vector2(size.x, 0)
	y_basis = Vector2(0, size.y)
	tile_size = size


func get_bounding_rect() -> Rect2:
	match mode:
		MODE.BOTH:
			var diagonal := x_basis + y_basis
			var cross_diagonal := x_basis - y_basis
			var bounding_rect := Rect2(-diagonal, Vector2.ZERO)
			bounding_rect = bounding_rect.expand(diagonal)
			bounding_rect = bounding_rect.expand(-cross_diagonal)
			bounding_rect = bounding_rect.expand(cross_diagonal)
			bounding_rect = bounding_rect.grow_individual(0, 0, tile_size.x, tile_size.y)
			return bounding_rect
		MODE.X_AXIS:
			var bounding_rect := Rect2(-x_basis, Vector2.ZERO)
			bounding_rect = bounding_rect.expand(x_basis)
			bounding_rect = bounding_rect.grow_individual(0, 0, tile_size.x, tile_size.y)
			return bounding_rect
		MODE.Y_AXIS:
			var bounding_rect := Rect2(-y_basis, Vector2.ZERO)
			bounding_rect = bounding_rect.expand(y_basis)
			bounding_rect = bounding_rect.grow_individual(0, 0, tile_size.x, tile_size.y)
			return bounding_rect
		_:
			return Rect2(Vector2.ZERO, tile_size)


func get_nearest_tile(point: Vector2) -> Rect2:
	var positions = Global.canvas.tile_mode.get_tile_positions()

	# Priortize main tile as nearest if mouse is in it
	if Rect2(Vector2.ZERO, tile_size).has_point(point):
		return Rect2(Vector2.ZERO, tile_size)

	for pos_ind in positions.size():
		# Tiles on top gets detected first in case of overlap
		var pos = positions[positions.size() - pos_ind - 1]
		var test_rect = Rect2(pos, tile_size)
		if test_rect.has_point(point):
			print(test_rect.position)
			return test_rect

	return Rect2(Vector2.ZERO, tile_size)


func get_canon_position(position: Vector2) -> Vector2:
	if mode == MODE.NONE:
		return position
	var nearest_tile = get_nearest_tile(position)
	if nearest_tile.has_point(position):
		position -= nearest_tile.position
	return position


func has_point(point: Vector2) -> bool:
	var positions = Global.canvas.tile_mode.get_tile_positions()
	positions.append(Vector2.ZERO)  # The central tile is included manually

	for pos in positions:
		var test_rect = Rect2(pos, tile_size)
		if test_rect.has_point(point):
			return true
	return false
