extends BaseTool

var _brush := Brushes.get_default_brush()
var _brush_size := 1
var _brush_size_dynamics := 1
var _cache_limit := 3
var _brush_interpolate := 0
var _brush_image := Image.new()
var _orignal_brush_image := Image.new()  # contains the orignal _brush_image (whithout resizing)
var _brush_texture := ImageTexture.new()
var _strength := 1.0
@warning_ignore("unused_private_class_variable")
var _picking_color := false

var _undo_data := {}
var _drawer := Drawer.new()
var _mask := PackedFloat32Array()
var _mirror_brushes := {}

var _draw_line := false
var _line_start := Vector2.ZERO
var _line_end := Vector2.ZERO

var _indicator := BitMap.new()
var _polylines := []
var _line_polylines := []

# Memorize some stuff when doing brush strokes
var _stroke_project: Project
var _stroke_images := []  # Array of Images
var _is_mask_size_zero := true
var _circle_tool_shortcut: PackedVector2Array


func _ready() -> void:
	super._ready()
	Global.global_tool_options.connect("dynamics_changed",Callable(self, "_reset_dynamics"))
	Tools.connect("color_changed", Callable(self, "_on_Color_changed"))
	Global.brushes_popup.connect("brush_removed", Callable(self, "_on_Brush_removed"))


func _on_BrushType_pressed() -> void:
	Global.brushes_popup.connect(
		"brush_selected", Callable(self, "_on_Brush_selected"), CONNECT_ONE_SHOT
	)
	if not Global.brushes_popup.is_connected("brush_selected", Callable(self, "_on_Brush_selected")):
		Global.brushes_popup.connect(
			"brush_selected", Callable(self, "_on_Brush_selected"), CONNECT_ONE_SHOT
		)
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
	print(brush)
	_brush = brush
	update_brush()
	save_config()


func _on_BrushSize_value_changed(value: float) -> void:
	if _brush_size != int(value):
		_brush_size = int(value)
		_brush_size_dynamics = _brush_size
		if Tools.dynamics_size != Tools.Dynamics.NONE:
			_brush_size_dynamics = Tools.brush_size_min
		_cache_limit = (_brush_size * _brush_size) * 3  # This equation seems the best match
		update_config()
		save_config()


func _reset_dynamics() -> void:
	_brush_size_dynamics = _brush_size
	if Tools.dynamics_size != Tools.Dynamics.NONE:
		_brush_size_dynamics = Tools.brush_size_min
	_cache_limit = (_brush_size * _brush_size) * 3  # This equation seems the best match
	update_config()
	save_config()


func _on_InterpolateFactor_value_changed(value: float) -> void:
	_brush_interpolate = int(value)
	update_config()
	save_config()


func _on_Color_changed(_color: Color, _button: int) -> void:
	update_brush()


func _on_Brush_removed(brush: Brushes.Brush) -> void:
	if brush == _brush:
		_brush = Brushes.get_default_brush()
		update_brush()
		save_config()


func get_config() -> Dictionary:
	return {
		"brush_type": _brush.type,
		"brush_index": _brush.index,
		"brush_size": _brush_size,
		"brush_interpolate": _brush_interpolate,
	}


func set_config(config: Dictionary) -> void:
	var type: int = config.get("brush_type", _brush.type)
	var index: int = config.get("brush_index", _brush.index)
	_brush = Global.brushes_popup.get_brush(type, index)
	_brush_size = config.get("brush_size", _brush_size)
	_brush_size_dynamics = _brush_size
	if Tools.dynamics_size != Tools.Dynamics.NONE:
		_brush_size_dynamics = Tools.brush_size_min
	_brush_interpolate = config.get("brush_interpolate", _brush_interpolate)


func update_config() -> void:
	$Brush/BrushSize.value = _brush_size
	$ColorInterpolation.value = _brush_interpolate
	update_brush()


func update_brush() -> void:
	$Brush/BrushSize.suffix = "px"  # Assume we are using default brushes
	match _brush.type:
		Brushes.PIXEL:
			_brush_texture = ImageTexture.create_from_image(load("res://assets/graphics/pixel_image.png"))
			_stroke_dimensions = Vector2.ONE * _brush_size
		Brushes.CIRCLE:
			_brush_texture = ImageTexture.create_from_image(load("res://assets/graphics/circle_9x9.png"))
			_stroke_dimensions = Vector2.ONE * _brush_size
		Brushes.FILLED_CIRCLE:
			_brush_texture = ImageTexture.create_from_image(load("res://assets/graphics/circle_filled_9x9.png"))
			_stroke_dimensions = Vector2.ONE * _brush_size
		Brushes.FILE, Brushes.RANDOM_FILE, Brushes.CUSTOM:
			$Brush/BrushSize.suffix = "00 %"  # Use a different size convention on images
			if _brush.random.size() <= 1:
				_orignal_brush_image = _brush.image
			else:
				var random := randi() % _brush.random.size()
				_orignal_brush_image = _brush.random[random]
			_brush_image = _create_blended_brush_image(_orignal_brush_image)
			_brush_texture = ImageTexture.create_from_image(_brush_image)
			update_mirror_brush()
			_stroke_dimensions = _brush_image.get_size()
	_indicator = _create_brush_indicator()
	_polylines = _create_polylines(_indicator)
	$Brush/Type/Texture2D.texture = _brush_texture
	$ColorInterpolation.visible = _brush.type in [Brushes.FILE, Brushes.RANDOM_FILE, Brushes.CUSTOM]


func update_random_image() -> void:
	if _brush.type != Brushes.RANDOM_FILE:
		return
	var random = randi() % _brush.random.size()
	_brush_image = _create_blended_brush_image(_brush.random[random])
	_brush_texture = ImageTexture.create_from_image(_brush_image)
	_indicator = _create_brush_indicator()
	update_mirror_brush()


func update_mirror_brush() -> void:
	_mirror_brushes.x = _brush_image.duplicate()
	_mirror_brushes.x.flip_x()
	_mirror_brushes.y = _brush_image.duplicate()
	_mirror_brushes.y.flip_y()
	_mirror_brushes.xy = _mirror_brushes.x.duplicate()
	_mirror_brushes.xy.flip_y()


func update_mask(can_skip := true) -> void:
	if can_skip and Tools.dynamics_alpha == Tools.Dynamics.NONE:
		if _mask:
			_mask = PackedFloat32Array()
		return
	var p_size: Vector2 = Global.current_project.size
	_is_mask_size_zero = false
	# Faster than zeroing PoolByteArray directly.
	# See: https://github.com/Orama-Interactive/Pixelorama/pull/439
	var nulled_array := []
	nulled_array.resize(p_size.x * p_size.y)
	_mask = PackedFloat32Array(nulled_array)


func update_line_polylines(start: Vector2, end: Vector2) -> void:
	var indicator := _create_line_indicator(_indicator, start, end)
	_line_polylines = _create_polylines(indicator)


func prepare_undo(action: String) -> void:
	var project: Project = Global.current_project
	_undo_data = _get_undo_data()
	project.undo_redo.create_action(action)


func commit_undo() -> void:
	var redo_data := _get_undo_data()
	var project: Project = Global.current_project
	var frame := -1
	var layer := -1
	if Global.animation_timer.is_stopped() and project.selected_cels.size() == 1:
		frame = project.current_frame
		layer = project.current_layer

	project.undos += 1
	for image in redo_data:
		project.undo_redo.add_do_property(image, "data", redo_data[image])
	for image in _undo_data:
		project.undo_redo.add_undo_property(image, "data", _undo_data[image])
	project.undo_redo.add_do_method(Callable(Global, "undo_or_redo").bind(false, frame, layer))
	project.undo_redo.add_undo_method(Callable(Global, "undo_or_redo").bind(true, frame, layer))
	project.undo_redo.commit_action()

	_undo_data.clear()


func draw_tool(pos: Vector2) -> void:
	_prepare_tool()
	var coords_to_draw := _draw_tool(pos)
	for coord in coords_to_draw:
		_set_pixel_no_cache(coord)


func draw_end(pos: Vector2) -> void:
	super.draw_end(pos)
	_brush_size_dynamics = _brush_size
	if Tools.dynamics_size != Tools.Dynamics.NONE:
		_brush_size_dynamics = Tools.brush_size_min
	match _brush.type:
		Brushes.FILE, Brushes.RANDOM_FILE, Brushes.CUSTOM:
			_brush_image = _create_blended_brush_image(_orignal_brush_image)
			_brush_texture = ImageTexture.create_from_image(_brush_image)
			update_mirror_brush()
			_stroke_dimensions = _brush_image.get_size()
	_indicator = _create_brush_indicator()
	_polylines = _create_polylines(_indicator)


func _prepare_tool() -> void:
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return
	_brush_size_dynamics = _brush_size
	var strength: float = Tools.get_alpha_dynamic(_strength)
	if Tools.dynamics_size == Tools.Dynamics.PRESSURE:
		_brush_size_dynamics = round(
			lerp(Tools.brush_size_min, Tools.brush_size_max, Tools.pen_pressure)
		)
	elif Tools.dynamics_size == Tools.Dynamics.VELOCITY:
		_brush_size_dynamics = round(
			lerp(Tools.brush_size_min, Tools.brush_size_max, Tools.mouse_velocity)
		)
	_drawer.pixel_perfect = Tools.pixel_perfect if _brush_size == 1 else false
	_drawer.horizontal_mirror = Tools.horizontal_mirror
	_drawer.vertical_mirror = Tools.vertical_mirror
	_drawer.color_op.strength = strength
	_indicator = _create_brush_indicator()
	_polylines = _create_polylines(_indicator)
	# Memorize current project
	_stroke_project = Global.current_project
	# Memorize the frame/layer we are drawing on rather than fetching it on every pixel
	_stroke_images = _get_selected_draw_images()
	# This may prevent a few tests when setting pixels
	_is_mask_size_zero = _mask.size() == 0
	match _brush.type:
		Brushes.CIRCLE:
			_prepare_circle_tool(false)
		Brushes.FILLED_CIRCLE:
			_prepare_circle_tool(true)
		Brushes.FILE, Brushes.RANDOM_FILE, Brushes.CUSTOM:
			# save _brush_image for safe keeping
			_brush_image = _create_blended_brush_image(_orignal_brush_image)
			_brush_texture = ImageTexture.create_from_image(_brush_image)
			update_mirror_brush()
			_stroke_dimensions = _brush_image.get_size()


func _prepare_circle_tool(fill: bool) -> void:
	var circle_tool_map := _create_circle_indicator(_brush_size_dynamics, fill)
	# Go through that BitMap and build an Array of the "displacement" from the center of the bits
	# that are true.
	var diameter := _brush_size_dynamics * 2 + 1
	for n in range(0, diameter):
		for m in range(0, diameter):
			if circle_tool_map.get_bitv(Vector2(m, n)):
				_circle_tool_shortcut.append(
					Vector2(m - _brush_size_dynamics, n - _brush_size_dynamics)
				)


# Make sure to always have invoked _prepare_tool() before this. This computes the coordinates to be
# drawn if it can (except for the generic brush, when it's actually drawing them)
func _draw_tool(pos: Vector2) -> PackedVector2Array:
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return PackedVector2Array()  # empty fallback
	match _brush.type:
		Brushes.PIXEL:
			return _compute_draw_tool_pixel(pos)
		Brushes.CIRCLE:
			return _compute_draw_tool_circle(pos, false)
		Brushes.FILLED_CIRCLE:
			return _compute_draw_tool_circle(pos, true)
		_:
			draw_tool_brush(pos)
	return PackedVector2Array()  # empty fallback


# Bresenham's Algorithm
# Thanks to https://godotengine.org/qa/35276/tile-based-line-drawing-algorithm-efficiency
func draw_fill_gap(start: Vector2, end: Vector2) -> void:
	var dx := int(abs(end.x - start.x))
	var dy := int(-abs(end.y - start.y))
	var err := dx + dy
	var e2 := err << 1
	var sx := 1 if start.x < end.x else -1
	var sy := 1 if start.y < end.y else -1
	var x := start.x
	var y := start.y
	_prepare_tool()
	var coords_to_draw := {}
	while !(x == end.x && y == end.y):
		e2 = err << 1
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
		#coords_to_draw.append_array(_draw_tool(Vector2(x, y)))
		var current_pixel_coord = Vector2(x, y)
		if _spacing_mode:
			current_pixel_coord = get_spacing_position(current_pixel_coord)
		for coord in _draw_tool(current_pixel_coord):
			coords_to_draw[coord] = 0
	for c in coords_to_draw.keys():
		_set_pixel_no_cache(c)


# Compute the array of coordinates that should be drawn
func _compute_draw_tool_pixel(pos: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var start := pos - Vector2.ONE * (_brush_size_dynamics >> 1)
	var end := start + Vector2.ONE * _brush_size_dynamics
	for y in range(start.y, end.y):
		for x in range(start.x, end.x):
			result.append(Vector2(x, y))
	return result


# Compute the array of coordinates that should be drawn
func _compute_draw_tool_circle(pos: Vector2, fill := false) -> PackedVector2Array:
	var b_size := Vector2(_brush_size_dynamics, _brush_size_dynamics)
	var central_point = pos - (b_size / 2).floor()
	if _circle_tool_shortcut:
		return _draw_tool_circle_from_map(pos)

	var result := PackedVector2Array()
	if fill:
		result = DrawingAlgos.get_ellipse_points_filled(central_point, b_size)
	else:
		result = DrawingAlgos.get_ellipse_points(central_point, b_size)
	return result


func _draw_tool_circle_from_map(pos: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for displacement in _circle_tool_shortcut:
		result.append(pos + displacement)
	return result


func draw_tool_brush(pos: Vector2) -> void:
	var project: Project = Global.current_project
	pos = project.tiles.get_canon_position(pos)

	var _size: Vector2 = _brush_image.get_size()
	var dst := pos - (_size / 2).floor()
	var dst_rect := Rect2(dst, _size)
	@warning_ignore("shadowed_variable_base_class")
	var draw_rect := _get_draw_rect()
	dst_rect = dst_rect.intersection(draw_rect)
	if dst_rect.size == Vector2.ZERO:
		return
	var src_rect := Rect2(dst_rect.position - dst, dst_rect.size)
	dst = dst_rect.position
	var brush_image: Image = remove_unselected_parts_of_brush(_brush_image, dst)
	_draw_brush_image(brush_image, src_rect, dst)

	# Handle Mirroring
	var mirror_x = (project.x_symmetry_point + 1) - dst.x - src_rect.size.x
	var mirror_y = (project.y_symmetry_point + 1) - dst.y - src_rect.size.y

	if Tools.horizontal_mirror:
		var x_dst := Vector2(mirror_x, dst.y)
		var mirror_brush_x: Image = remove_unselected_parts_of_brush(_mirror_brushes.x, x_dst)
		_draw_brush_image(mirror_brush_x, _flip_rect(src_rect, _size, true, false), x_dst)
		if Tools.vertical_mirror:
			var xy_dst := Vector2(mirror_x, mirror_y)
			var mirror_brush_xy := remove_unselected_parts_of_brush(_mirror_brushes.xy, xy_dst)
			_draw_brush_image(mirror_brush_xy, _flip_rect(src_rect, _size, true, true), xy_dst)
	if Tools.vertical_mirror:
		var y_dst := Vector2(dst.x, mirror_y)
		var mirror_brush_y: Image = remove_unselected_parts_of_brush(_mirror_brushes.y, y_dst)
		_draw_brush_image(mirror_brush_y, _flip_rect(src_rect, _size, false, true), y_dst)


func remove_unselected_parts_of_brush(brush: Image, dst: Vector2) -> Image:
	var project: Project = Global.current_project
	if !project.has_selection:
		return brush
	var _size := brush.get_size()
	var new_brush := Image.new()
	new_brush.copy_from(brush)

	for x in _size.x:
		for y in _size.y:
			var pos := Vector2(x, y) + dst
			if !project.selection_map.is_pixel_selected(pos):
				new_brush.set_pixel(x, y, Color(0))
	return new_brush


func draw_indicator(left: bool) -> void:
	var color := Global.left_tool_color if left else Global.right_tool_color
	draw_indicator_at(snap_position(_cursor), Vector2.ZERO, color)
	if Global.current_project.tiles.mode and Global.current_project.tiles.has_point(_cursor):
		var pos := _line_start if _draw_line else _cursor
		var nearest_tile := Global.current_project.tiles.get_nearest_tile(pos)
		if nearest_tile.position != Vector2.ZERO:
			var offset := nearest_tile.position
			draw_indicator_at(snap_position(_cursor), offset, Color.GREEN)


func draw_indicator_at(pos: Vector2, offset: Vector2, color: Color) -> void:
	var canvas = Global.canvas.indicators
	if _brush.type in [Brushes.FILE, Brushes.RANDOM_FILE, Brushes.CUSTOM] and not _draw_line:
		pos -= (Vector2(_brush_image.get_size()) / 2).floor()
		pos -= offset
		canvas.draw_texture(_brush_texture, pos)
	else:
		if _draw_line:
			pos.x = _line_end.x if _line_end.x < _line_start.x else _line_start.x
			pos.y = _line_end.y if _line_end.y < _line_start.y else _line_start.y
		pos -= (Vector2(_indicator.get_size()) / 2).floor()
		pos -= offset
		canvas.draw_set_transform(pos, canvas.rotation, canvas.scale)
		var polylines := _line_polylines if _draw_line else _polylines
		for line in polylines:
			var pool := PackedVector2Array(line)
			canvas.draw_polyline(pool, color)
		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func _set_pixel(pos: Vector2, ignore_mirroring := false) -> void:
	if pos in _draw_cache and _for_frame == _stroke_project.current_frame:
		return
	if _draw_cache.size() > _cache_limit or _for_frame != _stroke_project.current_frame:
		_draw_cache = []
		_for_frame = _stroke_project.current_frame
	_draw_cache.append(pos)  # Store the position of pixel
	# Invoke uncached version to actually draw the pixel
	_set_pixel_no_cache(pos, ignore_mirroring)


func _set_pixel_no_cache(pos: Vector2, ignore_mirroring := false) -> void:
	pos = _stroke_project.tiles.get_canon_position(pos)
	if !_stroke_project.can_pixel_get_drawn(pos):
		return

	var images := _stroke_images
	if _is_mask_size_zero:
		for image in images:
			_drawer.set_pixel(image, pos, tool_slot.color, ignore_mirroring)
	else:
		var i := int(pos.x + pos.y * _stroke_project.size.x)
		if _mask.size() >= i + 1:
			var alpha_dynamic: float = Tools.get_alpha_dynamic()
			var alpha: float = images[0].get_pixelv(pos).a
			if _mask[i] < alpha_dynamic:
				# Overwrite colors to avoid additive blending between strokes of
				# brushes that are larger than 1px
				# This is not a proper solution and it does not work if the pixels
				# in the background are not transparent
				var overwrite = _drawer.color_op.get("overwrite")
				if overwrite != null and _mask[i] > alpha:
					_drawer.color_op.overwrite = true
				_mask[i] = alpha_dynamic
				for image in images:
					_drawer.set_pixel(image, pos, tool_slot.color, ignore_mirroring)
				if overwrite != null:
					_drawer.color_op.overwrite = overwrite
		else:
			for image in images:
				_drawer.set_pixel(image, pos, tool_slot.color, ignore_mirroring)


func _draw_brush_image(_image: Image, _src_rect: Rect2, _dst: Vector2) -> void:
	pass


func _create_blended_brush_image(image: Image) -> Image:
	var _size := image.get_size() * _brush_size_dynamics
	var brush := Image.new()
	brush.copy_from(image)
	brush = _blend_image(brush, tool_slot.color, _brush_interpolate / 100.0)
	brush.resize(_size.x, _size.y, Image.INTERPOLATE_NEAREST)
	return brush


func _blend_image(image: Image, color: Color, factor: float) -> Image:
	var _size := image.get_size()
	for y in _size.y:
		for x in _size.x:
			var color_old := image.get_pixel(x, y)
			if color_old.a > 0:
				var color_new := color_old.lerp(color, factor)
				color_new.a = color_old.a
				image.set_pixel(x, y, color_new)
	return image


func _create_brush_indicator() -> BitMap:
	match _brush.type:
		Brushes.PIXEL:
			return _create_pixel_indicator(_brush_size_dynamics)
		Brushes.CIRCLE:
			return _create_circle_indicator(_brush_size_dynamics, false)
		Brushes.FILLED_CIRCLE:
			return _create_circle_indicator(_brush_size_dynamics, true)
		_:
			return _create_image_indicator(_brush_image)


func _create_image_indicator(image: Image) -> BitMap:
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, 0.0)
	return bitmap


func _create_pixel_indicator(_size: int) -> BitMap:
	var bitmap := BitMap.new()
	bitmap.create(Vector2.ONE * _size)
	bitmap.set_bit_rect(Rect2(Vector2.ZERO, Vector2.ONE * _size), true)
	return bitmap


func _create_circle_indicator(_size: int, fill := false) -> BitMap:
	_circle_tool_shortcut = PackedVector2Array()
	var diameter := Vector2(_size, _size) * 2 + Vector2.ONE
	return _fill_bitmap_with_points(_compute_draw_tool_circle(Vector2(_size, _size), fill), diameter)


func _create_line_indicator(indicator: BitMap, start: Vector2, end: Vector2) -> BitMap:
	var bitmap := BitMap.new()
	var _size := (end - start).abs() + Vector2(indicator.get_size())
	bitmap.create(_size)

	var offset := (Vector2(indicator.get_size()) / 2).floor()
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
	var sx := 1 if start.x < end.x else -1
	var sy := 1 if start.y < end.y else -1
	var x := start.x
	var y := start.y
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


func _blit_indicator(dst: BitMap, indicator: BitMap, _position: Vector2) -> void:
	var rect := Rect2(Vector2.ZERO, dst.get_size())
	var _size := indicator.get_size()
	_position -= (Vector2(_size) / 2).floor()
	for y in _size.y:
		for x in _size.x:
			var pos := Vector2(x, y)
			var bit := indicator.get_bitv(pos)
			pos += _position
			if bit and rect.has_point(pos):
				dst.set_bitv(pos, bit)


func _line_angle_constraint(start: Vector2, end: Vector2) -> Dictionary:
	var result := {}
	var angle := rad_to_deg(end.angle_to_point(start))
	var distance := start.distance_to(end)
	if Input.is_action_pressed("draw_snap_angle"):
		if Tools.pixel_perfect:
			angle = snapped(angle, 22.5)
			if step_decimals(angle) != 0:
				var diff := end - start
				var v := Vector2(2, 1) if abs(diff.x) > abs(diff.y) else Vector2(1, 2)
				var p := diff.project(diff.sign() * v).abs().round()
				var f := p.y if abs(diff.x) > abs(diff.y) else p.x
				end = start + diff.sign() * v * f - diff.sign()
				angle = rad_to_deg(atan2(sign(diff.y) * v.y, sign(diff.x) * v.x))
			else:
				end = start + Vector2.RIGHT.rotated(deg_to_rad(angle)) * distance
		else:
			angle = snapped(angle, 15)
			end = start + Vector2.RIGHT.rotated(deg_to_rad(angle)) * distance
	angle *= -1
	angle += 360 if angle < 0 else 0
	result.text = str(snapped(angle, 0.01)) + "°"
	result.position = end.round()
	return result


func _get_undo_data() -> Dictionary:
	var data := {}
	var project: Project = Global.current_project
	var cels := []  # Array of Cels
	if Global.animation_timer.is_stopped():
		for cel_index in project.selected_cels:
			cels.append(project.frames[cel_index[0]].cels[cel_index[1]])
	else:
		for frame in project.frames:
			var cel: BaseCel = frame.cels[project.current_layer]
			if not cel is PixelCel:
				continue
			cels.append(cel)
	for cel in cels:
		if not cel is PixelCel:
			continue
		var image: Image = cel.image
		data[image] = image.data
	return data


func _pick_color(pos: Vector2) -> void:
	var project: Project = Global.current_project
	pos = project.tiles.get_canon_position(pos)

	if pos.x < 0 or pos.y < 0:
		return

	var image := Image.new()
	image.copy_from(_get_draw_image())
	if pos.x > image.get_width() - 1 or pos.y > image.get_height() - 1:
		return

	var color := Color(0, 0, 0, 0)
	var curr_frame: Frame = project.frames[project.current_frame]
	for layer in project.layers.size():
		var idx = (project.layers.size() - 1) - layer
		if project.layers[idx].can_layer_get_drawn():
			image = curr_frame.cels[idx].get_image()
			color = image.get_pixelv(pos)
			if color != Color(0, 0, 0, 0):
				break
	var button := MOUSE_BUTTON_LEFT if Tools._slots[MOUSE_BUTTON_LEFT].tool_node == self else MOUSE_BUTTON_RIGHT
	Tools.assign_color(color, button, false)
