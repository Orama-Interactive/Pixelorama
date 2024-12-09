class_name BaseTool
extends VBoxContainer

var is_moving := false
var is_syncing := false
var kname: String
var tool_slot: Tools.Slot = null
var cursor_text := ""
var _cursor := Vector2i(Vector2.INF)
var _stabilizer_center := Vector2.ZERO

var _draw_cache: Array[Vector2i] = []  ## For storing already drawn pixels
@warning_ignore("unused_private_class_variable")
var _for_frame := 0  ## Cache for which frame

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
	if not is_syncing:  # If the tool isn't busy syncing with another tool.
		Tools.config_changed.emit(tool_slot.button, config)


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
	_stabilizer_center = pos
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
	var project := Global.current_project
	project.can_undo = true


func get_cell_position(pos: Vector2i) -> int:
	var tile_pos := 0
	if Global.current_project.get_current_cel() is not CelTileMap:
		return tile_pos
	var cel := Global.current_project.get_current_cel() as CelTileMap
	tile_pos = cel.get_cell_position(pos)
	return tile_pos


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
		pos = Tools.snap_to_rectangular_grid_boundary(
			pos, Global.grids[0].grid_size, Global.grids[0].grid_offset, snapping_distance
		)

	if Global.snap_to_rectangular_grid_center:
		pos = _snap_to_rectangular_grid_center(
			pos, Global.grids[0].grid_size, Global.grids[0].grid_offset, snapping_distance
		)

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


## Returns an array that mirrors each point of the [param array].
## An optional [param callable] can be passed, which gets called for each type of symmetry.
func mirror_array(array: Array[Vector2i], callable := func(_array): pass) -> Array[Vector2i]:
	var new_array: Array[Vector2i] = []
	var project := Global.current_project
	if Tools.horizontal_mirror and Tools.vertical_mirror:
		var hv_array: Array[Vector2i] = []
		for point in array:
			var mirror_x := Tools.calculate_mirror_horizontal(point, project)
			hv_array.append(Tools.calculate_mirror_vertical(mirror_x, project))
		if callable.is_valid():
			callable.call(hv_array)
		new_array += hv_array
	if Tools.horizontal_mirror:
		var h_array: Array[Vector2i] = []
		for point in array:
			h_array.append(Tools.calculate_mirror_horizontal(point, project))
		if callable.is_valid():
			callable.call(h_array)
		new_array += h_array
	if Tools.vertical_mirror:
		var v_array: Array[Vector2i] = []
		for point in array:
			v_array.append(Tools.calculate_mirror_vertical(point, project))
		if callable.is_valid():
			callable.call(v_array)
		new_array += v_array

	return new_array


func _snap_to_rectangular_grid_center(
	pos: Vector2, grid_size: Vector2i, grid_offset: Vector2i, snapping_distance: float
) -> Vector2:
	var grid_center := pos.snapped(grid_size) + Vector2(grid_size / 2)
	grid_center += Vector2(grid_offset)
	# keeping grid_center as is would have been fine but this adds extra accuracy as to
	# which snap point (from the list below) is closest to mouse and occupy THAT point
	# t_l is for "top left" and so on
	var t_l := grid_center + Vector2(-grid_size.x, -grid_size.y)
	var t_c := grid_center + Vector2(0, -grid_size.y)
	var t_r := grid_center + Vector2(grid_size.x, -grid_size.y)
	var m_l := grid_center + Vector2(-grid_size.x, 0)
	var m_c := grid_center
	var m_r := grid_center + Vector2(grid_size.x, 0)
	var b_l := grid_center + Vector2(-grid_size.x, grid_size.y)
	var b_c := grid_center + Vector2(0, grid_size.y)
	var b_r := grid_center + Vector2(grid_size)
	var vec_arr := [t_l, t_c, t_r, m_l, m_c, m_r, b_l, b_c, b_r]
	for vec in vec_arr:
		if vec.distance_to(pos) < grid_center.distance_to(pos):
			grid_center = vec
	if snapping_distance < 0:
		pos = grid_center.floor()
	else:
		if grid_center.distance_to(pos) <= snapping_distance:
			pos = grid_center.floor()
	return pos


func _snap_to_guide(
	snap_to: Vector2, pos: Vector2, distance: float, s1: Vector2, s2: Vector2
) -> Vector2:
	var closest_point := Tools.get_closest_point_to_segment(pos, distance, s1, s2)
	if closest_point == Vector2.INF:  # Is not close to a guide
		return Vector2.INF
	# Snap to the closest guide
	if snap_to == Vector2.INF or (snap_to - pos).length() > (closest_point - pos).length():
		snap_to = closest_point

	return snap_to


func _get_stabilized_position(normal_pos: Vector2) -> Vector2:
	if not Tools.stabilizer_enabled:
		return normal_pos
	var difference := normal_pos - _stabilizer_center
	var distance := difference.length() / Tools.stabilizer_value
	var angle := difference.angle()
	var pos := _stabilizer_center + Vector2(distance, distance) * Vector2.from_angle(angle)
	_stabilizer_center = pos
	return pos


func _get_draw_rect() -> Rect2i:
	if Global.current_project.has_selection:
		return Global.current_project.selection_map.get_used_rect()
	else:
		return Rect2i(Vector2i.ZERO, Global.current_project.size)


func _get_draw_image() -> ImageExtended:
	return Global.current_project.get_current_cel().get_image()


func _get_selected_draw_cels() -> Array[BaseCel]:
	var cels: Array[BaseCel]
	var project := Global.current_project
	for cel_index in project.selected_cels:
		var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
		if not cel is PixelCel:
			continue
		cels.append(cel)
	return cels


func _get_selected_draw_images() -> Array[ImageExtended]:
	var images: Array[ImageExtended] = []
	var project := Global.current_project
	for cel_index in project.selected_cels:
		var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
		if not cel is PixelCel:
			continue
		if project.layers[cel_index[1]].can_layer_get_drawn():
			images.append(cel.get_image())
	return images


func _pick_color(pos: Vector2i) -> void:
	var project := Global.current_project
	pos = project.tiles.get_canon_position(pos)

	if pos.x < 0 or pos.y < 0:
		return
	if Tools.is_placing_tiles():
		var cel := Global.current_project.get_current_cel() as CelTileMap
		Tools.selected_tile_index_changed.emit(cel.get_cell_index_at_coords(pos))
		return
	var image := Image.new()
	image.copy_from(_get_draw_image())
	if pos.x > image.get_width() - 1 or pos.y > image.get_height() - 1:
		return

	var color := Color(0, 0, 0, 0)
	var palette_index = -1
	var curr_frame: Frame = project.frames[project.current_frame]
	for layer in project.layers.size():
		var idx := (project.layers.size() - 1) - layer
		if project.layers[idx].is_visible_in_hierarchy():
			var cel := curr_frame.cels[idx]
			image = cel.get_image()
			color = image.get_pixelv(pos)
			# If image is indexed then get index as well
			if cel is PixelCel:
				if cel.image.is_indexed:
					palette_index = cel.image.indices_image.get_pixel(pos.x, pos.y).r8 - 1
			if not is_zero_approx(color.a) or palette_index > -1:
				break
	Tools.assign_color(color, tool_slot.button, false, palette_index)


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
	Global.canvas.previews_sprite.texture = null
	Global.canvas.indicators.queue_redraw()
