class_name BaseTool
extends VBoxContainer

var is_moving = false
var kname: String
var tool_slot: Tools.Slot = null
var cursor_text := ""
var _cursor := Vector2i(Vector2.INF)

var _draw_cache: Array[Vector2i] = []  ## For storing already drawn pixels
@warning_ignore("unused_private_class_variable") var _for_frame := 0  ## Cache for which frame

# Only use _spacing_mode and _spacing variables (the others are set automatically)
# The _spacing_mode and _spacing values are to be CHANGED only in the tool scripts (e.g Pencil.gd)
var _spacing_mode := false  ## Enables spacing (continuous gaps between two strokes)
var _spacing := Vector2i.ZERO  ## Spacing between two strokes
var _stroke_dimensions := Vector2i.ONE  ## 2D vector containing _brush_size from Draw.gd
var _spacing_offset := Vector2i.ZERO  ## The initial error between position and position.snapped()
@onready var color_rect := $ColorRect as ColorRect


func _ready() -> void:
	kname = name.replace(" ", "_").to_lower()
	if tool_slot.name == "Left tool":
		color_rect.color = Global.left_tool_color
	else:
		color_rect.color = Global.right_tool_color
	$Label.text = Tools.tools[name].display_name
	load_config()


func save_config() -> void:
	var config := get_config()
	Global.config_cache.set_value(tool_slot.kname, kname, config)


func load_config() -> void:
	var value = Global.config_cache.get_value(tool_slot.kname, kname, {})
	set_config(value)
	update_config()


func get_config() -> Dictionary:
	return {}


func set_config(_config: Dictionary) -> void:
	pass


func update_config() -> void:
	pass


func draw_start(pos: Vector2i) -> void:
	_draw_cache = []
	is_moving = true
	Global.current_project.can_undo = false
	_spacing_offset = _get_spacing_offset(pos)


func draw_move(pos: Vector2i) -> void:
	# This can happen if the user switches between tools with a shortcut
	# while using another tool
	if !is_moving:
		draw_start(pos)


func draw_end(_pos: Vector2i) -> void:
	is_moving = false
	_draw_cache = []
	Global.current_project.can_undo = true


func cursor_move(pos: Vector2i) -> void:
	_cursor = pos
	if _spacing_mode and is_moving:
		_cursor = get_spacing_position(pos)


func get_spacing_position(pos: Vector2i) -> Vector2i:
	# spacing_factor is the distance the mouse needs to get snapped by in order
	# to keep a space "_spacing" between two strokes of dimensions "_stroke_dimensions"
	var spacing_factor := _stroke_dimensions + _spacing
	var snap_pos := Vector2(pos.snapped(spacing_factor) + _spacing_offset)

	# keeping snap_pos as is would have been fine but this adds extra accuracy as to
	# which snap point (from the list below) is closest to mouse and occupy THAT point
	var t_l := snap_pos + Vector2(-spacing_factor.x, -spacing_factor.y)
	var t_c := snap_pos + Vector2(0, -spacing_factor.y)  # t_c is for "top centre" and so on...
	var t_r := snap_pos + Vector2(spacing_factor.x, -spacing_factor.y)
	var m_l := snap_pos + Vector2(-spacing_factor.x, 0)
	var m_c := snap_pos
	var m_r := snap_pos + Vector2(spacing_factor.x, 0)
	var b_l := snap_pos + Vector2(-spacing_factor.x, spacing_factor.y)
	var b_c := snap_pos + Vector2(0, spacing_factor.y)
	var b_r := snap_pos + Vector2(spacing_factor.x, spacing_factor.y)
	var vec_arr: PackedVector2Array = [t_l, t_c, t_r, m_l, m_c, m_r, b_l, b_c, b_r]
	for vec in vec_arr:
		if vec.distance_to(pos) < snap_pos.distance_to(pos):
			snap_pos = vec

	return Vector2i(snap_pos)


func _get_spacing_offset(pos: Vector2i) -> Vector2i:
	var spacing_factor := _stroke_dimensions + _spacing  # spacing_factor is explained above
	# since we just started drawing, the "position" is our intended location so the error
	# (_spacing_offset) is measured by subtracting both quantities
	return pos - pos.snapped(spacing_factor)


func draw_indicator(left: bool) -> void:
	var rect := Rect2(_cursor, Vector2.ONE)
	var color := Global.left_tool_color if left else Global.right_tool_color
	Global.canvas.indicators.draw_rect(rect, color, false)


func draw_preview() -> void:
	pass


func snap_position(pos: Vector2) -> Vector2:
	var snapping_distance := Global.snapping_distance / Global.camera.zoom.x
	if Global.snap_to_rectangular_grid_boundary:
		var grid_pos := pos.snapped(Global.grid_size)
		grid_pos += Vector2(Global.grid_offset)
		# keeping grid_pos as is would have been fine but this adds extra accuracy as to
		# which snap point (from the list below) is closest to mouse and occupy THAT point
		var t_l := grid_pos + Vector2(-Global.grid_size.x, -Global.grid_size.y)
		var t_c := grid_pos + Vector2(0, -Global.grid_size.y)  # t_c is for "top centre" and so on
		var t_r := grid_pos + Vector2(Global.grid_size.x, -Global.grid_size.y)
		var m_l := grid_pos + Vector2(-Global.grid_size.x, 0)
		var m_c := grid_pos
		var m_r := grid_pos + Vector2(Global.grid_size.x, 0)
		var b_l := grid_pos + Vector2(-Global.grid_size.x, Global.grid_size.y)
		var b_c := grid_pos + Vector2(0, Global.grid_size.y)
		var b_r := grid_pos + Vector2(Global.grid_size)
		var vec_arr: PackedVector2Array = [t_l, t_c, t_r, m_l, m_c, m_r, b_l, b_c, b_r]
		for vec in vec_arr:
			if vec.distance_to(pos) < grid_pos.distance_to(pos):
				grid_pos = vec

		var grid_point := _get_closest_point_to_grid(pos, snapping_distance, grid_pos)
		if grid_point != Vector2.INF:
			pos = grid_point.floor()

	if Global.snap_to_rectangular_grid_center:
		var grid_center := pos.snapped(Global.grid_size) + Vector2(Global.grid_size / 2)
		grid_center += Vector2(Global.grid_offset)
		# keeping grid_center as is would have been fine but this adds extra accuracy as to
		# which snap point (from the list below) is closest to mouse and occupy THAT point
		var t_l := grid_center + Vector2(-Global.grid_size.x, -Global.grid_size.y)
		var t_c := grid_center + Vector2(0, -Global.grid_size.y)  # t_c is for "top centre" and so on
		var t_r := grid_center + Vector2(Global.grid_size.x, -Global.grid_size.y)
		var m_l := grid_center + Vector2(-Global.grid_size.x, 0)
		var m_c := grid_center
		var m_r := grid_center + Vector2(Global.grid_size.x, 0)
		var b_l := grid_center + Vector2(-Global.grid_size.x, Global.grid_size.y)
		var b_c := grid_center + Vector2(0, Global.grid_size.y)
		var b_r := grid_center + Vector2(Global.grid_size)
		var vec_arr := [t_l, t_c, t_r, m_l, m_c, m_r, b_l, b_c, b_r]
		for vec in vec_arr:
			if vec.distance_to(pos) < grid_center.distance_to(pos):
				grid_center = vec
		if grid_center.distance_to(pos) <= snapping_distance:
			pos = grid_center.floor()

	var snap_to := Vector2.INF
	if Global.snap_to_guides:
		for guide in Global.current_project.guides:
			if guide is SymmetryGuide:
				continue
			var s1: Vector2 = guide.points[0]
			var s2: Vector2 = guide.points[1]
			var snap := _snap_to_guide(snap_to, pos, snapping_distance, s1, s2)
			if snap == Vector2.INF:
				continue
			snap_to = snap

	if Global.snap_to_perspective_guides:
		for point in Global.current_project.vanishing_points:
			if not (point.has("pos_x") and point.has("pos_y")):  # Sanity check
				continue
			for i in point.lines.size():
				if point.lines[i].has("angle") and point.lines[i].has("length"):  # Sanity check
					var angle := deg_to_rad(point.lines[i].angle)
					var length: float = point.lines[i].length
					var start := Vector2(point.pos_x, point.pos_y)
					var s1 := start
					var s2 := s1 + Vector2(length * cos(angle), length * sin(angle))
					var snap := _snap_to_guide(snap_to, pos, snapping_distance, s1, s2)
					if snap == Vector2.INF:
						continue
					snap_to = snap
	if snap_to != Vector2.INF:
		pos = snap_to.floor()

	return pos


func _get_closest_point_to_grid(pos: Vector2, distance: float, grid_pos: Vector2) -> Vector2:
	# If the cursor is close to the start/origin of a grid cell, snap to that
	var snap_distance := distance * Vector2.ONE
	var closest_point := Vector2.INF
	var rect := Rect2()
	rect.position = pos - (snap_distance / 4.0)
	rect.end = pos + (snap_distance / 4.0)
	if rect.has_point(grid_pos):
		closest_point = grid_pos
		return closest_point
	# If the cursor is far from the grid cell origin but still close to a grid line
	# Look for a point close to a horizontal grid line
	var grid_start_hor := Vector2(0, grid_pos.y)
	var grid_end_hor := Vector2(Global.current_project.size.x, grid_pos.y)
	var closest_point_hor := _get_closest_point_to_segment(
		pos, distance, grid_start_hor, grid_end_hor
	)
	# Look for a point close to a vertical grid line
	var grid_start_ver := Vector2(grid_pos.x, 0)
	var grid_end_ver := Vector2(grid_pos.x, Global.current_project.size.y)
	var closest_point_ver := _get_closest_point_to_segment(
		pos, distance, grid_start_ver, grid_end_ver
	)
	# Snap to the closest point to the closest grid line
	var horizontal_distance := (closest_point_hor - pos).length()
	var vertical_distance := (closest_point_ver - pos).length()
	if horizontal_distance < vertical_distance:
		closest_point = closest_point_hor
	elif horizontal_distance > vertical_distance:
		closest_point = closest_point_ver
	elif horizontal_distance == vertical_distance and closest_point_hor != Vector2.INF:
		closest_point = grid_pos
	return closest_point


func _get_closest_point_to_segment(
	pos: Vector2, distance: float, s1: Vector2, s2: Vector2
) -> Vector2:
	var test_line := (s2 - s1).rotated(deg_to_rad(90)).normalized()
	var from_a := pos - test_line * distance
	var from_b := pos + test_line * distance
	var closest_point := Vector2.INF
	if Geometry2D.segment_intersects_segment(from_a, from_b, s1, s2):
		closest_point = Geometry2D.get_closest_point_to_segment(pos, s1, s2)
	return closest_point


func _snap_to_guide(
	snap_to: Vector2, pos: Vector2, distance: float, s1: Vector2, s2: Vector2
) -> Vector2:
	var closest_point := _get_closest_point_to_segment(pos, distance, s1, s2)
	if closest_point == Vector2.INF:  # Is not close to a guide
		return Vector2.INF
	# Snap to the closest guide
	if snap_to == Vector2.INF or (snap_to - pos).length() > (closest_point - pos).length():
		snap_to = closest_point

	return snap_to


func _get_draw_rect() -> Rect2i:
	if Global.current_project.has_selection:
		return Global.current_project.selection_map.get_used_rect()
	else:
		return Rect2i(Vector2i.ZERO, Global.current_project.size)


func _get_draw_image() -> Image:
	return Global.current_project.get_current_cel().get_image()


func _get_selected_draw_images() -> Array[Image]:
	var images: Array[Image] = []
	var project := Global.current_project
	for cel_index in project.selected_cels:
		var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
		if not cel is PixelCel:
			continue
		if project.layers[cel_index[1]].can_layer_get_drawn():
			images.append(cel.get_image())
	return images


func _flip_rect(rect: Rect2, rect_size: Vector2, horiz: bool, vert: bool) -> Rect2:
	var result := rect
	if horiz:
		result.position.x = rect_size.x - rect.end.x
		result.end.x = rect_size.x - rect.position.x
	if vert:
		result.position.y = rect_size.y - rect.end.y
		result.end.y = rect_size.y - rect.position.y
	return result.abs()


func _create_polylines(bitmap: BitMap) -> Array:
	var lines := []
	var bitmap_size := bitmap.get_size()
	for y in bitmap_size.y:
		for x in bitmap_size.x:
			var p := Vector2i(x, y)
			if not bitmap.get_bitv(p):
				continue
			if x <= 0 or not bitmap.get_bitv(p - Vector2i(1, 0)):
				_add_polylines_segment(lines, p, p + Vector2i(0, 1))
			if y <= 0 or not bitmap.get_bitv(p - Vector2i(0, 1)):
				_add_polylines_segment(lines, p, p + Vector2i(1, 0))
			if x + 1 >= bitmap_size.x or not bitmap.get_bitv(p + Vector2i(1, 0)):
				_add_polylines_segment(lines, p + Vector2i(1, 0), p + Vector2i(1, 1))
			if y + 1 >= bitmap_size.y or not bitmap.get_bitv(p + Vector2i(0, 1)):
				_add_polylines_segment(lines, p + Vector2i(0, 1), p + Vector2i(1, 1))
	return lines


func _fill_bitmap_with_points(points: Array[Vector2i], bitmap_size: Vector2i) -> BitMap:
	var bitmap := BitMap.new()
	bitmap.create(bitmap_size)

	for point in points:
		if point.x < 0 or point.y < 0 or point.x >= bitmap_size.x or point.y >= bitmap_size.y:
			continue
		bitmap.set_bitv(point, 1)

	return bitmap


func _add_polylines_segment(lines: Array, start: Vector2i, end: Vector2i) -> void:
	for line in lines:
		if line[0] == start:
			line.insert(0, end)
			return
		if line[0] == end:
			line.insert(0, start)
			return
		if line[line.size() - 1] == start:
			line.append(end)
			return
		if line[line.size() - 1] == end:
			line.append(start)
			return
	lines.append([start, end])


func _exit_tree() -> void:
	if is_moving:
		draw_end(Global.canvas.current_pixel.floor())
