extends BaseSelectionTool

var _last_position := Vector2.INF
var _draw_points: Array[Vector2i] = []


func draw_start(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super.draw_start(pos)
	if !_move:
		_draw_points.append(pos)
		_last_position = pos


func draw_move(pos_i: Vector2i) -> void:
	if selection_node.arrow_key_move:
		return
	var pos := _get_stabilized_position(pos_i)
	pos = snap_position(pos)
	super.draw_move(pos)
	if !_move:
		append_gap(_last_position, pos)
		_last_position = pos
		_draw_points.append(Vector2i(pos))
		_offset = pos


func draw_end(pos: Vector2i) -> void:
	if selection_node.arrow_key_move:
		return
	pos = snap_position(pos)
	super.draw_end(pos)


func draw_preview() -> void:
	if _last_position != Vector2.INF and !_move:
		var canvas: Node2D = Global.canvas.previews
		var pos := canvas.position
		var canvas_scale := canvas.scale
		if Global.mirror_view:
			pos.x = pos.x + Global.current_project.size.x
			canvas_scale.x = -1
		canvas.draw_set_transform(pos, canvas.rotation, canvas_scale)
		var indicator := _fill_bitmap_with_points(_draw_points, Global.current_project.size)

		for line in _create_polylines(indicator):
			canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)

		# Handle mirroring
		if Tools.horizontal_mirror:
			for line in _create_polylines(
				_fill_bitmap_with_points(
					mirror_array(_draw_points, true, false), Global.current_project.size
				)
			):
				canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)
			if Tools.vertical_mirror:
				for line in _create_polylines(
					_fill_bitmap_with_points(
						mirror_array(_draw_points, true, true), Global.current_project.size
					)
				):
					canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)
		if Tools.vertical_mirror:
			for line in _create_polylines(
				_fill_bitmap_with_points(
					mirror_array(_draw_points, false, true), Global.current_project.size
				)
			):
				canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)

		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func apply_selection(_position) -> void:
	super.apply_selection(_position)
	var project := Global.current_project
	var cleared := false
	var previous_selection_map := SelectionMap.new()  # Used for intersect
	previous_selection_map.copy_from(project.selection_map)
	if !_add and !_subtract and !_intersect:
		cleared = true
		Global.canvas.selection.clear_selection()
	if _draw_points.size() > 3:
		if _intersect:
			project.selection_map.clear()
		lasso_selection(project.selection_map, previous_selection_map, _draw_points)

		# Handle mirroring
		if Tools.horizontal_mirror:
			var mirror_x := mirror_array(_draw_points, true, false)
			lasso_selection(project.selection_map, previous_selection_map, mirror_x)
			if Tools.vertical_mirror:
				var mirror_xy := mirror_array(_draw_points, true, true)
				lasso_selection(project.selection_map, previous_selection_map, mirror_xy)
		if Tools.vertical_mirror:
			var mirror_y := mirror_array(_draw_points, false, true)
			lasso_selection(project.selection_map, previous_selection_map, mirror_y)

		Global.canvas.selection.big_bounding_rectangle = project.selection_map.get_used_rect()
	else:
		if !cleared:
			Global.canvas.selection.clear_selection()

	Global.canvas.selection.commit_undo("Select", undo_data)
	_draw_points.clear()
	_last_position = Vector2.INF


func lasso_selection(
	selection_map: SelectionMap, previous_selection_map: SelectionMap, points: Array[Vector2i]
) -> void:
	var project := Global.current_project
	var selection_size := selection_map.get_size()
	for point in points:
		if point.x < 0 or point.y < 0 or point.x >= selection_size.x or point.y >= selection_size.y:
			continue
		if _intersect:
			if previous_selection_map.is_pixel_selected(point):
				selection_map.select_pixel(point, true)
		else:
			selection_map.select_pixel(point, !_subtract)

	var v := Vector2i()
	var image_size := project.size
	for x in image_size.x:
		v.x = x
		for y in image_size.y:
			v.y = y
			if Geometry2D.is_point_in_polygon(v, points):
				if _intersect:
					if previous_selection_map.is_pixel_selected(v):
						selection_map.select_pixel(v, true)
				else:
					selection_map.select_pixel(v, !_subtract)


# Bresenham's Algorithm
# Thanks to https://godotengine.org/qa/35276/tile-based-line-drawing-algorithm-efficiency
func append_gap(start: Vector2i, end: Vector2i) -> void:
	var dx := absi(end.x - start.x)
	var dy := -absi(end.y - start.y)
	var err := dx + dy
	var e2 := err << 1
	var sx := 1 if start.x < end.x else -1
	var sy := 1 if start.y < end.y else -1
	var x := start.x
	var y := start.y
	while !(x == end.x && y == end.y):
		e2 = err << 1
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
		_draw_points.append(Vector2i(x, y))


func mirror_array(array: Array[Vector2i], h: bool, v: bool) -> Array[Vector2i]:
	var new_array: Array[Vector2i] = []
	var project := Global.current_project
	for point in array:
		if h and v:
			new_array.append(
				Vector2i(project.x_symmetry_point - point.x, project.y_symmetry_point - point.y)
			)
		elif h:
			new_array.append(Vector2i(project.x_symmetry_point - point.x, point.y))
		elif v:
			new_array.append(Vector2i(point.x, project.y_symmetry_point - point.y))

	return new_array
