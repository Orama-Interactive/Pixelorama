extends BaseDrawTool

var _prev_mode := false
var _last_position := Vector2i(Vector2.INF)
var _changed := false
var _overwrite := false
var _fill_inside := false
var _fill_inside_rect := Rect2i()  ## The bounding box that surrounds the area that gets filled.
var _draw_points := PackedVector2Array()
var _old_spacing_mode := false  ## Needed to reset spacing mode in case we change it


class PencilOp:
	extends Drawer.ColorOp
	var changed := false
	var overwrite := false

	func process(src: Color, dst: Color) -> Color:
		changed = true
		src.a *= strength
		if overwrite:
			return src
		return dst.blend(src)


func _init() -> void:
	_drawer.color_op = PencilOp.new()


func _on_Overwrite_toggled(button_pressed: bool) -> void:
	_overwrite = button_pressed
	update_config()
	save_config()


func _on_FillInside_toggled(button_pressed: bool) -> void:
	_fill_inside = button_pressed
	update_config()
	save_config()


func _on_SpacingMode_toggled(button_pressed: bool) -> void:
	# This acts as an interface to access the intrinsic spacing_mode feature
	# BaseTool holds the spacing system, but for a tool to access them it's recommended to do it in
	# their own script
	_spacing_mode = button_pressed
	update_config()
	save_config()


func _on_Spacing_value_changed(value: Vector2) -> void:
	_spacing = value
	save_config()


func _input(event: InputEvent) -> void:
	var overwrite_button: CheckBox = $Overwrite

	if event.is_action_pressed("change_tool_mode"):
		_prev_mode = overwrite_button.button_pressed
	if event.is_action("change_tool_mode"):
		overwrite_button.set_pressed_no_signal(!_prev_mode)
		_overwrite = overwrite_button.button_pressed
	if event.is_action_released("change_tool_mode"):
		overwrite_button.set_pressed_no_signal(_prev_mode)
		_overwrite = overwrite_button.button_pressed


func get_config() -> Dictionary:
	var config := super.get_config()
	config["overwrite"] = _overwrite
	config["fill_inside"] = _fill_inside
	config["spacing_mode"] = _spacing_mode
	config["spacing"] = _spacing
	return config


func set_config(config: Dictionary) -> void:
	super.set_config(config)
	_overwrite = config.get("overwrite", _overwrite)
	_fill_inside = config.get("fill_inside", _fill_inside)
	_spacing_mode = config.get("spacing_mode", _spacing_mode)
	_spacing = config.get("spacing", _spacing)


func update_config() -> void:
	super.update_config()
	$Overwrite.button_pressed = _overwrite
	$FillInside.button_pressed = _fill_inside
	$SpacingMode.button_pressed = _spacing_mode
	$Spacing.visible = _spacing_mode
	$Spacing.value = _spacing


func draw_start(pos: Vector2i) -> void:
	_old_spacing_mode = _spacing_mode
	pos = snap_position(pos)
	super.draw_start(pos)
	if Input.is_action_pressed(&"draw_color_picker", true):
		_picking_color = true
		_pick_color(pos)
		return
	_picking_color = false

	Global.canvas.selection.transform_content_confirm()
	prepare_undo("Draw")
	var can_skip_mask := true
	if tool_slot.color.a < 1 and !_overwrite:
		can_skip_mask = false
	update_mask(can_skip_mask)
	_changed = false
	_drawer.color_op.changed = false
	_drawer.color_op.overwrite = _overwrite
	_draw_points = []

	_drawer.reset()

	_draw_line = Input.is_action_pressed("draw_create_line")
	if _draw_line:
		_spacing_mode = false  # spacing mode is disabled during line mode
		if Global.mirror_view:
			# mirroring position is ONLY required by "Preview"
			pos.x = (Global.current_project.size.x - 1) - pos.x
		_line_start = pos
		_line_end = pos
		update_line_polylines(_line_start, _line_end)
	else:
		if _fill_inside:
			_draw_points.append(pos)
			_fill_inside_rect = Rect2i(pos, Vector2i.ZERO)
		draw_tool(pos)
		_last_position = pos
		Global.canvas.sprite_changed_this_frame = true
	cursor_text = ""


func draw_move(pos_i: Vector2i) -> void:
	var pos := _get_stabilized_position(pos_i)
	pos = snap_position(pos)
	super.draw_move(pos)
	if _picking_color:  # Still return even if we released Alt
		if Input.is_action_pressed(&"draw_color_picker", true):
			_pick_color(pos)
		return

	if _draw_line:
		_spacing_mode = false  # spacing mode is disabled during line mode
		if Global.mirror_view:
			# mirroring position is ONLY required by "Preview"
			pos.x = (Global.current_project.size.x - 1) - pos.x
		var d := _line_angle_constraint(_line_start, pos)
		_line_end = d.position
		cursor_text = d.text
		update_line_polylines(_line_start, _line_end)
	else:
		draw_fill_gap(_last_position, pos)
		_last_position = pos
		cursor_text = ""
		Global.canvas.sprite_changed_this_frame = true
		if _fill_inside:
			_draw_points.append(pos)
			_fill_inside_rect = _fill_inside_rect.expand(pos)


func draw_end(pos: Vector2i) -> void:
	pos = snap_position(pos)
	if _picking_color:
		super.draw_end(pos)
		return

	if _draw_line:
		_spacing_mode = false  # spacing mode is disabled during line mode
		if Global.mirror_view:
			# now we revert back the coordinates from their mirror form so that line can be drawn
			_line_start.x = (Global.current_project.size.x - 1) - _line_start.x
			_line_end.x = (Global.current_project.size.x - 1) - _line_end.x
		draw_tool(_line_start)
		draw_fill_gap(_line_start, _line_end)
		_draw_line = false
	else:
		if _fill_inside:
			_draw_points.append(pos)
			if _draw_points.size() > 3:
				var v := Vector2i()
				for x in _fill_inside_rect.size.x:
					v.x = x + _fill_inside_rect.position.x
					for y in _fill_inside_rect.size.y:
						v.y = y + _fill_inside_rect.position.y
						if Geometry2D.is_point_in_polygon(v, _draw_points):
							if _spacing_mode:
								# use of get_spacing_position() in Pencil.gd is a rare case
								# (you would ONLY need _spacing_mode and _spacing in most cases)
								v = get_spacing_position(v)
							draw_tool(v)

	_fill_inside_rect = Rect2i()
	super.draw_end(pos)
	commit_undo()
	cursor_text = ""
	update_random_image()
	_spacing_mode = _old_spacing_mode


func _draw_brush_image(brush_image: Image, src_rect: Rect2i, dst: Vector2i) -> void:
	_changed = true
	var images := _get_selected_draw_images()
	if _overwrite:
		for draw_image in images:
			if Tools.alpha_locked:
				var mask := draw_image.get_region(Rect2i(dst, brush_image.get_size()))
				draw_image.blit_rect_mask(brush_image, mask, src_rect, dst)
			else:
				draw_image.blit_rect(brush_image, src_rect, dst)
			draw_image.convert_rgb_to_indexed()
	else:
		for draw_image in images:
			if Tools.alpha_locked:
				var mask := draw_image.get_region(Rect2i(dst, brush_image.get_size()))
				draw_image.blend_rect_mask(brush_image, mask, src_rect, dst)
			else:
				draw_image.blend_rect(brush_image, src_rect, dst)
			draw_image.convert_rgb_to_indexed()
