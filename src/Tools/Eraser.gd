extends "res://src/Tools/Draw.gd"

var _last_position := Vector2.INF
var _clear_image := Image.new()
var _changed := false


class EraseOp:
	extends Drawer.ColorOp
	var changed := false

	func process(_src: Color, dst: Color) -> Color:
		changed = true
		dst.a -= strength
		if dst.a <= 0:
			dst = Color(0, 0, 0, 0)
		return dst


func _init() -> void:
	_drawer.color_op = EraseOp.new()
	_clear_image.create(1, 1, false, Image.FORMAT_RGBA8)
	_clear_image.fill(Color(0, 0, 0, 0))


func get_config() -> Dictionary:
	var config := .get_config()
	config["strength"] = _strength
	return config


func set_config(config: Dictionary) -> void:
	.set_config(config)
	_strength = config.get("strength", _strength)


func draw_start(position: Vector2) -> void:
	position = snap_position(position)
	.draw_start(position)
	if Input.is_action_pressed("draw_color_picker"):
		_picking_color = true
		_pick_color(position)
		return
	_picking_color = false

	Global.canvas.selection.transform_content_confirm()
	update_mask(_strength == 1)
	_changed = false
	_drawer.color_op.changed = false

	prepare_undo("Draw")
	_drawer.reset()

	_draw_line = Input.is_action_pressed("draw_create_line")
	if _draw_line:
		_line_start = position
		_line_end = position
		update_line_polylines(_line_start, _line_end)
	else:
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
		var d := _line_angle_constraint(_line_start, position)
		_line_end = d.position
		cursor_text = d.text
		update_line_polylines(_line_start, _line_end)
	else:
		draw_fill_gap(_last_position, position)
		_last_position = position
		cursor_text = ""
		Global.canvas.sprite_changed_this_frame = true


func draw_end(position: Vector2) -> void:
	position = snap_position(position)
	.draw_end(position)
	if _picking_color:
		return

	if _draw_line:
		draw_tool(_line_start)
		draw_fill_gap(_line_start, _line_end)
		_draw_line = false

	commit_undo()
	cursor_text = ""
	update_random_image()


func _draw_brush_image(image: Image, src_rect: Rect2, dst: Vector2) -> void:
	_changed = true
	if _strength == 1:
		var size := image.get_size()
		if _clear_image.get_size() != size:
			_clear_image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)

		var images := _get_selected_draw_images()
		for draw_image in images:
			draw_image.blit_rect_mask(_clear_image, image, src_rect, dst)
	else:
		image.lock()
		for xx in image.get_size().x:
			for yy in image.get_size().y:
				if image.get_pixel(xx, yy).a > 0:
					var pos := Vector2(xx, yy) + dst - src_rect.position
					_set_pixel(pos, true)
		image.unlock()


func _on_Opacity_value_changed(value: float) -> void:
	_strength = value / 255
	update_config()
	save_config()


func update_config() -> void:
	.update_config()
	$OpacitySlider.value = _strength * 255


func update_brush() -> void:
	.update_brush()
	$ColorInterpolation.visible = false
