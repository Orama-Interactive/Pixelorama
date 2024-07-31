extends "res://src/Tools/BaseDraw.gd"

var _start := Vector2i.ZERO
var _offset := Vector2i.ZERO
var _dest := Vector2i.ZERO
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
	var t_offsetv := Vector2i(t_offset, t_offset)
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


## This tool has no brush, so just return the indicator as it is.
func _create_brush_indicator() -> BitMap:
	return _indicator


func _get_shape_points(_size: Vector2i) -> Array[Vector2i]:
	return []


func _get_shape_points_filled(_size: Vector2i) -> Array[Vector2i]:
	return []


func _input(event: InputEvent) -> void:
	if _drawing:
		if event.is_action_pressed("shape_displace"):
			_displace_origin = true
		elif event.is_action_released("shape_displace"):
			_displace_origin = false


func draw_start(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super.draw_start(pos)
	if Input.is_action_pressed("draw_color_picker"):
		_picking_color = true
		_pick_color(pos)
		return
	_picking_color = false

	Global.canvas.selection.transform_content_confirm()
	update_mask()

	if Global.mirror_view:
		# mirroring position is ONLY required by "Preview"
		pos.x = Global.current_project.size.x - pos.x - 1
	_start = pos
	_offset = pos
	_dest = pos
	_drawing = true


func draw_move(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super.draw_move(pos)
	if _picking_color:  # Still return even if we released draw_color_picker (Alt)
		if Input.is_action_pressed("draw_color_picker"):
			_pick_color(pos)
		return

	if _drawing:
		if Global.mirror_view:
			# mirroring position is ONLY required by "Preview"
			pos.x = Global.current_project.size.x - pos.x - 1
		if _displace_origin:
			_start += pos - _offset
		_dest = pos
		_offset = pos
		_set_cursor_text(_get_result_rect(_start, pos))


func draw_end(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super.draw_end(pos)
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
				pos.x += 1
		_draw_shape(_start, pos)

		_start = Vector2i.ZERO
		_dest = Vector2i.ZERO
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
		var t_offsetv := Vector2i(t_offset, t_offset)
		indicator.create(rect.size + t_offsetv)
		for point in points:
			indicator.set_bitv(point, 1)

		var transform_pos := (
			rect.position - t_offsetv + Vector2i((Vector2(0.5, 0.5) * (t_offset - 1)).ceil())
		)
		canvas.draw_set_transform(transform_pos, canvas.rotation, canvas.scale)

		for line in _create_polylines(indicator):
			canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)

		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func _draw_shape(origin: Vector2i, dest: Vector2i) -> void:
	var rect := _get_result_rect(origin, dest)
	var points := _get_points(rect.size)
	prepare_undo("Draw Shape")
	var images := _get_selected_draw_images()
	var thickness_vector := rect.position - Vector2i((Vector2(0.5, 0.5) * (_thickness - 1)).ceil())
	for point in points:
		# Reset drawer every time because pixel perfect sometimes breaks the tool
		_drawer.reset()
		# Draw each point offsetted based on the shape's thickness
		var draw_pos := point + thickness_vector
		if Global.current_project.can_pixel_get_drawn(draw_pos):
			for image in images:
				_drawer.set_pixel(image, draw_pos, tool_slot.color)

	commit_undo()


## Given an origin point and destination point, returns a rect representing
## where the shape will be drawn and what is its size
func _get_result_rect(origin: Vector2i, dest: Vector2i) -> Rect2i:
	var rect := Rect2i()

	# Center the rect on the mouse
	if Input.is_action_pressed("shape_center"):
		var new_size := dest - origin
		# Make rect 1:1 while centering it on the mouse
		if Input.is_action_pressed("shape_perfect"):
			var square_size := maxi(absi(new_size.x), absi(new_size.y))
			new_size = Vector2i(square_size, square_size)

		origin -= new_size
		dest = origin + 2 * new_size

	# Make rect 1:1 while not trying to center it
	if Input.is_action_pressed("shape_perfect"):
		var square_size := mini(absi(origin.x - dest.x), absi(origin.y - dest.y))
		rect.position.x = origin.x if origin.x < dest.x else origin.x - square_size
		rect.position.y = origin.y if origin.y < dest.y else origin.y - square_size
		rect.size = Vector2i(square_size, square_size)
	# Get the rect without any modifications
	else:
		rect.position = Vector2i(mini(origin.x, dest.x), mini(origin.y, dest.y))
		rect.size = (origin - dest).abs()

	rect.size += Vector2i.ONE

	return rect


func _get_points(shape_size: Vector2i) -> Array[Vector2i]:
	return _get_shape_points_filled(shape_size) if _fill else _get_shape_points(shape_size)


func _set_cursor_text(rect: Rect2i) -> void:
	cursor_text = "%s, %s" % [rect.position.x, rect.position.y]
	cursor_text += " -> %s, %s" % [rect.end.x - 1, rect.end.y - 1]
	cursor_text += " (%s, %s)" % [rect.size.x, rect.size.y]
