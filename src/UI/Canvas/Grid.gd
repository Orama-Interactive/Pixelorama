extends Node2D


var location := Vector2.ZERO
var isometric_polylines := [] # An array of PoolVector2Arrays


func _draw() -> void:
	if Global.draw_grid:
		draw_grid(Global.grid_type)


func draw_grid(grid_type : int) -> void:
	var size : Vector2 = Global.transparent_checker.rect_size
	if grid_type == Global.Grid_Types.CARTESIAN || grid_type == Global.Grid_Types.ALL:
		for x in range(Global.grid_width, size.x, Global.grid_width):
			draw_line(Vector2(x, location.y), Vector2(x, size.y), Global.grid_color, true)

		for y in range(Global.grid_height, size.y, Global.grid_height):
			draw_line(Vector2(location.x, y), Vector2(size.x, y), Global.grid_color, true)

	if grid_type == Global.Grid_Types.ISOMETRIC || grid_type == Global.Grid_Types.ALL:
		var i := 0
		for x in range(Global.grid_isometric_cell_size, size.x + 2, Global.grid_isometric_cell_size * 2):
			for y in range(0, size.y + 1, Global.grid_isometric_cell_size):
				draw_isometric_tile(i, Vector2(x, y))
				i += 1


func draw_isometric_tile(i : int, origin := Vector2.RIGHT, cell_size : int = Global.grid_isometric_cell_size) -> void:
	# A random value I found by trial and error, I have no idea why it "works"
	var diff = 1.11754
	var approx_30_degrees = deg2rad(26.565)

	var pool := PoolVector2Array()
	if i < isometric_polylines.size():
		pool = isometric_polylines[i]
	else:
		var a = origin - Vector2(0, 0.5)
		var b = a + Vector2(cos(approx_30_degrees), sin(approx_30_degrees)) * cell_size * diff
		var c = a + Vector2.DOWN * cell_size
		var d = c - Vector2(cos(approx_30_degrees), sin(approx_30_degrees)) * cell_size * diff
		pool.append(a)
		pool.append(b)
		pool.append(c)
		pool.append(d)
		pool.append(a)
		isometric_polylines.append(pool)

	if pool.size() > 2:
		draw_polyline(pool, Global.grid_color)
