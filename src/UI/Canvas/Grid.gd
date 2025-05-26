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
		var cel := Global.current_project.get_current_cel()
		if cel is CelTileMap and grid_idx == 0:
			if cel.get_tile_shape() == TileSet.TILE_SHAPE_ISOMETRIC:
				grid_type = Global.GridTypes.ISOMETRIC_PIXEL_REGULAR
			elif cel.get_tile_shape() == TileSet.TILE_SHAPE_HEXAGON:
				if cel.get_tile_offset_axis() == TileSet.TILE_OFFSET_AXIS_HORIZONTAL:
					grid_type = Global.GridTypes.HEXAGONAL_POINTY_TOP
				else:
					grid_type = Global.GridTypes.HEXAGONAL_FLAT_TOP
			else:
				grid_type = Global.GridTypes.CARTESIAN
		if grid_type == Global.GridTypes.CARTESIAN:
			_draw_cartesian_grid(grid_idx, target_rect)
		elif grid_type == Global.GridTypes.ISOMETRIC_REGULAR:
			_draw_pixelated_isometric_grid(grid_idx, target_rect)
		elif grid_type == Global.GridTypes.ISOMETRIC_PIXEL_REGULAR:
			_draw_pixelated_isometric_grid(grid_idx, target_rect)
		elif grid_type == Global.GridTypes.ISOMETRIC_PIXEL_STACKED:
			_draw_pixelated_isometric_grid(grid_idx, target_rect, true)
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
		grid_size = (cel as CelTileMap).get_tile_size()
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


func _create_polylines(points: Array[Vector2i], bound: Rect2i) -> Array:
	var lines = []
	for i in points.size():
		var point = points[i]
		if i < points.size() - 1:
			var next_point = points[i + 1]
			if (
				point.x < bound.position.x
				or point.x > bound.end.x
				or point.y < bound.position.y
				or point.y > bound.end.y
				or next_point.x < bound.position.x
				or next_point.x > bound.end.x
				or next_point.y < bound.position.y
				or next_point.y > bound.end.y
			):
				continue
			lines.append(point)
			if next_point.y < point.y:
				lines.append(point + Vector2i.UP)
				lines.append(point + Vector2i.UP)
			elif next_point.y > point.y:
				lines.append(point + Vector2i.DOWN)
				lines.append(point + Vector2i.DOWN)
			lines.append(next_point)
	return lines


func get_isometric_polyline(point: Vector2, tile_size: Vector2, bound, is_stacked := false) -> PackedVector2Array:
	var lines = PackedVector2Array()
	var centre = ((tile_size - Vector2.ONE) / 2).floor()
	var tile_size_x = Vector2i(tile_size.x, 0)
	var tile_size_y = Vector2i(0, tile_size.y)
	var top_left = Geometry2D.bresenham_line(
		Vector2i(point) + Vector2i(centre.x, 0), Vector2i(point) + Vector2i(0, centre.y)
	)
	# x-mirror of the top_left array
	var top_right = Geometry2D.bresenham_line(
		tile_size_x + Vector2i(point) - Vector2i(centre.x, 0),
		tile_size_x + Vector2i(point) + Vector2i(0, centre.y)
	)
	# y-mirror of the top_left array
	var down_left = Geometry2D.bresenham_line(
		tile_size_y + Vector2i(point) + Vector2i(centre.x, 0),
		tile_size_y + Vector2i(point) - Vector2i(0, centre.y)
	)
	# xy-mirror of the top_left array
	var down_right = Geometry2D.bresenham_line(
		Vector2i(tile_size) + Vector2i(point) - Vector2i(centre.x, 0),
		Vector2i(tile_size) + Vector2i(point) - Vector2i(0, centre.y)
	)
	## Add tile separators
	if is_stacked:
		var separator_points: Array[Vector2i] = [top_left[0], down_left[0]]
		var adders = [Vector2i.UP, Vector2i.DOWN]
		var compensation := Vector2i.RIGHT
		if tile_size.y > tile_size.x:
			separator_points = [top_left[-1], top_right[-1]]
			adders = [Vector2i.LEFT, Vector2i.RIGHT]
			compensation = Vector2i.DOWN
		if tile_size.y == tile_size.x:
			separator_points.clear()
			adders.clear()
			compensation = Vector2i.ZERO
		for i in separator_points.size():
			var sep = separator_points[i]
			if !bound.has_point(sep) or !bound.has_point(sep + adders[i]):
				continue
			lines.append(sep)
			lines.append(sep + compensation)
			lines.append(sep + compensation)
			lines.append(sep + compensation + adders[i])
	lines.append_array(_create_polylines(top_left, bound))
	lines.append_array(_create_polylines(top_right, bound))
	lines.append_array(_create_polylines(down_left, bound))
	lines.append_array(_create_polylines(down_right, bound))
	# Connect un-connected sides left in the shape
	# top/down peaks
	if (
		bound.has_point(Vector2i(point) + Vector2i(centre.x, 0))
		and bound.has_point(tile_size_x + Vector2i(point) - Vector2i(centre.x, 0))
	):
		lines.append(Vector2i(point) + Vector2i(centre.x, 0))
		lines.append(tile_size_x + Vector2i(point) - Vector2i(centre.x, 0))
	if (
		bound.has_point(tile_size_y + Vector2i(point) + Vector2i(centre.x, 0))
		and bound.has_point(Vector2i(tile_size) + Vector2i(point) - Vector2i(centre.x, 0))
	):
		lines.append(tile_size_y + Vector2i(point) + Vector2i(centre.x, 0))
		lines.append(Vector2i(tile_size) + Vector2i(point) - Vector2i(centre.x, 0))
	# side peaks
	if (
		bound.has_point(Vector2i(point) + Vector2i(0, centre.y))
		and bound.has_point(tile_size_y + Vector2i(point) - Vector2i(0, centre.y))
	):
		lines.append(Vector2i(point) + Vector2i(0, centre.y))
		lines.append(tile_size_y + Vector2i(point) - Vector2i(0, centre.y))
	if (
		bound.has_point(tile_size_x + Vector2i(point) + Vector2i(0, centre.y))
		and bound.has_point(Vector2i(tile_size) + Vector2i(point) - Vector2i(0, centre.y))
	):
		lines.append(tile_size_x + Vector2i(point) + Vector2i(0, centre.y))
		lines.append(Vector2i(tile_size) + Vector2i(point) - Vector2i(0, centre.y))
	return lines


func _draw_pixelated_isometric_grid(grid_index: int, target_rect: Rect2i, stacked := false) -> void:
	var grid := Global.grids[grid_index]
	var grid_multiline_points := PackedVector2Array()
	var cell_size: Vector2 = grid.grid_size
	var stack_offset := Vector2.ZERO
	if stacked:
		if cell_size.x > cell_size.y:
			if int(cell_size.y) % 2 == 0:
				stack_offset.y = 2
			else:
				stack_offset.y = 1
		elif cell_size.y > cell_size.x:
			if int(cell_size.x) % 2 == 0:
				stack_offset.x = 2
			else:
				stack_offset.x = 1
	var origin_offset: Vector2 = Vector2(grid.grid_offset - target_rect.position).posmodv(
		cell_size + stack_offset
	)
	var cel := Global.current_project.get_current_cel()
	if cel is CelTileMap and grid_index == 0:
		cell_size = (cel as CelTileMap).get_tile_size()
		origin_offset = Vector2((cel as CelTileMap).offset - target_rect.position).posmodv(
			cell_size + Vector2(0, 2)
		)
	var max_cell_count: Vector2 = Vector2(target_rect.size) / cell_size
	var start_offset = origin_offset - cell_size + Vector2(target_rect.position)
	var tile_sep = Vector2.ZERO
	for cel_y in range(0, max_cell_count.y + 2):
		for cel_x in range(0, max_cell_count.x + 2):
			var cel_pos: Vector2 = Vector2(cel_x, cel_y) * cell_size + start_offset + tile_sep
			grid_multiline_points.append_array(
				get_isometric_polyline(cel_pos, cell_size, target_rect, stacked)
			)
			if cell_size.y > cell_size.x:
				tile_sep.x += stack_offset.x
		tile_sep.x = 0
		if cell_size.x > cell_size.y:
			tile_sep.y += stack_offset.y
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
