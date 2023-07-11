extends SelectionTool

var _brush_size := 2
var _brush := Brushes.get_default_brush()
var _indicator := BitMap.new()
var _polylines := []
var _brush_image := Image.new()
var _brush_texture: ImageTexture
var _circle_tool_shortcut: PackedVector2Array

var _last_position := Vector2.INF
var _draw_points := []


func get_config() -> Dictionary:
	var config := super.get_config()
	config["brush_type"] = _brush.type
	config["brush_index"] = _brush.index
	config["brush_size"] = _brush_size
	return config


func set_config(config: Dictionary) -> void:
	var type: int = config.get("brush_type", _brush.type)
	var index: int = config.get("brush_index", _brush.index)
	_brush = Global.brushes_popup.get_brush(type, index)
	_brush_size = config.get("brush_size", _brush_size)


func update_config() -> void:
	$Brush/BrushSize.value = _brush_size
	update_brush()


func draw_start(pos: Vector2) -> void:
	pos = snap_position(pos)
	super.draw_start(pos)
	if !_move:
		_draw_points.append_array(draw_tool(pos))
		_last_position = pos


func draw_move(pos: Vector2) -> void:
	if selection_node.arrow_key_move:
		return
	pos = snap_position(pos)
	super.draw_move(pos)
	if !_move:
		append_gap(_last_position, pos)
		_last_position = pos
		_draw_points.append_array(draw_tool(pos))
		_offset = pos


func draw_end(pos: Vector2) -> void:
	if selection_node.arrow_key_move:
		return
	pos = snap_position(pos)
	if !_move:
		_draw_points.append_array(draw_tool(pos))
	super.draw_end(pos)


func draw_preview() -> void:
	if _last_position != Vector2.INF and !_move:
		var canvas: Node2D = Global.canvas.previews
		var pos := canvas.position
		var _scale := canvas.scale
		if Global.mirror_view:
			pos.x = pos.x + Global.current_project.size.x
			_scale.x = -1
		canvas.draw_set_transform(pos, canvas.rotation, _scale)
		var indicator := _fill_bitmap_with_points(_draw_points, Global.current_project.size)

		for line in _create_polylines(indicator):
			canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)

		# Handle mirroring
		if Tools.horizontal_mirror:
			for line in _create_polylines(
				_fill_bitmap_with_points(
					mirror_array(_draw_points, true, false), Global.current_project.size
				)
			):
				canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)
			if Tools.vertical_mirror:
				for line in _create_polylines(
					_fill_bitmap_with_points(
						mirror_array(_draw_points, true, true), Global.current_project.size
					)
				):
					canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)
		if Tools.vertical_mirror:
			for line in _create_polylines(
				_fill_bitmap_with_points(
					mirror_array(_draw_points, false, true), Global.current_project.size
				)
			):
				canvas.draw_polyline(PackedVector2Array(line), Color.BLACK)

		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func apply_selection(pos) -> void:
	super.apply_selection(pos)
	var project: Project = Global.current_project
	var cleared := false
	if !_add and !_subtract and !_intersect:
		cleared = true
		Global.canvas.selection.clear_selection()
	# This is paint selection so we've done >= 1 nstead of > 1
	if _draw_points.size() >= 1:
		var selection_map_copy := SelectionMap.new()
		selection_map_copy.copy_from(project.selection_map)
		if _intersect:
			selection_map_copy.clear()
		paint_selection(selection_map_copy, _draw_points)

		# Handle mirroring
		if Tools.horizontal_mirror:
			paint_selection(selection_map_copy, mirror_array(_draw_points, true, false))
			if Tools.vertical_mirror:
				paint_selection(selection_map_copy, mirror_array(_draw_points, true, true))
		if Tools.vertical_mirror:
			paint_selection(selection_map_copy, mirror_array(_draw_points, false, true))

		project.selection_map = selection_map_copy
		Global.canvas.selection.big_bounding_rectangle = project.selection_map.get_used_rect()
	else:
		if !cleared:
			Global.canvas.selection.clear_selection()

	Global.canvas.selection.commit_undo("Select", undo_data)
	_draw_points.clear()
	_last_position = Vector2.INF


func paint_selection(selection_map: SelectionMap, points: PackedVector2Array) -> void:
	var project: Project = Global.current_project
	var selection_size := selection_map.get_size()
	for point in points:
		if point.x < 0 or point.y < 0 or point.x >= selection_size.x or point.y >= selection_size.y:
			continue
		if _intersect:
			if project.selection_map.is_pixel_selected(point):
				selection_map.select_pixel(point, true)
		else:
			selection_map.select_pixel(point, !_subtract)


# Bresenham's Algorithm
# Thanks to https://godotengine.org/qa/35276/tile-based-line-drawing-algorithm-efficiency
func append_gap(start: Vector2, end: Vector2) -> void:
	var dx := absi(end.x - start.x)
	var dy := -absi(end.y - start.y)
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
		_draw_points.append_array(draw_tool(Vector2(x, y)))


func mirror_array(array: Array, h: bool, v: bool) -> Array:
	var new_array := []
	var project: Project = Global.current_project
	for point in array:
		if h and v:
			new_array.append(
				Vector2(project.x_symmetry_point - point.x, project.y_symmetry_point - point.y)
			)
		elif h:
			new_array.append(Vector2(project.x_symmetry_point - point.x, point.y))
		elif v:
			new_array.append(Vector2(point.x, project.y_symmetry_point - point.y))

	return new_array


func draw_tool(pos: Vector2) -> PackedVector2Array:
	_prepare_tool()
	return _draw_tool(pos)


func _prepare_tool() -> void:
	match _brush.type:
		Brushes.CIRCLE:
			_prepare_circle_tool(false)
		Brushes.FILLED_CIRCLE:
			_prepare_circle_tool(true)


func _prepare_circle_tool(fill: bool) -> void:
	var circle_tool_map := _create_circle_indicator(_brush_size, fill)
	# Go through that BitMap and build an Array of the "displacement" from the center of the bits
	# that are true.
	var diameter := _brush_size * 2 + 1
	for n in range(0, diameter):
		for m in range(0, diameter):
			if circle_tool_map.get_bitv(Vector2(m, n)):
				_circle_tool_shortcut.append(Vector2(m - _brush_size, n - _brush_size))


# Make sure to always have invoked _prepare_tool() before this. This computes the coordinates to be
# drawn if it can (except for the generic brush, when it's actually drawing them)
func _draw_tool(pos: Vector2) -> PackedVector2Array:
	match _brush.type:
		Brushes.PIXEL:
			return _compute_draw_tool_pixel(pos)
		Brushes.CIRCLE:
			return _compute_draw_tool_circle(pos, false)
		Brushes.FILLED_CIRCLE:
			return _compute_draw_tool_circle(pos, true)
		_:
			return _compute_draw_tool_brush(pos)


func _compute_draw_tool_pixel(pos: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var start := pos - Vector2.ONE * (_brush_size >> 1)
	var end := start + Vector2.ONE * _brush_size
	for y in range(start.y, end.y):
		for x in range(start.x, end.x):
			if !_draw_points.has(Vector2(x, y)):
				result.append(Vector2(x, y))
	return result


# Compute the array of coordinates that should be drawn
func _compute_draw_tool_circle(pos: Vector2, fill := false) -> PackedVector2Array:
	var brush_size := Vector2(_brush_size, _brush_size)
	var offset_pos := pos - (brush_size / 2).floor()
	if _circle_tool_shortcut:
		return _draw_tool_circle_from_map(pos)

	var result := PackedVector2Array()
	if fill:
		result = DrawingAlgos.get_ellipse_points_filled(offset_pos, brush_size)
	else:
		result = DrawingAlgos.get_ellipse_points(offset_pos, brush_size)
	return result


func _draw_tool_circle_from_map(pos: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for displacement in _circle_tool_shortcut:
		result.append(pos + displacement)
	return result


func _compute_draw_tool_brush(pos: Vector2i) -> PackedVector2Array:
	var result := PackedVector2Array()
	var brush_mask := BitMap.new()
	pos = pos - (_indicator.get_size() / 2)
	brush_mask.create_from_image_alpha(_brush_image, 0.0)
	for x in brush_mask.get_size().x:
		for y in brush_mask.get_size().y:
			if !_draw_points.has(Vector2(x, y)):
				if brush_mask.get_bitv(Vector2i(x, y)):
					result.append(pos + Vector2i(x, y))

	return result


func _on_BrushType_pressed() -> void:
	if not Global.brushes_popup.brush_selected.is_connected(_on_Brush_selected):
		Global.brushes_popup.brush_selected.connect(_on_Brush_selected, CONNECT_ONE_SHOT)
	# Now we set position and columns
	var tool_option_container = get_node("../../")
	var brush_button = $Brush/Type
	var pop_position = brush_button.global_position + Vector2(0, brush_button.size.y)
	var size_x = tool_option_container.size.x
	var size_y = tool_option_container.size.y - $Brush.position.y - $Brush.size.y
	var columns = int(size_x / 36) - 1  # 36 is the size of BrushButton.tscn
	var categories = Global.brushes_popup.get_node("Background/Brushes/Categories")
	for child in categories.get_children():
		if child is GridContainer:
			child.columns = columns
	Global.brushes_popup.popup(Rect2(pop_position, Vector2(size_x, size_y)))


func _on_Brush_selected(brush: Brushes.Brush) -> void:
	_brush = brush
	update_brush()
	save_config()


func _on_BrushSize_value_changed(value: float) -> void:
	if _brush_size != int(value):
		_brush_size = int(value)
		update_config()
		save_config()


# The Blue Indicator code
func update_brush() -> void:
	$Brush/BrushSize.suffix = "px"  # Assume we are using default brushes
	match _brush.type:
		Brushes.PIXEL:
			_brush_texture = ImageTexture.create_from_image(
				load("res://assets/graphics/pixel_image.png")
			)
		Brushes.CIRCLE:
			_brush_texture = ImageTexture.create_from_image(
				load("res://assets/graphics/circle_9x9.png")
			)
		Brushes.FILLED_CIRCLE:
			_brush_texture = ImageTexture.create_from_image(
				load("res://assets/graphics/circle_filled_9x9.png")
			)
		Brushes.FILE, Brushes.RANDOM_FILE, Brushes.CUSTOM:
			$Brush/BrushSize.suffix = "00 %"  # Use a different size convention on images
			if _brush.random.size() <= 1:
				_brush_image = _create_blended_brush_image(_brush.image)
			else:
				var random := randi() % _brush.random.size()
				_brush_image = _create_blended_brush_image(_brush.random[random])
			_brush_texture = ImageTexture.create_from_image(_brush_image)
	_indicator = _create_brush_indicator()
	_polylines = _create_polylines(_indicator)

	$Brush/Type/Texture2D.texture = _brush_texture


func _create_blended_brush_image(image: Image) -> Image:
	var brush_size := image.get_size() * _brush_size
	var brush := Image.new()
	brush.copy_from(image)
	brush.resize(brush_size.x, brush_size.y, Image.INTERPOLATE_NEAREST)
	return brush


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


func _create_pixel_indicator(brush_size: int) -> BitMap:
	var bitmap := BitMap.new()
	bitmap.create(Vector2.ONE * brush_size)
	bitmap.set_bit_rect(Rect2(Vector2.ZERO, Vector2.ONE * size), true)
	return bitmap


func _create_circle_indicator(brush_size: int, fill := false) -> BitMap:
	_circle_tool_shortcut = PackedVector2Array()
	var brush_size_v2 := Vector2(brush_size, brush_size)
	var diameter := brush_size_v2 * 2 + Vector2.ONE
	return _fill_bitmap_with_points(_compute_draw_tool_circle(brush_size_v2, fill), diameter)


func _create_image_indicator(image: Image) -> BitMap:
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, 0.0)
	return bitmap


func draw_indicator(left: bool) -> void:
	var color := Global.left_tool_color if left else Global.right_tool_color
	draw_indicator_at(_cursor, Vector2.ZERO, color)


func draw_indicator_at(pos: Vector2i, offset: Vector2i, color: Color) -> void:
	var canvas = Global.canvas.indicators
	pos -= _indicator.get_size() / 2
	pos -= offset
	canvas.draw_set_transform(pos, canvas.rotation, canvas.scale)
	var polylines := _polylines
	for line in polylines:
		var pool := PackedVector2Array(line)
		canvas.draw_polyline(pool, color)
	canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)
