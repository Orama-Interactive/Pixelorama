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
	var canvas := Global.canvas.previews_sprite
	if _last_position != Vector2.INF and !_move:
		var image := Image.create(
			Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_LA8
		)
		for point in _draw_points:
			var draw_point := point
			if Global.mirror_view:  # This fixes previewing in mirror mode
				draw_point.x = image.get_width() - draw_point.x - 1
			if Rect2i(Vector2i.ZERO, image.get_size()).has_point(draw_point):
				image.set_pixelv(draw_point, Color.WHITE)

		# Handle mirroring
		for point in mirror_array(_draw_points):
			var draw_point := point
			if Global.mirror_view:  # This fixes previewing in mirror mode
				draw_point.x = image.get_width() - draw_point.x - 1
			if Rect2i(Vector2i.ZERO, image.get_size()).has_point(draw_point):
				image.set_pixelv(draw_point, Color.WHITE)
		var texture := ImageTexture.create_from_image(image)
		canvas.texture = texture


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
		lasso_selection(_draw_points, project, previous_selection_map)
		# Handle mirroring
		var callable := lasso_selection.bind(project, previous_selection_map)
		mirror_array(_draw_points, callable)
		Global.canvas.selection.big_bounding_rectangle = project.selection_map.get_used_rect()
	else:
		if !cleared:
			Global.canvas.selection.clear_selection()

	Global.canvas.selection.commit_undo("Select", undo_data)
	_draw_points.clear()
	_last_position = Vector2.INF
	Global.canvas.previews_sprite.texture = null


func lasso_selection(
	points: Array[Vector2i], project: Project, previous_selection_map: SelectionMap
) -> void:
	var selection_map := project.selection_map
	var selection_size := selection_map.get_size()
	var bounding_rect := Rect2i(points[0], Vector2i.ZERO)
	for point in points:
		if point.x < 0 or point.y < 0 or point.x >= selection_size.x or point.y >= selection_size.y:
			continue
		bounding_rect = bounding_rect.expand(point)
		if _intersect:
			if previous_selection_map.is_pixel_selected(point):
				select_pixel(point, project, true)
		else:
			select_pixel(point, project, !_subtract)

	var v := Vector2i()
	for x in bounding_rect.size.x:
		v.x = x + bounding_rect.position.x
		for y in bounding_rect.size.y:
			v.y = y + bounding_rect.position.y
			if Geometry2D.is_point_in_polygon(v, points):
				if _intersect:
					if previous_selection_map.is_pixel_selected(v):
						select_pixel(v, project, true)
				else:
					select_pixel(v, project, !_subtract)


func select_pixel(point: Vector2i, project: Project, select: bool) -> void:
	if Tools.is_placing_tiles():
		var tilemap := project.get_current_cel() as CelTileMap
		var cell_position := tilemap.get_cell_position(point)
		select_tilemap_cell(tilemap, cell_position, project.selection_map, select)
	project.selection_map.select_pixel(point, select)


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
