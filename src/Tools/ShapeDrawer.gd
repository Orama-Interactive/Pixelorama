extends "res://src/Tools/Draw.gd"


var _start := Vector2.ZERO
var _offset := Vector2.ZERO
var _dest := Vector2.ZERO
var _fill := false
var _drawing := false
var _displace_origin := false
var _thickness := 1


func _init() -> void:
	_drawer.color_op = Drawer.ColorOp.new()


func _on_Thickness_value_changed(value: int) -> void:
	_thickness = value
	update_config()
	save_config()


func _on_FillCheckbox_toggled(button_pressed: bool) -> void:
	_fill = button_pressed
	update_config()
	save_config()


func get_config() -> Dictionary:
	var config := .get_config()
	config["fill"] = _fill
	config["thickness"] = _thickness
	return config


func set_config(config: Dictionary) -> void:
	.set_config(config)
	_fill = config.get("fill", _fill)
	_thickness = config.get("thickness", _thickness)


func update_config() -> void:
	.update_config()
	$FillCheckbox.pressed = _fill
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

	_start = position
	_offset = position
	_dest = position
	_drawing = true


func draw_move(position : Vector2) -> void:
	if _drawing:
		if _displace_origin:
			_start += position - _offset
		_dest = position
		_offset = position


func draw_end(position : Vector2) -> void:
	if _drawing:
		_draw_shape(_start, position)

		_start = Vector2.ZERO
		_dest = Vector2.ZERO
		_drawing = false
		_displace_origin = false


func draw_preview() -> void:
	if _drawing:
		var canvas : CanvasItem = Global.canvas.previews
		var indicator := BitMap.new()
		var rect := _get_result_rect(_start, _dest)
		var points := _get_points(rect.size)
		var t_offset := _thickness - 1
		var t_offsetv := Vector2(t_offset, t_offset)
		indicator.create(rect.size + t_offsetv * 2)
		for point in points:
			indicator.set_bit(point, 1)

		canvas.draw_set_transform(rect.position - t_offsetv, canvas.rotation, canvas.scale)

		for line in _create_polylines(indicator):
			canvas.draw_polyline(PoolVector2Array(line), tool_slot.color)

		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func _draw_shape(origin: Vector2, dest: Vector2) -> void:
	var rect := _get_result_rect(origin, dest)
	var points := _get_points(rect.size)
	prepare_undo()
	for point in points:
		# Reset drawer every time because pixel perfect sometimes breaks the tool
		_drawer.reset()
		# Draw each point offseted based on the shape's thickness
		draw_tool(rect.position + point - Vector2.ONE * (_thickness - 1))

	commit_undo("Draw Shape")


# Given an origin point and destination point, returns a rect representing where the shape will be drawn and what it's size
func _get_result_rect(origin: Vector2, dest: Vector2) -> Rect2:
	# WARNING: Don't replace Input.is_action_pressed for Tools.control, it makes the preview jittery on windows
	var rect := Rect2(Vector2.ZERO, Vector2.ZERO)

	# Center the rect on the mouse
	if Input.is_action_pressed("ctrl"):
		var new_size := (dest - origin).floor()
		# Make rect 1:1 while centering it on the mouse
		if Input.is_action_pressed("shift"):
			var _square_size := max(abs(new_size.x), abs(new_size.y))
			new_size = Vector2(_square_size, _square_size)

		origin -= new_size
		dest = origin + 2 * new_size

	# Make rect 1:1 while not trying to center it
	if Input.is_action_pressed("shift"):
		var square_size := min(abs(origin.x - dest.x), abs(origin.y - dest.y))
		rect.position.x = origin.x if origin.x < dest.x else origin.x - square_size
		rect.position.y = origin.y if origin.y < dest.y else origin.y - square_size
		rect.size = Vector2(square_size, square_size)
	# Get the rect without any modifications
	else:
		rect.position = Vector2(min(origin.x, dest.x), min(origin.y, dest.y))
		rect.size = (origin - dest).abs()

	rect.size += Vector2.ONE

	return rect


func _get_points(size: Vector2) -> PoolVector2Array:
	return _get_shape_points_filled(size) if _fill else _get_shape_points(size)


func _outline_point(p: Vector2, thickness: int = 1, include_p: bool = true) -> Array:
		var array := []

		if thickness != 1:
			var t_of = thickness - 1
			for x in range (-t_of, thickness):
				for y in range (-t_of, thickness):
					if x == 0 and y == 0 and not include_p:
						continue

					array.append(p + Vector2(x,y))

		return array
