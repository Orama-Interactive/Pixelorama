class_name Tiles
extends Reference

enum MODE { NONE, BOTH, X_AXIS, Y_AXIS }

var mode: int = MODE.NONE
var x_basis: Vector2
var y_basis: Vector2
var tile_size: Vector2
var tile_mask := Image.new()
var has_mask := false


func _init(size: Vector2):
	x_basis = Vector2(size.x, 0)
	y_basis = Vector2(0, size.y)
	tile_size = size
	tile_mask.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
	tile_mask.fill(Color.white)


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
	positions.append(Vector2.ZERO)

	var candidates := []
	for pos in positions:
		var test_rect = Rect2(pos, tile_size)
		if test_rect.has_point(point):
			candidates.append(test_rect)
	if candidates.empty():
		return Rect2(Vector2.ZERO, tile_size)

	var final := []
	tile_mask.lock()
	for candidate in candidates:
		var rel_pos = point - candidate.position
		if tile_mask.get_pixelv(rel_pos).a == 1.0:
			final.append(candidate)
	tile_mask.unlock()

	if final.empty():
		return Rect2(Vector2.ZERO, tile_size)
	final.sort_custom(self, "sort_by_height")
	return final[0]


func sort_by_height(a: Rect2, b: Rect2):
	if a.position.y > b.position.y:
		return false
	else:
		return true


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
	tile_mask.lock()
	for tile_pos in positions:
		var test_rect = Rect2(tile_pos, tile_size)
		var rel_pos = point - tile_pos
		if test_rect.has_point(point) and tile_mask.get_pixelv(rel_pos).a == 1.0:
			return true
	tile_mask.unlock()
	return false


func reset_mask():
	tile_mask.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
	tile_mask.fill(Color.white)
	has_mask = false
