extends BaseSelectionTool

var _last_position := Vector2i(Vector2.INF)
var _draw_points: Array[Vector2i] = []
var _ready_to_apply := false


func _input(event: InputEvent) -> void:
	if _move:
		return
	if event is InputEventMouseMotion:
		_last_position = Global.canvas.current_pixel.floor()
		if Global.mirror_view:
			_last_position.x = (Global.current_project.size.x - 1) - _last_position.x
	elif event is InputEventMouseButton:
		if event.double_click and event.button_index == tool_slot.button and _draw_points:
			$DoubleClickTimer.start()
			append_gap(_draw_points[-1], _draw_points[0], _draw_points)
			_ready_to_apply = true
			apply_selection(Vector2i.ZERO)  # Argument doesn't matter
	else:
		if event.is_action_pressed("transformation_cancel") and _ongoing_selection:
			_ongoing_selection = false
			_draw_points.clear()
			_ready_to_apply = false
			Global.canvas.previews.queue_redraw()


func draw_start(pos: Vector2i) -> void:
	if !$DoubleClickTimer.is_stopped():
		return
	pos = snap_position(pos)
	super.draw_start(pos)
	if !_move and !_draw_points:
		_ongoing_selection = true
		_draw_points.append(pos)
		_last_position = pos


func draw_move(pos: Vector2i) -> void:
	if selection_node.arrow_key_move:
		return
	pos = snap_position(pos)
	super.draw_move(pos)


func draw_end(pos: Vector2i) -> void:
	if selection_node.arrow_key_move:
		return
	pos = snap_position(pos)
	if !_move and _draw_points:
		append_gap(_draw_points[-1], pos, _draw_points)
		if pos == _draw_points[0] and _draw_points.size() > 1:
			_ready_to_apply = true

	super.draw_end(pos)


func draw_preview() -> void:
	if _ongoing_selection and !_move:
		var canvas: Node2D = Global.canvas.previews
		var pos := canvas.position
		var canvas_scale := canvas.scale
		if Global.mirror_view:
			pos.x = pos.x + Global.current_project.size.x
			canvas_scale.x = -1

		var preview_draw_points := _draw_points.duplicate()
		append_gap(_draw_points[-1], _last_position, preview_draw_points)

		canvas.draw_set_transform(pos, canvas.rotation, canvas_scale)
		var indicator := _fill_bitmap_with_points(preview_draw_points, Global.current_project.size)

		for line in _create_polylines(indicator):
			canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)

		var circle_radius := Global.camera.zoom * 10
		circle_radius.x = clampf(circle_radius.x, 2, circle_radius.x)
		circle_radius.y = clampf(circle_radius.y, 2, circle_radius.y)

		if _last_position == _draw_points[0] and _draw_points.size() > 1:
			draw_empty_circle(
				canvas, Vector2(_draw_points[0]) + Vector2.ONE * 0.5, circle_radius, Color.BLACK
			)

		# Handle mirroring
		if Tools.horizontal_mirror:
			for line in _create_polylines(
				_fill_bitmap_with_points(
					mirror_array(preview_draw_points, true, false), Global.current_project.size
				)
			):
				canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)
			if Tools.vertical_mirror:
				for line in _create_polylines(
					_fill_bitmap_with_points(
						mirror_array(preview_draw_points, true, true), Global.current_project.size
					)
				):
					canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)
		if Tools.vertical_mirror:
			for line in _create_polylines(
				_fill_bitmap_with_points(
					mirror_array(preview_draw_points, false, true), Global.current_project.size
				)
			):
				canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)

		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func apply_selection(pos: Vector2i) -> void:
	super.apply_selection(pos)
	if !_ready_to_apply:
		return
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
	_ongoing_selection = false
	_draw_points.clear()
	_ready_to_apply = false
	Global.canvas.previews.queue_redraw()


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
func append_gap(start: Vector2i, end: Vector2i, array: Array[Vector2i]) -> void:
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
		array.append(Vector2i(x, y))


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


# Thanks to
# https://www.reddit.com/r/godot/comments/3ktq39/drawing_empty_circles_and_curves/cv0f4eo/
func draw_empty_circle(
	canvas: CanvasItem, circle_center: Vector2, circle_radius: Vector2, color: Color
) -> void:
	var draw_counter := 1
	var line_origin := Vector2()
	var line_end := Vector2()
	line_origin = circle_radius + circle_center

	while draw_counter <= 360:
		line_end = circle_radius.rotated(deg_to_rad(draw_counter)) + circle_center
		canvas.draw_line(line_origin, line_end, color)
		draw_counter += 1
		line_origin = line_end

	line_end = circle_radius.rotated(deg_to_rad(360)) + circle_center
	canvas.draw_line(line_origin, line_end, color)
