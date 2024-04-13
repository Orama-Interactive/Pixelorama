extends BaseSelectionTool

var _rect := Rect2i(0, 0, 0, 0)

var _square := false  ## Mouse Click + Shift
var _expand_from_center := false  ## Mouse Click + Ctrl
var _displace_origin = false  ## Mouse Click + Alt


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
		var canvas_scale := canvas.scale
		var temp_rect := _rect
		if Global.mirror_view:
			pos.x = pos.x + Global.current_project.size.x
			temp_rect.position.x = Global.current_project.size.x - temp_rect.position.x
			canvas_scale.x = -1

		var border := DrawingAlgos.get_ellipse_points_filled(Vector2.ZERO, temp_rect.size)
		var indicator := _fill_bitmap_with_points(border, temp_rect.size)

		canvas.draw_set_transform(temp_rect.position, canvas.rotation, canvas_scale)
		for line in _create_polylines(indicator):
			canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)

		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func apply_selection(_position: Vector2i) -> void:
	super.apply_selection(_position)
	var project := Global.current_project
	if !_add and !_subtract and !_intersect:
		Global.canvas.selection.clear_selection()
		if _rect.size == Vector2i.ZERO and Global.current_project.has_selection:
			Global.canvas.selection.commit_undo("Select", undo_data)
	if _rect.size == Vector2i.ZERO:
		return
	set_ellipse(project.selection_map, _rect.position)
	# Handle mirroring
	var mirror_positions := Tools.get_mirrored_positions(_rect.position, project, 1)
	var mirror_ends := Tools.get_mirrored_positions(_rect.end, project, 1)
	for i in mirror_positions.size():
		var mirror_rect := Rect2i()
		mirror_rect.position = mirror_positions[i]
		mirror_rect.end = mirror_ends[i]
		set_ellipse(project.selection_map, mirror_rect.abs().position)

	Global.canvas.selection.big_bounding_rectangle = project.selection_map.get_used_rect()
	Global.canvas.selection.commit_undo("Select", undo_data)


func set_ellipse(selection_map: SelectionMap, pos: Vector2i) -> void:
	var bitmap_size := selection_map.get_size()
	var previous_selection_map := SelectionMap.new()  # Used for intersect
	previous_selection_map.copy_from(selection_map)
	if _intersect:
		selection_map.clear()
	var points := DrawingAlgos.get_ellipse_points_filled(Vector2.ZERO, _rect.size)
	for p in points:
		var fill_p := pos + Vector2i(p)
		if fill_p.x < 0 or fill_p.y < 0 or fill_p.x >= bitmap_size.x or fill_p.y >= bitmap_size.y:
			continue
		if _intersect:
			if previous_selection_map.is_pixel_selected(fill_p):
				selection_map.select_pixel(fill_p, true)
		else:
			selection_map.select_pixel(fill_p, !_subtract)


# Given an origin point and destination point, returns a rect representing
# where the shape will be drawn and what is its size
func _get_result_rect(origin: Vector2i, dest: Vector2i) -> Rect2i:
	var rect := Rect2i()

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
