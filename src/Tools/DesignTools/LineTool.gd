extends BaseDrawTool

var _original_pos := Vector2i.ZERO
var _start := Vector2i.ZERO
var _offset := Vector2i.ZERO
var _dest := Vector2i.ZERO
var _drawing := false
var _displace_origin := false


func _init() -> void:
	_drawer.color_op = Drawer.ColorOp.new()
	update_indicator()


func update_indicator() -> void:
	var bitmap := BitMap.new()
	bitmap.create(Vector2i.ONE)
	bitmap.set_bit_rect(Rect2i(Vector2i.ZERO, Vector2i.ONE), true)
	_indicator = bitmap
	_polylines = _create_polylines(_indicator)


func get_config() -> Dictionary:
	var config := super.get_config()
	return config


func set_config(config: Dictionary) -> void:
	super.set_config(config)


func _input(event: InputEvent) -> void:
	if _drawing:
		if event.is_action_pressed("shape_displace"):
			_displace_origin = true
		elif event.is_action_released("shape_displace"):
			_displace_origin = false
	else:
		super(event)


func draw_start(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super.draw_start(pos)

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

	if _drawing:
		if Global.mirror_view:
			# now we revert back the coordinates from their mirror form so that line can be drawn
			_original_pos.x = (Global.current_project.size.x - 1) - _original_pos.x
			_start.x = (Global.current_project.size.x - 1) - _start.x
			_offset.x = (Global.current_project.size.x - 1) - _offset.x
			_dest.x = (Global.current_project.size.x - 1) - _dest.x
		_draw_shape()
		_reset_tool()
	super.draw_end(pos)


func cancel_tool() -> void:
	super()
	_reset_tool()


func _reset_tool() -> void:
	_original_pos = Vector2.ZERO
	_start = Vector2.ZERO
	_dest = Vector2.ZERO
	_drawing = false
	Global.canvas.previews_sprite.texture = null
	_displace_origin = false
	cursor_text = ""


func draw_preview() -> void:
	if not _drawing:
		return
	var canvas := Global.canvas.previews_sprite
	var points := Geometry2D.bresenham_line(_start, _dest)
	var final_points := get_coords_to_draw(points, false)
	var image := Image.create(
		Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_LA8
	)
	for point in final_points:
		if Rect2i(Vector2i.ZERO, image.get_size()).has_point(point):
			image.set_pixelv(point, Color.WHITE)
	# Handle mirroring
	for point in mirror_array(final_points):
		if Rect2i(Vector2i.ZERO, image.get_size()).has_point(point):
			image.set_pixelv(point, Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	canvas.texture = texture


func _draw_shape() -> void:
	var points := Geometry2D.bresenham_line(_start, _dest)
	prepare_undo()
	_prepare_tool()
	var final_points := get_coords_to_draw(points)
	for point in final_points:
		_set_pixel(point)

	commit_undo("Draw Shape")


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
