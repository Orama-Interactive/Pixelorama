class_name Tiles
extends RefCounted

enum MODE { NONE, BOTH, X_AXIS, Y_AXIS }

var mode := MODE.NONE
var x_basis: Vector2i
var y_basis: Vector2i
var tile_size: Vector2i
var tile_mask := Image.new()
var has_mask := false


func _init(size: Vector2i) -> void:
	x_basis = Vector2i(size.x, 0)
	y_basis = Vector2i(0, size.y)
	tile_size = size
	tile_mask = Image.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
	tile_mask.fill(Color.WHITE)


func get_bounding_rect() -> Rect2i:
	match mode:
		MODE.BOTH:
			var diagonal := x_basis + y_basis
			var cross_diagonal := x_basis - y_basis
			var bounding_rect := Rect2i(-diagonal, Vector2.ZERO)
			bounding_rect = bounding_rect.expand(diagonal)
			bounding_rect = bounding_rect.expand(-cross_diagonal)
			bounding_rect = bounding_rect.expand(cross_diagonal)
			bounding_rect = bounding_rect.grow_individual(0, 0, tile_size.x, tile_size.y)
			return bounding_rect
		MODE.X_AXIS:
			var bounding_rect := Rect2i(-x_basis, Vector2.ZERO)
			bounding_rect = bounding_rect.expand(x_basis)
			bounding_rect = bounding_rect.grow_individual(0, 0, tile_size.x, tile_size.y)
			return bounding_rect
		MODE.Y_AXIS:
			var bounding_rect := Rect2i(-y_basis, Vector2.ZERO)
			bounding_rect = bounding_rect.expand(y_basis)
			bounding_rect = bounding_rect.grow_individual(0, 0, tile_size.x, tile_size.y)
			return bounding_rect
		_:
			return Rect2i(Vector2i.ZERO, tile_size)


func get_nearest_tile(point: Vector2i) -> Rect2i:
	var positions: Array[Vector2i] = Global.canvas.tile_mode.get_tile_positions()
	positions.append(Vector2i.ZERO)

	var candidates: Array[Rect2i] = []
	for pos in positions:
		var test_rect := Rect2i(pos, tile_size)
		if test_rect.has_point(point):
			candidates.append(test_rect)
	if candidates.is_empty():
		return Rect2i(Vector2i.ZERO, tile_size)

	var final: Array[Rect2i] = []
	for candidate in candidates:
		var rel_pos := point - candidate.position
		if tile_mask.get_pixelv(rel_pos).a == 1.0:
			final.append(candidate)

	if final.is_empty():
		return Rect2i(Vector2i.ZERO, tile_size)
	final.sort_custom(func(a: Rect2i, b: Rect2i): return a.position.y < b.position.y)
	return final[0]


func get_canon_position(position: Vector2i) -> Vector2i:
	if mode == MODE.NONE:
		return position
	var nearest_tile := get_nearest_tile(position)
	if nearest_tile.has_point(position):
		position -= nearest_tile.position
	return position


func get_point_in_tiles(pixel: Vector2i) -> Array[Vector2i]:
	var positions: Array[Vector2i] = Global.canvas.tile_mode.get_tile_positions()
	positions.append(Vector2i.ZERO)
	var result: Array[Vector2i] = []
	for pos in positions:
		result.append(pos + pixel)
	return result


func has_point(point: Vector2i) -> bool:
	var positions: Array[Vector2i] = Global.canvas.tile_mode.get_tile_positions()
	positions.append(Vector2i.ZERO)  # The central tile is included manually
	for tile_pos in positions:
		var test_rect := Rect2i(tile_pos, tile_size)
		var rel_pos := point - tile_pos
		if test_rect.has_point(point) and tile_mask.get_pixelv(rel_pos).a == 1.0:
			return true
	return false


func reset_mask() -> void:
	tile_mask = Image.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
	tile_mask.fill(Color.WHITE)
	has_mask = false
