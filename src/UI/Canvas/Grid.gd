extends Node2D


func _ready() -> void:
	Global.project_switched.connect(queue_redraw)


func _draw() -> void:
	if not Global.draw_grid:
		return

	var target_rect: Rect2i
	if Global.grid_draw_over_tile_mode:
		target_rect = Global.current_project.tiles.get_bounding_rect()
	else:
		target_rect = Rect2i(Vector2i.ZERO, Global.current_project.size)
	if not target_rect.has_area():
		return

	var grid_type := Global.grid_type
	if grid_type == Global.GridTypes.CARTESIAN || grid_type == Global.GridTypes.ALL:
		_draw_cartesian_grid(target_rect)

	if grid_type == Global.GridTypes.ISOMETRIC || grid_type == Global.GridTypes.ALL:
		_draw_isometric_grid(target_rect)


func _draw_cartesian_grid(target_rect: Rect2i) -> void:
	var grid_multiline_points := PackedVector2Array()

	var x: float = (
		target_rect.position.x
		+ fposmod(Global.grid_offset.x - target_rect.position.x, Global.grid_size.x)
	)
	while x <= target_rect.end.x:
		grid_multiline_points.push_back(Vector2(x, target_rect.position.y))
		grid_multiline_points.push_back(Vector2(x, target_rect.end.y))
		x += Global.grid_size.x

	var y: float = (
		target_rect.position.y
		+ fposmod(Global.grid_offset.y - target_rect.position.y, Global.grid_size.y)
	)
	while y <= target_rect.end.y:
		grid_multiline_points.push_back(Vector2(target_rect.position.x, y))
		grid_multiline_points.push_back(Vector2(target_rect.end.x, y))
		y += Global.grid_size.y

	if not grid_multiline_points.is_empty():
		draw_multiline(grid_multiline_points, Global.grid_color)


func _draw_isometric_grid(target_rect: Rect2i) -> void:
	var grid_multiline_points := PackedVector2Array()

	var cell_size := Global.isometric_grid_size
	var max_cell_count := target_rect.size / cell_size
	var origin_offset := Vector2(Global.grid_offset - target_rect.position).posmodv(cell_size)

	# lines ↗↗↗ (from bottom-left to top-right)
	var per_cell_offset := cell_size * Vector2i(1, -1)

	#  lines ↗↗↗ starting from the rect's left side (top to bottom):
	var y: float = fposmod(
		origin_offset.y + cell_size.y * (0.5 + origin_offset.x / cell_size.x), cell_size.y
	)
	while y < target_rect.size.y:
		var start: Vector2 = target_rect.position + Vector2i(0, y)
		var cells_to_rect_bounds := minf(max_cell_count.x, y / cell_size.y)
		var end := start + cells_to_rect_bounds * per_cell_offset
		grid_multiline_points.push_back(start)
		grid_multiline_points.push_back(end)
		y += cell_size.y

	#  lines ↗↗↗ starting from the rect's bottom side (left to right):
	var x: float = (y - target_rect.size.y) / cell_size.y * cell_size.x
	while x < target_rect.size.x:
		var start: Vector2 = target_rect.position + Vector2i(x, target_rect.size.y)
		var cells_to_rect_bounds := minf(max_cell_count.y, max_cell_count.x - x / cell_size.x)
		var end: Vector2 = start + cells_to_rect_bounds * per_cell_offset
		grid_multiline_points.push_back(start)
		grid_multiline_points.push_back(end)
		x += cell_size.x

	# lines ↘↘↘ (from top-left to bottom-right)
	per_cell_offset = cell_size

	#  lines ↘↘↘ starting from the rect's left side (top to bottom):
	y = fposmod(origin_offset.y - cell_size.y * (0.5 + origin_offset.x / cell_size.x), cell_size.y)
	while y < target_rect.size.y:
		var start: Vector2 = target_rect.position + Vector2i(0, y)
		var cells_to_rect_bounds := minf(max_cell_count.x, max_cell_count.y - y / cell_size.y)
		var end: Vector2 = start + cells_to_rect_bounds * per_cell_offset
		grid_multiline_points.push_back(start)
		grid_multiline_points.push_back(end)
		y += cell_size.y

	#  lines ↘↘↘ starting from the rect's top side (left to right):
	x = fposmod(origin_offset.x - cell_size.x * (0.5 + origin_offset.y / cell_size.y), cell_size.x)
	while x < target_rect.size.x:
		var start: Vector2 = target_rect.position + Vector2i(x, 0)
		var cells_to_rect_bounds := minf(max_cell_count.y, max_cell_count.x - x / cell_size.x)
		var end: Vector2 = start + cells_to_rect_bounds * per_cell_offset
		grid_multiline_points.push_back(start)
		grid_multiline_points.push_back(end)
		x += cell_size.x

	if not grid_multiline_points.is_empty():
		draw_multiline(grid_multiline_points, Global.grid_color)
