extends BaseDrawTool

enum BoxState { A, B, H, READY }

var _fill_inside := false  ## When true, the inside area of the curve gets filled.
var _thickness := 1  ## The thickness of the curve.
var _drawing := false  ## Set to true when a curve is being drawn.
var _visible_edges := false  ## When true, the inside area of the curve gets filled.
var _fill_inside_rect := Rect2i()  ## The bounding box that surrounds the area that gets filled.
var _current_state: int = BoxState.A  ## Current state of the bezier curve (in SINGLE mode)
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
	_fill_inside = toggled_on
	update_config()
	save_config()


func _on_edges_checkbox_toggled(toggled_on: bool) -> void:
	_visible_edges = toggled_on
	update_config()
	save_config()


func _on_left_shade_option_item_selected(index: int) -> void:
	update_config()
	save_config()


func _on_right_shade_option_item_selected(index: int) -> void:
	update_config()
	save_config()


func _on_left_shade_slider_value_changed(value: float) -> void:
	_left_shade_value = value
	update_config()
	save_config()


func _on_right_shade_slider_value_changed(value: float) -> void:
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
	config["visible_edges"] = _thickness
	config["left_shade_value"] = _left_shade_value
	config["right_shade_value"] = _right_shade_value
	config["left_shade_option"] = %LeftShadeOption.selected
	config["right_shade_option"] = %RightShadeOption.selected
	return config


func set_config(config: Dictionary) -> void:
	super.set_config(config)
	_thickness = config.get("thickness", _thickness)
	_fill_inside = config.get("fill_inside", _fill_inside)
	_visible_edges = config.get("visible_edges", _visible_edges)
	_left_shade_value = config.get("left_shade_value", _left_shade_value)
	_right_shade_value = config.get("right_shade_value", _right_shade_value)
	%LeftShadeOption.select(config.get("left_shade_option", 1))
	%RightShadeOption.select(config.get("right_shade_option", 0))


func update_config() -> void:
	super.update_config()
	$ThicknessSlider.value = _thickness
	$FillCheckbox.button_pressed = _fill_inside
	$FillOptions.visible = _fill_inside
	$FillOptions/EdgesCheckbox.button_pressed = _visible_edges
	%LeftShadeSlider.value = _left_shade_value
	%RightShadeSlider.value = _right_shade_value


## This tool has no brush, so just return the indicator as it is.
func _create_brush_indicator() -> BitMap:
	return _indicator


func cursor_move(pos: Vector2i):
	super.cursor_move(pos)
	if _drawing:
		if Input.is_action_pressed("shape_displace"):
			_origin += pos - _last_pixel
			for i in _control_pts.size():
				_control_pts[i] = _control_pts[i] + pos - _last_pixel
		if Input.is_action_pressed("change_tool_mode"):
			if _control_pts.size() > 0:
				var temp_state = maxi(BoxState.A, _current_state - 1)
				var new_value := _control_pts[temp_state] + pos - _last_pixel
				_control_pts[temp_state] = box_constraint(
					_control_pts[temp_state], new_value, temp_state
				)

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


func draw_preview() -> void:
	var previews := Global.canvas.previews_sprite
	if not _drawing:
		return

	var points := _iso_box_outline()
	var image := Image.create(
		Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_LA8
	)
	for i in points.size():
		if Global.mirror_view:  # This fixes previewing in mirror mode
			points[i].x = image.get_width() - points[i].x - 1
		if Rect2i(Vector2i.ZERO, image.get_size()).has_point(points[i]):
			image.set_pixelv(points[i], Color.WHITE)

	if Input.is_action_pressed("change_tool_mode") and _control_pts.size() > 0:
		var canvas = Global.canvas.previews
		var circle_radius := Vector2.ONE * (5.0 / Global.camera.zoom.x)
		var idx = maxi(BoxState.A, _current_state - 1)
		var focus_point =  _control_pts[idx]
		var prev_point: Vector2 = _origin
		print(idx)
		if idx > 0:
			prev_point = _control_pts[idx - 1]
		canvas.draw_circle(focus_point, circle_radius.x, Color.WHITE)
		canvas.draw_circle(focus_point, circle_radius.x * 2, Color.WHITE, false)
		canvas.draw_line(prev_point, focus_point, Color.WHITE, 1)

	# Handle mirroring
	for point in mirror_array(points):
		if Rect2i(Vector2i.ZERO, image.get_size()).has_point(point):
			image.set_pixelv(point, Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	previews.texture = texture


func _draw_shape() -> void:
	_drawing = false
	prepare_undo("Draw Shape")
	var images := _get_selected_draw_images()
	if _fill_inside:  # Thickness isn't supported for this mode
		# converting control points to local basis vectors
		var a = _control_pts[0] - _origin
		var b = _control_pts[1] - _control_pts[0]
		var h = _control_pts[2] - _control_pts[1]
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
			a, b, h.y, color, left_color, right_color, _visible_edges
		)
		if !box_img:  # Invalid shape
			_clear()
		var offset = min(0, a.y, (a + b).y, b.y)
		var dst := Vector2i(0, - h.y + offset)
		for img: ImageExtended in images:
			img.blend_rect(box_img, Rect2i(Vector2i.ZERO, box_img.get_size()), _origin + dst)
	else:
		var points := _iso_box_outline()
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
	_current_state = BoxState.A
	Global.canvas.previews_sprite.texture = null
	Global.canvas.previews.queue_redraw()


## Get the [member _curve]'s baked points, and draw lines between them
## using [method Geometry2D.bresenham_line].
func _iso_box_outline() -> Array[Vector2i]:
	var new_thickness = _thickness
	if _fill_inside:
		new_thickness = 1
	var preview: Array[Vector2i]
	if _current_state < BoxState.READY:
		_control_pts.append(_last_pixel)
	match _control_pts.size():
		1:
			# a line
			preview.append_array(bresenham_line_thickness(_origin, _control_pts[0], new_thickness))
		2:
			# an isometric "rextangle"
			preview.append_array(bresenham_line_thickness(_origin, _control_pts[0], new_thickness))
			preview.append_array(
				bresenham_line_thickness(_control_pts[0], _control_pts[1], new_thickness)
			)
			preview.append_array(bresenham_line_thickness(
				_control_pts[1], _control_pts[1] - _control_pts[0] + _origin, new_thickness)
			)
			preview.append_array(bresenham_line_thickness(
				_control_pts[1] - _control_pts[0] + _origin, _origin, new_thickness)
			)
		3:
			# an isometric "box"
			var diff = _control_pts[2] - _control_pts[1]
			diff.x = 0
			diff.y = abs(diff.y)
			# outer outline (arranged clockwise)
			preview.append_array(
				bresenham_line_thickness(
					_control_pts[1] - _control_pts[0] + _origin - diff,
					_origin - diff,
					new_thickness
				)
			)
			preview.append_array(
				bresenham_line_thickness(
					_control_pts[1] - diff,
					_control_pts[1] - _control_pts[0] + _origin - diff,
					new_thickness
				)
			)
			preview.append_array(
				bresenham_line_thickness(_control_pts[1], _control_pts[1] - diff, new_thickness)
			)
			preview.append_array(
				bresenham_line_thickness(_control_pts[0], _control_pts[1], new_thickness)
			)
			preview.append_array(
				bresenham_line_thickness(_origin, _control_pts[0], new_thickness)
			)
			preview.append_array(
				bresenham_line_thickness(_origin, _origin - diff, new_thickness)
			)
			# inner lines
			if _fill_inside and _drawing:
				# This part will only be visible on preview
				var canvas = Global.canvas.previews
				canvas.draw_dashed_line(_control_pts[0] - diff, _control_pts[1] - diff, Color.WHITE)
				canvas.draw_dashed_line(_origin - diff, _control_pts[0] - diff, Color.WHITE)
				canvas.draw_dashed_line(_control_pts[0], _control_pts[0] - diff, Color.WHITE)
			else:
				preview.append_array(bresenham_line_thickness(
					_control_pts[0] - diff, _control_pts[1] - diff, new_thickness)
				)
				preview.append_array(
					bresenham_line_thickness(_origin - diff, _control_pts[0] - diff, new_thickness)
				)
				preview.append_array(
					bresenham_line_thickness(_control_pts[0], _control_pts[0] - diff, new_thickness)
				)
	if _current_state < BoxState.READY:
		_control_pts.resize(_control_pts.size() - 1)
	return preview


func generate_isometric_box(
	a: Vector2i,
	b: Vector2i,
	box_height: int,
	c_t: Color,
	c_l: Color,
	c_r: Color,
	edge := false
) -> Image:
	# a is ↘, b is ↗  (both of them are basis vectors)
	var c := Vector2i(0, box_height)
	var width: int =  max(0, a.x, (a + b).x, b.x) + 1
	var height: int = max(0, a.y, (a + b).y, b.y) - min(0, a.y, (a + b).y, b.y) + box_height
	var offset = Vector2i(0, abs(min(0, a.y, (a + b).y, b.y)))

	# starting point of upper plate
	var u_st = Vector2i.ZERO + offset
	# starting point of lower plate
	var b_st = u_st + c

	var edge_0_1 := PackedVector2Array()
	var edge_0_2 := PackedVector2Array()
	var edge_1_2 := PackedVector2Array()
	if edge:
		edge_0_1 = bresenham_line_thickness(u_st, u_st + a, _thickness)
		edge_0_1 = bresenham_line_thickness(u_st, u_st + a, _thickness)
		edge_0_2 = bresenham_line_thickness(u_st + a, u_st + a + b, _thickness)
		edge_1_2 = bresenham_line_thickness(u_st + a, b_st + a, _thickness)

	var top_poly: PackedVector2Array = [u_st, a + offset, a + b + offset, b + offset]
	var b_l_poly: PackedVector2Array = [b_st, b_st + a, b_st + a - c, u_st]
	var b_r_poly: PackedVector2Array = [b_st + a, b_st + a + b, b_st + a + b - c, b_st + a - c]

	if width <= 0 or height <= 0:
		return
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)

	# a convenient lambdha function
	var is_canon_edge := func(point, edge_1: int, edge_2: int):
		var poly = [top_poly, b_l_poly, b_r_poly]
		return (
			Geometry2D.is_point_in_polygon(point, poly[edge_1])
			or Geometry2D.is_point_in_polygon(point, poly[edge_2])
		)
	for x: int in width:
		for y: int in height:
			var point = Vector2(x, y)

			 # Edge coloring
			var edge_color: Color
			var should_color := false
			if point in edge_0_1 and is_canon_edge.call(point, 0, 1):
				edge_color = Color(c_t.r + c_l.r, c_t.g + c_l.g, c_t.b + c_l.b, c_t.a + c_l.a)
				should_color = true
			elif point in edge_0_2 and is_canon_edge.call(point, 0, 2):
				edge_color = Color(c_t.r + c_r.r, c_t.g + c_r.g, c_t.b + c_r.b, c_t.a + c_r.a)
				if should_color:
					continue
				should_color = true
			elif point in edge_1_2 and is_canon_edge.call(point, 1, 2):
				edge_color = Color(c_l.r + c_r.r, c_l.g + c_r.g, c_l.b + c_r.b, c_l.a + c_r.a)
				if should_color:
					continue
				should_color = true
			if should_color:
				image.set_pixelv(point, edge_color)
				continue

			# Shape filling
			if Geometry2D.is_point_in_polygon(point, top_poly):
				image.set_pixel(x, y, c_t)
			elif Geometry2D.is_point_in_polygon(point, b_l_poly):
				image.set_pixel(x, y, c_l)
			elif Geometry2D.is_point_in_polygon(point, b_r_poly):
				image.set_pixel(x, y, c_r)
	return image


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
			return Vector2i((prev_point + Vector2.RIGHT.rotated(deg_to_rad(angle)) * distance).round())
	return Vector2i(point)


func box_constraint(old_point: Vector2i, point: Vector2i, state: int) -> Vector2i:
	if state == BoxState.A:
		point.x = max(_origin.x, point.x)
		if state != _current_state:
			if Vector2(_last_pixel - _origin).angle() >= Vector2(point - _origin).angle():
				point = old_point
	elif state == BoxState.B:
		# restriction on B
		point.x = max(_control_pts[0].x, point.x)
		if Vector2(point - _origin).angle() >= Vector2(_control_pts[0] - _origin).angle():
			point = old_point
	return point
