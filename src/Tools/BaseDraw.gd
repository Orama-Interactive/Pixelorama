class_name BaseDrawTool
extends BaseTool

const IMAGE_BRUSHES := [Brushes.FILE, Brushes.RANDOM_FILE, Brushes.CUSTOM]

var _brush := Brushes.get_default_brush()
var _brush_size := 1
var _brush_size_dynamics := 1
var _brush_density := 100
var _brush_flip_x := false
var _brush_flip_y := false
var _brush_rotate_90 := false
var _brush_rotate_180 := false
var _brush_rotate_270 := false
var _cache_limit := 3
var _brush_interpolate := 0
var _brush_image := Image.new()
var _orignal_brush_image := Image.new()  ## Contains the original _brush_image, without resizing
var _brush_texture := ImageTexture.new()
var _strength := 1.0
var _is_eraser := false
@warning_ignore("unused_private_class_variable")
var _picking_color := false

var _undo_data := {}
var _drawer := Drawer.new()
var _mask := PackedFloat32Array()
var _mirror_brushes := {}

var _draw_line := false
var _line_start := Vector2i.ZERO
var _line_end := Vector2i.ZERO

var _indicator := BitMap.new()
var _polylines := []
var _line_polylines := []

# Memorize some stuff when doing brush strokes
var _stroke_project: Project
var _stroke_images: Array[ImageExtended] = []
var _is_mask_size_zero := true
var _circle_tool_shortcut: Array[Vector2i]


func _ready() -> void:
	super._ready()
	Global.cel_switched.connect(update_brush)
	Global.global_tool_options.dynamics_panel.dynamics_changed.connect(_reset_dynamics)
	Tools.color_changed.connect(_on_Color_changed)
	Global.brushes_popup.brush_removed.connect(_on_Brush_removed)


func _on_BrushType_pressed() -> void:
	if not Global.brushes_popup.brush_selected.is_connected(_on_Brush_selected):
		Global.brushes_popup.brush_selected.connect(_on_Brush_selected, CONNECT_ONE_SHOT)
	# Now we set position and columns
	var tool_option_container = get_node("../../")
	var brush_button = $Brush/Type
	var pop_position = brush_button.global_position + Vector2(0, brush_button.size.y)
	var size_x = tool_option_container.size.x
	var size_y = tool_option_container.size.y - $Brush.position.y - $Brush.size.y
	var columns := int(size_x / 36) - 1  # 36 is the size of BrushButton.tscn
	var categories = Global.brushes_popup.get_node("Background/Brushes/Categories")
	for child in categories.get_children():
		if child is GridContainer:
			child.columns = columns
	Global.brushes_popup.popup_on_parent(Rect2(pop_position, Vector2(size_x, size_y)))
	Tools.flip_rotated.emit(
		_brush_flip_x, _brush_flip_y, _brush_rotate_90, _brush_rotate_180, _brush_rotate_270
	)


func _on_Brush_selected(brush: Brushes.Brush) -> void:
	_brush = brush
	update_brush()
	save_config()


func _on_BrushSize_value_changed(value: float) -> void:
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


func _on_density_value_slider_value_changed(value: int) -> void:
	_brush_density = value
	update_config()
	save_config()


func _on_InterpolateFactor_value_changed(value: float) -> void:
	_brush_interpolate = int(value)
	update_config()
	save_config()


func _on_Color_changed(_color_info: Dictionary, _button: int) -> void:
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
		"brush_density": _brush_density,
		"brush_interpolate": _brush_interpolate,
		"brush_flip_x": _brush_flip_x,
		"brush_flip_y": _brush_flip_y,
		"brush_rotate_90": _brush_rotate_90,
		"brush_rotate_180": _brush_rotate_180,
		"brush_rotate_270": _brush_rotate_270,
	}


func set_config(config: Dictionary) -> void:
	var type: int = config.get("brush_type", _brush.type)
	var index: int = config.get("brush_index", _brush.index)
	_brush = Global.brushes_popup.get_brush(type, index)
	_brush_size = config.get("brush_size", _brush_size)
	_brush_size_dynamics = _brush_size
	if Tools.dynamics_size != Tools.Dynamics.NONE:
		_brush_size_dynamics = Tools.brush_size_min
	_brush_density = config.get("brush_density", _brush_density)
	_brush_interpolate = config.get("brush_interpolate", _brush_interpolate)
	_brush_flip_x = config.get("brush_flip_x", _brush_flip_x)
	_brush_flip_y = config.get("brush_flip_y", _brush_flip_y)
	_brush_rotate_90 = config.get("brush_rotate_90", _brush_rotate_90)
	_brush_rotate_180 = config.get("brush_rotate_180", _brush_rotate_180)
	_brush_rotate_270 = config.get("brush_rotate_270", _brush_rotate_270)


func update_config() -> void:
	$Brush/BrushSize.value = _brush_size
	$ColorInterpolation.value = _brush_interpolate
	%FlipX.button_pressed = _brush_flip_x
	%FlipY.button_pressed = _brush_flip_y
	%Rotate90.button_pressed = _brush_rotate_90
	%Rotate180.button_pressed = _brush_rotate_180
	%Rotate270.button_pressed = _brush_rotate_270
	update_brush()


func update_brush() -> void:
	$Brush/BrushSize.suffix = "px"  # Assume we are using default brushes
	if Tools.is_placing_tiles():
		var tilemap_cel := Global.current_project.get_current_cel() as CelTileMap
		var tileset := tilemap_cel.tileset
		var tile_index := clampi(TileSetPanel.selected_tile_index, 0, tileset.tiles.size() - 1)
		var tile_image := tileset.tiles[tile_index].image
		tile_image = tilemap_cel.transform_tile(
			tile_image,
			TileSetPanel.is_flipped_h,
			TileSetPanel.is_flipped_v,
			TileSetPanel.is_transposed
		)
		_brush_image.copy_from(tile_image)
		_brush_texture = ImageTexture.create_from_image(_brush_image)
	else:
		match _brush.type:
			Brushes.PIXEL:
				_brush_texture = ImageTexture.create_from_image(
					load("res://assets/graphics/pixel_image.png")
				)
				_stroke_dimensions = Vector2.ONE * _brush_size
			Brushes.CIRCLE:
				_brush_texture = ImageTexture.create_from_image(
					load("res://assets/graphics/circle_9x9.png")
				)
				_stroke_dimensions = Vector2.ONE * _brush_size
			Brushes.FILLED_CIRCLE:
				_brush_texture = ImageTexture.create_from_image(
					load("res://assets/graphics/circle_filled_9x9.png")
				)
				_stroke_dimensions = Vector2.ONE * _brush_size
			Brushes.FILE, Brushes.RANDOM_FILE, Brushes.CUSTOM:
				$Brush/BrushSize.suffix = "00 %"  # Use a different size convention on images
				if _brush.random.size() <= 1:
					_orignal_brush_image = _brush.image
				else:
					var random := randi() % _brush.random.size()
					_orignal_brush_image = _brush.random[random]
				_brush_image = _create_blended_brush_image(_orignal_brush_image)
				update_brush_image_flip_and_rotate()
				_brush_texture = ImageTexture.create_from_image(_brush_image)
				update_mirror_brush()
				_stroke_dimensions = _brush_image.get_size()
	_circle_tool_shortcut = []
	_indicator = _create_brush_indicator()
	_polylines = _create_polylines(_indicator)
	$Brush/Type/Texture.texture = _brush_texture
	$DensityValueSlider.visible = _brush.type not in IMAGE_BRUSHES
	$ColorInterpolation.visible = _brush.type in IMAGE_BRUSHES
	$RotationOptions.visible = _brush.type in IMAGE_BRUSHES
	Global.canvas.indicators.queue_redraw()


func update_random_image() -> void:
	if _brush.type != Brushes.RANDOM_FILE:
		return
	var random := randi() % _brush.random.size()
	_brush_image = _create_blended_brush_image(_brush.random[random])
	_orignal_brush_image = _brush_image
	update_brush_image_flip_and_rotate()
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


func update_brush_image_flip_and_rotate() -> void:
	if _brush_flip_x == true:
		_brush_image.flip_x()
	if _brush_flip_y == true:
		_brush_image.flip_y()
	if _brush_rotate_90 == true:
		_brush_image.rotate_90(CLOCKWISE)
	if _brush_rotate_180 == true:
		_brush_image.rotate_180()
	if _brush_rotate_270 == true:
		_brush_image.rotate_90(COUNTERCLOCKWISE)


func update_mask(can_skip := true) -> void:
	if can_skip and Tools.dynamics_alpha == Tools.Dynamics.NONE:
		if _mask:
			_mask = PackedFloat32Array()
		return
	_is_mask_size_zero = false
	# Faster than zeroing PackedFloat32Array directly.
	# See: https://github.com/Orama-Interactive/Pixelorama/pull/439
	var nulled_array := []
	nulled_array.resize(Global.current_project.size.x * Global.current_project.size.y)
	_mask = PackedFloat32Array(nulled_array)


func update_line_polylines(start: Vector2i, end: Vector2i) -> void:
	var indicator := _create_line_indicator(_indicator, start, end)
	_line_polylines = _create_polylines(indicator)


func prepare_undo(action: String) -> void:
	var project := Global.current_project
	_undo_data = _get_undo_data()
	project.undo_redo.create_action(action)


func commit_undo() -> void:
	var project := Global.current_project
	Global.canvas.update_selected_cels_textures(project)
	project.update_tilemaps(_undo_data)
	var redo_data := _get_undo_data()
	var frame := -1
	var layer := -1
	if Global.animation_timeline.animation_timer.is_stopped() and project.selected_cels.size() == 1:
		frame = project.current_frame
		layer = project.current_layer

	project.undos += 1
	project.deserialize_cel_undo_data(redo_data, _undo_data)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false, frame, layer))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true, frame, layer))
	project.undo_redo.commit_action()

	_undo_data.clear()


func draw_tool(pos: Vector2i) -> void:
	if Global.mirror_view:
		# Even brushes are not perfectly centred and are offsetted by 1 px so we add it
		if int(_stroke_dimensions.x) % 2 == 0:
			pos.x += 1
	_prepare_tool()
	var coords_to_draw := _draw_tool(pos)
	for coord in coords_to_draw:
		_set_pixel_no_cache(coord)


func draw_end(pos: Vector2i) -> void:
	super.draw_end(pos)
	_stroke_project = null
	_stroke_images = []
	_circle_tool_shortcut = []
	_brush_size_dynamics = _brush_size
	if Tools.dynamics_size != Tools.Dynamics.NONE:
		_brush_size_dynamics = Tools.brush_size_min
	match _brush.type:
		Brushes.FILE, Brushes.RANDOM_FILE, Brushes.CUSTOM:
			_brush_image = _create_blended_brush_image(_orignal_brush_image)
			update_brush_image_flip_and_rotate()
			_brush_texture = ImageTexture.create_from_image(_brush_image)
			update_mirror_brush()
			_stroke_dimensions = _brush_image.get_size()
	_indicator = _create_brush_indicator()
	_polylines = _create_polylines(_indicator)


func draw_tile(pos: Vector2i) -> void:
	var tile_index := 0 if _is_eraser else TileSetPanel.selected_tile_index
	var mirrored_positions := Tools.get_mirrored_positions(pos, Global.current_project)
	var tile_positions := PackedInt32Array()
	tile_positions.resize(mirrored_positions.size() + 1)
	tile_positions[0] = get_cell_position(pos)
	for i in mirrored_positions.size():
		var mirrored_position := mirrored_positions[i]
		tile_positions[i + 1] = get_cell_position(mirrored_position)
	for cel in _get_selected_draw_cels():
		if cel is not CelTileMap:
			return
		for tile_position in tile_positions:
			(cel as CelTileMap).set_index(tile_position, tile_index)


func _prepare_tool() -> void:
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return
	_brush_size_dynamics = _brush_size
	var strength := Tools.get_alpha_dynamic(_strength)
	if Tools.dynamics_size == Tools.Dynamics.PRESSURE:
		_brush_size_dynamics = roundi(
			lerpf(Tools.brush_size_min, Tools.brush_size_max, Tools.pen_pressure)
		)
	elif Tools.dynamics_size == Tools.Dynamics.VELOCITY:
		_brush_size_dynamics = roundi(
			lerpf(Tools.brush_size_min, Tools.brush_size_max, Tools.mouse_velocity)
		)
	_drawer.pixel_perfect = Tools.pixel_perfect if _brush_size == 1 else false
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
		Brushes.FILE, Brushes.RANDOM_FILE, Brushes.CUSTOM:
			# save _brush_image for safe keeping
			_brush_image = _create_blended_brush_image(_orignal_brush_image)
			update_brush_image_flip_and_rotate()
			_brush_texture = ImageTexture.create_from_image(_brush_image)
			update_mirror_brush()
			_stroke_dimensions = _brush_image.get_size()


## Make sure to always have invoked _prepare_tool() before this. This computes the coordinates to be
## drawn if it can (except for the generic brush, when it's actually drawing them)
func _draw_tool(pos: Vector2) -> PackedVector2Array:
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return PackedVector2Array()  # empty fallback
	if Tools.is_placing_tiles():
		return _compute_draw_tool_pixel(pos)
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
func draw_fill_gap(start: Vector2i, end: Vector2i) -> void:
	if Global.mirror_view:
		# Even brushes are not perfectly centred and are offsetted by 1 px so we add it
		if int(_stroke_dimensions.x) % 2 == 0:
			start.x += 1
			end.x += 1
	_prepare_tool()
	var dx := absi(end.x - start.x)
	var dy := -absi(end.y - start.y)
	var err := dx + dy
	var e2 := err << 1
	var sx := 1 if start.x < end.x else -1
	var sy := 1 if start.y < end.y else -1
	var x := start.x
	var y := start.y
	# This needs to be a dictionary to ensure duplicate coordinates are not being added
	var coords_to_draw := {}
	while !(x == end.x && y == end.y):
		e2 = err << 1
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
		var current_pixel_coord := Vector2(x, y)
		if _spacing_mode:
			current_pixel_coord = get_spacing_position(current_pixel_coord)
		for coord in _draw_tool(current_pixel_coord):
			coords_to_draw[coord] = 0
	for c in coords_to_draw.keys():
		_set_pixel_no_cache(c)


## Compute the array of coordinates that should be drawn
func _compute_draw_tool_pixel(pos: Vector2) -> PackedVector2Array:
	var brush_size := _brush_size_dynamics
	if Tools.is_placing_tiles():
		brush_size = 1
	var result := PackedVector2Array()
	var start := pos - Vector2.ONE * (brush_size >> 1)
	var end := start + Vector2.ONE * brush_size
	for y in range(start.y, end.y):
		for x in range(start.x, end.x):
			result.append(Vector2(x, y))
	return result


## Compute the array of coordinates that should be drawn
func _compute_draw_tool_circle(pos: Vector2i, fill := false) -> Array[Vector2i]:
	var brush_size := Vector2i(_brush_size_dynamics, _brush_size_dynamics)
	var offset_pos := pos - (brush_size / 2)
	if _circle_tool_shortcut:
		return _draw_tool_circle_from_map(pos)

	var result: Array[Vector2i] = []
	if fill:
		result = DrawingAlgos.get_ellipse_points_filled(offset_pos, brush_size)
	else:
		result = DrawingAlgos.get_ellipse_points(offset_pos, brush_size)
	return result


func _draw_tool_circle_from_map(pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for displacement in _circle_tool_shortcut:
		result.append(pos + displacement)
	return result


func draw_tool_brush(brush_position: Vector2i) -> void:
	var project := Global.current_project
	# image brushes work differently, (we have to consider all 8 surrounding points)
	var central_point := project.tiles.get_canon_position(brush_position)
	var positions := project.tiles.get_point_in_tiles(central_point)
	if Global.current_project.has_selection and project.tiles.mode == Tiles.MODE.NONE:
		positions = Global.current_project.selection_map.get_point_in_tile_mode(central_point)

	var brush_size := _brush_image.get_size()
	for i in positions.size():
		var pos := positions[i]
		var dst := pos - (brush_size / 2)
		var dst_rect := Rect2i(dst, brush_size)
		var draw_rectangle := _get_draw_rect()
		dst_rect = dst_rect.intersection(draw_rectangle)
		if dst_rect.size == Vector2i.ZERO:
			continue
		var src_rect := Rect2i(dst_rect.position - dst, dst_rect.size)
		var brush_image: Image = remove_unselected_parts_of_brush(_brush_image, dst)
		dst = dst_rect.position
		_draw_brush_image(brush_image, src_rect, dst)

		# Handle Mirroring
		var mirror_x := (project.x_symmetry_point + 1) - dst.x - src_rect.size.x
		var mirror_y := (project.y_symmetry_point + 1) - dst.y - src_rect.size.y

		if Tools.horizontal_mirror:
			var x_dst := Vector2i(mirror_x, dst.y)
			var mirror_brush_x := remove_unselected_parts_of_brush(_mirror_brushes.x, x_dst)
			_draw_brush_image(mirror_brush_x, _flip_rect(src_rect, brush_size, true, false), x_dst)
			if Tools.vertical_mirror:
				var xy_dst := Vector2i(mirror_x, mirror_y)
				var mirror_brush_xy := remove_unselected_parts_of_brush(_mirror_brushes.xy, xy_dst)
				_draw_brush_image(
					mirror_brush_xy, _flip_rect(src_rect, brush_size, true, true), xy_dst
				)
		if Tools.vertical_mirror:
			var y_dst := Vector2i(dst.x, mirror_y)
			var mirror_brush_y := remove_unselected_parts_of_brush(_mirror_brushes.y, y_dst)
			_draw_brush_image(mirror_brush_y, _flip_rect(src_rect, brush_size, false, true), y_dst)


func remove_unselected_parts_of_brush(brush: Image, dst: Vector2i) -> Image:
	var project := Global.current_project
	if !project.has_selection:
		return brush
	var brush_size := brush.get_size()
	var new_brush := Image.new()
	new_brush.copy_from(brush)

	for x in brush_size.x:
		for y in brush_size.y:
			var pos := Vector2i(x, y) + dst
			if !project.can_pixel_get_drawn(pos):
				new_brush.set_pixel(x, y, Color(0))
	return new_brush


func draw_indicator(left: bool) -> void:
	var color := Global.left_tool_color if left else Global.right_tool_color
	var snapped_position := snap_position(_cursor)
	if Tools.is_placing_tiles():
		var tileset := (Global.current_project.get_current_cel() as CelTileMap).tileset
		var grid_size := tileset.tile_size
		snapped_position = _snap_to_rectangular_grid_center(
			snapped_position, grid_size, Vector2i.ZERO, -1
		)
	draw_indicator_at(snapped_position, Vector2i.ZERO, color)
	if (
		Global.current_project.has_selection
		and Global.current_project.tiles.mode == Tiles.MODE.NONE
	):
		var pos := _line_start if _draw_line else _cursor
		var nearest_pos := Global.current_project.selection_map.get_nearest_position(pos)
		if nearest_pos != Vector2i.ZERO:
			var offset := nearest_pos
			draw_indicator_at(snapped_position, offset, Color.GREEN)
			return

	if Global.current_project.tiles.mode and Global.current_project.tiles.has_point(_cursor):
		var pos := _line_start if _draw_line else _cursor
		var nearest_tile := Global.current_project.tiles.get_nearest_tile(pos)
		if nearest_tile.position != Vector2i.ZERO:
			var offset := nearest_tile.position
			draw_indicator_at(snapped_position, offset, Color.GREEN)


func draw_indicator_at(pos: Vector2i, offset: Vector2i, color: Color) -> void:
	var canvas: Node2D = Global.canvas.indicators
	if _brush.type in IMAGE_BRUSHES and not _draw_line or Tools.is_placing_tiles():
		pos -= _brush_image.get_size() / 2
		pos -= offset
		canvas.draw_texture(_brush_texture, pos)
	else:
		if _draw_line:
			pos.x = _line_end.x if _line_end.x < _line_start.x else _line_start.x
			pos.y = _line_end.y if _line_end.y < _line_start.y else _line_start.y
		pos -= _indicator.get_size() / 2
		pos -= offset
		canvas.draw_set_transform(pos, canvas.rotation, canvas.scale)
		var polylines := _line_polylines if _draw_line else _polylines
		for line in polylines:
			var pool := PackedVector2Array(line)
			canvas.draw_polyline(pool, color)
		canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func _set_pixel(pos: Vector2i, ignore_mirroring := false) -> void:
	if pos in _draw_cache and _for_frame == _stroke_project.current_frame:
		return
	if _draw_cache.size() > _cache_limit or _for_frame != _stroke_project.current_frame:
		_draw_cache = []
		_for_frame = _stroke_project.current_frame
	_draw_cache.append(pos)  # Store the position of pixel
	# Invoke uncached version to actually draw the pixel
	_set_pixel_no_cache(pos, ignore_mirroring)


func _set_pixel_no_cache(pos: Vector2i, ignore_mirroring := false) -> void:
	if randi() % 100 >= _brush_density:
		return
	pos = _stroke_project.tiles.get_canon_position(pos)
	if Global.current_project.has_selection:
		pos = Global.current_project.selection_map.get_canon_position(pos)
	if Tools.is_placing_tiles():
		draw_tile(pos)
		return
	if !_stroke_project.can_pixel_get_drawn(pos):
		return

	var images := _stroke_images
	if _is_mask_size_zero:
		for image in images:
			_drawer.set_pixel(image, pos, tool_slot.color, ignore_mirroring)
	else:
		var i := pos.x + pos.y * _stroke_project.size.x
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


func _draw_brush_image(_image: Image, _src_rect: Rect2i, _dst: Vector2i) -> void:
	pass


func _create_blended_brush_image(image: Image) -> Image:
	var brush_size := image.get_size() * _brush_size_dynamics
	var brush := Image.new()
	brush.copy_from(image)
	brush = _blend_image(brush, tool_slot.color, _brush_interpolate / 100.0)
	brush.resize(brush_size.x, brush_size.y, Image.INTERPOLATE_NEAREST)
	return brush


func _blend_image(image: Image, color: Color, factor: float) -> Image:
	var image_size := image.get_size()
	for y in image_size.y:
		for x in image_size.x:
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


func _create_pixel_indicator(brush_size: int) -> BitMap:
	var bitmap := BitMap.new()
	bitmap.create(Vector2i.ONE * brush_size)
	bitmap.set_bit_rect(Rect2i(Vector2i.ZERO, Vector2i.ONE * brush_size), true)
	return bitmap


func _create_circle_indicator(brush_size: int, fill := false) -> BitMap:
	if Tools.dynamics_size != Tools.Dynamics.NONE:
		_circle_tool_shortcut = []
	var brush_size_v2 := Vector2i(brush_size, brush_size)
	var diameter_v2 := brush_size_v2 * 2 + Vector2i.ONE
	var circle_tool_map := _fill_bitmap_with_points(
		_compute_draw_tool_circle(brush_size_v2, fill), diameter_v2
	)
	if _circle_tool_shortcut.is_empty():
		# Go through that BitMap and build an Array of the "displacement"
		# from the center of the bits that are true.
		var diameter := _brush_size_dynamics * 2 + 1
		for n in range(0, diameter):
			for m in range(0, diameter):
				if circle_tool_map.get_bitv(Vector2i(m, n)):
					_circle_tool_shortcut.append(
						Vector2i(m - _brush_size_dynamics, n - _brush_size_dynamics)
					)
	return circle_tool_map


func _create_line_indicator(indicator: BitMap, start: Vector2i, end: Vector2i) -> BitMap:
	var bitmap := BitMap.new()
	var brush_size := (end - start).abs() + indicator.get_size()
	bitmap.create(brush_size)

	var offset := indicator.get_size() / 2
	var diff := end - start
	start.x = -diff.x if diff.x < 0 else 0
	end.x = 0 if diff.x < 0 else diff.x
	start.y = -diff.y if diff.y < 0 else 0
	end.y = 0 if diff.y < 0 else diff.y
	start += offset
	end += offset

	var dx := absi(end.x - start.x)
	var dy := -absi(end.y - start.y)
	var err := dx + dy
	var e2 := err << 1
	var sx := 1 if start.x < end.x else -1
	var sy := 1 if start.y < end.y else -1
	var x := start.x
	var y := start.y
	while !(x == end.x && y == end.y):
		_blit_indicator(bitmap, indicator, Vector2i(x, y))
		e2 = err << 1
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	_blit_indicator(bitmap, indicator, Vector2i(x, y))
	return bitmap


func _blit_indicator(dst: BitMap, indicator: BitMap, pos: Vector2i) -> void:
	var rect := Rect2i(Vector2i.ZERO, dst.get_size())
	var brush_size := indicator.get_size()
	pos -= brush_size / 2
	for y in brush_size.y:
		for x in brush_size.x:
			var brush_pos := Vector2i(x, y)
			var bit := indicator.get_bitv(brush_pos)
			brush_pos += pos
			if bit and rect.has_point(brush_pos):
				dst.set_bitv(brush_pos, bit)


func _line_angle_constraint(start: Vector2, end: Vector2) -> Dictionary:
	var result := {}
	var angle := rad_to_deg(start.angle_to_point(end))
	var distance := start.distance_to(end)
	if Input.is_action_pressed("draw_snap_angle"):
		if Tools.pixel_perfect:
			angle = snappedf(angle, 22.5)
			if step_decimals(angle) != 0:
				var diff := end - start
				var v := Vector2(2, 1) if absf(diff.x) > absf(diff.y) else Vector2(1, 2)
				var p := diff.project(diff.sign() * v).abs().round()
				var f := p.y if absf(diff.x) > absf(diff.y) else p.x
				end = start + diff.sign() * v * f - diff.sign()
				angle = rad_to_deg(atan2(signi(diff.y) * v.y, signi(diff.x) * v.x))
			else:
				end = start + Vector2.RIGHT.rotated(deg_to_rad(angle)) * distance
		else:
			angle = snappedf(angle, 15)
			end = start + Vector2.RIGHT.rotated(deg_to_rad(angle)) * distance
	angle *= -1
	angle += 360 if angle < 0 else 0
	result.text = str(snappedf(angle, 0.01)) + "°"
	result.position = Vector2i(end.round())
	return result


func _get_undo_data() -> Dictionary:
	var data := {}
	var project := Global.current_project
	var cels: Array[BaseCel] = []
	if Global.animation_timeline.animation_timer.is_stopped():
		for cel_index in project.selected_cels:
			cels.append(project.frames[cel_index[0]].cels[cel_index[1]])
	else:
		for frame in project.frames:
			var cel: BaseCel = frame.cels[project.current_layer]
			if not cel is PixelCel:
				continue
			cels.append(cel)
	project.serialize_cel_undo_data(cels, data)
	return data


func _on_flip_x_toggled(button_pressed: bool) -> void:
	_brush_flip_x = button_pressed
	update_brush()
	save_config()


func _on_flip_y_toggled(button_pressed: bool) -> void:
	_brush_flip_y = button_pressed
	update_brush()
	save_config()


func _on_rotate_90_toggled(button_pressed: bool) -> void:
	_brush_rotate_90 = button_pressed
	update_brush()
	save_config()


func _on_rotate_180_toggled(button_pressed: bool) -> void:
	_brush_rotate_180 = button_pressed
	update_brush()
	save_config()


func _on_rotate_270_toggled(button_pressed: bool) -> void:
	_brush_rotate_270 = button_pressed
	update_brush()
	save_config()
