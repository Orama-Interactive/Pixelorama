class_name BaseTool
extends VBoxContainer

var is_moving = false
var kname: String
var tool_slot = null  # Tools.Slot, can't have static typing due to cyclic errors
var cursor_text := ""
var _cursor := Vector2.INF

var _draw_cache: PoolVector2Array = []  # for storing already drawn pixels
var _for_frame := 0  # cache for which frame?

var _snap_mode := false
var _snap_vector := Vector2.ONE
var _snap_offset := Vector2.ZERO
var _stroke_gap := Vector2.ZERO
onready var color_rect: ColorRect = $ColorRect


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


func draw_start(position: Vector2) -> void:
	_draw_cache = []
	is_moving = true
	Global.current_project.can_undo = false
	_snap_offset = _get_snapped_offset(position)


func draw_move(position: Vector2) -> void:
	# This can happen if the user switches between tools with a shortcut
	# while using another tool
	if !is_moving:
		draw_start(position)


func draw_end(_position: Vector2) -> void:
	is_moving = false
	_draw_cache = []
	Global.current_project.can_undo = true


func cursor_move(position: Vector2) -> void:
	_cursor = position
	if _snap_mode and is_moving:
		_cursor = get_snapped_position(position)


func get_snapped_position(position: Vector2) -> Vector2:
	var snap_factor = _snap_vector + _stroke_gap
	var snap_position = position.snapped(snap_factor) + _snap_offset
	var t_c = snap_position + Vector2(0, -snap_factor.y)
	var t_r = snap_position + Vector2(snap_factor.x, -snap_factor.y)
	var t_r_r = snap_position + Vector2(2 * snap_factor.x, -snap_factor.y)
	var m_c = snap_position
	var m_r = snap_position + Vector2(snap_factor.x, 0)
	var m_r_r = snap_position + Vector2(2 * snap_factor.x, 0)
	var b_c = snap_position + Vector2(0, snap_factor.y)
	var b_r = snap_position + Vector2(snap_factor.x, snap_factor.y)
	var b_r_r = snap_position + Vector2(2 * snap_factor.x, snap_factor.y)
	var vec_arr := [t_c, t_r, t_r_r, m_c, m_r, m_r_r, b_c, b_r, b_r_r]
	for vec in vec_arr:
		if vec.distance_to(position) < snap_position.distance_to(position):
			snap_position = vec
	return snap_position


func _get_snapped_offset(position: Vector2) -> Vector2:
	return position - position.snapped(_snap_vector + _stroke_gap)


func draw_indicator(left: bool) -> void:
	var rect := Rect2(_cursor, Vector2.ONE)
	var color := Global.left_tool_color if left else Global.right_tool_color
	Global.canvas.indicators.draw_rect(rect, color, false)


func draw_preview() -> void:
	pass


func snap_position(position: Vector2) -> Vector2:
	var snap_distance := Global.snapping_distance * Vector2.ONE
	if Global.snap_to_rectangular_grid:
		var grid_size := Vector2(Global.grid_width, Global.grid_height)
		var grid_offset := Vector2(Global.grid_offset_x, Global.grid_offset_y)
		var grid_pos := position.snapped(grid_size)
		grid_pos += grid_offset
		var closest_point_grid := _get_closest_point_to_grid(position, snap_distance, grid_pos)
		if closest_point_grid != Vector2.INF:
			position = closest_point_grid.floor()

	if Global.snap_to_guides:
		var snap_to := Vector2.INF
		for guide in Global.current_project.guides:
			if guide is SymmetryGuide:
				continue
			var closest_point := _get_closest_point_to_segment(
				position, snap_distance, guide.points[0], guide.points[1]
			)
			if closest_point == Vector2.INF:  # Is not close to a guide
				continue
			# Snap to the closest guide
			if (
				snap_to == Vector2.INF
				or (snap_to - position).length() > (closest_point - position).length()
			):
				snap_to = closest_point
		if snap_to != Vector2.INF:
			position = snap_to.floor()
	return position


func _get_closest_point_to_grid(
	position: Vector2, snap_distance: Vector2, grid_pos: Vector2
) -> Vector2:
	# If the cursor is close to the start/origin of a grid cell, snap to that
	var closest_point := Vector2.INF
	var rect := Rect2()
	rect.position = position - (snap_distance / 4.0)
	rect.end = position + (snap_distance / 4.0)
	if rect.has_point(grid_pos):
		closest_point = grid_pos
		return closest_point
	# If the cursor is far from the grid cell origin but still close to a grid line
	# Look for a point close to a horizontal grid line
	var grid_start_hor := Vector2(0, grid_pos.y)
	var grid_end_hor := Vector2(Global.current_project.size.x, grid_pos.y)
	var closest_point_hor := _get_closest_point_to_segment(
		position, snap_distance, grid_start_hor, grid_end_hor
	)
	# Look for a point close to a vertical grid line
	var grid_start_ver := Vector2(grid_pos.x, 0)
	var grid_end_ver := Vector2(grid_pos.x, Global.current_project.size.y)
	var closest_point_ver := _get_closest_point_to_segment(
		position, snap_distance, grid_start_ver, grid_end_ver
	)
	# Snap to the closest point to the closest grid line
	var horizontal_distance := (closest_point_hor - position).length()
	var vertical_distance := (closest_point_ver - position).length()
	if horizontal_distance < vertical_distance:
		closest_point = closest_point_hor
	elif horizontal_distance > vertical_distance:
		closest_point = closest_point_ver
	elif horizontal_distance == vertical_distance and closest_point_hor != Vector2.INF:
		closest_point = grid_pos
	return closest_point


func _get_closest_point_to_segment(
	position: Vector2, distance: Vector2, s1: Vector2, s2: Vector2
) -> Vector2:
	var closest_point := Vector2.INF
	if Geometry.segment_intersects_segment_2d(position - distance, position + distance, s1, s2):
		closest_point = Geometry.get_closest_point_to_segment_2d(position, s1, s2)
	return closest_point


func _get_draw_rect() -> Rect2:
	if Global.current_project.has_selection:
		return Global.current_project.selection_map.get_used_rect()
	else:
		return Rect2(Vector2.ZERO, Global.current_project.size)


func _get_draw_image() -> Image:
	return Global.current_project.get_current_cel().get_image()


func _get_selected_draw_images() -> Array:  # Array of Images
	var images := []
	var project: Project = Global.current_project
	for cel_index in project.selected_cels:
		var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
		if project.layers[cel_index[1]].can_layer_get_drawn():
			images.append(cel.image)
	return images


func _flip_rect(rect: Rect2, size: Vector2, horizontal: bool, vertical: bool) -> Rect2:
	var result := rect
	if horizontal:
		result.position.x = size.x - rect.end.x
		result.end.x = size.x - rect.position.x
	if vertical:
		result.position.y = size.y - rect.end.y
		result.end.y = size.y - rect.position.y
	return result.abs()


func _create_polylines(bitmap: BitMap) -> Array:
	var lines := []
	var size := bitmap.get_size()
	for y in size.y:
		for x in size.x:
			var p := Vector2(x, y)
			if not bitmap.get_bit(p):
				continue
			if x <= 0 or not bitmap.get_bit(p - Vector2(1, 0)):
				_add_polylines_segment(lines, p, p + Vector2(0, 1))
			if y <= 0 or not bitmap.get_bit(p - Vector2(0, 1)):
				_add_polylines_segment(lines, p, p + Vector2(1, 0))
			if x + 1 >= size.x or not bitmap.get_bit(p + Vector2(1, 0)):
				_add_polylines_segment(lines, p + Vector2(1, 0), p + Vector2(1, 1))
			if y + 1 >= size.y or not bitmap.get_bit(p + Vector2(0, 1)):
				_add_polylines_segment(lines, p + Vector2(0, 1), p + Vector2(1, 1))
	return lines


func _fill_bitmap_with_points(points: Array, size: Vector2) -> BitMap:
	var bitmap := BitMap.new()
	bitmap.create(size)

	for point in points:
		if point.x < 0 or point.y < 0 or point.x >= size.x or point.y >= size.y:
			continue
		bitmap.set_bit(point, 1)

	return bitmap


func _add_polylines_segment(lines: Array, start: Vector2, end: Vector2) -> void:
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
