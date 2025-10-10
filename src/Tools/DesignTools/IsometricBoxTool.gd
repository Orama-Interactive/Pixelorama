extends BaseDrawTool

enum BoxState { SIDE_A, SIDE_GAP, SIDE_B, H, READY }
enum EdgeBlend { TOOL_COLOR, ADJUSTED_AVERAGE, BLEND_INTERFACE, NONE }

var _fill_inside := false  ## When true, the inside area of the curve gets filled.
var _thickness := 1  ## The thickness of the Edge.
var _drawing := false  ## Set to true when shape is being drawn.
var _blend_edge_mode := EdgeBlend.TOOL_COLOR  ## The blend method used by edges
var _color_from_other_tool := false
var _fill_inside_rect := Rect2i()  ## The bounding box that surrounds the area that gets filled.
var _current_state: int = BoxState.SIDE_A  ## Current state of the bezier curve (in SINGLE mode)
var _last_pixel: Vector2i
var _control_pts: Array[Vector2i]
var _origin: Vector2i
var _left_shade_value := 0.5
var _right_shade_value := 0.5


func _init() -> void:
	# To prevent tool from remaining active when switching projects
	Global.project_about_to_switch.connect(_clear)
	_drawer.color_op = Drawer.ColorOp.new()
	update_indicator()


func update_brush() -> void:
	pass


func _on_thickness_value_changed(value: int) -> void:
	_thickness = value
	update_indicator()
	update_config()
	save_config()


func _on_fill_checkbox_toggled(toggled_on: bool) -> void:
	if _fill_inside != toggled_on:
		_fill_inside = toggled_on
		update_config()
		save_config()


func _on_edge_behavior_item_selected(index: int) -> void:
	@warning_ignore("int_as_enum_without_cast")
	_blend_edge_mode = index
	%ColorFromTool.visible = _blend_edge_mode == EdgeBlend.TOOL_COLOR
	update_config()
	save_config()


func _on_color_from_tool_toggled(toggled_on: bool) -> void:
	if _color_from_other_tool != toggled_on:
		_color_from_other_tool = toggled_on
		update_config()
		save_config()


func _on_left_shade_option_item_selected(_index: int) -> void:
	update_config()
	save_config()


func _on_right_shade_option_item_selected(_index: int) -> void:
	update_config()
	save_config()


func _on_left_shade_slider_value_changed(value: float) -> void:
	if _left_shade_value != value:
		_left_shade_value = value
		update_config()
		save_config()


func _on_right_shade_slider_value_changed(value: float) -> void:
	if _right_shade_value != value:
		_right_shade_value = value
		update_config()
		save_config()


func update_indicator() -> void:
	var bitmap := BitMap.new()
	bitmap.create(Vector2i.ONE * _thickness)
	bitmap.set_bit_rect(Rect2i(Vector2i.ZERO, Vector2i.ONE * _thickness), true)
	_indicator = bitmap
	_polylines = _create_polylines(_indicator)


func get_config() -> Dictionary:
	var config := super.get_config()
	config["thickness"] = _thickness
	config["fill_inside"] = _fill_inside
	config["blend_edge_mode"] = _blend_edge_mode
	config["color_from_other_tool"] = _color_from_other_tool
	config["left_shade_value"] = _left_shade_value
	config["right_shade_value"] = _right_shade_value
	config["left_shade_option"] = %LeftShadeOption.selected
	config["right_shade_option"] = %RightShadeOption.selected
	return config


func set_config(config: Dictionary) -> void:
	super.set_config(config)
	_thickness = config.get("thickness", _thickness)
	_fill_inside = config.get("fill_inside", _fill_inside)
	_blend_edge_mode = config.get("blend_edge_mode", _blend_edge_mode)
	_color_from_other_tool = config.get("color_from_other_tool", _color_from_other_tool)
	_left_shade_value = config.get("left_shade_value", _left_shade_value)
	_right_shade_value = config.get("right_shade_value", _right_shade_value)

	%LeftShadeOption.select(config.get("left_shade_option", 1))
	%RightShadeOption.select(config.get("right_shade_option", 0))
	%ColorFromTool.visible = _blend_edge_mode == EdgeBlend.TOOL_COLOR
	%ColorFromTool.button_pressed = _color_from_other_tool


func update_config() -> void:
	super.update_config()
	$ThicknessSlider.value = _thickness
	$FillCheckbox.button_pressed = _fill_inside
	$FillOptions.visible = _fill_inside
	%EdgeBehavior.selected = _blend_edge_mode
	%ColorFromTool.button_pressed = _color_from_other_tool
	%LeftShadeSlider.value = _left_shade_value
	%RightShadeSlider.value = _right_shade_value


## This tool has no brush, so just return the indicator as it is.
func _create_brush_indicator() -> BitMap:
	return _indicator


func _input(event: InputEvent) -> void:
	if _drawing:
		if event.is_action_pressed("change_tool_mode"):
			if _control_pts.size() > 0:
				_current_state -= 1
				_control_pts.resize(_control_pts.size() - 1)
			else:
				_drawing = false
				_clear()


func cursor_move(pos: Vector2i):
	super.cursor_move(pos)
	if Global.mirror_view:
		pos.x = Global.current_project.size.x - pos.x - 1
	if _drawing:
		if Input.is_action_pressed("shape_displace"):
			_origin += pos - _last_pixel
			for i in _control_pts.size():
				_control_pts[i] = _control_pts[i] + pos - _last_pixel
		## This is used for preview
		pos = box_constraint(_last_pixel, pos, _current_state)
	_last_pixel = angle_constraint(Vector2(pos))


func draw_start(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super.draw_start(pos)
	if Input.is_action_pressed("shape_displace"):
		_picking_color = true
		_pick_color(pos)
		return
	pos = angle_constraint(Vector2(pos))
	_picking_color = false  # fixes _picking_color being true indefinitely after we pick color
	Global.canvas.selection.transform_content_confirm()
	update_mask()
	if !_drawing:
		_drawing = true
		_origin = pos
	else:
		pos = box_constraint(_last_pixel, pos, _current_state)
		if _current_state < BoxState.READY:
			_control_pts.append(pos)
		_current_state += 1
	_fill_inside_rect = Rect2i(pos, Vector2i.ZERO)


func draw_move(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super.draw_move(pos)
	if _picking_color:  # Still return even if we released Alt
		if Input.is_action_pressed("shape_displace"):
			_pick_color(pos)
		return


func draw_end(pos: Vector2i) -> void:
	# we still need bezier preview when curve is in SINGLE mode.
	if _current_state == BoxState.READY:
		_draw_shape()
	super.draw_end(pos)
	Global.canvas.measurements.queue_redraw()


func draw_preview() -> void:
	var previews := Global.canvas.previews_sprite
	if not _drawing:
		return
	var image := Image.create(
		Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_LA8
	)

	var box_points = _control_pts.duplicate()
	box_points.push_front(_origin)
	var canvas = Global.canvas.previews

	canvas.draw_set_transform(Vector2(0.5, 0.5))
	for i: int in box_points.size():
		var point: Vector2 = box_points[i]
		canvas.draw_set_transform(point + Vector2(0.5, 0.5))
		# Draw points on screen
		canvas.draw_circle(Vector2.ZERO, 0.2, Color.WHITE, false)
		canvas.draw_circle(Vector2.ZERO, 0.4, Color.WHITE, false)
		canvas.draw_line(Vector2.UP * 0.5, Vector2.DOWN * 0.5, Color.WHITE)
		canvas.draw_line(Vector2.RIGHT * 0.5, Vector2.LEFT * 0.5, Color.WHITE)
	if box_points.size() in [2, 4]:
		var current_pixel = Global.canvas.current_pixel.floor()
		current_pixel = box_constraint(_last_pixel, current_pixel, _current_state)
		var length = int(current_pixel.distance_to(box_points[-1]))
		var prefix = "Corner" if box_points.size() == 2 else "Height"
		var str_val = str(prefix, ": ", length + 1 if box_points.size() == 2 else length, " ", "px")
		# We are using the measurementsnode for measurement based previews.
		Global.canvas.measurements.draw.connect(
			_preview_updater.bind(current_pixel, box_points[-1], str_val)
		)
		Global.canvas.measurements.queue_redraw()

	for points: Array[Vector2i] in _iso_box_outline(box_points).values():
		for i in points.size():
			if Global.mirror_view:  # This fixes previewing in mirror mode
				points[i].x = image.get_width() - points[i].x - 1
			if Rect2i(Vector2i.ZERO, image.get_size()).has_point(points[i]):
				image.set_pixelv(points[i], Color.WHITE)
		# Handle mirroring
		for point in mirror_array(points):
			if Rect2i(Vector2i.ZERO, image.get_size()).has_point(point):
				image.set_pixelv(point, Color.WHITE)

	var texture := ImageTexture.create_from_image(image)
	previews.texture = texture


func _preview_updater(point_a: Vector2, point_b: Vector2, str_value: String) -> void:
	var measurements = Global.canvas.measurements
	var font = measurements.font
	var line_color = Color.WHITE
	var offset = (point_a - point_b).rotated(PI / 2).normalized()
	measurements.draw_set_transform(Vector2(0.5, 0.5) + offset)
	measurements.draw_line(point_a + offset, point_b + offset, line_color)
	measurements.draw_line(point_a, point_a + offset, line_color)
	measurements.draw_line(point_b, point_b + offset, line_color)
	var pos = point_a + (point_b - point_a) / 2
	measurements.draw_set_transform(
		pos + offset * 5, Global.camera.rotation, Vector2.ONE / Global.camera.zoom
	)
	measurements.draw_string(font, Vector2i.ZERO, str_value)
	Global.canvas.measurements.draw.disconnect(_preview_updater)


func _draw_shape() -> void:
	_drawing = false
	prepare_undo("Draw Shape")
	var images := _get_selected_draw_images()
	if _fill_inside and !Tools.is_placing_tiles():
		# converting control points to local basis vectors
		var a = _control_pts[0] - _origin
		var gap = _control_pts[1] - _control_pts[0]
		var b = _control_pts[2] - _control_pts[1]
		var h = _control_pts[3] - _control_pts[2]
		h.y = abs(h.y)
		var color = tool_slot.color
		if color.a == 0:
			_clear()
		var left_color = (
			color.lightened(_left_shade_value)
			if %LeftShadeOption.selected == 0
			else color.darkened(_left_shade_value)
		)
		var right_color = (
			color.lightened(_right_shade_value)
			if %RightShadeOption.selected == 0
			else color.darkened(_right_shade_value)
		)
		var box_img = generate_isometric_box(
			a, gap, b, h.y, color, left_color, right_color, _blend_edge_mode
		)
		if !box_img:  # Invalid shape
			_clear()
		# Fill mode works differently, (we have to consider all 8 surrounding points)
		var project := Global.current_project
		var central_point := project.tiles.get_canon_position(_origin)
		var positions := project.tiles.get_point_in_tiles(central_point)
		var offset = min(0, a.y, (a + gap).y, b.y, (b + gap).y, (a + b + gap).y) - 1
		var draw_rectangle := _get_draw_rect()
		if Global.current_project.has_selection and project.tiles.mode == Tiles.MODE.NONE:
			positions = Global.current_project.selection_map.get_point_in_tile_mode(central_point)
		var box_size = box_img.get_size()
		for i in positions.size():
			var pos := positions[i]
			var dst := (
				Vector2i(0, -h.y + offset)
				+ pos
				- Vector2i(floori(_thickness / 2.0), floori(_thickness / 2.0))
			)
			var dst_rect := Rect2i(dst, box_size)
			dst_rect = dst_rect.intersection(draw_rectangle)
			if dst_rect.size == Vector2i.ZERO:
				continue
			var src_rect := Rect2i(dst_rect.position - dst, dst_rect.size)
			var brush_image: Image = remove_unselected_parts_of_brush(box_img, dst)
			dst = dst_rect.position
			_draw_brush_image(brush_image, src_rect, dst)

			# Handle Mirroring
			var mirror_x := (project.x_symmetry_point + 1) - dst.x - src_rect.size.x
			var mirror_y := (project.y_symmetry_point + 1) - dst.y - src_rect.size.y

			if Tools.horizontal_mirror or Tools.vertical_mirror:
				var brush_copy_x = brush_image.duplicate()
				brush_copy_x.flip_x()
				var brush_copy_y = brush_image.duplicate()
				brush_copy_y.flip_y()
				if Tools.horizontal_mirror:
					var x_dst := Vector2i(mirror_x, dst.y)
					var mirr_b_x = remove_unselected_parts_of_brush(brush_copy_x, x_dst)
					_draw_brush_image(mirr_b_x, _flip_rect(src_rect, box_size, true, false), x_dst)
					if Tools.vertical_mirror:
						brush_copy_x.flip_y()
						var xy_dst := Vector2i(mirror_x, mirror_y)
						var mirr_b_xy := remove_unselected_parts_of_brush(brush_copy_x, xy_dst)
						_draw_brush_image(
							mirr_b_xy, _flip_rect(src_rect, box_size, true, true), xy_dst
						)
				if Tools.vertical_mirror:
					var y_dst := Vector2i(dst.x, mirror_y)
					var mirr_b_y := remove_unselected_parts_of_brush(brush_copy_y, y_dst)
					_draw_brush_image(mirr_b_y, _flip_rect(src_rect, box_size, false, true), y_dst)
	else:
		var box_points = _control_pts.duplicate()
		box_points.push_front(_origin)
		for points: Array[Vector2i] in _iso_box_outline(box_points).values():
			for point in points:
				# Reset drawer every time because pixel perfect sometimes breaks the tool
				_drawer.reset()
				_fill_inside_rect = _fill_inside_rect.expand(point)
				# Draw each point offsetted based on the shape's thickness
				_draw_pixel(point, images)
	_clear()
	commit_undo()


func _draw_pixel(point: Vector2i, images: Array[ImageExtended]) -> void:
	if Tools.is_placing_tiles():
		draw_tile(point)
	else:
		if Global.current_project.can_pixel_get_drawn(point):
			for image in images:
				_drawer.set_pixel(image, point, tool_slot.color)


func _clear() -> void:
	_control_pts.clear()
	_fill_inside_rect = Rect2i()
	_current_state = BoxState.SIDE_A
	Global.canvas.previews_sprite.texture = null
	Global.canvas.previews.queue_redraw()
	Global.canvas.measurements.queue_redraw()


## Get the [member _curve]'s baked points, and draw lines between them
## using [method Geometry2D.bresenham_line]. [param box_points] contains the minimum number of
## points required to construct a box.
## namely origin, first edge end, gap end, second edge end, height end
func _iso_box_outline(box_points: Array[Vector2i]) -> Dictionary:
	var origin: Vector2i = box_points.pop_front()
	if _current_state < BoxState.READY:
		box_points.append(_last_pixel)
	var edge_up: Array[Vector2i]
	var edge_down_left: Array[Vector2i]
	var edge_down_right: Array[Vector2i]
	var edge_left: Array[Vector2i]
	var edge_right: Array[Vector2i]
	var edge_0_1: Array[Vector2i]
	var edge_0_2: Array[Vector2i]
	var edge_1_2: Array[Vector2i]
	if box_points.size() >= 1:  # Line
		# (origin --> point A)
		edge_0_1.append_array(bresenham_line_thickness(origin, box_points[0], _thickness))
		if box_points.size() >= 2:  # Isometric box
			# (point A --> point A + gap)
			var gap = box_points[1] - box_points[0]
			var point_b = box_points[1]  # Assume it's the same as gap point for now
			var gap_points = bresenham_line_thickness(
				box_points[0], box_points[0] + gap, _thickness
			)
			if box_points.size() < 4:  # Optimization
				edge_1_2.append_array(gap_points)
			if box_points.size() >= 3:
				# (point A + gap --> point B)
				point_b = box_points[2]
				edge_0_2.append_array(
					bresenham_line_thickness(box_points[0] + gap, point_b, _thickness)
				)
			# draw the other sides of isometric polygon (we also add a 1px vertical offset)
			var upper_a = point_b - box_points[1] + origin + Vector2i.UP  # origin + point A basis
			# (point B --> upper_a + gap)
			edge_up.append_array(
				bresenham_line_thickness(point_b + Vector2i.UP, upper_a + gap, _thickness)
			)
			# (upper_a + gap --> upper_a)
			edge_up.append_array(bresenham_line_thickness(upper_a + gap, upper_a, _thickness))
			# (upper_a --> origin)
			edge_up.append_array(
				bresenham_line_thickness(upper_a, origin + Vector2i.UP, _thickness)
			)
			if box_points.size() == 4:
				# move the polygon up a height
				var height = Vector2i(0, -abs(box_points[3].y - box_points[2].y))
				for i in edge_up.size():
					if i < edge_0_1.size():
						edge_0_1[i] += height
					if i < edge_0_2.size():
						edge_0_2[i] += height
					edge_up[i] += height
				## Add new foundation lines
				edge_down_left.append_array(
					bresenham_line_thickness(origin, box_points[0], _thickness)
				)
				edge_down_right.append_array(
					bresenham_line_thickness(box_points[0] + gap, point_b, _thickness)
				)
				# Draw left/right vertical boundaries
				edge_left.append_array(
					bresenham_line_thickness(origin, origin + height, _thickness)
				)
				edge_right.append_array(
					bresenham_line_thickness(point_b, point_b + height, _thickness)
				)
				edge_1_2.clear()
				for point in gap_points:
					# NOTE: Height vector is negative so that it points upwards
					var end = point + height
					end.y = min(point.y, end.y)
					edge_1_2.append_array(Geometry2D.bresenham_line(point, end))
	if _current_state < BoxState.READY:
		box_points.resize(box_points.size() - 1)
	return {
		"edge_up": edge_up,
		"edge_down_left": edge_down_left,
		"edge_down_right": edge_down_right,
		"edge_left": edge_left,
		"edge_right": edge_right,
		"edge_0_1": edge_0_1,
		"edge_0_2": edge_0_2,
		"edge_1_2": edge_1_2,
	}


func generate_isometric_box(
	a: Vector2i,
	gap: Vector2i,
	b: Vector2i,
	box_height: int,
	c_t: Color,
	c_l: Color,
	c_r: Color,
	blend_mode := EdgeBlend.TOOL_COLOR
) -> Image:
	# a is ↘, b is ↗  (both of them are basis vectors)
	var h := Vector2i(0, box_height)
	var width: int = (a + gap + b).x + _thickness
	var height: int = (
		max(0, a.y, (a + gap).y, b.y, (b + gap).y, (a + b + gap).y)
		- min(0, a.y, (a + gap).y, b.y, (b + gap).y, (a + b + gap).y)
		+ abs(box_height + _thickness + 1)
	)
	# starting point of upper plate
	var u_st = Vector2i(
		floori(_thickness / 2.0),
		(
			abs(min(0, a.y, b.y, (b + gap).y, (a + gap).y, (a + gap + b).y))
			+ 1
			+ floori(_thickness / 2.0)
		)
	)
	# starting point of lower plate
	var b_st = u_st + h
	# a convenient lambdha function
	var basis_to_polygon := func(basis_steps: Array) -> Array[Vector2i]:
		var poly: Array[Vector2i] = [basis_steps.pop_front()]
		for i in basis_steps.size():
			poly.append(poly[i] + basis_steps[i])
		return poly
	# info for constructing the box
	var top_poly: PackedVector2Array = basis_to_polygon.call(
		[u_st, a, gap, b, Vector2i.UP, -a, -gap, -b]
	)
	var b_l_poly: PackedVector2Array = basis_to_polygon.call([b_st, a, -h, -a])
	var b_r_poly: PackedVector2Array = basis_to_polygon.call([b_st + a + gap, b, -h, -b])
	var b_poly: Array[Vector2i] = basis_to_polygon.call([b_st, a, gap, b, -h])
	var edge_points = _iso_box_outline(b_poly)
	var edge_up: Array[Vector2i] = edge_points.get("edge_up", [])
	var edge_down_left: Array[Vector2i] = edge_points.get("edge_down_left", [])
	var edge_down_right: Array[Vector2i] = edge_points.get("edge_down_right", [])
	var edge_left: Array[Vector2i] = edge_points.get("edge_left", [])
	var edge_right: Array[Vector2i] = edge_points.get("edge_right", [])
	var edge_0_1: Array[Vector2i] = edge_points.get("edge_0_1", [])
	var edge_0_2: Array[Vector2i] = edge_points.get("edge_0_2", [])
	var edge_1_2: Array[Vector2i] = edge_points.get("edge_1_2", [])

	if width <= 0 or height <= 0:
		return
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	for x: int in width:
		var top_started: bool = false
		var middle_edge_offset := INF  # Allows top polygon to be drawn before starting middle edge.
		for y: int in height:
			var point = Vector2i(x, y)
			## Edge coloring
			var edge_color: Color
			var should_color := false
			if point in edge_0_1:
				edge_color = get_blend_color(c_t, c_l, blend_mode)
				top_started = false
				should_color = true
			elif point in edge_0_2:
				edge_color = get_blend_color(c_t, c_r, blend_mode)
				top_started = false
				should_color = true
			elif point in edge_1_2:
				if middle_edge_offset == INF:
					middle_edge_offset = y + _thickness
				if top_started:  # Fills any points missed by top ponygon
					if point.y < middle_edge_offset and blend_mode == EdgeBlend.NONE:
						image.set_pixelv(point, c_t)
						continue
				var least_x = edge_1_2[0].x
				var max_x = edge_1_2[edge_1_2.size() - 1].x
				if point.x <= least_x + floori((max_x - least_x) / 2.0):
					edge_color = get_blend_color(c_l, c_r, blend_mode)
				else:
					edge_color = get_blend_color(c_r, c_l, blend_mode)
				top_started = false
				should_color = true
			elif point in edge_up:
				edge_color = get_blend_color(c_t, c_t, blend_mode)
				should_color = true
			elif point in edge_left or point in edge_down_left:
				edge_color = get_blend_color(c_l, c_l, blend_mode)
				should_color = true
			elif point in edge_right or point in edge_down_right:
				edge_color = get_blend_color(c_r, c_r, blend_mode)
				should_color = true
			## Shape filling
			elif Geometry2D.is_point_in_polygon(point, top_poly):
				top_started = true
				image.set_pixelv(point, c_t)
			elif Geometry2D.is_point_in_polygon(point, b_l_poly):
				image.set_pixelv(point, c_l)
			elif Geometry2D.is_point_in_polygon(point, b_r_poly):
				image.set_pixelv(point, c_r)
			if should_color:
				if blend_mode == EdgeBlend.ADJUSTED_AVERAGE:
					edge_color = (c_t + c_l + c_r) / 3
					# If the color gets equal to the top tool color, then this only happens when
					# all sides have same color and we'd end up getting a single colored blob so
					# we cheat a bit and change the color a little.
					if edge_color.is_equal_approx(c_t):
						edge_color = edge_color.darkened(0.5)
						if edge_color.is_equal_approx(c_t):
							edge_color = edge_color.lightened(0.5)
				edge_color = edge_color if box_height > 0 else c_t
				image.set_pixelv(point, edge_color)
	return image


func get_blend_color(face_color: Color, interface_color: Color, blend_mode):
	var tool_color = tool_slot.color
	match blend_mode:
		EdgeBlend.TOOL_COLOR:
			if _color_from_other_tool:
				var button = MOUSE_BUTTON_LEFT
				if tool_slot.button == MOUSE_BUTTON_LEFT:
					button = MOUSE_BUTTON_RIGHT
				return Tools.get_assigned_color(button)
			return tool_color
		EdgeBlend.BLEND_INTERFACE:
			return (face_color + interface_color) / 2
		_:
			return face_color


func angle_constraint(point: Vector2) -> Vector2i:
	if Input.is_action_pressed("shape_perfect") and _current_state < BoxState.H:
		var prev_point: Vector2 = _origin
		if _control_pts.size() > 0:
			prev_point = _control_pts[-1]
		var angle := rad_to_deg(prev_point.angle_to_point(point))
		var distance := prev_point.distance_to(point)
		angle = snappedf(angle, 22.5)
		if step_decimals(angle) != 0:
			var diff := point - prev_point
			var v := Vector2(2, 1) if absf(diff.x) > absf(diff.y) else Vector2(1, 2)
			var p := diff.project(diff.sign() * v).abs().round()
			var f := p.y if absf(diff.x) > absf(diff.y) else p.x
			return Vector2i((prev_point + diff.sign() * v * f - diff.sign()).round())
		else:
			return Vector2i(
				(prev_point + Vector2.RIGHT.rotated(deg_to_rad(angle)) * distance).round()
			)
	return Vector2i(point)


func box_constraint(old_point: Vector2i, point: Vector2i, state: int) -> Vector2i:
	if state == BoxState.SIDE_A:
		point.x = max(_origin.x, point.x)
		if state != _current_state:
			if Vector2(_last_pixel - _origin).angle() >= Vector2(point - _origin).angle():
				point = old_point
	elif state == BoxState.SIDE_GAP:
		# restriction on Gap joining two sides:
		# It should always be the same height as SIDE_A with x-value greater or equal than SIDE_A)
		point.x = max(_control_pts[0].x, point.x)
		if Vector2(point - _origin).angle() > Vector2(_control_pts[0] - _origin).angle():
			point = old_point
	elif state == BoxState.SIDE_B:
		# restriction on B:
		# It should always have x-value greater or equal than SIDE_GAP
		# And is placed such that it's angle with respect to origin is always greater than
		# angle of SIDE_A point with respect to origin
		point.x = max(_control_pts[1].x, point.x)
		if (
			Vector2(point - _control_pts[0]).angle()
			> Vector2(_control_pts[1] - _control_pts[0]).angle()
		):
			point = old_point
	elif state == BoxState.H:
		# restriction on H:
		# It's x-value is always constant. and y-value is always in upward direction
		point.x = _control_pts[2].x
		point.y = _control_pts[2].y - abs(floori(point.distance_to(_control_pts[2])))
	return point


func _draw_brush_image(brush_image: Image, src_rect: Rect2i, dst: Vector2i) -> void:
	var images := _get_selected_draw_images()
	for draw_image in images:
		if Tools.alpha_locked:
			var mask := draw_image.get_region(Rect2i(dst, brush_image.get_size()))
			draw_image.blend_rect_mask(brush_image, mask, src_rect, dst)
		else:
			draw_image.blend_rect(brush_image, src_rect, dst)
		draw_image.convert_rgb_to_indexed()
