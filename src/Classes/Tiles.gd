class_name Tiles
extends Reference

enum MODE { NONE, BOTH, X_AXIS, Y_AXIS }

var mode: int = MODE.NONE
var tile_size := Vector2.ZERO


static func get_x_basis() -> Vector2:
	return Vector2(Global.tilemode_x_basis_x, Global.tilemode_x_basis_y)


static func get_y_basis() -> Vector2:
	return Vector2(Global.tilemode_y_basis_x, Global.tilemode_y_basis_y)


func get_bounding_rect() -> Rect2:
	var x_basis := get_x_basis()
	var y_basis := get_y_basis()
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
	var x_basis := get_x_basis()
	var y_basis := get_y_basis()
	var tile_to_screen_space := Transform2D(x_basis, y_basis, Vector2.ZERO)
	# Transform2D.basis_xform_inv() is broken so compute the inverse explicitly:
	# https://github.com/godotengine/godot/issues/58556
	var screen_to_tile_space := tile_to_screen_space.affine_inverse()
	var p := point - tile_size / 2.0 + Vector2(0.5, 0.5)  # p relative to center of tiles
	var p_tile_space := screen_to_tile_space.basis_xform(p)
	var tl_tile := tile_to_screen_space.basis_xform(p_tile_space.floor())
	var tr_tile := tl_tile + x_basis
	var bl_tile := tl_tile + y_basis
	var br_tile := tl_tile + x_basis + y_basis
	var tl_tile_dist := (p - tl_tile).length_squared()
	var tr_tile_dist := (p - tr_tile).length_squared()
	var bl_tile_dist := (p - bl_tile).length_squared()
	var br_tile_dist := (p - br_tile).length_squared()
	match [tl_tile_dist, tr_tile_dist, bl_tile_dist, br_tile_dist].min():
		tl_tile_dist:
			return Rect2(tl_tile, tile_size)
		tr_tile_dist:
			return Rect2(tr_tile, tile_size)
		bl_tile_dist:
			return Rect2(bl_tile, tile_size)
		_:
			return Rect2(br_tile, tile_size)


func get_canon_position(position: Vector2) -> Vector2:
	if mode == MODE.NONE:
		return position
	var nearest_tile = get_nearest_tile(position)
	if nearest_tile.has_point(position):
		position -= nearest_tile.position
	return position


func has_point(point: Vector2) -> bool:
	var x_basis := get_x_basis()
	var y_basis := get_y_basis()
	var screen_to_tile_space := Transform2D(x_basis, y_basis, Vector2.ZERO).affine_inverse()
	var nearest_tile := get_nearest_tile(point)
	var nearest_tile_tile_space := screen_to_tile_space.basis_xform(nearest_tile.position).round()
	match mode:
		MODE.BOTH:
			return abs(nearest_tile_tile_space.x) <= 1 and abs(nearest_tile_tile_space.y) <= 1
		MODE.X_AXIS:
			return abs(nearest_tile_tile_space.x) <= 1 and abs(nearest_tile_tile_space.y) == 0
		MODE.Y_AXIS:
			return abs(nearest_tile_tile_space.x) == 0 and abs(nearest_tile_tile_space.y) <= 1
		_:
			return nearest_tile_tile_space == Vector2.ZERO
