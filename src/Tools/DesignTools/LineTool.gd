extends BaseDrawTool

var _original_pos := Vector2i.ZERO
var _start := Vector2i.ZERO
var _offset := Vector2i.ZERO
var _dest := Vector2i.ZERO
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
	if Input.is_action_pressed("shape_displace"):
		_picking_color = true
		_pick_color(pos)
		return
	_picking_color = false

	Global.canvas.selection.transform_content_confirm()
	update_mask()

	if Global.mirror_view:
		# mirroring position is ONLY required by "Preview"
		pos.x = Global.current_project.size.x - pos.x - 1
	_original_pos = pos
	_start = pos
	_offset = pos
	_dest = pos
	_drawing = true


func draw_move(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super.draw_move(pos)
	if _picking_color:  # Still return even if we released Alt
		if Input.is_action_pressed("shape_displace"):
			_pick_color(pos)
		return

	if _drawing:
		if Global.mirror_view:
			# mirroring position is ONLY required by "Preview"
			pos.x = Global.current_project.size.x - pos.x - 1
		if _displace_origin:
			_original_pos += pos - _offset
		var d := _line_angle_constraint(_original_pos, pos)
		_dest = d.position

		if Input.is_action_pressed("shape_center"):
			_start = _original_pos - (_dest - _original_pos)
		else:
			_start = _original_pos
		cursor_text = d.text
		_offset = pos


func draw_end(pos: Vector2i) -> void:
	pos = snap_position(pos)
	if _picking_color:
		super.draw_end(pos)
		return

	if _drawing:
		if Global.mirror_view:
			# now we revert back the coordinates from their mirror form so that line can be drawn
			_original_pos.x = (Global.current_project.size.x - 1) - _original_pos.x
			_start.x = (Global.current_project.size.x - 1) - _start.x
			_offset.x = (Global.current_project.size.x - 1) - _offset.x
			_dest.x = (Global.current_project.size.x - 1) - _dest.x
			if _thickness % 2 == 0:
				_original_pos.x += 1
				_start.x += 1
				_offset.x += 1
				_dest.x += 1
		_draw_shape()

		_original_pos = Vector2.ZERO
		_start = Vector2.ZERO
		_dest = Vector2.ZERO
		_drawing = false
		Global.canvas.previews_sprite.texture = null
		_displace_origin = false
		cursor_text = ""
	super.draw_end(pos)


func draw_preview() -> void:
	var canvas := Global.canvas.previews_sprite
	if _drawing:
		var points := _get_points()
		var image := Image.create(
			Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_LA8
		)
		for point in points:
			if Rect2i(Vector2i.ZERO, image.get_size()).has_point(point):
				image.set_pixelv(point, Color.WHITE)
		# Handle mirroring
		for point in mirror_array(points):
			if Rect2i(Vector2i.ZERO, image.get_size()).has_point(point):
				image.set_pixelv(point, Color.WHITE)
		var texture := ImageTexture.create_from_image(image)
		canvas.texture = texture


func _draw_shape() -> void:
	var points := _get_points()
	prepare_undo("Draw Shape")
	var images := _get_selected_draw_images()
	for point in points:
		# Reset drawer every time because pixel perfect sometimes breaks the tool
		_drawer.reset()
		if Tools.is_placing_tiles():
			draw_tile(point)
		else:
			# Draw each point offsetted based on the shape's thickness
			if Global.current_project.can_pixel_get_drawn(point):
				for image in images:
					_drawer.set_pixel(image, point, tool_slot.color)

	commit_undo()


func _get_points() -> Array[Vector2i]:
	var array: Array[Vector2i] = []
	var dx := absi(_dest.x - _start.x)
	var dy := -absi(_dest.y - _start.y)
	var err := dx + dy
	var e2 := err << 1
	var sx := 1 if _start.x < _dest.x else -1
	var sy := 1 if _start.y < _dest.y else -1
	var x := _start.x
	var y := _start.y

	var start := _start - Vector2i.ONE * (_thickness >> 1)
	var end := start + Vector2i.ONE * _thickness
	for yy in range(start.y, end.y):
		for xx in range(start.x, end.x):
			array.append(Vector2i(xx, yy))

	while !(x == _dest.x && y == _dest.y):
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


func _line_angle_constraint(start: Vector2, end: Vector2) -> Dictionary:
	var result := {}
	var angle := rad_to_deg(start.angle_to_point(end))
	var distance := start.distance_to(end)
	if Input.is_action_pressed("shape_perfect"):
		angle = snappedf(angle, 22.5)
		if step_decimals(angle) != 0:
			var diff := end - start
			var v := Vector2(2, 1) if absf(diff.x) > absf(diff.y) else Vector2(1, 2)
			var p := diff.project(diff.sign() * v).abs().round()
			var f := p.y if absf(diff.x) > absf(diff.y) else p.x
			end = start + diff.sign() * v * f - diff.sign()
			angle = rad_to_deg(atan2(signi(diff.y) * v.y, signi(diff.x) * v.x))
		else:
			end = start + Vector2.RIGHT.rotated(deg_to_rad(angle)) * distance
	angle *= -1
	angle += 360 if angle < 0 else 0
	result.text = str(snappedf(angle, 0.01)) + "°"
	result.position = end.round()
	return result
