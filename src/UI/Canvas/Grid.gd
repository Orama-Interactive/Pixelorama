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
		if grid_type == Global.GridTypes.CARTESIAN || grid_type == Global.GridTypes.ALL:
			_draw_cartesian_grid(grid_idx, target_rect)

		if grid_type == Global.GridTypes.ISOMETRIC || grid_type == Global.GridTypes.ALL:
			_draw_isometric_grid(grid_idx, target_rect)


func _draw_cartesian_grid(grid_index: int, target_rect: Rect2i) -> void:
	var grid := Global.grids[grid_index]
	var grid_size := grid.grid_size
	var grid_offset := grid.grid_offset
	var cel := Global.current_project.get_current_cel()
	if cel is CelTileMap and grid_index == 0:
		grid_size = (cel as CelTileMap).tileset.tile_size
		grid_offset = Vector2i.ZERO
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

	var cell_size: Vector2 = grid.isometric_grid_size
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
