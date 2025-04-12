extends BaseDrawTool

enum SingleState { START, END, MIDDLE_A, MIDDLE_B, READY }
enum Bezier { CHAINED, SINGLE }

var _curve := Curve2D.new()  ## The [Curve2D] responsible for the shape of the curve being drawn.
var _drawing := false  ## Set to true when a curve is being drawn.
var _fill_inside := false  ## When true, the inside area of the curve gets filled.
var _fill_inside_rect := Rect2i()  ## The bounding box that surrounds the area that gets filled.
var _editing_bezier := false  ## Needed to determine when to show the control points preview line.
var _editing_out_control_point := false  ## True when controlling the out control point only.
var _thickness := 1  ## The thickness of the curve.
var _last_mouse_position := Vector2.INF  ## The last position of the mouse
## chained means Krita-like behavior, single means Aseprite-like.
var _bezier_mode: int = Bezier.CHAINED
var _current_state: int = SingleState.START  ## Current state of the bezier curve (in SINGLE mode)

@onready var bezier_option_button: OptionButton = $BezierOptions/BezierMode


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


func _on_bezier_mode_item_selected(index: int) -> void:
	_bezier_mode = index
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
	config["bezier_mode"] = _bezier_mode
	return config


func set_config(config: Dictionary) -> void:
	super.set_config(config)
	_fill_inside = config.get("fill_inside", _fill_inside)
	_thickness = config.get("thickness", _thickness)
	_bezier_mode = config.get("bezier_mode", _bezier_mode)


func update_config() -> void:
	super.update_config()
	$FillCheckbox.button_pressed = _fill_inside
	$ThicknessSlider.value = _thickness
	bezier_option_button.select(_bezier_mode)


## This tool has no brush, so just return the indicator as it is.
func _create_brush_indicator() -> BitMap:
	return _indicator


func _input(event: InputEvent) -> void:
	if _drawing:
		if event is InputEventMouseMotion:
			_last_mouse_position = Global.canvas.current_pixel.floor()
			if Global.mirror_view:
				_last_mouse_position.x = Global.current_project.size.x - 1 - _last_mouse_position.x
			if _bezier_mode == Bezier.SINGLE and _current_state >= SingleState.MIDDLE_A:
				# if bezier's curvature is being changed in SINGLE mode
				if _current_state == SingleState.MIDDLE_A:
					_curve.set_point_out(
						0, Vector2(_last_mouse_position) - _curve.get_point_position(0)
					)
				_curve.set_point_in(
					1,
					(
						Vector2(_last_mouse_position)
						- _curve.get_point_position(_curve.point_count - 1)
					)
				)
		elif event is InputEventMouseButton:
			if event.double_click and event.button_index == tool_slot.button:
				$DoubleClickTimer.start()
				_draw_shape()
		else:
			if _bezier_mode == Bezier.CHAINED:
				if event.is_action_pressed("shape_perfect"):
					_editing_out_control_point = true
				elif event.is_action_released("shape_perfect"):
					_editing_out_control_point = false
			if event.is_action_pressed("change_tool_mode"):  # Control removes the last added point
				if _curve.point_count > 1:
					match _current_state:
						SingleState.START:  # Point removed in CHAINED mode
							_curve.remove_point(_curve.point_count - 1)
						SingleState.MIDDLE_A:  # End point is to be removed in SINGLE mode
							_curve.remove_point(_curve.point_count - 1)
							_curve.set_point_out(0, Vector2.ZERO)
							_editing_bezier = false
							_current_state -= 1
						SingleState.MIDDLE_B:  # Bezier curvature is to be reset in SINGLE mode
							_curve.set_point_out(
								0, _last_mouse_position - _curve.get_point_position(0)
							)
							_current_state -= 1


func draw_start(pos: Vector2i) -> void:
	if !$DoubleClickTimer.is_stopped():
		return
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
		bezier_option_button.disabled = true
		_drawing = true
		_current_state = SingleState.START
	# NOTE: _current_state of CHAINED mode is always SingleState.START so it will always pass this.
	if _current_state == SingleState.START or _current_state == SingleState.END:
		_curve.add_point(pos)
	if _bezier_mode == Bezier.SINGLE:
		_current_state += 1
	_fill_inside_rect = Rect2i(pos, Vector2i.ZERO)


func draw_move(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super.draw_move(pos)
	if _picking_color:  # Still return even if we released Alt
		if Input.is_action_pressed("shape_displace"):
			_pick_color(pos)
		return
	if _drawing and _bezier_mode == Bezier.CHAINED:
		_editing_bezier = true
		var current_position := _curve.get_point_position(_curve.point_count - 1) - Vector2(pos)
		if not _editing_out_control_point:
			_curve.set_point_in(_curve.point_count - 1, current_position)
		_curve.set_point_out(_curve.point_count - 1, -current_position)


func draw_end(pos: Vector2i) -> void:
	if (
		_current_state == SingleState.MIDDLE_A
		or _current_state == SingleState.MIDDLE_B
	):  # we still need preview when curve is in SINGLE mode.
		_editing_bezier = true
	else:
		_editing_bezier = false
	if (
		(_is_hovering_first_position(pos) and _curve.point_count > 1)
		or _current_state == SingleState.READY
	):
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
		var current_point = _curve.point_count - 1
		if _current_state == SingleState.MIDDLE_A:
			# We need this when we are modifying curve of "first" point in SINGLE mode
			current_point = 0
		var current_position := _curve.get_point_position(current_point)
		var start := current_position
		if current_point > 0:
			start = current_position + _curve.get_point_in(current_point)
		var end := current_position + _curve.get_point_out(current_point)
		if Global.mirror_view:  # This fixes previewing in mirror mode
			current_position.x = Global.current_project.size.x - current_position.x - 1
			start.x = Global.current_project.size.x - start.x - 1
			end.x = Global.current_project.size.x - end.x - 1

		canvas.draw_line(start, current_position, Color.BLACK)
		canvas.draw_line(current_position, end, Color.BLACK)
		draw_empty_circle(canvas, start, circle_radius, Color.BLACK)
		draw_empty_circle(canvas, end, circle_radius, Color.BLACK)


func _draw_shape() -> void:
	bezier_option_button.disabled = false
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


## Get the [member _curve]'s baked points, and draw lines between them
## using [method Geometry2D.bresenham_line].
func _bezier() -> Array[Vector2i]:
	var last_pixel := Global.canvas.current_pixel.floor()
	if Global.mirror_view:
		# Mirror the last point of the curve
		last_pixel.x = (Global.current_project.size.x - 1) - last_pixel.x
	if _current_state <= SingleState.END:  # this is general for both modes
		_curve.add_point(last_pixel)
	var points := _curve.get_baked_points()
	if _current_state <= SingleState.END:  # this is general for both modes
		_curve.remove_point(_curve.point_count - 1)
	var final_points: Array[Vector2i] = []
	for i in points.size() - 1:
		var point1 := points[i]
		var point2 := points[i + 1]
		final_points.append_array(bresenham_line_thickness(point1, point2, _thickness))
	return final_points


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
