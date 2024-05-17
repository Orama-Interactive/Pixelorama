extends "res://src/Tools/BaseDraw.gd"

var perma_points := []  # Optimization approach
var control_points := []
var _drawing := false
var _editing_bezier := false
var _thickness := 1
var _detail := 1000


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


func _on_detail_value_changed(value: float) -> void:
	_detail = value

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
	config["detail"] = _detail
	return config


func set_config(config: Dictionary) -> void:
	super.set_config(config)
	_thickness = config.get("thickness", _thickness)
	_detail = config.get("detail", _detail)


func update_config() -> void:
	super.update_config()
	$ThicknessSlider.value = _thickness
	$DetailSlider.value = _detail


func _get_shape_points(_size: Vector2i) -> Array[Vector2i]:
	return []


func _get_shape_points_filled(_size: Vector2i) -> Array[Vector2i]:
	return []


func _input(event: InputEvent) -> void:
	if _drawing:
		if event is InputEventMouseMotion:
			var pos: Vector2i = snap_position(Global.canvas.current_pixel.floor())
			if _drawing:
				if Global.mirror_view:
					# mirroring position is ONLY required by "Preview"
					pos.x = Global.current_project.size.x - pos.x - 1
				#set_current_point(pos)
		elif event is InputEventMouseButton:
			if event.double_click and event.button_index == tool_slot.button:
				$DoubleClickTimer.start()
				_draw_shape()


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
	if Global.mirror_view:
		# mirroring position is ONLY required by "Preview"
		pos.x = Global.current_project.size.x - pos.x - 1
	if !_drawing:
		_drawing = true
	control_points.append_array([pos, pos, pos])  # Append first start point and 2 bezier points


func draw_move(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super.draw_move(pos)
	if _picking_color:  # Still return even if we released Alt
		if Input.is_action_pressed("shape_displace"):
			_pick_color(pos)
		return
	if _drawing:
		_editing_bezier = true
		control_points[-1] = pos
		control_points[-2] = pos
		if control_points.size() > 3:
			var offset: Vector2i = (
				Vector2(control_points[-3] - control_points[-2]).rotated(deg_to_rad(180)).floor()
			)
			control_points[-4] = control_points[-3] - offset


func draw_end(pos: Vector2i) -> void:
	_editing_bezier = false
	super.draw_end(pos)


func draw_preview() -> void:
	if _drawing:
		var canvas: Node2D = Global.canvas.previews
		var pos := canvas.position
		var canvas_scale := canvas.scale
		if Global.mirror_view:
			pos.x = pos.x + Global.current_project.size.x
			canvas_scale.x = -1

		var points := _bezier(_detail)
		canvas.draw_set_transform(pos, canvas.rotation, canvas_scale)
		var indicator := _fill_bitmap_with_points(points, Global.current_project.size)

		for line in _create_polylines(indicator):
			canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)

		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)

		if _editing_bezier:
			var start = control_points[0]  # well.. i have to start the line somewhere
			var end = control_points[-2]
			if control_points.size() > 3:
				start = control_points[-4]
			canvas.draw_line(start, end, Color.BLACK)
			var circle_radius := Vector2.ONE * (5 / Global.camera.zoom.x)
			draw_empty_circle(canvas, start, circle_radius, Color.BLACK)
			draw_empty_circle(canvas, end, circle_radius, Color.BLACK)


func _draw_shape() -> void:
	var points := _bezier(_detail)
	prepare_undo("Draw Shape")
	for point in points:
		# Reset drawer every time because pixel perfect sometimes breaks the tool
		_drawer.reset()
		# Draw each point offsetted based on the shape's thickness
		draw_tool(point)
	control_points.clear()
	_drawing = false

	commit_undo()


func _bezier(detail: float = 50) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for i in range(0, control_points.size(), 3):
		var points = control_points.slice(i, i + 4)
		if points.size() < 4:
			for _missing in range(points.size(), 4):
				points.append(Global.canvas.current_pixel)

		for d in range(0, detail + 1):
			var t = d / detail
			var point: Vector2i = (
				(pow(1 - t, 3) * points[0])
				+ (3 * pow(1 - t, 2) * t * points[1])
				+ (3 * (1 - t) * pow(t, 2) * points[2])
				+ (pow(t, 3) * points[3])
			)
			if !point in res:
				if res.is_empty():
					res.append(point)
				else:
					res.append_array(_fill_gap(res[-1], point))
	return res


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

	line_end = circle_radius.rotated(deg_to_rad(360)) + circle_center
	canvas.draw_line(line_origin, line_end, color)
