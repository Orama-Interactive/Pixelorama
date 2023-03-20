extends "res://src/Tools/Draw.gd"

var _prev_mode := false
var _last_position := Vector2.INF
var _changed := false
var _overwrite := false
var _fill_inside := false
var _draw_points := Array()
var _old_spacing_mode := false  # needed to reset spacing mode in case we change it


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


func _input(event: InputEvent) -> void:
	var overwrite_button: CheckBox = $Overwrite

	if event.is_action_pressed("change_tool_mode"):
		_prev_mode = overwrite_button.pressed
	if event.is_action("change_tool_mode"):
		overwrite_button.pressed = !_prev_mode
		_overwrite = overwrite_button.pressed
	if event.is_action_released("change_tool_mode"):
		overwrite_button.pressed = _prev_mode
		_overwrite = overwrite_button.pressed


func get_config() -> Dictionary:
	var config := .get_config()
	config["overwrite"] = _overwrite
	config["fill_inside"] = _fill_inside
	config["spacing_mode"] = _spacing_mode
	config["spacing"] = _spacing
	return config


func set_config(config: Dictionary) -> void:
	.set_config(config)
	_overwrite = config.get("overwrite", _overwrite)
	_fill_inside = config.get("fill_inside", _fill_inside)
	_spacing_mode = config.get("spacing_mode", _spacing_mode)
	_spacing = config.get("spacing", _spacing)


func update_config() -> void:
	.update_config()
	$Overwrite.pressed = _overwrite
	$FillInside.pressed = _fill_inside
	$SpacingMode.pressed = _spacing_mode
	$Spacing.visible = _spacing_mode
	$Spacing.value = _spacing


func draw_start(position: Vector2) -> void:
	_old_spacing_mode = _spacing_mode
	position = snap_position(position)
	.draw_start(position)
	if Input.is_action_pressed("draw_color_picker"):
		_picking_color = true
		_pick_color(position)
		return
	_picking_color = false

	Global.canvas.selection.transform_content_confirm()
	var can_skip_mask := true
	if tool_slot.color.a < 1 and !_overwrite:
		can_skip_mask = false
	update_mask(can_skip_mask)
	_changed = false
	_drawer.color_op.changed = false
	_drawer.color_op.overwrite = _overwrite
	_draw_points = Array()

	prepare_undo("Draw")
	_drawer.reset()

	_draw_line = Input.is_action_pressed("draw_create_line")
	if _draw_line:
		_spacing_mode = false  # spacing mode is disabled during line mode
		_line_start = position
		_line_end = position
		update_line_polylines(_line_start, _line_end)
	else:
		if _fill_inside:
			_draw_points.append(position)
		draw_tool(position)
		_last_position = position
		Global.canvas.sprite_changed_this_frame = true
	cursor_text = ""


func draw_move(position: Vector2) -> void:
	position = snap_position(position)
	.draw_move(position)
	if _picking_color:  # Still return even if we released Alt
		if Input.is_action_pressed("draw_color_picker"):
			_pick_color(position)
		return

	if _draw_line:
		_spacing_mode = false  # spacing mode is disabled during line mode
		var d := _line_angle_constraint(_line_start, position)
		_line_end = d.position
		cursor_text = d.text
		update_line_polylines(_line_start, _line_end)
	else:
		draw_fill_gap(_last_position, position)
		_last_position = position
		cursor_text = ""
		Global.canvas.sprite_changed_this_frame = true
		if _fill_inside:
			_draw_points.append(position)


func draw_end(position: Vector2) -> void:
	position = snap_position(position)
	.draw_end(position)
	if _picking_color:
		return

	if _draw_line:
		_spacing_mode = false  # spacing mode is disabled during line mode
		draw_tool(_line_start)
		draw_fill_gap(_line_start, _line_end)
		_draw_line = false
	else:
		if _fill_inside:
			_draw_points.append(position)
			if _draw_points.size() > 3:
				var v = Vector2()
				var image_size = Global.current_project.size
				for x in image_size.x:
					v.x = x
					for y in image_size.y:
						v.y = y
						if Geometry.is_point_in_polygon(v, _draw_points):
							if _spacing_mode:
								# use of get_spacing_position() in Pencil.gd is a rare case
								# (you would ONLY need _spacing_mode and _spacing in most cases)
								v = get_spacing_position(v)
							draw_tool(v)

	commit_undo()
	cursor_text = ""
	update_random_image()
	_spacing_mode = _old_spacing_mode


func _draw_brush_image(image: Image, src_rect: Rect2, dst: Vector2) -> void:
	_changed = true
	var images := _get_selected_draw_images()
	if _overwrite:
		for draw_image in images:
			draw_image.blit_rect(image, src_rect, dst)
	else:
		for draw_image in images:
			draw_image.blend_rect(image, src_rect, dst)
