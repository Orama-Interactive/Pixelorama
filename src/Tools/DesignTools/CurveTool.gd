extends "res://src/Tools/BaseDraw.gd"

var _curve := Curve2D.new()  ## The [Curve2D] responsible for the shape of the curve being drawn.
var _drawing := false  ## Set to true when a curve is being drawn.
var _editing_bezier := false  ## Needed to determine when to show the control points preview line.
var _thickness := 1  ## The thickness of the curve.


func _init() -> void:
	Global.project_about_to_switch.connect(_draw_shape)  # To prevent tool from remaining active
	_drawer.color_op = Drawer.ColorOp.new()
	update_indicator()


func update_brush() -> void:
	pass


func _on_Thickness_value_changed(value: int) -> void:
	_thickness = value
	update_indicator()
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
	return config


func set_config(config: Dictionary) -> void:
	super.set_config(config)
	_thickness = config.get("thickness", _thickness)


func update_config() -> void:
	super.update_config()
	$ThicknessSlider.value = _thickness


func _input(event: InputEvent) -> void:
	if _drawing:
		if event is InputEventMouseButton:
			if event.double_click and event.button_index == tool_slot.button:
				$DoubleClickTimer.start()
				_draw_shape()
		else:
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
		_curve.set_point_in(_curve.point_count - 1, current_position)
		_curve.set_point_out(_curve.point_count - 1, -current_position)


func draw_end(pos: Vector2i) -> void:
	_editing_bezier = false
	super.draw_end(pos)


func draw_preview() -> void:
	if not _drawing:
		return
	var canvas: Node2D = Global.canvas.previews
	var pos := canvas.position
	var canvas_scale := canvas.scale
	if Global.mirror_view:  # This fixes previewing in mirror mode
		pos.x = pos.x + Global.current_project.size.x
		canvas_scale.x = -1

	var points := _bezier()
	canvas.draw_set_transform(pos, canvas.rotation, canvas_scale)
	var indicator := _fill_bitmap_with_points(points, Global.current_project.size)

	for line in _create_polylines(indicator):
		canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)

	canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)

	if _editing_bezier:
		var start := _curve.get_point_position(0)
		if _curve.point_count > 1:
			start = (
				_curve.get_point_position(_curve.point_count - 1)
				+ _curve.get_point_in(_curve.point_count - 1)
			)
		var end := (
			_curve.get_point_position(_curve.point_count - 1)
			+ _curve.get_point_out(_curve.point_count - 1)
		)
		if Global.mirror_view:  # This fixes previewing in mirror mode
			start.x = Global.current_project.size.x - start.x - 1
			end.x = Global.current_project.size.x - end.x - 1

		canvas.draw_line(start, end, Color.BLACK)
		var circle_radius := Vector2.ONE * (5.0 / Global.camera.zoom.x)
		draw_empty_circle(canvas, start, circle_radius, Color.BLACK)
		draw_empty_circle(canvas, end, circle_radius, Color.BLACK)


func _draw_shape() -> void:
	var points := _bezier()
	prepare_undo("Draw Shape")
	for point in points:
		# Reset drawer every time because pixel perfect sometimes breaks the tool
		_drawer.reset()
		# Draw each point offsetted based on the shape's thickness
		draw_tool(point)
	_curve.clear_points()
	_drawing = false
	commit_undo()


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
