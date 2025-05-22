extends BaseDrawTool

enum SingleState { A, B, H, READY }

var _drawing := false  ## Set to true when a curve is being drawn.
var _fill_inside := false  ## When true, the inside area of the curve gets filled.
var _fill_inside_rect := Rect2i()  ## The bounding box that surrounds the area that gets filled.
var _thickness := 1  ## The thickness of the curve.
var _current_state: int = SingleState.A  ## Current state of the bezier curve (in SINGLE mode)
var _basis_points: Array[Vector2i]
var _origin: Vector2i


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


func update_indicator() -> void:
	var bitmap := BitMap.new()
	bitmap.create(Vector2i.ONE * _thickness)
	bitmap.set_bit_rect(Rect2i(Vector2i.ZERO, Vector2i.ONE * _thickness), true)
	_indicator = bitmap
	_polylines = _create_polylines(_indicator)


func get_config() -> Dictionary:
	var config := super.get_config()
	config["fill_inside"] = _fill_inside
	config["thickness"] = _thickness
	return config


func set_config(config: Dictionary) -> void:
	super.set_config(config)
	_fill_inside = config.get("fill_inside", _fill_inside)
	_thickness = config.get("thickness", _thickness)


func update_config() -> void:
	super.update_config()
	$FillCheckbox.button_pressed = _fill_inside
	$ThicknessSlider.value = _thickness


## This tool has no brush, so just return the indicator as it is.
func _create_brush_indicator() -> BitMap:
	return _indicator


func _input(event: InputEvent) -> void:
	if _drawing:
		if event is InputEventMouseMotion:

			if event.is_action_pressed("shape_perfect"):
				pass
			elif event.is_action_released("shape_perfect"):
				pass
			if event.is_action_pressed("change_tool_mode"):
				pass


func draw_start(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super.draw_start(pos)
	if Input.is_action_pressed("shape_displace"):
		_picking_color = true
		_pick_color(pos)
		return
	_picking_color = false  # fixes _picking_color being true indefinitely after we pick color
	Global.canvas.selection.transform_content_confirm()
	update_mask()
	if !_drawing:
		_drawing = true
		_current_state = SingleState.A
		_origin = pos
	else:
		if _current_state == SingleState.H:
			pos.x = 0
		elif _current_state == SingleState.A:
			pos.x = max(_origin.x, pos.x)
		elif _current_state == SingleState.B:  # restriction on B
			pos.x = max(_basis_points[0].x, pos.x)
			if Vector2(pos - _origin).angle() >= Vector2(_basis_points[0] - _origin).angle():
				pos = _basis_points[0]
		if _current_state < SingleState.READY:
			_basis_points.append(pos)
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
	if _current_state == SingleState.READY:
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

	# Handle mirroring
	for point in mirror_array(points):
		if Rect2i(Vector2i.ZERO, image.get_size()).has_point(point):
			image.set_pixelv(point, Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	previews.texture = texture

	var canvas := Global.canvas.previews
	var circle_radius := Vector2.ONE * (5.0 / Global.camera.zoom.x)


func _draw_shape() -> void:
	prepare_undo("Draw Shape")
	var images := _get_selected_draw_images()
	if _fill_inside:  # Thickness isn't supported for this mode
		var a = _basis_points[0] - _origin
		var b = _basis_points[1] - _basis_points[0]
		var h = _basis_points[2] - _basis_points[1]
		h.y = abs(h.y)
		var color = tool_slot.color
		var box_img = generate_isometric_box(
			a, b, h.y, color, color.darkened(0.5), color.lightened(0.5), true
		)
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
	_basis_points.clear()
	_fill_inside_rect = Rect2i()
	_drawing = false
	Global.canvas.previews_sprite.texture = null
	Global.canvas.previews.queue_redraw()


## Get the [member _curve]'s baked points, and draw lines between them
## using [method Geometry2D.bresenham_line].
func _iso_box_outline() -> Array[Vector2i]:
	var new_thickness = _thickness
	if _fill_inside:
		new_thickness = 1
	var last_pixel: Vector2i = Global.canvas.current_pixel.floor()
	var preview: Array[Vector2i]
	if _current_state < SingleState.READY:
		if _current_state == SingleState.A:
			last_pixel.x = max(_origin.x, last_pixel.x)
		if _current_state == SingleState.B:
			# restriction on b point (For preview only)
			last_pixel.x = max(_basis_points[0].x, last_pixel.x)
			if Vector2(last_pixel - _origin).angle() >= Vector2(_basis_points[0] - _origin).angle():
				last_pixel = _basis_points[0]
		_basis_points.append(last_pixel)
	match _basis_points.size():
		1:
			# a line
			preview.append_array(bresenham_line_thickness(_origin, _basis_points[0], new_thickness))
		2:
			# an isometric "rextangle"
			preview.append_array(bresenham_line_thickness(_origin, _basis_points[0], new_thickness))
			preview.append_array(
				bresenham_line_thickness(_basis_points[0], _basis_points[1], new_thickness)
			)
			preview.append_array(bresenham_line_thickness(
				_basis_points[1], _basis_points[1] - _basis_points[0] + _origin, new_thickness)
			)
			preview.append_array(bresenham_line_thickness(
				_basis_points[1] - _basis_points[0] + _origin, _origin, new_thickness)
			)
		3:
			# an isometric "box"
			var diff = _basis_points[2] - _basis_points[1]
			diff.x = 0
			diff.y = min(0, diff.y)
			# outer outline (arranged clockwise)
			preview.append_array(
				bresenham_line_thickness(
					_basis_points[1] - _basis_points[0] + _origin + diff,
					_origin + diff,
					new_thickness
				)
			)
			preview.append_array(
				bresenham_line_thickness(
					_basis_points[1] + diff,
					_basis_points[1] - _basis_points[0] + _origin + diff,
					new_thickness
				)
			)
			preview.append_array(
				bresenham_line_thickness(_basis_points[1], _basis_points[1] + diff, new_thickness)
			)
			preview.append_array(
				bresenham_line_thickness(_basis_points[0], _basis_points[1], new_thickness)
			)
			preview.append_array(
				bresenham_line_thickness(_origin, _basis_points[0], new_thickness)
			)
			preview.append_array(
				bresenham_line_thickness(_origin, _origin + diff, new_thickness)
			)
			# inner lines
			preview.append_array(bresenham_line_thickness(
				_basis_points[0] + diff, _basis_points[1] + diff, new_thickness)
			)
			preview.append_array(
				bresenham_line_thickness(_origin + diff, _basis_points[0] + diff, new_thickness)
			)
			preview.append_array(
				bresenham_line_thickness(_basis_points[0], _basis_points[0] + diff, new_thickness)
			)
	if _current_state < SingleState.READY:
		_basis_points.resize(_basis_points.size() - 1)
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
	var width: int =  max(0, a.x, (a + b).x, b.x)
	var height: int = max(0, a.y, (a + b).y, b.y) - min(0, a.y, (a + b).y, b.y) + box_height
	var offset = Vector2i(0, abs(min(0, a.y, (a + b).y, b.y)))
	var upper_roof_start = Vector2i.ZERO + offset
	var base_start = upper_roof_start + Vector2i(0, box_height)

	var edge_0_1 := PackedVector2Array()
	var edge_0_2 := PackedVector2Array()
	var edge_1_2 := PackedVector2Array()
	if edge:
		edge_0_1 = bresenham_line_thickness(upper_roof_start, upper_roof_start + a, _thickness)
		edge_0_1 = bresenham_line_thickness(upper_roof_start, upper_roof_start + a, _thickness)
		edge_0_2 = bresenham_line_thickness(upper_roof_start + a, upper_roof_start + a + b, _thickness)
		edge_1_2 = bresenham_line_thickness(upper_roof_start + a, base_start + a, _thickness)
	var top_poly: PackedVector2Array = [
		upper_roof_start,
		a + offset,
		a + b + offset,
		b + offset
	]
	var b_l_poly: PackedVector2Array = [
		base_start,
		base_start + a,
		base_start + a - Vector2i(0, box_height),
		upper_roof_start
	]
	var b_r_poly: PackedVector2Array = [
		base_start + a,
		base_start + a + b,
		base_start + a + b - Vector2i(0, box_height),
		base_start + a - Vector2i(0, box_height)
	]
	if width <= 0 or height <= 0:
		return
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	for x: int in width:
		for y: int in height:
			var point = Vector2(x, y)
			 # Edge coloring
			if point in edge_0_1:
				image.set_pixel(x, y, Color(
						c_t.r + c_l.r,
						c_t.g + c_l.g,
						c_t.b + c_l.b,
						c_t.a + c_l.a)
					)
				continue
			elif point in edge_0_2:
				image.set_pixel(x, y, Color(
						c_t.r + c_r.r,
						c_t.g + c_r.g,
						c_t.b + c_r.b,
						c_t.a + c_r.a)
					)
				continue
			elif point in edge_1_2:
				image.set_pixel(x, y, Color(
						c_l.r + c_r.r,
						c_l.g + c_r.g,
						c_l.b + c_r.b,
						c_l.a + c_r.a)
					)
				continue
			# Shape
			if Geometry2D.is_point_in_polygon(point, top_poly):
				image.set_pixel(x, y, c_t)
			elif Geometry2D.is_point_in_polygon(point, b_l_poly):
				image.set_pixel(x, y, c_l)
			elif Geometry2D.is_point_in_polygon(point, b_r_poly):
				image.set_pixel(x, y, c_r)
	return image.get_region(image.get_used_rect())


func outline_poly(a: Vector2i, b: Vector2i, c: Vector2i):
	var out: Array[Vector2i]
	out.append_array(bresenham_line_thickness(a, b, _thickness))
	out.append_array(bresenham_line_thickness(b, c, _thickness))
	out.append_array(bresenham_line_thickness(
		c, c - b + a, _thickness)
	)
	out.append_array(bresenham_line_thickness(
		c - b + a, a, _thickness)
	)
	return out


func _fill_bitmap_with_points(points: Array[Vector2i], bitmap_size: Vector2i) -> BitMap:
	var bitmap := BitMap.new()
	bitmap.create(bitmap_size)

	for point in points:
		if point.x < 0 or point.y < 0 or point.x >= bitmap_size.x or point.y >= bitmap_size.y:
			continue
		bitmap.set_bitv(point, 1)

	return bitmap
