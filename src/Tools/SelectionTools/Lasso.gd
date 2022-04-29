extends SelectionTool

var _last_position := Vector2.INF
var _draw_points := []


func draw_start(position: Vector2) -> void:
	.draw_start(position)
	if !_move:
		_draw_points.append(position)
		_last_position = position


func draw_move(position: Vector2) -> void:
	if selection_node.arrow_key_move:
		return
	.draw_move(position)
	if !_move:
		append_gap(_last_position, position)
		_last_position = position
		_draw_points.append(position)
		_offset = position


func draw_end(position: Vector2) -> void:
	if selection_node.arrow_key_move:
		return
	if !_move:
		_draw_points.append(position)
	.draw_end(position)


func draw_preview() -> void:
	if _last_position != Vector2.INF and !_move:
		var canvas: Node2D = Global.canvas.previews
		var position := canvas.position
		var scale := canvas.scale
		if Global.mirror_view:
			position.x = position.x + Global.current_project.size.x
			scale.x = -1
		canvas.draw_set_transform(position, canvas.rotation, scale)
		var indicator := _fill_bitmap_with_points(_draw_points, Global.current_project.size)

		for line in _create_polylines(indicator):
			canvas.draw_polyline(PoolVector2Array(line), Color.black)

		# Handle mirroring
		if Tools.horizontal_mirror:
			for line in _create_polylines(
				_fill_bitmap_with_points(
					mirror_array(_draw_points, true, false), Global.current_project.size
				)
			):
				canvas.draw_polyline(PoolVector2Array(line), Color.black)
			if Tools.vertical_mirror:
				for line in _create_polylines(
					_fill_bitmap_with_points(
						mirror_array(_draw_points, true, true), Global.current_project.size
					)
				):
					canvas.draw_polyline(PoolVector2Array(line), Color.black)
		if Tools.vertical_mirror:
			for line in _create_polylines(
				_fill_bitmap_with_points(
					mirror_array(_draw_points, false, true), Global.current_project.size
				)
			):
				canvas.draw_polyline(PoolVector2Array(line), Color.black)

		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func apply_selection(_position) -> void:
	var project: Project = Global.current_project
	var cleared := false
	if !_add and !_subtract and !_intersect:
		cleared = true
		Global.canvas.selection.clear_selection()
	if _draw_points.size() > 3:
		var selection_bitmap_copy: BitMap = project.selection_bitmap.duplicate()
		var bitmap_size: Vector2 = selection_bitmap_copy.get_size()
		if _intersect:
			selection_bitmap_copy.set_bit_rect(Rect2(Vector2.ZERO, bitmap_size), false)
		lasso_selection(selection_bitmap_copy, _draw_points)

		# Handle mirroring
		if Tools.horizontal_mirror:
			lasso_selection(selection_bitmap_copy, mirror_array(_draw_points, true, false))
			if Tools.vertical_mirror:
				lasso_selection(selection_bitmap_copy, mirror_array(_draw_points, true, true))
		if Tools.vertical_mirror:
			lasso_selection(selection_bitmap_copy, mirror_array(_draw_points, false, true))

		project.selection_bitmap = selection_bitmap_copy
		Global.canvas.selection.big_bounding_rectangle = project.get_selection_rectangle(
			project.selection_bitmap
		)
	else:
		if !cleared:
			Global.canvas.selection.clear_selection()

	Global.canvas.selection.commit_undo("Select", undo_data)
	_draw_points.clear()
	_last_position = Vector2.INF


func lasso_selection(bitmap: BitMap, points: PoolVector2Array) -> void:
	var project: Project = Global.current_project
	var size := bitmap.get_size()
	for point in points:
		if point.x < 0 or point.y < 0 or point.x >= size.x or point.y >= size.y:
			continue
		if _intersect:
			if project.selection_bitmap.get_bit(point):
				bitmap.set_bit(point, true)
		else:
			bitmap.set_bit(point, !_subtract)

	var v := Vector2()
	var image_size: Vector2 = project.size
	for x in image_size.x:
		v.x = x
		for y in image_size.y:
			v.y = y
			if Geometry.is_point_in_polygon(v, points):
				if _intersect:
					if project.selection_bitmap.get_bit(v):
						bitmap.set_bit(v, true)
				else:
					bitmap.set_bit(v, !_subtract)


# Bresenham's Algorithm
# Thanks to https://godotengine.org/qa/35276/tile-based-line-drawing-algorithm-efficiency
func append_gap(start: Vector2, end: Vector2) -> void:
	var dx := int(abs(end.x - start.x))
	var dy := int(-abs(end.y - start.y))
	var err := dx + dy
	var e2 := err << 1
	var sx = 1 if start.x < end.x else -1
	var sy = 1 if start.y < end.y else -1
	var x = start.x
	var y = start.y
	while !(x == end.x && y == end.y):
		e2 = err << 1
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
		_draw_points.append(Vector2(x, y))


func _fill_bitmap_with_points(points: Array, size: Vector2) -> BitMap:
	var bitmap := BitMap.new()
	bitmap.create(size)

	for point in points:
		if point.x < 0 or point.y < 0 or point.x >= size.x or point.y >= size.y:
			continue
		bitmap.set_bit(point, 1)

	return bitmap


func mirror_array(array: Array, h: bool, v: bool) -> Array:
	var new_array := []
	var project: Project = Global.current_project
	for point in array:
		if h and v:
			new_array.append(
				Vector2(project.x_symmetry_point - point.x, project.y_symmetry_point - point.y)
			)
		elif h:
			new_array.append(Vector2(project.x_symmetry_point - point.x, point.y))
		elif v:
			new_array.append(Vector2(point.x, project.y_symmetry_point - point.y))

	return new_array
