extends "res://src/Tools/Base.gd"


var _brush := Brushes.get_default_brush()
var _brush_size := 1
var _brush_interpolate := 0
var _brush_image := Image.new()
var _brush_texture := ImageTexture.new()
var _strength := 1.0

var _undo_data := {}
var _drawer := Drawer.new()
var _mask := PoolByteArray()
var _mirror_brushes := {}

var _draw_line := false
var _line_start := Vector2.ZERO
var _line_end := Vector2.ZERO

var _indicator := BitMap.new()
var _polylines := []
var _line_polylines := []

func _ready() -> void:
	Tools.connect("color_changed", self, "_on_Color_changed")
	Global.brushes_popup.connect("brush_removed", self, "_on_Brush_removed")


func _on_BrushType_pressed() -> void:
	if not Global.brushes_popup.is_connected("brush_selected", self, "_on_Brush_selected"):
		Global.brushes_popup.connect("brush_selected", self, "_on_Brush_selected", [], CONNECT_ONESHOT)
	Global.brushes_popup.popup(Rect2($Brush/Type.rect_global_position, Vector2(226, 72)))


func _on_Brush_selected(brush : Brushes.Brush) -> void:
	_brush = brush
	update_brush()
	save_config()


func _on_BrushSize_value_changed(value : float) -> void:
	_brush_size = int(value)
	update_config()
	save_config()


func _on_InterpolateFactor_value_changed(value : float) -> void:
	_brush_interpolate = int(value)
	update_config()
	save_config()


func _on_Color_changed(_color : Color, _button : int) -> void:
	update_brush()


func _on_Brush_removed(brush : Brushes.Brush) -> void:
	if brush == _brush:
		_brush = Brushes.get_default_brush()
		update_brush()
		save_config()


func get_config() -> Dictionary:
	return {
		"brush_type" : _brush.type,
		"brush_index" : _brush.index,
		"brush_size" : _brush_size,
		"brush_interpolate" : _brush_interpolate,
	}


func set_config(config : Dictionary) -> void:
	var type = config.get("brush_type", _brush.type)
	var index = config.get("brush_index", _brush.index)
	_brush = Global.brushes_popup.get_brush(type, index)
	_brush_size = config.get("brush_size", _brush_size)
	_brush_interpolate = config.get("brush_interpolate", _brush_interpolate)


func update_config() -> void:
	$Brush/Size.value = _brush_size
	$BrushSize.value = _brush_size
	$ColorInterpolation/Factor.value = _brush_interpolate
	$ColorInterpolation/Slider.value = _brush_interpolate
	update_brush()


func update_brush() -> void:
	match _brush.type:
		Brushes.PIXEL:
			_brush_texture.create_from_image(load("res://assets/graphics/pixel_image.png"), 0)
		Brushes.CIRCLE:
			_brush_texture.create_from_image(load("res://assets/graphics/circle_9x9.png"), 0)
		Brushes.FILLED_CIRCLE:
			_brush_texture.create_from_image(load("res://assets/graphics/circle_filled_9x9.png"), 0)
		Brushes.FILE, Brushes.RANDOM_FILE, Brushes.CUSTOM:
			if _brush.random.size() <= 1:
				_brush_image = _create_blended_brush_image(_brush.image)
			else:
				var random = randi() % _brush.random.size()
				_brush_image = _create_blended_brush_image(_brush.random[random])
			_brush_image.lock()
			_brush_texture.create_from_image(_brush_image, 0)
			update_mirror_brush()
	_indicator = _create_brush_indicator()
	_polylines = _create_polylines(_indicator)
	$Brush/Type/Texture.texture = _brush_texture
	$ColorInterpolation.visible = _brush.type in [Brushes.FILE, Brushes.RANDOM_FILE, Brushes.CUSTOM]


func update_random_image() -> void:
	if _brush.type != Brushes.RANDOM_FILE:
		return
	var random = randi() % _brush.random.size()
	_brush_image = _create_blended_brush_image(_brush.random[random])
	_brush_image.lock()
	_brush_texture.create_from_image(_brush_image, 0)
	_indicator = _create_brush_indicator()
	update_mirror_brush()


func update_mirror_brush() -> void:
	_mirror_brushes.x = _brush_image.duplicate()
	_mirror_brushes.x.flip_x()
	_mirror_brushes.y = _brush_image.duplicate()
	_mirror_brushes.y.flip_y()
	_mirror_brushes.xy = _mirror_brushes.x.duplicate()
	_mirror_brushes.xy.flip_y()


func update_mask() -> void:
	var size := _get_draw_image().get_size()
	_mask = PoolByteArray()
	_mask.resize(size.x * size.y)
	for i in _mask.size():
		_mask[i] = 0


func update_line_polylines(start : Vector2, end : Vector2) -> void:
	var indicator := _create_line_indicator(_indicator, start, end)
	_line_polylines = _create_polylines(indicator)


func restore_image() -> void:
	var project : Project = Global.current_project
	var image = project.frames[project.current_frame].cels[project.current_layer].image
	image.unlock()
	image.data = _undo_data[image]
	image.lock()


func prepare_undo() -> void:
	_undo_data = _get_undo_data()


func commit_undo(action : String) -> void:
	var redo_data = _get_undo_data()
	var project : Project = Global.current_project
	var frame := -1
	var layer := -1
	if Global.animation_timer.is_stopped():
		frame = project.current_frame
		layer = project.current_layer

	project.undos += 1
	project.undo_redo.create_action(action)
	for image in redo_data:
		project.undo_redo.add_do_property(image, "data", redo_data[image])
	for image in _undo_data:
		project.undo_redo.add_undo_property(image, "data", _undo_data[image])
	project.undo_redo.add_do_method(Global, "redo", frame, layer)
	project.undo_redo.add_undo_method(Global, "undo", frame, layer)
	project.undo_redo.commit_action()

	_undo_data.clear()


func draw_tool(position : Vector2) -> void:
	if Global.current_project.layers[Global.current_project.current_layer].locked:
		return
	var strength := _strength
	if Global.pressure_sensitivity_mode == Global.Pressure_Sensitivity.ALPHA:
		strength *= Tools.pen_pressure

	_drawer.pixel_perfect = tool_slot.pixel_perfect if _brush_size == 1 else false
	_drawer.horizontal_mirror = tool_slot.horizontal_mirror
	_drawer.vertical_mirror = tool_slot.vertical_mirror
	_drawer.color_op.strength = strength

	match _brush.type:
		Brushes.PIXEL:
			draw_tool_pixel(position)
		Brushes.CIRCLE:
			draw_tool_circle(position, false)
		Brushes.FILLED_CIRCLE:
			draw_tool_circle(position, true)
		_:
			draw_tool_brush(position)


# Bresenham's Algorithm
# Thanks to https://godotengine.org/qa/35276/tile-based-line-drawing-algorithm-efficiency
func draw_fill_gap(start : Vector2, end : Vector2) -> void:
	var dx := int(abs(end.x - start.x))
	var dy := int(-abs(end.y - start.y))
	var err := dx + dy
	var e2 := err << 1
	var sx = 1 if start.x < end.x else -1
	var sy = 1 if start.y < end.y else -1
	var x = start.x
	var y = start.y
	while !(x == end.x && y == end.y):
		e2 = err << 1
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
		draw_tool(Vector2(x, y))


func draw_tool_pixel(position : Vector2) -> void:
	var start := position - Vector2.ONE * (_brush_size >> 1)
	var end := start + Vector2.ONE * _brush_size
	for y in range(start.y, end.y):
		for x in range(start.x, end.x):
			_set_pixel(Vector2(x, y))


# Algorithm based on http://members.chello.at/easyfilter/bresenham.html
func draw_tool_circle(position : Vector2, fill := false) -> void:
	var r := _brush_size
	var x := -r
	var y := 0
	var err := 2 - r * 2
	var draw := true
	if fill:
		_set_pixel(position)
	while x < 0:
		if draw:
			for i in range(1 if fill else -x, -x + 1):
				_set_pixel(position + Vector2(-i, y))
				_set_pixel(position + Vector2(-y, -i))
				_set_pixel(position + Vector2(i, -y))
				_set_pixel(position + Vector2(y, i))
		draw = not fill
		r = err
		if r <= y:
			y += 1
			err += y * 2 + 1
			draw = true
		if r > x || err > y:
			x += 1
			err += x * 2 + 1


func draw_tool_brush(position : Vector2) -> void:
	if Global.mirror_view:
		position.x = Global.current_project.size.x - position.x

	if Global.current_project.tile_mode and _get_tile_mode_rect().has_point(position):
		position = position.posmodv(Global.current_project.size)

	var size := _brush_image.get_size()
	var dst := position - (size / 2).floor()
	var dst_rect := Rect2(dst, size)
	var draw_rect := _get_draw_rect()
	dst_rect = dst_rect.clip(draw_rect)
	if dst_rect.size == Vector2.ZERO:
		return
	var src_rect := Rect2(dst_rect.position - dst, dst_rect.size)
	dst = dst_rect.position

	var project : Project = Global.current_project
	_draw_brush_image(_brush_image, src_rect, dst)

	# Handle Mirroring
	var mirror_x = (project.x_symmetry_point + 1) - dst.x - src_rect.size.x
	var mirror_y = (project.y_symmetry_point + 1) - dst.y - src_rect.size.y
	var mirror_x_inside : bool
	var mirror_y_inside : bool
	var entire_image_selected : bool = project.selected_pixels.size() == project.size.x * project.size.y
	if entire_image_selected:
		mirror_x_inside = mirror_x >= 0 and mirror_x < project.size.x
		mirror_y_inside = mirror_y >= 0 and mirror_y < project.size.y
	else:
		var selected_pixels_x := []
		var selected_pixels_y := []
		for i in project.selected_pixels:
			selected_pixels_x.append(i.x)
			selected_pixels_y.append(i.y)

		mirror_x_inside = mirror_x in selected_pixels_x
		mirror_y_inside = mirror_y in selected_pixels_y

	if tool_slot.horizontal_mirror and mirror_x_inside:
		_draw_brush_image(_mirror_brushes.x, _flip_rect(src_rect, size, true, false), Vector2(mirror_x, dst.y))
		if tool_slot.vertical_mirror and mirror_y_inside:
			_draw_brush_image(_mirror_brushes.xy, _flip_rect(src_rect, size, true, true), Vector2(mirror_x, mirror_y))
	if tool_slot.vertical_mirror and mirror_y_inside:
		_draw_brush_image(_mirror_brushes.y, _flip_rect(src_rect, size, false, true), Vector2(dst.x, mirror_y))


func draw_indicator() -> void:
	draw_indicator_at(_cursor, Vector2.ZERO, Color.blue)
	if Global.current_project.tile_mode and _get_tile_mode_rect().has_point(_cursor):
		var tile := _line_start if _draw_line else _cursor
		if not tile in Global.current_project.selected_pixels:
			var offset := tile - tile.posmodv(Global.current_project.size)
			draw_indicator_at(_cursor, offset, Color.green)


func draw_indicator_at(position : Vector2, offset : Vector2, color : Color) -> void:
	var canvas = Global.canvas.indicators
	if _brush.type in [Brushes.FILE, Brushes.RANDOM_FILE, Brushes.CUSTOM] and not _draw_line:
		position -= (_brush_image.get_size() / 2).floor()
		position -= offset
		canvas.draw_texture(_brush_texture, position)
	else:
		if _draw_line:
			position.x = _line_end.x if _line_end.x < _line_start.x else _line_start.x
			position.y = _line_end.y if _line_end.y < _line_start.y else _line_start.y
		position -= (_indicator.get_size() / 2).floor()
		position -= offset
		canvas.draw_set_transform(position, canvas.rotation, canvas.scale)
		var polylines := _line_polylines if _draw_line else _polylines
		for line in polylines:
			var pool := PoolVector2Array(line)
			canvas.draw_polyline(pool, color)
		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func _set_pixel(position : Vector2) -> void:
	var project : Project = Global.current_project
	if Global.mirror_view:
		position.x = project.size.x - position.x - 1
	if Global.current_project.tile_mode and _get_tile_mode_rect().has_point(position):
		position = position.posmodv(project.size)

	var entire_image_selected : bool = project.selected_pixels.size() == project.size.x * project.size.y
	if entire_image_selected:
		if not _get_draw_rect().has_point(position):
			return
	else:
		if not position in project.selected_pixels:
			return

	var image := _get_draw_image()
	var i := int(position.x + position.y * image.get_size().x)
	if _mask[i] < Tools.pen_pressure:
		_mask[i] = Tools.pen_pressure
		_drawer.set_pixel(image, position, tool_slot.color)


func _draw_brush_image(_image : Image, _src_rect: Rect2, _dst: Vector2) -> void:
	pass


func _create_blended_brush_image(image : Image) -> Image:
	var size := image.get_size() * _brush_size
	var brush := Image.new()
	brush.copy_from(image)
	brush = _blend_image(brush, tool_slot.color, _brush_interpolate / 100.0)
	brush.unlock()
	brush.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	return brush


func _blend_image(image : Image, color : Color, factor : float) -> Image:
	var size := image.get_size()
	image.lock()
	for y in size.y:
		for x in size.x:
			var color_old := image.get_pixel(x, y)
			if color_old.a > 0:
				var color_new := color_old.linear_interpolate(color, factor)
				color_new.a = color_old.a
				image.set_pixel(x, y, color_new)
	return image


func _create_brush_indicator() -> BitMap:
	match _brush.type:
		Brushes.PIXEL:
			return _create_pixel_indicator(_brush_size)
		Brushes.CIRCLE:
			return _create_circle_indicator(_brush_size, false)
		Brushes.FILLED_CIRCLE:
			return _create_circle_indicator(_brush_size, true)
		_:
			return _create_image_indicator(_brush_image)


func _create_image_indicator(image : Image) -> BitMap:
			var bitmap := BitMap.new()
			bitmap.create_from_image_alpha(image, 0.0)
			return bitmap


func _create_pixel_indicator(size : int) -> BitMap:
	var bitmap := BitMap.new()
	bitmap.create(Vector2.ONE * size)
	bitmap.set_bit_rect(Rect2(Vector2.ZERO, Vector2.ONE * size), true)
	return bitmap


func _create_circle_indicator(size : int, fill := false) -> BitMap:
	var bitmap := BitMap.new()
	bitmap.create(Vector2.ONE * (size * 2 + 1))
	var position := Vector2(size, size)

	var r := size
	var x := -r
	var y := 0
	var err := 2 - r * 2
	var draw := true
	if fill:
		bitmap.set_bit(position, true)
	while x < 0:
		if draw:
			for i in range(1 if fill else -x, -x + 1):
				bitmap.set_bit(position + Vector2(-i, y), true)
				bitmap.set_bit(position + Vector2(-y, -i), true)
				bitmap.set_bit(position + Vector2(i, -y), true)
				bitmap.set_bit(position + Vector2(y, i), true)
		draw = not fill
		r = err
		if r <= y:
			y += 1
			err += y * 2 + 1
			draw = true
		if r > x || err > y:
			x += 1
			err += x * 2 + 1
	return bitmap


func _create_line_indicator(indicator : BitMap, start : Vector2, end : Vector2) -> BitMap:
	var bitmap := BitMap.new()
	var size := (end - start).abs() + indicator.get_size()
	bitmap.create(size)

	var offset := (indicator.get_size() / 2).floor()
	var diff := end - start
	start.x = -diff.x if diff.x < 0 else 0.0
	end.x = 0.0 if diff.x < 0 else diff.x
	start.y = -diff.y if diff.y < 0 else 0.0
	end.y = 0.0 if diff.y < 0 else diff.y
	start += offset
	end += offset

	var dx := int(abs(end.x - start.x))
	var dy := int(-abs(end.y - start.y))
	var err := dx + dy
	var e2 := err << 1
	var sx = 1 if start.x < end.x else -1
	var sy = 1 if start.y < end.y else -1
	var x = start.x
	var y = start.y
	while !(x == end.x && y == end.y):
		_blit_indicator(bitmap, indicator, Vector2(x, y))
		e2 = err << 1
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	_blit_indicator(bitmap, indicator, Vector2(x, y))
	return bitmap


func _blit_indicator(dst : BitMap, indicator : BitMap, position : Vector2) -> void:
	var rect := Rect2(Vector2.ZERO, dst.get_size())
	var size := indicator.get_size()
	position -= (size / 2).floor()
	for y in size.y:
		for x in size.x:
			var pos := Vector2(x, y)
			var bit := indicator.get_bit(pos)
			pos += position
			if bit and rect.has_point(pos):
				dst.set_bit(pos, bit)


func _line_angle_constraint(start : Vector2, end : Vector2) -> Dictionary:
	var result := {}
	var angle := rad2deg(end.angle_to_point(start))
	var distance := start.distance_to(end)
	if Tools.control:
		if tool_slot.pixel_perfect:
			angle = stepify(angle, 22.5)
			if step_decimals(angle) != 0:
				var diff := end - start
				var v := Vector2(2 , 1) if abs(diff.x) > abs(diff.y) else Vector2(1 , 2)
				var p := diff.project(diff.sign() * v).abs().round()
				var f := p.y if abs(diff.x) > abs(diff.y) else p.x
				end = start + diff.sign() * v * f - diff.sign()
				angle = rad2deg(atan2(sign(diff.y) * v.y, sign(diff.x) * v.x))
			else:
				end = start + Vector2.RIGHT.rotated(deg2rad(angle)) * distance
		else:
			angle = stepify(angle, 15)
			end = start + Vector2.RIGHT.rotated(deg2rad(angle)) * distance
	angle *= -1
	angle += 360 if angle < 0 else 0
	result.text = str(stepify(angle, 0.01)) + "°"
	result.position = end.round()
	return result


func _get_undo_data() -> Dictionary:
	var data = {}
	var project : Project = Global.current_project
	var frames := project.frames
	if Global.animation_timer.is_stopped():
		frames = [project.frames[project.current_frame]]
	for frame in frames:
		var image : Image = frame.cels[project.current_layer].image
		image.unlock()
		data[image] = image.data
		image.lock()
	return data
