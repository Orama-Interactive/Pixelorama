extends BaseDrawTool

var _curve := Curve2D.new()  ## The [Curve2D] responsible for the shape of the curve being drawn.
var _drawing := false  ## Set to true when a curve is being drawn.
var _fill_inside := false  ## When true, the inside area of the curve gets filled.
var _fill_inside_rect := Rect2i()  ## The bounding box that surrounds the area that gets filled.
var _editing_bezier := false  ## Needed to determine when to show the control points preview line.
var _editing_out_control_point := false  ## True when controlling the out control point only.
var _thickness := 1  ## The thickness of the curve.
var _last_mouse_position := Vector2.INF  ## The last position of the mouse


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
			_last_mouse_position = Global.canvas.current_pixel.floor()
			if Global.mirror_view:
				_last_mouse_position.x = Global.current_project.size.x - 1 - _last_mouse_position.x
		elif event is InputEventMouseButton:
			if event.double_click and event.button_index == tool_slot.button:
				$DoubleClickTimer.start()
				_draw_shape()
		else:
			if event.is_action_pressed("shape_perfect"):
				_editing_out_control_point = true
			elif event.is_action_released("shape_perfect"):
				_editing_out_control_point = false
			if event.is_action_pressed("change_tool_mode"):  # Control removes the last added point
				if _curve.point_count > 1:
					_curve.remove_point(_curve.point_count - 1)


func draw_start(pos: Vector2i) -> void:
	if !$DoubleClickTimer.is_stopped():
		return
	pos = snap_position(pos)
	super.draw_start(pos)
	if Input.is_action_pressed("shape_displace"):
		_picking_color = true
		_pick_color(pos)
		return
	Global.canvas.selection.transform_content_confirm()
	update_mask()
	if !_drawing:
		_drawing = true
	_curve.add_point(pos)
	_fill_inside_rect = Rect2i(pos, Vector2i.ZERO)


func draw_move(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super.draw_move(pos)
	if _picking_color:  # Still return even if we released Alt
		if Input.is_action_pressed("shape_displace"):
			_pick_color(pos)
		return
	if _drawing:
		_editing_bezier = true
		var current_position := _curve.get_point_position(_curve.point_count - 1) - Vector2(pos)
		if not _editing_out_control_point:
			_curve.set_point_in(_curve.point_count - 1, current_position)
		_curve.set_point_out(_curve.point_count - 1, -current_position)


func draw_end(pos: Vector2i) -> void:
	_editing_bezier = false
	if _is_hovering_first_position(pos) and _curve.point_count > 1:
		_draw_shape()
	super.draw_end(pos)


func draw_preview() -> void:
	var previews := Global.canvas.previews_sprite
	if not _drawing:
		return
	var points := _bezier()
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
	if _is_hovering_first_position(_last_mouse_position) and _curve.point_count > 1:
		var circle_center := _curve.get_point_position(0)
		if Global.mirror_view:  # This fixes previewing in mirror mode
			circle_center.x = Global.current_project.size.x - circle_center.x - 1
		circle_center += Vector2.ONE * 0.5
		draw_empty_circle(canvas, circle_center, circle_radius * 2.0, Color.BLACK)
	if _editing_bezier:
		var current_position := _curve.get_point_position(_curve.point_count - 1)
		var start := current_position
		if _curve.point_count > 1:
			start = current_position + _curve.get_point_in(_curve.point_count - 1)
		var end := current_position + _curve.get_point_out(_curve.point_count - 1)
		if Global.mirror_view:  # This fixes previewing in mirror mode
			current_position.x = Global.current_project.size.x - current_position.x - 1
			start.x = Global.current_project.size.x - start.x - 1
			end.x = Global.current_project.size.x - end.x - 1

		canvas.draw_line(start, current_position, Color.BLACK)
		canvas.draw_line(current_position, end, Color.BLACK)
		draw_empty_circle(canvas, start, circle_radius, Color.BLACK)
		draw_empty_circle(canvas, end, circle_radius, Color.BLACK)


func _draw_shape() -> void:
	var points := _bezier()
	prepare_undo("Draw Shape")
	var images := _get_selected_draw_images()
	for point in points:
		# Reset drawer every time because pixel perfect sometimes breaks the tool
		_drawer.reset()
		_fill_inside_rect = _fill_inside_rect.expand(point)
		# Draw each point offsetted based on the shape's thickness
		_draw_pixel(point, images)
	if _fill_inside:
		var v := Vector2i()
		for x in _fill_inside_rect.size.x:
			v.x = x + _fill_inside_rect.position.x
			for y in _fill_inside_rect.size.y:
				v.y = y + _fill_inside_rect.position.y
				if Geometry2D.is_point_in_polygon(v, points):
					_draw_pixel(v, images)
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
	_curve.clear_points()
	_fill_inside_rect = Rect2i()
	_drawing = false
	Global.canvas.previews_sprite.texture = null
	_editing_out_control_point = false
	Global.canvas.previews.queue_redraw()


## Get the [member _curve]'s baked points, and draw lines between them using [method _fill_gap].
func _bezier() -> Array[Vector2i]:
	var last_pixel := Global.canvas.current_pixel
	if Global.mirror_view:
		# Mirror the last point of the curve
		last_pixel.x = (Global.current_project.size.x - 1) - last_pixel.x
	_curve.add_point(last_pixel)
	var points := _curve.get_baked_points()
	_curve.remove_point(_curve.point_count - 1)
	var final_points: Array[Vector2i] = []
	for i in points.size() - 1:
		var point1 := points[i]
		var point2 := points[i + 1]
		final_points.append_array(_fill_gap(point1, point2))
	return final_points


## Fills the gap between [param point_a] and [param point_b] using Bresenham's line algorithm.
## Takes the [member _thickness] into account.
func _fill_gap(point_a: Vector2i, point_b: Vector2i) -> Array[Vector2i]:
	var array: Array[Vector2i] = []
	var dx := absi(point_b.x - point_a.x)
	var dy := -absi(point_b.y - point_a.y)
	var err := dx + dy
	var e2 := err << 1
	var sx := 1 if point_a.x < point_b.x else -1
	var sy := 1 if point_a.y < point_b.y else -1
	var x := point_a.x
	var y := point_a.y

	var start := point_a - Vector2i.ONE * (_thickness >> 1)
	var end := start + Vector2i.ONE * _thickness
	for yy in range(start.y, end.y):
		for xx in range(start.x, end.x):
			array.append(Vector2i(xx, yy))

	while !(x == point_b.x && y == point_b.y):
		e2 = err << 1
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy

		var pos := Vector2i(x, y)
		start = pos - Vector2i.ONE * (_thickness >> 1)
		end = start + Vector2i.ONE * _thickness
		for yy in range(start.y, end.y):
			for xx in range(start.x, end.x):
				array.append(Vector2i(xx, yy))

	return array


func _fill_bitmap_with_points(points: Array[Vector2i], bitmap_size: Vector2i) -> BitMap:
	var bitmap := BitMap.new()
	bitmap.create(bitmap_size)

	for point in points:
		if point.x < 0 or point.y < 0 or point.x >= bitmap_size.x or point.y >= bitmap_size.y:
			continue
		bitmap.set_bitv(point, 1)

	return bitmap


func _is_hovering_first_position(pos: Vector2) -> bool:
	return _curve.point_count > 0 and _curve.get_point_position(0) == pos


# Thanks to
# https://www.reddit.com/r/godot/comments/3ktq39/drawing_empty_circles_and_curves/cv0f4eo/
func draw_empty_circle(
	canvas: CanvasItem, circle_center: Vector2, circle_radius: Vector2, color: Color
) -> void:
	var draw_counter := 1
	var line_origin := Vector2()
	var line_end := Vector2()
	line_origin = circle_radius + circle_center

	while draw_counter <= 360:
		line_end = circle_radius.rotated(deg_to_rad(draw_counter)) + circle_center
		canvas.draw_line(line_origin, line_end, color)
		draw_counter += 1
		line_origin = line_end

	line_end = circle_radius.rotated(TAU) + circle_center
	canvas.draw_line(line_origin, line_end, color)
