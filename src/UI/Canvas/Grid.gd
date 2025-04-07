extends Node2D

var unique_rect_lines := PackedVector2Array()
var unique_iso_lines := PackedVector2Array()


func _ready() -> void:
	Global.project_switched.connect(queue_redraw)
	Global.cel_switched.connect(queue_redraw)


func _draw() -> void:
	if not Global.draw_grid:
		return

	var target_rect: Rect2i
	unique_rect_lines.clear()
	unique_iso_lines.clear()
	for grid_idx in range(Global.grids.size() - 1, -1, -1):
		if Global.grids[grid_idx].grid_draw_over_tile_mode:
			target_rect = Global.current_project.tiles.get_bounding_rect()
		else:
			target_rect = Rect2i(Vector2i.ZERO, Global.current_project.size)
		if not target_rect.has_area():
			return

		var grid_type := Global.grids[grid_idx].grid_type
		if grid_type == Global.GridTypes.CARTESIAN:
			_draw_cartesian_grid(grid_idx, target_rect)
		elif grid_type == Global.GridTypes.ISOMETRIC:
			_draw_isometric_grid(grid_idx, target_rect)
		elif grid_type == Global.GridTypes.HEXAGONAL_POINTY_TOP:
			_draw_hexagonal_grid(grid_idx, target_rect, true)
		elif grid_type == Global.GridTypes.HEXAGONAL_FLAT_TOP:
			_draw_hexagonal_grid(grid_idx, target_rect, false)


func _draw_cartesian_grid(grid_index: int, target_rect: Rect2i) -> void:
	var grid := Global.grids[grid_index]
	var grid_size := grid.grid_size
	var grid_offset := grid.grid_offset
	var cel := Global.current_project.get_current_cel()
	if cel is CelTileMap and grid_index == 0:
		grid_size = (cel as CelTileMap).tileset.tile_size
		grid_offset = (cel as CelTileMap).offset
	var grid_multiline_points := PackedVector2Array()

	var x: float = (
		target_rect.position.x + fposmod(grid_offset.x - target_rect.position.x, grid_size.x)
	)
	while x <= target_rect.end.x:
		if not Vector2(x, target_rect.position.y) in unique_rect_lines:
			grid_multiline_points.push_back(Vector2(x, target_rect.position.y))
			grid_multiline_points.push_back(Vector2(x, target_rect.end.y))
		x += grid_size.x

	var y: float = (
		target_rect.position.y + fposmod(grid_offset.y - target_rect.position.y, grid_size.y)
	)
	while y <= target_rect.end.y:
		if not Vector2(target_rect.position.x, y) in unique_rect_lines:
			grid_multiline_points.push_back(Vector2(target_rect.position.x, y))
			grid_multiline_points.push_back(Vector2(target_rect.end.x, y))
		y += grid_size.y

	unique_rect_lines.append_array(grid_multiline_points)
	if not grid_multiline_points.is_empty():
		draw_multiline(grid_multiline_points, grid.grid_color)


func _draw_isometric_grid(grid_index: int, target_rect: Rect2i) -> void:
	var grid := Global.grids[grid_index]
	var grid_multiline_points := PackedVector2Array()

	var cell_size: Vector2 = grid.grid_size
	var max_cell_count: Vector2 = Vector2(target_rect.size) / cell_size
	var origin_offset: Vector2 = Vector2(grid.grid_offset - target_rect.position).posmodv(cell_size)

	# lines ↗↗↗ (from bottom-left to top-right)
	var per_cell_offset: Vector2 = cell_size * Vector2(1, -1)

	#  lines ↗↗↗ starting from the rect's left side (top to bottom):
	var y: float = fposmod(
		origin_offset.y + cell_size.y * (0.5 + origin_offset.x / cell_size.x), cell_size.y
	)
	while y < target_rect.size.y:
		var start: Vector2 = Vector2(target_rect.position) + Vector2(0, y)
		var cells_to_rect_bounds: float = minf(max_cell_count.x, y / cell_size.y)
		var end := start + cells_to_rect_bounds * per_cell_offset
		if not start in unique_iso_lines:
			grid_multiline_points.push_back(start)
			grid_multiline_points.push_back(end)
		y += cell_size.y

	#  lines ↗↗↗ starting from the rect's bottom side (left to right):
	var x: float = (y - target_rect.size.y) / cell_size.y * cell_size.x
	while x < target_rect.size.x:
		var start: Vector2 = Vector2(target_rect.position) + Vector2(x, target_rect.size.y)
		var cells_to_rect_bounds: float = minf(max_cell_count.y, max_cell_count.x - x / cell_size.x)
		var end: Vector2 = start + cells_to_rect_bounds * per_cell_offset
		if not start in unique_iso_lines:
			grid_multiline_points.push_back(start)
			grid_multiline_points.push_back(end)
		x += cell_size.x

	# lines ↘↘↘ (from top-left to bottom-right)
	per_cell_offset = cell_size

	#  lines ↘↘↘ starting from the rect's left side (top to bottom):
	y = fposmod(origin_offset.y - cell_size.y * (0.5 + origin_offset.x / cell_size.x), cell_size.y)
	while y < target_rect.size.y:
		var start: Vector2 = Vector2(target_rect.position) + Vector2(0, y)
		var cells_to_rect_bounds: float = minf(max_cell_count.x, max_cell_count.y - y / cell_size.y)
		var end: Vector2 = start + cells_to_rect_bounds * per_cell_offset
		if not start in unique_iso_lines:
			grid_multiline_points.push_back(start)
			grid_multiline_points.push_back(end)
		y += cell_size.y

	#  lines ↘↘↘ starting from the rect's top side (left to right):
	x = fposmod(origin_offset.x - cell_size.x * (0.5 + origin_offset.y / cell_size.y), cell_size.x)
	while x < target_rect.size.x:
		var start: Vector2 = Vector2(target_rect.position) + Vector2(x, 0)
		var cells_to_rect_bounds: float = minf(max_cell_count.y, max_cell_count.x - x / cell_size.x)
		var end: Vector2 = start + cells_to_rect_bounds * per_cell_offset
		if not start in unique_iso_lines:
			grid_multiline_points.push_back(start)
			grid_multiline_points.push_back(end)
		x += cell_size.x
	grid_multiline_points.append_array(grid_multiline_points)

	if not grid_multiline_points.is_empty():
		draw_multiline(grid_multiline_points, grid.grid_color)


func _draw_hexagonal_grid(grid_index: int, target_rect: Rect2i, pointy_top: bool) -> void:
	var grid := Global.grids[grid_index]
	var grid_size := grid.grid_size
	var grid_offset := grid.grid_offset
	var cel := Global.current_project.get_current_cel()
	if cel is CelTileMap and grid_index == 0:
		grid_size = (cel as CelTileMap).get_tile_size()
		grid_offset = (cel as CelTileMap).offset
	var grid_multiline_points := PackedVector2Array()
	var x: float
	var y: float
	if pointy_top:
		x = (target_rect.position.x + fposmod(grid_offset.x - target_rect.position.x, grid_size.x))
		y = (
			target_rect.position.y
			+ fposmod(grid_offset.y - target_rect.position.y, grid_size.y * 1.5)
		)
		x -= grid_size.x
		y -= grid_size.y * 1.5
	else:
		x = (
			target_rect.position.x
			+ fposmod(grid_offset.x - target_rect.position.x, grid_size.x * 1.5)
		)
		y = (target_rect.position.y + fposmod(grid_offset.y - target_rect.position.y, grid_size.y))
		x -= grid_size.x * 1.5
		y -= grid_size.y
	var half_size := grid_size / 2.0
	var quarter_size := grid_size / 4.0
	var three_quarters_size := (grid_size * 3.0) / 4.0
	if pointy_top:
		while x < target_rect.end.x:
			var i := 0
			while y < target_rect.end.y:
				var xx := x
				if i % 2 == 1:
					@warning_ignore("integer_division")
					xx += grid_size.x / 2
				var width := xx + grid_size.x
				var height := y + grid_size.y
				var half := xx + half_size.x
				var quarter := y + quarter_size.y
				var third_quarter := y + three_quarters_size.y

				var top_pos := Vector2(half, y)
				var quarter_top_right := Vector2(width, quarter)
				var quarter_bottom_right := Vector2(width, third_quarter)
				var bottom_pos := Vector2(half, height)
				var quarter_bottom_left := Vector2(xx, third_quarter)
				var quarter_top_left := Vector2(xx, quarter)
				_hexagonal_cell_points_append(
					top_pos, quarter_top_right, target_rect, grid_multiline_points
				)
				_hexagonal_cell_points_append(
					quarter_top_right, quarter_bottom_right, target_rect, grid_multiline_points
				)
				_hexagonal_cell_points_append(
					quarter_bottom_right, bottom_pos, target_rect, grid_multiline_points
				)
				_hexagonal_cell_points_append(
					bottom_pos, quarter_bottom_left, target_rect, grid_multiline_points
				)
				_hexagonal_cell_points_append(
					quarter_bottom_left, quarter_top_left, target_rect, grid_multiline_points
				)
				_hexagonal_cell_points_append(
					quarter_top_left, top_pos, target_rect, grid_multiline_points
				)
				y += ((grid_size.y * 3.0) / 4.0)
				i += 1
			y = (
				target_rect.position.y
				+ fposmod(grid_offset.y - target_rect.position.y, grid_size.y * 1.5)
			)
			y -= grid_size.y * 1.5
			x += grid_size.x
	else:
		while y < target_rect.end.y:
			var i := 0
			while x < target_rect.end.x:
				var yy := y
				if i % 2 == 1:
					@warning_ignore("integer_division")
					yy += grid_size.y / 2
				var width := x + grid_size.x
				var height := yy + grid_size.y
				var half := yy + half_size.y
				var quarter := x + quarter_size.x
				var third_quarter := x + three_quarters_size.x

				var left_pos := Vector2(x, half)
				var quarter_top_left := Vector2(quarter, height)
				var quarter_top_right := Vector2(third_quarter, height)
				var right_pos := Vector2(width, half)
				var quarter_bottom_right := Vector2(third_quarter, yy)
				var quarter_bottom_left := Vector2(quarter, yy)
				_hexagonal_cell_points_append(
					left_pos, quarter_top_left, target_rect, grid_multiline_points
				)
				_hexagonal_cell_points_append(
					quarter_top_left, quarter_top_right, target_rect, grid_multiline_points
				)
				_hexagonal_cell_points_append(
					quarter_top_right, right_pos, target_rect, grid_multiline_points
				)
				_hexagonal_cell_points_append(
					right_pos, quarter_bottom_right, target_rect, grid_multiline_points
				)
				_hexagonal_cell_points_append(
					quarter_bottom_right, quarter_bottom_left, target_rect, grid_multiline_points
				)
				_hexagonal_cell_points_append(
					quarter_bottom_left, left_pos, target_rect, grid_multiline_points
				)
				x += ((grid_size.x * 3.0) / 4.0)
				i += 1
			x = (
				target_rect.position.x
				+ fposmod(grid_offset.x - target_rect.position.x, grid_size.x * 1.5)
			)
			x -= grid_size.x * 1.5
			y += grid_size.y
	if not grid_multiline_points.is_empty():
		draw_multiline(grid_multiline_points, grid.grid_color)


func _hexagonal_cell_points_append(
	a: Vector2, b: Vector2, rect: Rect2, grid_multiline_points: PackedVector2Array
) -> void:
	var expanded_rect := rect
	expanded_rect.size += Vector2.ONE
	if expanded_rect.has_point(a) && expanded_rect.has_point(b):
		grid_multiline_points.push_back(a)
		grid_multiline_points.push_back(b)
	# If a point is outside the edge of the canvas,
	# we want to draw the line until the point of intersection with the canvas edge.
	# Find the slope of the line and find the line equation, then solve for y or x.
	# TODO: There has to be a better way to do this.
	# This is too much code and it does not produce 100% correct results.
	elif expanded_rect.has_point(a):
		var m := (b.y - a.y) / (b.x - a.x)
		if b.x > rect.end.x:
			grid_multiline_points.push_back(a)
			var yy := m * (rect.end.x - a.x) + a.y
			grid_multiline_points.push_back(Vector2(rect.end.x, yy))
		elif b.x < rect.position.x:
			grid_multiline_points.push_back(a)
			var yy := m * (rect.position.x - a.x) + a.y
			grid_multiline_points.push_back(Vector2(rect.position.x, yy))
		elif b.y > rect.end.y:
			grid_multiline_points.push_back(a)
			var xx := (rect.end.y - a.y) / m + a.x
			grid_multiline_points.push_back(Vector2(xx, rect.end.y))
		elif b.y < rect.position.y:
			grid_multiline_points.push_back(a)
			var xx := (rect.position.y - a.y) / m + a.x
			grid_multiline_points.push_back(Vector2(xx, rect.position.y))

	elif expanded_rect.has_point(b):
		var m := (a.y - b.y) / (a.x - b.x)
		if a.x > rect.end.x:
			grid_multiline_points.push_back(b)
			var yy := m * (rect.end.x - b.x) + b.y
			grid_multiline_points.push_back(Vector2(rect.end.x, yy))
		elif a.x < rect.position.x:
			grid_multiline_points.push_back(b)
			var yy := m * (rect.position.x - b.x) + b.y
			grid_multiline_points.push_back(Vector2(rect.position.x, yy))
		elif a.y > rect.end.y:
			grid_multiline_points.push_back(b)
			var xx := (rect.end.y - b.y) / m + b.x
			grid_multiline_points.push_back(Vector2(xx, rect.end.y))
		elif a.y < rect.position.y:
			grid_multiline_points.push_back(b)
			var xx := (rect.position.y - b.y) / m + b.x
			grid_multiline_points.push_back(Vector2(xx, rect.position.y))
