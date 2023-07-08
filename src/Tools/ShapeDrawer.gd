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
	update_indicator()


func update_brush() -> void:
	pass


func _on_Thickness_value_changed(value: int) -> void:
	_thickness = value

	update_indicator()
	update_config()
	save_config()


func update_indicator() -> void:
	var indicator := BitMap.new()
	var rect := _get_result_rect(_start, _dest)
	var points := _get_points(rect.size)
	var t_offset := _thickness - 1
	var t_offsetv := Vector2(t_offset, t_offset)
	indicator.create(rect.size + t_offsetv)
	for point in points:
		indicator.set_bitv(point, 1)

	_indicator = indicator
	_polylines = _create_polylines(_indicator)


func _on_FillCheckbox_toggled(button_pressed: bool) -> void:
	_fill = button_pressed
	update_config()
	save_config()


func get_config() -> Dictionary:
	var config := super.get_config()
	config["fill"] = _fill
	config["thickness"] = _thickness
	return config


func set_config(config: Dictionary) -> void:
	super.set_config(config)
	_fill = config.get("fill", _fill)
	_thickness = config.get("thickness", _thickness)


func update_config() -> void:
	super.update_config()
	$FillCheckbox.button_pressed = _fill
	$ThicknessSlider.value = _thickness


func _get_shape_points(_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array()


func _get_shape_points_filled(_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array()


func _input(event: InputEvent) -> void:
	if _drawing:
		if event.is_action_pressed("shape_displace"):
			_displace_origin = true
		elif event.is_action_released("shape_displace"):
			_displace_origin = false


func draw_start(position: Vector2) -> void:
	position = snap_position(position)
	super.draw_start(position)
	if Input.is_action_pressed("draw_color_picker"):
		_picking_color = true
		_pick_color(position)
		return
	_picking_color = false

	Global.canvas.selection.transform_content_confirm()
	update_mask()

	if Global.mirror_view:
		# mirroring position is ONLY required by "Preview"
		position.x = Global.current_project.size.x - position.x - 1
	_start = position
	_offset = position
	_dest = position
	_drawing = true


func draw_move(position: Vector2) -> void:
	position = snap_position(position)
	super.draw_move(position)
	if _picking_color:  # Still return even if we released draw_color_picker (Alt)
		if Input.is_action_pressed("draw_color_picker"):
			_pick_color(position)
		return

	if _drawing:
		if Global.mirror_view:
			# mirroring position is ONLY required by "Preview"
			position.x = Global.current_project.size.x - position.x - 1
		if _displace_origin:
			_start += position - _offset
		_dest = position
		_offset = position
		_set_cursor_text(_get_result_rect(_start, position))


func draw_end(position: Vector2) -> void:
	position = snap_position(position)
	super.draw_end(position)
	if _picking_color:
		return

	if _drawing:
		if Global.mirror_view:
			# now we revert back the coordinates from their mirror form so that shape can be drawn
			_start.x = (Global.current_project.size.x - 1) - _start.x
			_offset.x = (Global.current_project.size.x - 1) - _offset.x
			_dest.x = (Global.current_project.size.x - 1) - _dest.x
			if _thickness % 2 == 0:
				_start.x += 1
				_offset.x += 1
				_dest.x += 1
				position.x += 1
		_draw_shape(_start, position)

		_start = Vector2.ZERO
		_dest = Vector2.ZERO
		_drawing = false
		_displace_origin = false
		cursor_text = ""


func draw_preview() -> void:
	if _drawing:
		var canvas: CanvasItem = Global.canvas.previews
		var indicator := BitMap.new()
		var rect := _get_result_rect(_start, _dest)
		var points := _get_points(rect.size)
		var t_offset := _thickness - 1
		var t_offsetv := Vector2(t_offset, t_offset)
		indicator.create(rect.size + t_offsetv)
		for point in points:
			indicator.set_bitv(point, 1)

		var transform_pos: Vector2 = rect.position - t_offsetv + Vector2(0.5, 0.5) * (t_offset - 1)
		canvas.draw_set_transform(transform_pos.ceil(), canvas.rotation, canvas.scale)

		for line in _create_polylines(indicator):
			canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)

		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func _draw_shape(origin: Vector2, dest: Vector2) -> void:
	var rect := _get_result_rect(origin, dest)
	var points := _get_points(rect.size)
	prepare_undo("Draw Shape3D")
	for point in points:
		# Reset drawer every time because pixel perfect sometimes breaks the tool
		_drawer.reset()
		# Draw each point offsetted based on the shape's thickness
		draw_tool(rect.position + point - Vector2(0.5, 0.5) * (_thickness - 1))

	commit_undo()


# Given an origin point and destination point, returns a rect representing
# where the shape will be drawn and what is its size
func _get_result_rect(origin: Vector2, dest: Vector2) -> Rect2:
	var rect := Rect2()

	# Center the rect on the mouse
	if Input.is_action_pressed("shape_center"):
		var new_size := (dest - origin).floor()
		# Make rect 1:1 while centering it on the mouse
		if Input.is_action_pressed("shape_perfect"):
			var square_size := maxf(absf(new_size.x), absf(new_size.y))
			new_size = Vector2(square_size, square_size)

		origin -= new_size
		dest = origin + 2 * new_size

	# Make rect 1:1 while not trying to center it
	if Input.is_action_pressed("shape_perfect"):
		var square_size := minf(absf(origin.x - dest.x), absf(origin.y - dest.y))
		rect.position.x = origin.x if origin.x < dest.x else origin.x - square_size
		rect.position.y = origin.y if origin.y < dest.y else origin.y - square_size
		rect.size = Vector2(square_size, square_size)
	# Get the rect without any modifications
	else:
		rect.position = Vector2(min(origin.x, dest.x), min(origin.y, dest.y))
		rect.size = (origin - dest).abs()

	rect.size += Vector2.ONE

	return rect


func _get_points(size: Vector2) -> PackedVector2Array:
	return _get_shape_points_filled(size) if _fill else _get_shape_points(size)


func _set_cursor_text(rect: Rect2) -> void:
	cursor_text = "%s, %s" % [rect.position.x, rect.position.y]
	cursor_text += " -> %s, %s" % [rect.end.x - 1, rect.end.y - 1]
	cursor_text += " (%s, %s)" % [rect.size.x, rect.size.y]
