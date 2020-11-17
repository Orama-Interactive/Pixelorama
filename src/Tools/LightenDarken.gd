extends "res://src/Tools/Draw.gd"


enum ShadingMode {SIMPLE, HUE_SHIFTING}
enum LightenDarken {LIGHTEN, DARKEN}


var _last_position := Vector2.INF
var _changed := false
var _shading_mode : int = ShadingMode.SIMPLE
var _mode : int = LightenDarken.LIGHTEN
var _amount := 10
var _hue_amount := 10
var _sat_amount := 10
var _value_amount := 10


class LightenDarkenOp extends Drawer.ColorOp:
	var changed := false
	var shading_mode : int = ShadingMode.SIMPLE
	var lighten_or_darken : int = LightenDarken.LIGHTEN
	var hue_amount := 10.0
	var sat_amount := 10.0
	var value_amount := 10.0

	var hue_lighten_limit := 60.0 / 359.0
	var hue_darken_limit := 270.0 / 359.0

	var sat_lighten_limit := 10.0 / 100.0
	var value_darken_limit := 10.0 / 100.0


	func process(_src: Color, dst: Color) -> Color:
		changed = true
		if dst.a == 0:
			return dst
		if shading_mode == ShadingMode.SIMPLE:
			if strength > 0:
				dst = dst.lightened(strength)
			elif strength < 0:
				dst = dst.darkened(-strength)
		else:
			var hue_shift := hue_amount / 359.0
			var sat_shift := sat_amount / 100.0
			var value_shift := value_amount / 100.0

			var prev_hue := dst.h
			var prev_sat := dst.s
			var prev_value := dst.v

			# If the colors are roughly between yellow and purple,
			# reverse hue direction
			if !hue_range(dst.h):
				hue_shift = -hue_shift

			if lighten_or_darken == LightenDarken.LIGHTEN:
				hue_shift = hue_limit_lighten(dst.h, hue_shift)
				dst.h += hue_shift
				dst.s -= sat_shift
				dst.v += value_shift
				if dst.s < sat_lighten_limit:
					dst.v = prev_value
					dst.s = prev_sat
					dst.h = prev_hue

			else:
				hue_shift = hue_limit_darken(dst.h, hue_shift)
				dst.h -= hue_shift
				dst.s += sat_shift
				dst.v -= value_shift
				if dst.v < value_darken_limit:
					dst.v = prev_value

		return dst


	# Returns true if the colors are roughly between red and yellow, and purple and red
	# False when the colors are roughly between yellow and purple (includes green & blue)
	func hue_range(hue : float) -> bool:
		return hue < hue_lighten_limit or hue > hue_darken_limit


	func hue_limit_lighten(hue : float, hue_shift : float) -> float:
		# Colors between red-yellow and purple-red
		if hue_shift > 0:
			# Just colors between red-yellow
			if hue < hue_darken_limit:
				if hue + hue_shift >= hue_lighten_limit:
					hue_shift = 0

		# Colors between yellow-purple
		elif hue_shift < 0 and hue + hue_shift <= hue_lighten_limit:
			hue_shift = 0
		return hue_shift


	func hue_limit_darken(hue : float, hue_shift : float) -> float:
		# Colors between red-yellow and purple-red
		if hue_shift > 0:
			# Just colors between purple-red
			if hue > hue_darken_limit:
				if hue + hue_shift <= hue_darken_limit:
					hue_shift = 0

		# Colors between yellow-purple
		elif hue_shift < 0 and hue + hue_shift <= hue_darken_limit:
			hue_shift = 0
		return hue_shift


func _init() -> void:
	_drawer.color_op = LightenDarkenOp.new()


func _on_ShadingMode_item_selected(id : int) -> void:
	_shading_mode = id
	_drawer.color_op.shading_mode = id
	update_config()
	save_config()


func _on_LightenDarken_item_selected(id : int) -> void:
	_mode = id
	_drawer.color_op.lighten_or_darken = id
	update_config()
	save_config()


func _on_LightenDarken_value_changed(value : float) -> void:
	_amount = int(value)
	update_config()
	save_config()


func _on_LightenDarken_hue_value_changed(value : float) -> void:
	_hue_amount = int(value)
	update_config()
	save_config()


func _on_LightenDarken_sat_value_changed(value : float) -> void:
	_sat_amount = int(value)
	update_config()
	save_config()


func _on_LightenDarken_value_value_changed(value : float) -> void:
	_value_amount = int(value)
	update_config()
	save_config()


func get_config() -> Dictionary:
	var config := .get_config()
	config["shading_mode"] = _shading_mode
	config["mode"] = _mode
	config["amount"] = _amount
	config["hue_amount"] = _hue_amount
	config["sat_amount"] = _sat_amount
	config["value_amount"] = _value_amount
	return config


func set_config(config : Dictionary) -> void:
	.set_config(config)
	_shading_mode = config.get("shading_mode", _shading_mode)
	_drawer.color_op.shading_mode = _shading_mode
	_mode = config.get("mode", _mode)
	_drawer.color_op.lighten_or_darken = _mode
	_amount = config.get("amount", _amount)
	_hue_amount = config.get("hue_amount", _hue_amount)
	_sat_amount = config.get("sat_amount", _sat_amount)
	_value_amount = config.get("value_amount", _value_amount)


func update_config() -> void:
	.update_config()
	$ShadingMode.selected = _shading_mode
	$LightenDarken.selected = _mode
	$Amount/Spinbox.value = _amount
	$Amount/Slider.value = _amount
	$HueShiftingOptions/AmountHue/Spinbox.value = _hue_amount
	$HueShiftingOptions/AmountHue/Slider.value = _hue_amount
	$HueShiftingOptions/AmountSat/Spinbox.value = _sat_amount
	$HueShiftingOptions/AmountSat/Slider.value = _sat_amount
	$HueShiftingOptions/AmountValue/Spinbox.value = _value_amount
	$HueShiftingOptions/AmountValue/Slider.value = _value_amount
	$Amount.visible = _shading_mode == ShadingMode.SIMPLE
	$HueShiftingOptions.visible = _shading_mode == ShadingMode.HUE_SHIFTING
	update_strength()


func update_strength() -> void:
	var factor = 1 if _mode == 0 else -1
	_strength = _amount * factor / 100.0

	_drawer.color_op.hue_amount = _hue_amount
	_drawer.color_op.sat_amount = _sat_amount
	_drawer.color_op.value_amount = _value_amount


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


func _draw_brush_image(_image : Image, _src_rect: Rect2, _dst: Vector2) -> void:
	_changed = true
	draw_tool_pixel(_cursor.floor())
