extends "res://src/Tools/Draw.gd"



var _start := Vector2.ZERO
var _dest := Vector2.ZERO
var _shapes := [
	ShapeToolOptions.Rectangle.new(),
	ShapeToolOptions.Ellipse.new(),
]
var _curr_shape: ShapeToolOptions.ShapeToolOption = _shapes[0]
var _curr_shape_i := 0 setget _set_curr_shape_i
var _fill := 0
var _drawing := false
var _thickness := 1
var _keep_preview := false
var _prev_rect := Rect2()


func _init() -> void:
	_drawer.color_op = Drawer.ColorOp.new()


func _ready() -> void:
	for shape in _shapes:
		$ShapesDropdown.add_item(shape.name)


func _on_Thickness_value_changed(value: int):
	_thickness = value
	update_config()
	save_config()


func _on_ShapesDropdown_item_selected(index: int) -> void:
	_set_curr_shape_i(index)
	update_config()
	save_config()


func _on_FillCheckbox_toggled(button_pressed: bool) -> void:
	_fill = button_pressed
	update_config()
	save_config()


func get_config() -> Dictionary:
	var config := .get_config()
	config["fill"] = _fill
	config["curr_shape"] = _curr_shape_i
	config["thickness"] = _thickness
	return config


func set_config(config: Dictionary) -> void:
	.set_config(config)
	_fill = config.get("fill", _fill)
	_set_curr_shape_i(config.get("curr_shape", _curr_shape_i))
	_thickness = config.get("thickness", _thickness)


func update_config() -> void:
	.update_config()
	$FillCheckbox.pressed = _fill
	$ShapesDropdown.select(_curr_shape_i)
	$ThicknessSlider.value = _thickness
	$ThicknessSpinbox.value = _thickness


func draw_start(position : Vector2) -> void:
	update_mask()

	if Tools.control:
		_keep_preview = false
		_prev_rect = Rect2()

	if _keep_preview:
		_draw_shape(_prev_rect.position, _prev_rect.end)
		_prev_rect = Rect2()
		_keep_preview = false
	else:
		_start = position
		_dest = position
		_drawing = true


func draw_move(position : Vector2) -> void:
	if _drawing:
		_dest = position


func cursor_move(position : Vector2):
	.cursor_move(position)
	if _keep_preview:
		_prev_rect.position = position


func draw_end(position : Vector2) -> void:
	if _drawing:
		if Tools.control:
			_prev_rect = _get_result_rect(_start, position)
			_keep_preview = true
		else:
			_draw_shape(_start, position)

		_start = Vector2.ZERO
		_dest = Vector2.ZERO
		_drawing = false


func draw_preview() -> void:
	if _drawing or _keep_preview:
		var canvas = Global.canvas.previews
		var indicator := BitMap.new()
		var rect := _get_result_rect(_start, _dest) if not _keep_preview else _get_result_rect(_prev_rect.position, _prev_rect.end)
		var points := _get_shape_points(rect.size)
		var t_offset := _thickness - 1
		var t_offsetv := Vector2(t_offset, t_offset)
		indicator.create(rect.size + t_offsetv * 2)
		for point in points:
			indicator.set_bit(point + t_offsetv, 1)

		var polylines = _create_polylines(indicator)

		canvas.draw_set_transform(rect.position - t_offsetv, canvas.rotation, canvas.scale)
		for line in polylines:
			var pool := PoolVector2Array(line)
			canvas.draw_polyline(pool, tool_slot.color)
		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func _draw_shape(origin: Vector2, dest: Vector2) -> void:
	var rect := _get_result_rect(origin, dest)
	var points := _get_shape_points(rect.size)
	prepare_undo()
	for point in points:
		# Reset drawer every time because pixel perfect sometimes brake the tool
		_drawer.reset()
		draw_tool(rect.position + point)

	commit_undo("Draw Shape")


func _get_result_rect(origin: Vector2, dest: Vector2) -> Rect2:
	var rect := Rect2(Vector2.ZERO, Vector2.ZERO)

	if Tools.alt:
		var new_size := (dest - origin).floor()
		new_size = (new_size / 2).floor() if _keep_preview else new_size
		if Tools.shift and not _keep_preview:
			var _square_size := max(abs(new_size.x), abs(new_size.y))
			new_size = Vector2(_square_size, _square_size)

		origin -= new_size
		dest = origin + 2 * new_size

	if Tools.shift and not Tools.alt and not _keep_preview:
		var square_size := min(abs(origin.x - dest.x), abs(origin.y - dest.y))
		rect.position.x = origin.x if origin.x < dest.x else origin.x - square_size
		rect.position.y = origin.y if origin.y < dest.y else origin.y - square_size
		rect.size = Vector2(square_size, square_size)
	else:
		rect.position = Vector2(min(origin.x, dest.x), min(origin.y, dest.y))
		rect.size = (origin - dest).abs()

	rect.size += Vector2.ONE
	return rect


func _get_shape_points(size: Vector2) -> PoolVector2Array:
	return _curr_shape.get_draw_points_filled(size, _thickness) if _fill else _curr_shape.get_draw_points(size, _thickness)


func _set_curr_shape_i(i: int) -> void:
	_curr_shape_i = i
	_curr_shape = _shapes[i]


