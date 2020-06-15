extends "res://src/Tools/Draw.gd"


var _last_position := Vector2.INF
var _changed := false
var _mode := 0
var _amount := 10
var _factor := 1


class LightenDarkenOp extends Drawer.ColorOp:
	var changed := false


	func process(_src: Color, dst: Color) -> Color:
		changed = true
		if strength > 0:
			return dst.lightened(strength)
		elif strength < 0:
			return dst.darkened(-strength)
		else:
			return dst


func _init() -> void:
	_drawer.color_op = LightenDarkenOp.new()


func _on_LightenDarken_item_selected(id : int):
	_mode = id
	update_config()
	save_config()


func _on_LightenDarken_value_changed(value : float):
	_amount = value
	update_config()
	save_config()


func get_config() -> Dictionary:
	var config := .get_config()
	config["mode"] = _mode
	config["amount"] = _amount
	return config


func set_config(config : Dictionary) -> void:
	.set_config(config)
	_mode = config.get("mode", _mode)
	_amount = config.get("amount", _amount)


func update_config() -> void:
	.update_config()
	$LightenDarken.selected = _mode
	$Amount/Spinbox.value = _amount
	$Amount/Slider.value = _amount
	update_strength()


func update_strength() -> void:
	var factor = 1 if _mode == 0 else -1
	_strength = _amount * factor / 100.0


func draw_start(position : Vector2) -> void:
	update_mask()
	_changed = false
	_drawer.color_op.changed = false

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


func _draw_brush_image(_image : Image, src_rect: Rect2, dst: Vector2) -> void:
	_changed = true
	draw_tool_pixel(_cursor.floor())
