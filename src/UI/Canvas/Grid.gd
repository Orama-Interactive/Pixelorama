extends Node2D


func _draw() -> void:
	if not Global.draw_grid:
		return

	var rect := Rect2(Vector2.ZERO, Global.current_project.size)
	if rect.has_no_area():
		return

	var grid_type : int = Global.grid_type
	if grid_type == Global.Grid_Types.CARTESIAN || grid_type == Global.Grid_Types.ALL:
		var start_x : float = wrapf(0, rect.position.x, rect.position.x + Global.grid_width)
		for x in range(start_x, rect.end.x + 1, Global.grid_width):
			draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Global.grid_color)

		var start_y : float = wrapf(0, rect.position.y, rect.position.y + Global.grid_height)
		for y in range(start_y, rect.end.y + 1, Global.grid_height):
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Global.grid_color)

	if grid_type == Global.Grid_Types.ISOMETRIC || grid_type == Global.Grid_Types.ALL:
		_draw_isometric_grid(rect)


func _draw_isometric_grid(target_rect : Rect2) -> void:
	# Using Array instead of PoolVector2Array to avoid kinda
	# random "resize: Can't resize PoolVector if locked" errors.
	#  See: https://github.com/Orama-Interactive/Pixelorama/issues/331
	# It will be converted to PoolVector2Array before being sent to be rendered.
	var grid_multiline_points := []

	var cell_size := Vector2(Global.grid_isometric_cell_bounds_width, Global.grid_isometric_cell_bounds_height)
	var max_cell_count : Vector2 = target_rect.size / cell_size

	var origin := Vector2(Global.grid_isometric_offset_x, Global.grid_isometric_offset_y)
	var origin_offset : Vector2 = (origin - target_rect.position).posmodv(cell_size)

	# lines ↗↗↗ (from bottom-left to top-right)
	var per_cell_offset := cell_size * Vector2(1, -1)

	#  lines ↗↗↗ starting from the rect's left side (top to bottom):
	var y : float = fposmod(origin_offset.y + cell_size.y * (0.5 + origin_offset.x / cell_size.x), cell_size.y)
	while y < target_rect.size.y:
		var start : Vector2 = target_rect.position + Vector2(0, y)
		var cells_to_rect_bounds : float = min(max_cell_count.x, y / cell_size.y)
		var end : Vector2 = start + cells_to_rect_bounds * per_cell_offset
		grid_multiline_points.push_back(start)
		grid_multiline_points.push_back(end)
		y += cell_size.y

	#  lines ↗↗↗ starting from the rect's bottom side (left to right):
	var x : float = (y - target_rect.size.y) / cell_size.y * cell_size.x
	while x < target_rect.size.x:
		var start : Vector2 = target_rect.position + Vector2(x, target_rect.size.y)
		var cells_to_rect_bounds : float = min(max_cell_count.y, max_cell_count.x - x / cell_size.x)
		var end : Vector2 = start + cells_to_rect_bounds * per_cell_offset
		grid_multiline_points.push_back(start)
		grid_multiline_points.push_back(end)
		x += cell_size.x

	# lines ↘↘↘ (from top-left to bottom-right)
	per_cell_offset = cell_size

	#  lines ↘↘↘ starting from the rect's left side (top to bottom):
	y = fposmod(origin_offset.y - cell_size.y * (0.5 + origin_offset.x / cell_size.x), cell_size.y)
	while y < target_rect.size.y:
		var start : Vector2 = target_rect.position + Vector2(0, y)
		var cells_to_rect_bounds : float = min(max_cell_count.x, max_cell_count.y - y / cell_size.y)
		var end : Vector2 = start + cells_to_rect_bounds * per_cell_offset
		grid_multiline_points.push_back(start)
		grid_multiline_points.push_back(end)
		y += cell_size.y

	#  lines ↘↘↘ starting from the rect's top side (left to right):
	x = fposmod(origin_offset.x - cell_size.x * (0.5 + origin_offset.y / cell_size.y), cell_size.x)
	while x < target_rect.size.x:
		var start : Vector2 = target_rect.position + Vector2(x, 0)
		var cells_to_rect_bounds : float = min(max_cell_count.y, max_cell_count.x - x / cell_size.x)
		var end : Vector2 = start + cells_to_rect_bounds * per_cell_offset
		grid_multiline_points.push_back(start)
		grid_multiline_points.push_back(end)
		x += cell_size.x

	if not grid_multiline_points.empty():
		draw_multiline(grid_multiline_points, Global.grid_color)
