extends "res://src/Tools/Draw.gd"


var _original_pos := Vector2.ZERO
var _start := Vector2.ZERO
var _offset := Vector2.ZERO
var _dest := Vector2.ZERO
var _drawing := false
var _displace_origin := false
var _thickness := 1


func _init() -> void:
	_drawer.color_op = Drawer.ColorOp.new()


func _on_Thickness_value_changed(value: int) -> void:
	_thickness = value
	update_config()
	save_config()


func get_config() -> Dictionary:
	var config := .get_config()
	config["thickness"] = _thickness
	return config


func set_config(config: Dictionary) -> void:
	.set_config(config)
	_thickness = config.get("thickness", _thickness)


func update_config() -> void:
	.update_config()
	$ThicknessSlider.value = _thickness
	$ShapeThickness/ThicknessSpinbox.value = _thickness


func _get_shape_points(_size: Vector2) -> PoolVector2Array:
	return PoolVector2Array()


func _get_shape_points_filled(_size: Vector2) -> PoolVector2Array:
	return PoolVector2Array()


func _input(event : InputEvent) -> void:
	if _drawing:
		if event.is_action_pressed("alt"):
			_displace_origin = true
		elif event.is_action_released("alt"):
			_displace_origin = false


func draw_start(position : Vector2) -> void:
	Global.canvas.selection.transform_content_confirm()
	update_mask()

	_original_pos = position
	_start = position
	_offset = position
	_dest = position
	_drawing = true


func draw_move(position : Vector2) -> void:
	if _drawing:
		if _displace_origin:
			_original_pos += position - _offset
		var d = _line_angle_constraint(_original_pos, position)
		_dest = d.position
		if Tools.control:
			_start = _original_pos - (_dest - _original_pos)
		else:
			_start = _original_pos
		cursor_text = d.text
		_offset = position


func draw_end(_position : Vector2) -> void:
	if _drawing:
		_draw_shape()

		_original_pos = Vector2.ZERO
		_start = Vector2.ZERO
		_dest = Vector2.ZERO
		_drawing = false
		_displace_origin = false
		cursor_text = ""


func draw_preview() -> void:
	if _drawing:
		var canvas : CanvasItem = Global.canvas.previews
		var indicator := BitMap.new()
		var start := _start
		if _start.x > _dest.x:
			start.x = _dest.x
		if _start.y > _dest.y:
			start.y = _dest.y

		var points := _get_points()
		var t_offset := _thickness - 1
		var t_offsetv := Vector2(t_offset, t_offset)
		indicator.create((_dest - _start).abs() + t_offsetv * 2 + Vector2.ONE)

		for point in points:
			var p : Vector2 = point - start + t_offsetv
			indicator.set_bit(p, 1)

		canvas.draw_set_transform(start - t_offsetv, canvas.rotation, canvas.scale)

		for line in _create_polylines(indicator):
			canvas.draw_polyline(PoolVector2Array(line), tool_slot.color)

		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func _draw_shape() -> void:
#	var rect := _get_result_rect(origin, dest)
	var points := _get_points()
	prepare_undo()
	for point in points:
		# Reset drawer every time because pixel perfect sometimes breaks the tool
		_drawer.reset()
		# Draw each point offseted based on the shape's thickness
		draw_tool(point)

	commit_undo("Draw Shape")


func _get_points() -> PoolVector2Array:
	var array := []
	var dx := int(abs(_dest.x - _start.x))
	var dy := int(-abs(_dest.y - _start.y))
	var err := dx + dy
	var e2 := err << 1
	var sx = 1 if _start.x < _dest.x else -1
	var sy = 1 if _start.y < _dest.y else -1
	var x = _start.x
	var y = _start.y

	var start := _start - Vector2.ONE * (_thickness >> 1)
	var end := start + Vector2.ONE * _thickness
	for yy in range(start.y, end.y):
		for xx in range(start.x, end.x):
			array.append(Vector2(xx, yy))

	while !(x == _dest.x && y == _dest.y):
		e2 = err << 1
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy

		var pos := Vector2(x, y)
		start = pos - Vector2.ONE * (_thickness >> 1)
		end = start + Vector2.ONE * _thickness
		for yy in range(start.y, end.y):
			for xx in range(start.x, end.x):
				array.append(Vector2(xx, yy))

	return PoolVector2Array(array)


func _line_angle_constraint(start : Vector2, end : Vector2) -> Dictionary:
	var result := {}
	var angle := rad2deg(end.angle_to_point(start))
	var distance := start.distance_to(end)
	if Tools.shift:
		angle = stepify(angle, 22.5)
		if step_decimals(angle) != 0:
			var diff := end - start
			var v := Vector2(2 , 1) if abs(diff.x) > abs(diff.y) else Vector2(1 , 2)
			var p := diff.project(diff.sign() * v).abs().round()
			var f := p.y if abs(diff.x) > abs(diff.y) else p.x
			end = start + diff.sign() * v * f - diff.sign()
			angle = rad2deg(atan2(sign(diff.y) * v.y, sign(diff.x) * v.x))
		else:
			end = start + Vector2.RIGHT.rotated(deg2rad(angle)) * distance
	angle *= -1
	angle += 360 if angle < 0 else 0
	result.text = str(stepify(angle, 0.01)) + "°"
	result.position = end.round()
	return result
