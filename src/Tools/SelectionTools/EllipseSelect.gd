extends SelectionTool


var _rect := Rect2(0, 0, 0, 0)

var _square := false # Mouse Click + Shift
var _expand_from_center := false # Mouse Click + Ctrl
var _displace_origin = false # Mouse Click + Alt


func _input(event : InputEvent) -> void:
	._input(event)
	if !_move and !_rect.has_no_area():
		if event.is_action_pressed("shift"):
			_square = true
		elif event.is_action_released("shift"):
			_square = false
		if event.is_action_pressed("ctrl"):
			_expand_from_center = true
		elif event.is_action_released("ctrl"):
			_expand_from_center = false
		if event.is_action_pressed("alt"):
			_displace_origin = true
		elif event.is_action_released("alt"):
			_displace_origin = false


func draw_move(position : Vector2) -> void:
	if selection_node.arrow_key_move:
		return
	.draw_move(position)
	if !_move:
		if _displace_origin:
			_start_pos += position - _offset
		_rect = _get_result_rect(_start_pos, position)
		_set_cursor_text(_rect)
		_offset = position


func draw_end(position : Vector2) -> void:
	if selection_node.arrow_key_move:
		return
	.draw_end(position)
	_rect = Rect2(0, 0, 0, 0)
	_square = false
	_expand_from_center = false
	_displace_origin = false


func draw_preview() -> void:
	if !_move && !_rect.has_no_area():
		var canvas : Node2D = Global.canvas.previews
		var _position := canvas.position
		var _scale := canvas.scale
		if Global.mirror_view:
			_position.x = _position.x + Global.current_project.size.x
			_scale.x = -1

		var border := _get_shape_points_filled(_rect.size)
		var indicator := _fill_bitmap_with_points(border, _rect.size)

		canvas.draw_set_transform(_rect.position, canvas.rotation, _scale)
		for line in _create_polylines(indicator):
			canvas.draw_polyline(PoolVector2Array(line), Color.black)

		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func apply_selection(_position : Vector2) -> void:
	var project : Project = Global.current_project
	if !_add and !_subtract and !_intersect:
		Global.canvas.selection.clear_selection()
		if _rect.size == Vector2.ZERO and Global.current_project.has_selection:
			Global.canvas.selection.commit_undo("Rectangle Select", undo_data)

	if _rect.size != Vector2.ZERO:
		var selection_bitmap_copy : BitMap = project.selection_bitmap.duplicate()
		set_ellipse(selection_bitmap_copy, _rect.position)
		# Handle mirroring
		if tool_slot.horizontal_mirror:
			var mirror_x_rect := _rect
			mirror_x_rect.position.x = Global.current_project.x_symmetry_point - _rect.position.x
			mirror_x_rect.end.x = Global.current_project.x_symmetry_point - _rect.end.x
			set_ellipse(selection_bitmap_copy, mirror_x_rect.abs().position)
			if tool_slot.vertical_mirror:
				var mirror_xy_rect := mirror_x_rect
				mirror_xy_rect.position.y = Global.current_project.y_symmetry_point - _rect.position.y
				mirror_xy_rect.end.y = Global.current_project.y_symmetry_point - _rect.end.y
				set_ellipse(selection_bitmap_copy, mirror_xy_rect.abs().position)
		if tool_slot.vertical_mirror:
			var mirror_y_rect := _rect
			mirror_y_rect.position.y = Global.current_project.y_symmetry_point - _rect.position.y
			mirror_y_rect.end.y = Global.current_project.y_symmetry_point - _rect.end.y
			set_ellipse(selection_bitmap_copy, mirror_y_rect.abs().position)

		project.selection_bitmap = selection_bitmap_copy
		Global.canvas.selection.big_bounding_rectangle = project.get_selection_rectangle(project.selection_bitmap)
		Global.canvas.selection.commit_undo("Rectangle Select", undo_data)


func set_ellipse(bitmap : BitMap, position : Vector2) -> void:
	var project : Project = Global.current_project
	var bitmap_size : Vector2 = bitmap.get_size()
	if _intersect:
		bitmap.set_bit_rect(Rect2(Vector2.ZERO, bitmap_size), false)
	var points := _get_shape_points_filled(_rect.size)
	for p in points:
		var pos : Vector2 = position + p
		if pos.x < 0 or pos.y < 0 or pos.x >= bitmap_size.x or pos.y >= bitmap_size.y:
			continue
		if _intersect:
			if project.selection_bitmap.get_bit(pos):
				bitmap.set_bit(pos, true)
		else:
			bitmap.set_bit(pos, !_subtract)


# Given an origin point and destination point, returns a rect representing where the shape will be drawn and what it's size
func _get_result_rect(origin: Vector2, dest: Vector2) -> Rect2:
	var rect := Rect2(Vector2.ZERO, Vector2.ZERO)

	# Center the rect on the mouse
	if _expand_from_center:
		var new_size := (dest - origin).floor()
		# Make rect 1:1 while centering it on the mouse
		if _square:
			var _square_size := max(abs(new_size.x), abs(new_size.y))
			new_size = Vector2(_square_size, _square_size)

		origin -= new_size
		dest = origin + 2 * new_size

	# Make rect 1:1 while not trying to center it
	if _square:
		var square_size := min(abs(origin.x - dest.x), abs(origin.y - dest.y))
		rect.position.x = origin.x if origin.x < dest.x else origin.x - square_size
		rect.position.y = origin.y if origin.y < dest.y else origin.y - square_size
		rect.size = Vector2(square_size, square_size)
	# Get the rect without any modifications
	else:
		rect.position = Vector2(min(origin.x, dest.x), min(origin.y, dest.y))
		rect.size = (origin - dest).abs()

	rect.size += Vector2.ONE

	return rect


func _get_shape_points_filled(size: Vector2) -> PoolVector2Array:
	var border := _get_ellipse_points(Vector2.ZERO, size)
	var filling := []
	var bitmap := _fill_bitmap_with_points(border, size)

	for x in range(1, ceil(size.x / 2)):
		var fill := false
		var prev_is_true := false
		for y in range(0, ceil(size.y / 2)):
			var top_l_p := Vector2(x, y)
			var bit := bitmap.get_bit(top_l_p)

			if bit and not fill:
				prev_is_true = true
				continue

			if not bit and (fill or prev_is_true):
				filling.append(top_l_p)
				filling.append(Vector2(x, size.y - y - 1))
				filling.append(Vector2(size.x - x - 1, y))
				filling.append(Vector2(size.x - x - 1, size.y - y - 1))

				if prev_is_true:
					fill = true
					prev_is_true = false
			elif bit and fill:
				break

	return PoolVector2Array(border + filling)


# Algorithm based on http://members.chello.at/easyfilter/bresenham.html
func _get_ellipse_points (pos: Vector2, size: Vector2) -> Array:
	var array := []
	var x0 := int(pos.x)
	var x1 := pos.x + int(size.x - 1)
	var y0 := int(pos.y)
	var y1 := int(pos.y) + int(size.y - 1)
	var a := int(abs(x1 - x0))
	var b := int(abs(y1 - x0))
	var b1 := b & 1
	var dx := 4*(1-a)*b*b
	var dy := 4*(b1+1)*a*a
	var err := dx+dy+b1*a*a
	var e2 := 0

	if x0 > x1:
		x0 = x1
		x1 += a

	if y0 > y1:
		y0 = y1

# warning-ignore:integer_division
	y0 += (b+1) / 2
	y1 = y0-b1
	a *= 8*a
	b1 = 8*b*b

	while x0 <= x1:
		var v1 := Vector2(x1, y0)
		var v2 := Vector2(x0, y0)
		var v3 := Vector2(x0, y1)
		var v4 := Vector2(x1, y1)
		array.append(v1)
		array.append(v2)
		array.append(v3)
		array.append(v4)

		e2 = 2*err;

		if e2 <= dy:
			y0 += 1
			y1 -= 1
			dy += a
			err += dy

		if e2 >= dx || 2*err > dy:
			x0+=1
			x1-=1
			dx += b1
			err += dx

	while y0-y1 < b:
		var v1 := Vector2(x0-1, y0)
		var v2 := Vector2(x1+1, y0)
		var v3 := Vector2(x0-1, y1)
		var v4 := Vector2(x1+1, y1)
		array.append(v1)
		array.append(v2)
		array.append(v3)
		array.append(v4)
		y0+=1
		y1-=1

	return array


func _fill_bitmap_with_points(points: Array, size: Vector2) -> BitMap:
	var bitmap := BitMap.new()
	bitmap.create(size)

	for point in points:
		bitmap.set_bit(point, 1)

	return bitmap
