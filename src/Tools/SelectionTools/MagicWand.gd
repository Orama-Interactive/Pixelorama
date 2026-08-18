extends BaseSelectionTool

var _tolerance := 0.003


func apply_selection(pos: Vector2i) -> void:
	super.apply_selection(pos)
	var project := Global.current_project
	if pos.x < 0 or pos.y < 0 or pos.x >= project.size.x or pos.y >= project.size.y:
		return
	var previous_selection_map := SelectionMap.new()  # Used for intersect
	previous_selection_map.copy_from(project.selection_map)
	if !_add and !_subtract and !_intersect:
		Global.canvas.selection.clear_selection()
	if _intersect:
		project.selection_map.clear()

	var cel_image := Image.new()
	cel_image.copy_from(_get_draw_image())
	_flood_fill(pos, cel_image, project, previous_selection_map)
	# Handle mirroring
	for mirror_pos in Tools.get_mirrored_positions(pos):
		_flood_fill(mirror_pos, cel_image, project, previous_selection_map)

	Global.canvas.selection.commit_undo("Select", undo_data)


func get_config() -> Dictionary:
	var config := super.get_config()
	config["tolerance"] = _tolerance
	return config


func set_config(config: Dictionary) -> void:
	super.set_config(config)
	_tolerance = config.get("tolerance", _tolerance)


func update_config() -> void:
	super.update_config()
	$ToleranceSlider.value = _tolerance * 255.0


func _on_tolerance_slider_value_changed(value: float) -> void:
	_tolerance = value / 255.0
	update_config()
	save_config()


func _flood_fill(
	pos: Vector2i, image: Image, project: Project, previous_selection_map: SelectionMap
) -> void:
	# implements the floodfill routine by Shawn Hargreaves
	# from https://www1.udel.edu/CIS/software/dist/allegro-4.2.1/src/flood.c
	var selection_map := project.selection_map
	if Tools.is_placing_tiles():
		for cel in _get_selected_draw_cels():
			if cel is not CelTileMap:
				continue
			var tilemap_cel := cel as CelTileMap
			var cell_pos := tilemap_cel.get_cell_position(pos)
			tilemap_cel.bucket_fill(cell_pos, _set_bit_rect.bind(project, previous_selection_map))
		return
	var flood_fill_object := FloodFillObject.new()
	flood_fill_object.tolerance = _tolerance
	flood_fill_object.flood_fill(
		pos, image, selection_map, project, _select_segments.bind(previous_selection_map)
	)


func _select_segments(
	selection_map: SelectionMap,
	segments: Array[FloodFillObject.Segment],
	previous_selection_map: SelectionMap
) -> void:
	# short circuit for flat colors
	for c in segments.size():
		var p := segments[c]
		for px in range(p.left_position, p.right_position + 1):
			# We don't have to check again whether the point being processed is within the bounds
			_set_bit(Vector2i(px, p.y), selection_map, previous_selection_map)


func _set_bit(p: Vector2i, selection_map: SelectionMap, prev_selection_map: SelectionMap) -> void:
	if _intersect:
		selection_map.select_pixel(p, prev_selection_map.is_pixel_selected(p))
	else:
		selection_map.select_pixel(p, !_subtract)


func _set_bit_rect(
	p: Vector2i, _index: int, project: Project, prev_selection_map: SelectionMap
) -> void:
	var selection_map := project.selection_map
	var tilemap := project.get_current_cel() as CelTileMap
	var pixel_coords := p * tilemap.get_tile_size()
	if _intersect:
		select_tilemap_cell(
			tilemap, pixel_coords, project.selection_map, prev_selection_map.is_pixel_selected(p)
		)
	else:
		select_tilemap_cell(tilemap, pixel_coords, project.selection_map, !_subtract)
