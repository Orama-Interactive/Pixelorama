class_name BaseDrawTool
extends BaseTool

const IMAGE_BRUSHES := [Brushes.FILE, Brushes.RANDOM_FILE, Brushes.CUSTOM]

var _brush := Brushes.get_default_brush()
var _brush_size := 1
var _brush_size_dynamics := 1
var _brush_density := 100
var _brush_flip_x := false
var _brush_flip_y := false
var _brush_transposed := false
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
var _mm_action: Keychain.MouseMovementInputAction


func _ready() -> void:
	super._ready()
	if tool_slot.button == MOUSE_BUTTON_RIGHT:
		$Brush/BrushSize.allow_global_input_events = not Global.share_options_between_tools
		Global.share_options_between_tools_changed.connect(
			func(enabled): $Brush/BrushSize.allow_global_input_events = not enabled
		)
		_update_mm_action("mm_change_brush_size")
		Keychain.action_changed.connect(_update_mm_action)
		Keychain.profile_switched.connect(func(_prof): _update_mm_action("mm_change_brush_size"))
	else:
		_mm_action = Keychain.actions[&"mm_change_brush_size"] as Keychain.MouseMovementInputAction
	Global.cel_switched.connect(update_brush)
	Global.dynamics_changed.connect(_reset_dynamics)
	Tools.color_changed.connect(_on_Color_changed)
	Global.brushes_popup.brush_removed.connect(_on_Brush_removed)


func _input(event: InputEvent) -> void:
	for action in [&"undo", &"redo"]:
		if Input.is_action_pressed(action):
			return
	# If options are being shared, no need to change the brush size on the right tool slots,
	# otherwise it will be changed twice on both left and right tools.
	if tool_slot.button == MOUSE_BUTTON_RIGHT and Global.share_options_between_tools:
		return
	var brush_size_value := _mm_action.get_action_distance_int(event, true)
	$Brush/BrushSize.value += brush_size_value


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
	Tools.flip_rotated.emit(_brush_flip_x, _brush_flip_y, _brush_transposed)


func _on_Brush_selected(brush: Brushes.Brush) -> void:
	_brush = brush
	_brush_flip_x = false
	_brush_flip_y = false
	_brush_transposed = false
	update_brush()
	save_config()


func _on_BrushSize_value_changed(value: float) -> void:
	_brush_size = int(value)
	_brush_size_dynamics = _brush_size
	_cache_limit = (_brush_size * _brush_size) * 3  # This equation seems the best match
	update_config()
	save_config()


func _reset_dynamics() -> void:
	_brush_size_dynamics = _brush_size
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
	}


func set_config(config: Dictionary) -> void:
	var type: int = config.get("brush_type", _brush.type)
	var index: int = config.get("brush_index", _brush.index)
	_brush = Global.brushes_popup.get_brush(type, index)
	_brush_size = config.get("brush_size", _brush_size)
	_brush_size_dynamics = _brush_size
	_brush_density = config.get("brush_density", _brush_density)
	_brush_interpolate = config.get("brush_interpolate", _brush_interpolate)


func update_config() -> void:
	$Brush/BrushSize.value = _brush_size
	$DensityValueSlider.value = _brush_density
	$ColorInterpolation.value = _brush_interpolate
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
	$TransformButtonsContainer.visible = _brush.type in IMAGE_BRUSHES
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
	if _brush_transposed == true:
		_brush_image.rotate_90(COUNTERCLOCKWISE)
	if _brush_flip_x == true:
		_brush_image.flip_x()
	if _brush_flip_y == true:
		_brush_image.flip_y()


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


func prepare_undo() -> void:
	_undo_data = _get_undo_data()


func commit_undo(action := "Draw") -> void:
	var project := Global.current_project
	var layer := project.layers[project.current_layer]
	if layer is Layer3D:
		var properties: Array[Layer3D.Property]
		for mat in materials_3d:
			var image := materials_3d[mat][0] as Image
			var surface_index := materials_3d[mat][1] as int
			var original_tex := ImageTexture.create_from_image(image)
			var new_tex := ImageTexture.create_from_image(mat.albedo_texture.get_image())
			mat.albedo_texture.update(image)
			var property_path := "mesh:surface_%s/material:albedo_texture" % surface_index
			if drawing_on_3d_node.mesh is PrimitiveMesh:
				property_path = "mesh:material:albedo_texture"
			var property := Layer3D.Property.new(property_path, new_tex, original_tex)
			properties.append(property)
		layer.update_animation_track(drawing_on_3d_node, properties, project.current_frame)
	else:
		Global.canvas.update_selected_cels_textures(project)
		var tile_editing_mode := TileSetPanel.tile_editing_mode
		if TileSetPanel.placing_tiles:
			tile_editing_mode = TileSetPanel.TileEditingMode.STACK
		project.update_tilemaps(_undo_data, tile_editing_mode)
		var redo_data := _get_undo_data()
		var frame_index := -1
		var layer_index := -1
		if (
			Global.animation_timeline.animation_timer.is_stopped()
			and project.selected_cels.size() == 1
		):
			frame_index = project.current_frame
			layer_index = project.current_layer
		project.undo_redo.create_action(action)
		manage_undo_redo_palettes()
		project.deserialize_cel_undo_data(redo_data, _undo_data)
		project.undo_redo.add_do_method(Global.undo_or_redo.bind(false, frame_index, layer_index))
		project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true, frame_index, layer_index))
		project.undo_redo.commit_action()

	_undo_data.clear()


## Manages conversion of global palettes into local if a drawable tool is used
func manage_undo_redo_palettes() -> void:
	if _is_eraser:
		return
	var palette_in_focus := Palettes.current_palette
	if not is_instance_valid(palette_in_focus):
		return
	var palette_has_color := Palettes.current_palette.has_theme_color(tool_slot.color)
	if not palette_in_focus.is_project_palette:
		# Make a project copy of the palette if it has (or about to have) the color
		# and is still global
		if palette_has_color or Palettes.auto_add_colors:
			palette_in_focus = palette_in_focus.duplicate()
			palette_in_focus.is_project_palette = true
			Palettes.undo_redo_add_palette(palette_in_focus)
	if Palettes.auto_add_colors and not palette_has_color:
		# Get an estimate of where the color will end up (used for undo)
		var index := 0
		var color_max: int = palette_in_focus.colors_max
		# If palette is full automatically increase the palette height
		if palette_in_focus.is_full():
			color_max = palette_in_focus.width * (palette_in_focus.height + 1)
		for i in range(0, color_max):
			if not palette_in_focus.colors.has(i):
				index = i
				break
		var undo_redo := Global.current_project.undo_redo
		undo_redo.add_do_method(palette_in_focus.add_color.bind(tool_slot.color, 0))
		undo_redo.add_undo_method(palette_in_focus.remove_color.bind(index))
		if not Global.palette_panel:  # Failsafe
			printerr("Missing global reference to PalettePanel")
			return
		undo_redo.add_do_method(Global.palette_panel.redraw_current_palette)
		undo_redo.add_undo_method(Global.palette_panel.redraw_current_palette)
		undo_redo.add_do_method(Global.palette_panel.toggle_add_delete_buttons)
		undo_redo.add_undo_method(Global.palette_panel.toggle_add_delete_buttons)


func draw_tool(pos: Vector2i) -> void:
	var project := Global.current_project
	if project.has_selection:
		project.selection_map.lock_selection_rect(project, true)
	if Global.mirror_view:
		# Even brushes are not perfectly centered and are offsetted by 1 px, so we add it.
		if int(_stroke_dimensions.x) % 2 == 0:
			pos.x += 1
	_prepare_tool()
	var coords_to_draw := _draw_tool(pos)
	for coord in coords_to_draw:
		_set_pixel_no_cache(coord)
	if project.has_selection:
		project.selection_map.lock_selection_rect(project, false)


func draw_end(pos: Vector2i) -> void:
	super.draw_end(pos)
	_stroke_project = null
	_stroke_images = []
	drawing_on_3d_node = null
	materials_3d = {}
	_circle_tool_shortcut = []
	_brush_size_dynamics = _brush_size
	match _brush.type:
		Brushes.FILE, Brushes.RANDOM_FILE, Brushes.CUSTOM:
			_brush_image = _create_blended_brush_image(_orignal_brush_image)
			update_brush_image_flip_and_rotate()
			_brush_texture = ImageTexture.create_from_image(_brush_image)
			update_mirror_brush()
			_stroke_dimensions = _brush_image.get_size()
	_indicator = _create_brush_indicator()
	_polylines = _create_polylines(_indicator)


func cancel_tool() -> void:
	super()
	for data in _undo_data:
		if data is not Image:
			continue
		var image_data = _undo_data[data]["data"]
		data.set_data(
			data.get_width(), data.get_height(), data.has_mipmaps(), data.get_format(), image_data
		)
	Global.canvas.sprite_changed_this_frame = true


func draw_tile(pos: Vector2i) -> void:
	var tile_index := 0 if _is_eraser else TileSetPanel.selected_tile_index
	var mirrored_positions := Tools.get_mirrored_positions(pos, Global.current_project)
	var tile_positions: Array[Vector2i] = []
	tile_positions.resize(mirrored_positions.size() + 1)
	tile_positions[0] = get_cell_position(pos)
	for i in mirrored_positions.size():
		var mirrored_position := mirrored_positions[i]
		tile_positions[i + 1] = get_cell_position(mirrored_position)
	for cel in _get_selected_draw_cels():
		if cel is not CelTileMap:
			return
		for tile_position in tile_positions:
			var cell := (cel as CelTileMap).get_cell_at(tile_position)
			(cel as CelTileMap).set_index(cell, tile_index)


func _prepare_tool() -> void:
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return
	_brush_size_dynamics = _brush_size
	var strength := Tools.get_alpha_dynamic(_strength)
	var max_inctrment := maxi(1, _brush_size + Tools.brush_size_max_increment)
	if Tools.dynamics_size == Tools.Dynamics.PRESSURE:
		_brush_size_dynamics = roundi(lerpf(_brush_size, max_inctrment, Tools.pen_pressure))
	elif Tools.dynamics_size == Tools.Dynamics.VELOCITY:
		_brush_size_dynamics = roundi(lerpf(_brush_size, max_inctrment, Tools.mouse_velocity))
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


func draw_fill_gap(start: Vector2i, end: Vector2i) -> void:
	var project := Global.current_project
	if project.has_selection:
		project.selection_map.lock_selection_rect(project, true)
	if Global.mirror_view:
		# Even brushes are not perfectly centred and are offsetted by 1 px so we add it
		if int(_stroke_dimensions.x) % 2 == 0:
			start.x += 1
			end.x += 1
	_prepare_tool()
	# This needs to be a dictionary to ensure duplicate coordinates are not being added
	var coords_to_draw := {}
	var pixel_coords := Geometry2D.bresenham_line(start, end)
	pixel_coords.pop_front()
	if project.get_current_cel() is Cel3D:
		var layer := project.layers[project.current_layer] as Layer3D
		for i in pixel_coords.size():
			var pos := pixel_coords[i]
			var draw_pos := draw_on_3d_object(pos, layer, false)
			if draw_pos == Vector2.INF:
				return
			pixel_coords[i] = Vector2i(draw_pos)
	for current_pixel_coord in pixel_coords:
		if _spacing_mode:
			current_pixel_coord = get_spacing_position(current_pixel_coord)
		for coord in _draw_tool(current_pixel_coord):
			coords_to_draw[coord] = 0
	for c in coords_to_draw.keys():
		_set_pixel_no_cache(c)
	if project.has_selection:
		project.selection_map.lock_selection_rect(project, false)


func draw_on_3d_object(pos: Vector2, layer: Layer3D, clear_mat := true) -> Vector2:
	var object_data := get_3d_node_uvs(pos, layer.camera)
	if object_data.is_empty():
		if clear_mat:
			drawing_on_3d_node = null
			materials_3d = {}
		return Vector2.INF
	var mesh_instance := object_data[0] as MeshInstance3D
	if mesh_instance.mesh.get_surface_count() == 0:
		if clear_mat:
			drawing_on_3d_node = null
			materials_3d = {}
		return Vector2.INF
	var uv := object_data[1] as Vector2
	var surface_index := object_data[2] as int
	var image: ImageExtended
	if mesh_instance.mesh.surface_get_material(surface_index) == null:
		var mat := StandardMaterial3D.new()
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mesh_instance.mesh.surface_set_material(surface_index, mat)
		image = ImageExtended.create_custom(
			64, 64, false, Global.current_project.get_image_format(), false
		)
		mat.albedo_texture = ImageTexture.create_from_image(image)
		drawing_on_3d_node = mesh_instance
		materials_3d[mat] = [image, surface_index]
	else:
		var mat := mesh_instance.mesh.surface_get_material(surface_index) as BaseMaterial3D
		if not is_instance_valid(mat.albedo_texture):
			image = ImageExtended.create_custom(
				64, 64, false, Global.current_project.get_image_format(), false
			)
			image.fill(Color.WHITE)
			mat.albedo_texture = ImageTexture.create_from_image(image)
		var temp_image := mat.albedo_texture.get_image()
		image = ImageExtended.new()
		image.copy_from_custom(temp_image)
		if not materials_3d.has(mat):
			drawing_on_3d_node = mesh_instance
			materials_3d[mat] = [image, surface_index]
	return uv * Vector2(image.get_size())


func update_materials(images: Array[ImageExtended]) -> void:
	if not materials_3d.is_empty():
		for i in materials_3d.size():
			var mat := materials_3d.keys()[i] as BaseMaterial3D
			if i < images.size():
				mat.albedo_texture.update(images[i])


## Calls [method Geometry2D.bresenham_line] and takes [param thickness] into account.
## Used by tools such as the line and the curve tool.
func bresenham_line_thickness(from: Vector2i, to: Vector2i, thickness: int) -> Array[Vector2i]:
	var array: Array[Vector2i] = []
	for pixel in Geometry2D.bresenham_line(from, to):
		var start := pixel - Vector2i.ONE * (thickness >> 1)
		var end := start + Vector2i.ONE * thickness
		for yy in range(start.y, end.y):
			for xx in range(start.x, end.x):
				array.append(Vector2i(xx, yy))
	return array


## Compute the array of coordinates that should be drawn.
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
		var tilemap_cel := Global.current_project.get_current_cel() as CelTileMap
		var grid_size := tilemap_cel.get_tile_size()
		var grid_center := Vector2()
		if tilemap_cel.get_tile_shape() != TileSet.TILE_SHAPE_SQUARE:
			var cell_position := tilemap_cel.get_cell_position(snapped_position)
			grid_center = tilemap_cel.get_pixel_coords(cell_position) + (grid_size / 2)
		else:
			var offset := tilemap_cel.offset % grid_size
			var offset_pos := snapped_position - Vector2(grid_size / 2) - Vector2(offset)
			grid_center = offset_pos.snapped(grid_size) + Vector2(grid_size / 2) + Vector2(offset)
		snapped_position = grid_center.floor()
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
	update_materials(images)


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

	for pixel in Geometry2D.bresenham_line(start, end):
		_blit_indicator(bitmap, indicator, pixel)
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


func _on_flip_horizontal_button_pressed() -> void:
	_brush_flip_x = not _brush_flip_x
	update_brush()
	save_config()


func _on_flip_vertical_button_pressed() -> void:
	_brush_flip_y = not _brush_flip_y
	update_brush()
	save_config()


func _on_rotate_pressed(clockwise: bool) -> void:
	for i in TileSetPanel.ROTATION_MATRIX.size():
		var final_i := i
		if (
			_brush_flip_x == TileSetPanel.ROTATION_MATRIX[i * 3]
			&& _brush_flip_y == TileSetPanel.ROTATION_MATRIX[i * 3 + 1]
			&& _brush_transposed == TileSetPanel.ROTATION_MATRIX[i * 3 + 2]
		):
			if clockwise:
				@warning_ignore("integer_division")
				final_i = i / 4 * 4 + posmod(i - 1, 4)
			else:
				@warning_ignore("integer_division")
				final_i = i / 4 * 4 + (i + 1) % 4
			_brush_flip_x = TileSetPanel.ROTATION_MATRIX[final_i * 3]
			_brush_flip_y = TileSetPanel.ROTATION_MATRIX[final_i * 3 + 1]
			_brush_transposed = TileSetPanel.ROTATION_MATRIX[final_i * 3 + 2]
			break
	update_brush()
	save_config()


func _update_mm_action(action_name: String) -> void:
	if action_name != "mm_change_brush_size":
		return
	_mm_action = Keychain.actions[&"mm_change_brush_size"] as Keychain.MouseMovementInputAction
	var new_mm_action := Keychain.MouseMovementInputAction.new()
	new_mm_action.action_name = &"mm_change_brush_size"
	new_mm_action.mouse_dir = _mm_action.mouse_dir
	new_mm_action.sensitivity = _mm_action.sensitivity
	_mm_action = new_mm_action
