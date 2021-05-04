extends "res://src/Tools/Draw.gd"


var _last_position := Vector2.INF
var _changed := false
var _overwrite := false


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


func get_config() -> Dictionary:
	var config := .get_config()
	config["overwrite"] = _overwrite
	return config


func set_config(config : Dictionary) -> void:
	.set_config(config)
	_overwrite = config.get("overwrite", _overwrite)


func update_config() -> void:
	.update_config()
	$Overwrite.pressed = _overwrite


func draw_start(position : Vector2) -> void:
	Global.canvas.selection.transform_content_confirm()
	update_mask()
	_changed = false
	_drawer.color_op.changed = false
	_drawer.color_op.overwrite = _overwrite

	prepare_undo()
	_drawer.reset()

	_draw_line = Tools.shift
	if _draw_line:
		_line_start = position
		_line_end = position
		update_line_polylines(_line_start, _line_end)
	else:
		draw_tool(position)
		_last_position = position
		Global.canvas.sprite_changed_this_frame = true
	cursor_text = ""


func draw_move(position : Vector2) -> void:
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


func draw_end(_position : Vector2) -> void:
	if _draw_line:
		draw_tool(_line_start)
		draw_fill_gap(_line_start, _line_end)
		_draw_line = false
	if _changed or _drawer.color_op.changed:
		commit_undo("Draw")
	cursor_text = ""
	update_random_image()


func _draw_brush_image(image : Image, src_rect: Rect2, dst: Vector2) -> void:
	_changed = true
	if _overwrite:
		_get_draw_image().blit_rect(image, src_rect, dst)
	else:
		_get_draw_image().blend_rect(image, src_rect, dst)
