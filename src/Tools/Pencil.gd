extends "res://src/Tools/Draw.gd"


var _prev_mode := false
var _last_position := Vector2.INF
var _changed := false
var _overwrite := false
var _fill_inside := false
var _draw_points := Array()


class PencilOp extends Drawer.ColorOp:
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


func _on_Overwrite_toggled(button_pressed : bool):
	_overwrite = button_pressed
	update_config()
	save_config()


func _on_FillInside_toggled(button_pressed):
	_fill_inside = button_pressed
	update_config()
	save_config()


func _input(event: InputEvent) -> void:
	var overwrite_button : CheckBox = $Overwrite

	if event.is_action_pressed("ctrl"):
		_prev_mode = overwrite_button.pressed
	if event.is_action("ctrl"):
		overwrite_button.pressed = !_prev_mode
		_overwrite = overwrite_button.pressed
	if event.is_action_released("ctrl"):
		overwrite_button.pressed = _prev_mode
		_overwrite = overwrite_button.pressed


func get_config() -> Dictionary:
	var config := .get_config()
	config["overwrite"] = _overwrite
	config["fill_inside"] = _fill_inside
	return config


func set_config(config : Dictionary) -> void:
	.set_config(config)
	_overwrite = config.get("overwrite", _overwrite)
	_fill_inside = config.get("fill_inside", _fill_inside)


func update_config() -> void:
	.update_config()
	$Overwrite.pressed = _overwrite
	$FillInside.pressed = _fill_inside


func draw_start(position : Vector2) -> void:
	if Input.is_action_pressed("alt"):
		_picking_color = true
		_pick_color(position)
		return
	_picking_color = false

	Global.canvas.selection.transform_content_confirm()
	update_mask()
	_changed = false
	_drawer.color_op.changed = false
	_drawer.color_op.overwrite = _overwrite
	_draw_points = Array()

	prepare_undo()
	_drawer.reset()

	_draw_line = Tools.shift
	if _draw_line:
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


func draw_move(position : Vector2) -> void:
	if _picking_color: # Still return even if we released Alt
		if Input.is_action_pressed("alt"):
			_pick_color(position)
		return

	if _draw_line:
		var d = _line_angle_constraint(_line_start, position)
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


func draw_end(_position : Vector2) -> void:
	if _picking_color:
		return

	if _draw_line:
		draw_tool(_line_start)
		draw_fill_gap(_line_start, _line_end)
		_draw_line = false
	else:
		if _fill_inside:
			_draw_points.append(_position)
			if _draw_points.size() > 3:
				var v = Vector2()
				var image_size = Global.current_project.size
				for x in image_size.x:
					v.x = x
					for y in image_size.y:
						v.y = y
						if Geometry.is_point_in_polygon(v, _draw_points):
							draw_tool(v)
	if _changed or _drawer.color_op.changed:
		commit_undo("Draw")
	cursor_text = ""
	update_random_image()


func _draw_brush_image(image : Image, src_rect: Rect2, dst: Vector2) -> void:
	_changed = true
	var images := _get_selected_draw_images()
	if _overwrite:
		for draw_image in images:
			draw_image.blit_rect(image, src_rect, dst)
	else:
		for draw_image in images:
			draw_image.blend_rect(image, src_rect, dst)
