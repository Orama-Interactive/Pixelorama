extends "res://src/Tools/BaseDraw.gd"

enum ShadingMode { SIMPLE, HUE_SHIFTING }
enum LightenDarken { LIGHTEN, DARKEN }

var _prev_mode := 0
var _last_position := Vector2.INF
var _changed := false
var _shading_mode: int = ShadingMode.SIMPLE
var _mode: int = LightenDarken.LIGHTEN
var _amount := 10
var _hue_amount := 10
var _sat_amount := 10
var _value_amount := 10


class LightenDarkenOp:
	extends Drawer.ColorOp
	var changed := false
	var shading_mode := ShadingMode.SIMPLE
	var lighten_or_darken := LightenDarken.LIGHTEN
	var hue_amount := 10.0
	var sat_amount := 10.0
	var value_amount := 10.0

	var hue_lighten_limit := 60.0 / 360.0  # A yellow color
	var hue_darken_limit := 240.0 / 360.0  # A blue color

	var sat_lighten_limit := 10.0 / 100.0
	var value_darken_limit := 10.0 / 100.0

	func process(_src: Color, dst: Color) -> Color:
		changed = true
		if dst.a == 0:
			return dst
		if shading_mode == ShadingMode.SIMPLE:
			if lighten_or_darken == LightenDarken.LIGHTEN:
				dst = dst.lightened(strength)
			else:
				dst = dst.darkened(strength)
		else:
			var hue_shift := hue_amount / 360.0
			var sat_shift := sat_amount / 100.0
			var value_shift := value_amount / 100.0

			# If the colors are roughly between yellow-green-blue,
			# reverse hue direction
			if hue_range(dst.h):
				hue_shift = -hue_shift

			if lighten_or_darken == LightenDarken.LIGHTEN:
				hue_shift = hue_limit_lighten(dst.h, hue_shift)
				dst.h = fposmod(dst.h + hue_shift, 1)
				if dst.s > sat_lighten_limit:
					dst.s = maxf(dst.s - minf(sat_shift, dst.s), sat_lighten_limit)
				dst.v += value_shift

			else:
				hue_shift = hue_limit_darken(dst.h, hue_shift)
				dst.h = fposmod(dst.h - hue_shift, 1)
				dst.s += sat_shift
				if dst.v > value_darken_limit:
					dst.v = maxf(dst.v - minf(value_shift, dst.v), value_darken_limit)

		return dst

	# Returns true if the colors are roughly between yellow, green and blue
	# False when the colors are roughly between red-orange-yellow, or blue-purple-red
	func hue_range(hue: float) -> bool:
		return hue > hue_lighten_limit and hue < hue_darken_limit

	func hue_limit_lighten(hue: float, hue_shift: float) -> float:
		# Colors between red-orange-yellow and blue-purple-red
		if hue_shift > 0:
			# Just colors between red-orange-yellow
			if hue < hue_darken_limit:
				if hue + hue_shift >= hue_lighten_limit:
					hue_shift = hue_lighten_limit - hue
			# Just blue-purple-red
			else:
				if hue + hue_shift >= hue_lighten_limit + 1:  # +1 looping around the color wheel
					hue_shift = hue_lighten_limit - hue

		# Colors between yellow-green-blue
		elif hue_shift < 0 and hue + hue_shift <= hue_lighten_limit:
			hue_shift = hue_lighten_limit - hue
		return hue_shift

	func hue_limit_darken(hue: float, hue_shift: float) -> float:
		# Colors between red-orange-yellow and blue-purple-red
		if hue_shift > 0:
			# Just colors between red-orange-yellow
			if hue < hue_darken_limit:
				if hue - hue_shift <= hue_darken_limit - 1:  # -1 looping backwards around the color wheel
					hue_shift = hue - hue_darken_limit
			# Just blue-purple-red
			else:
				if hue - hue_shift <= hue_darken_limit:
					hue_shift = hue - hue_darken_limit

		# Colors between yellow-green-blue
		elif hue_shift < 0 and hue - hue_shift >= hue_darken_limit:
			hue_shift = hue - hue_darken_limit
		return hue_shift


func _init() -> void:
	_drawer.color_op = LightenDarkenOp.new()


func _input(event: InputEvent) -> void:
	var options: OptionButton = $LightenDarken

	if event.is_action_pressed("change_tool_mode"):
		_prev_mode = options.selected
	if event.is_action("change_tool_mode"):
		options.selected = _prev_mode ^ 1
		_mode = options.selected
		_drawer.color_op.lighten_or_darken = _mode
	if event.is_action_released("change_tool_mode"):
		options.selected = _prev_mode
		_mode = options.selected
		_drawer.color_op.lighten_or_darken = _mode


func _on_ShadingMode_item_selected(id: int) -> void:
	_shading_mode = id
	_drawer.color_op.shading_mode = id
	update_config()
	save_config()


func _on_LightenDarken_item_selected(id: int) -> void:
	_mode = id
	_drawer.color_op.lighten_or_darken = id
	update_config()
	save_config()


func _on_LightenDarken_value_changed(value: float) -> void:
	_amount = int(value)
	update_config()
	save_config()


func _on_LightenDarken_hue_value_changed(value: float) -> void:
	_hue_amount = int(value)
	update_config()
	save_config()


func _on_LightenDarken_sat_value_changed(value: float) -> void:
	_sat_amount = int(value)
	update_config()
	save_config()


func _on_LightenDarken_value_value_changed(value: float) -> void:
	_value_amount = int(value)
	update_config()
	save_config()


func get_config() -> Dictionary:
	var config := super.get_config()
	config["shading_mode"] = _shading_mode
	config["mode"] = _mode
	config["amount"] = _amount
	config["hue_amount"] = _hue_amount
	config["sat_amount"] = _sat_amount
	config["value_amount"] = _value_amount
	return config


func set_config(config: Dictionary) -> void:
	super.set_config(config)
	_shading_mode = config.get("shading_mode", _shading_mode)
	_drawer.color_op.shading_mode = _shading_mode
	_mode = config.get("mode", _mode)
	_drawer.color_op.lighten_or_darken = _mode
	_amount = config.get("amount", _amount)
	_hue_amount = config.get("hue_amount", _hue_amount)
	_sat_amount = config.get("sat_amount", _sat_amount)
	_value_amount = config.get("value_amount", _value_amount)


func update_config() -> void:
	super.update_config()
	$ShadingMode.selected = _shading_mode
	$LightenDarken.selected = _mode
	$AmountSlider.value = _amount
	$HueShiftingOptions/HueSlider.value = _hue_amount
	$HueShiftingOptions/SatSlider.value = _sat_amount
	$HueShiftingOptions/ValueSlider.value = _value_amount
	$AmountSlider.visible = _shading_mode == ShadingMode.SIMPLE
	$HueShiftingOptions.visible = _shading_mode == ShadingMode.HUE_SHIFTING
	update_strength()


func update_strength() -> void:
	_strength = _amount / 100.0

	_drawer.color_op.hue_amount = _hue_amount
	_drawer.color_op.sat_amount = _sat_amount
	_drawer.color_op.value_amount = _value_amount


func draw_start(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super.draw_start(pos)
	if Input.is_action_pressed("draw_color_picker"):
		_picking_color = true
		_pick_color(pos)
		return
	_picking_color = false

	Global.canvas.selection.transform_content_confirm()
	update_mask(false)
	_changed = false
	_drawer.color_op.changed = false

	prepare_undo("Draw")
	_drawer.reset()

	_draw_line = Input.is_action_pressed("draw_create_line")
	if _draw_line:
		if Global.mirror_view:
			# mirroring position is ONLY required by "Preview"
			pos.x = (Global.current_project.size.x - 1) - pos.x
		_line_start = pos
		_line_end = pos
		update_line_polylines(_line_start, _line_end)
	else:
		draw_tool(pos)
		_last_position = pos
		Global.canvas.sprite_changed_this_frame = true
	cursor_text = ""


func draw_move(pos_i: Vector2i) -> void:
	var pos := _get_stabilized_position(pos_i)
	pos = snap_position(pos)
	super.draw_move(pos)
	if _picking_color:  # Still return even if we released Alt
		if Input.is_action_pressed(&"draw_color_picker"):
			_pick_color(pos)
		return

	if _draw_line:
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


func draw_end(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super.draw_end(pos)
	if _picking_color:
		return

	if _draw_line:
		if Global.mirror_view:
			# now we revert back the coordinates from their mirror form so that line can be drawn
			_line_start.x = (Global.current_project.size.x - 1) - _line_start.x
			_line_end.x = (Global.current_project.size.x - 1) - _line_end.x
		draw_tool(_line_start)
		draw_fill_gap(_line_start, _line_end)
		_draw_line = false

	commit_undo()
	cursor_text = ""
	update_random_image()


func _draw_brush_image(image: Image, src_rect: Rect2i, dst: Vector2i) -> void:
	_changed = true
	for xx in image.get_size().x:
		for yy in image.get_size().y:
			if image.get_pixel(xx, yy).a > 0:
				var pos := Vector2i(xx, yy) + dst - src_rect.position
				_set_pixel(pos, true)


func update_brush() -> void:
	super.update_brush()
	$ColorInterpolation.visible = false
