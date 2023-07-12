extends SelectionTool

var _rect := Rect2i(0, 0, 0, 0)

var _square := false  # Mouse Click + Shift
var _expand_from_center := false  # Mouse Click + Ctrl
var _displace_origin = false  # Mouse Click + Alt


func _input(event: InputEvent) -> void:
	if !_move and _rect.has_area():
		if event.is_action_pressed("shape_perfect"):
			_square = true
		elif event.is_action_released("shape_perfect"):
			_square = false
		if event.is_action_pressed("shape_center"):
			_expand_from_center = true
		elif event.is_action_released("shape_center"):
			_expand_from_center = false
		if event.is_action_pressed("shape_displace"):
			_displace_origin = true
		elif event.is_action_released("shape_displace"):
			_displace_origin = false


func draw_move(pos: Vector2i) -> void:
	if selection_node.arrow_key_move:
		return
	pos = snap_position(pos)
	super.draw_move(pos)
	if !_move:
		if _displace_origin:
			_start_pos += pos - _offset
		_rect = _get_result_rect(_start_pos, pos)
		_set_cursor_text(_rect)
		_offset = pos


func draw_end(pos: Vector2i) -> void:
	if selection_node.arrow_key_move:
		return
	pos = snap_position(pos)
	super.draw_end(pos)
	_rect = Rect2i(0, 0, 0, 0)
	_square = false
	_expand_from_center = false
	_displace_origin = false


func draw_preview() -> void:
	if !_move && _rect.has_area():
		var canvas: Node2D = Global.canvas.previews
		var pos := canvas.position
		var _scale := canvas.scale
		var temp_rect := _rect
		if Global.mirror_view:
			pos.x = pos.x + Global.current_project.size.x
			temp_rect.position.x = Global.current_project.size.x - temp_rect.position.x
			_scale.x = -1

		var border := DrawingAlgos.get_ellipse_points_filled(Vector2.ZERO, temp_rect.size)
		var indicator := _fill_bitmap_with_points(border, temp_rect.size)

		canvas.draw_set_transform(temp_rect.position, canvas.rotation, _scale)
		for line in _create_polylines(indicator):
			canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)

		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func apply_selection(_position: Vector2i) -> void:
	super.apply_selection(_position)
	var project: Project = Global.current_project
	if !_add and !_subtract and !_intersect:
		Global.canvas.selection.clear_selection()
		if _rect.size == Vector2i.ZERO and Global.current_project.has_selection:
			Global.canvas.selection.commit_undo("Select", undo_data)

	if _rect.size != Vector2i.ZERO:
		var selection_map_copy := SelectionMap.new()
		selection_map_copy.copy_from(project.selection_map)
		set_ellipse(selection_map_copy, _rect.position)

		# Handle mirroring
		if Tools.horizontal_mirror:
			var mirror_x_rect := _rect
			mirror_x_rect.position.x = (
				Global.current_project.x_symmetry_point - _rect.position.x + 1
			)
			mirror_x_rect.end.x = Global.current_project.x_symmetry_point - _rect.end.x + 1
			set_ellipse(selection_map_copy, mirror_x_rect.abs().position)
			if Tools.vertical_mirror:
				var mirror_xy_rect := mirror_x_rect
				mirror_xy_rect.position.y = (
					Global.current_project.y_symmetry_point - _rect.position.y + 1
				)
				mirror_xy_rect.end.y = Global.current_project.y_symmetry_point - _rect.end.y + 1
				set_ellipse(selection_map_copy, mirror_xy_rect.abs().position)
		if Tools.vertical_mirror:
			var mirror_y_rect := _rect
			mirror_y_rect.position.y = (
				Global.current_project.y_symmetry_point - _rect.position.y + 1
			)
			mirror_y_rect.end.y = Global.current_project.y_symmetry_point - _rect.end.y + 1
			set_ellipse(selection_map_copy, mirror_y_rect.abs().position)

		project.selection_map = selection_map_copy
		Global.canvas.selection.big_bounding_rectangle = project.selection_map.get_used_rect()
		Global.canvas.selection.commit_undo("Select", undo_data)


func set_ellipse(selection_map: SelectionMap, pos: Vector2i) -> void:
	var project: Project = Global.current_project
	var bitmap_size := selection_map.get_size()
	if _intersect:
		selection_map.clear()
	var points := DrawingAlgos.get_ellipse_points_filled(Vector2.ZERO, _rect.size)
	for p in points:
		var _pos := pos + Vector2i(p)
		if _pos.x < 0 or _pos.y < 0 or _pos.x >= bitmap_size.x or _pos.y >= bitmap_size.y:
			continue
		if _intersect:
			if project.selection_map.is_pixel_selected(_pos):
				selection_map.select_pixel(_pos, true)
		else:
			selection_map.select_pixel(_pos, !_subtract)


# Given an origin point and destination point, returns a rect representing
# where the shape will be drawn and what is its size
func _get_result_rect(origin: Vector2i, dest: Vector2i) -> Rect2i:
	var rect := Rect2i(Vector2i.ZERO, Vector2i.ZERO)

	# Center the rect on the mouse
	if _expand_from_center:
		var new_size := dest - origin
		# Make rect 1:1 while centering it on the mouse
		if _square:
			var square_size := maxi(absi(new_size.x), absi(new_size.y))
			new_size = Vector2i(square_size, square_size)

		origin -= new_size
		dest = origin + 2 * new_size

	# Make rect 1:1 while not trying to center it
	if _square:
		var square_size := mini(absi(origin.x - dest.x), absi(origin.y - dest.y))
		rect.position.x = origin.x if origin.x < dest.x else origin.x - square_size
		rect.position.y = origin.y if origin.y < dest.y else origin.y - square_size
		rect.size = Vector2i(square_size, square_size)
	# Get the rect without any modifications
	else:
		rect.position = Vector2i(mini(origin.x, dest.x), mini(origin.y, dest.y))
		rect.size = (origin - dest).abs()

	rect.size += Vector2i.ONE

	return rect
