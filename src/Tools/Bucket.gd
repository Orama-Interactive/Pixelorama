extends BaseTool


var _pattern : Patterns.Pattern
var _fill_area := 0
var _fill_with := 0
var _offset_x := 0
var _offset_y := 0


func _ready() -> void:
	update_pattern()


func _on_FillAreaOptions_item_selected(index : int) -> void:
	_fill_area = index
	update_config()
	save_config()


func _on_FillWithOptions_item_selected(index : int) -> void:
	_fill_with = index
	update_config()
	save_config()


func _on_PatternType_pressed():
	Global.patterns_popup.connect("pattern_selected", self, "_on_Pattern_selected", [], CONNECT_ONESHOT)
	Global.patterns_popup.popup(Rect2($FillPattern/Type.rect_global_position, Vector2(226, 72)))


func _on_Pattern_selected(pattern : Patterns.Pattern) -> void:
	_pattern = pattern
	update_pattern()
	save_config()


func _on_PatternOffsetX_value_changed(value : float) -> void:
	_offset_x = int(value)
	update_config()
	save_config()


func _on_PatternOffsetY_value_changed(value : float) -> void:
	_offset_y = int(value)
	update_config()
	save_config()


func get_config() -> Dictionary:
	if !_pattern:
		return {}
	return {
		"pattern_index" : _pattern.index,
		"fill_area" : _fill_area,
		"fill_with" : _fill_with,
		"offset_x" : _offset_x,
		"offset_y" : _offset_y,
	}


func set_config(config : Dictionary) -> void:
	if _pattern:
		var index = config.get("pattern_index", _pattern.index)
		_pattern = Global.patterns_popup.get_pattern(index)
	_fill_area = config.get("fill_area", _fill_area)
	_fill_with = config.get("fill_with", _fill_with)
	_offset_x = config.get("offset_x", _offset_x)
	_offset_y = config.get("offset_y", _offset_y)
	update_pattern()


func update_config() -> void:
	$FillAreaOptions.selected = _fill_area
	$FillWithOptions.selected = _fill_with
	$Mirror.visible = _fill_area == 0
	$FillPattern.visible = _fill_with == 1
	$FillPattern/XOffset/OffsetX.value = _offset_x
	$FillPattern/YOffset/OffsetY.value = _offset_y


func update_pattern() -> void:
	if _pattern == null:
		if Global.patterns_popup.default_pattern == null:
			return
		else:
			_pattern = Global.patterns_popup.default_pattern
	var tex := ImageTexture.new()
	tex.create_from_image(_pattern.image, 0)
	$FillPattern/Type/Texture.texture = tex
	var size := _pattern.image.get_size()
	$FillPattern/XOffset/OffsetX.max_value = size.x - 1
	$FillPattern/YOffset/OffsetY.max_value = size.y - 1


func draw_start(position : Vector2) -> void:
	Global.canvas.selection.transform_content_confirm()
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn() or !Global.current_project.tile_mode_rects[Global.TileMode.NONE].has_point(position):
		return
	if Global.current_project.has_selection and not Global.current_project.can_pixel_get_drawn(position):
		return
	var undo_data = _get_undo_data()
	if _fill_area == 0:
		fill_in_area(position)
	else:
		fill_in_color(position)
	commit_undo("Draw", undo_data)


func draw_move(_position : Vector2) -> void:
	pass


func draw_end(_position : Vector2) -> void:
	pass


func fill_in_color(position : Vector2) -> void:
	var project : Project = Global.current_project
	var image := _get_draw_image()
	var color := image.get_pixelv(position)
	if _fill_with == 0 or _pattern == null:
		if tool_slot.color.is_equal_approx(color):
			return

	image.lock()

	for x in Global.current_project.size.x:
		for y in Global.current_project.size.y:
			var pos := Vector2(x, y)
			if project.has_selection and not project.can_pixel_get_drawn(pos):
				continue
			if image.get_pixelv(pos).is_equal_approx(color):
				_set_pixel(image, x, y, tool_slot.color)


func fill_in_area(position : Vector2) -> void:
	var project : Project = Global.current_project
	_flood_fill(position)

	# Handle Mirroring
	var mirror_x = project.x_symmetry_point - position.x
	var mirror_y = project.y_symmetry_point - position.y
	var mirror_x_inside : bool
	var mirror_y_inside : bool

	mirror_x_inside = project.can_pixel_get_drawn(Vector2(mirror_x, position.y))
	mirror_y_inside = project.can_pixel_get_drawn(Vector2(position.x, mirror_y))

	if tool_slot.horizontal_mirror and mirror_x_inside:
		_flood_fill(Vector2(mirror_x, position.y))
		if tool_slot.vertical_mirror and mirror_y_inside:
			_flood_fill(Vector2(mirror_x, mirror_y))
	if tool_slot.vertical_mirror and mirror_y_inside:
		_flood_fill(Vector2(position.x, mirror_y))


func _flood_fill(position : Vector2) -> void:
	var project : Project = Global.current_project
	var image := _get_draw_image()
	var color := image.get_pixelv(position)
	if _fill_with == 0 or _pattern == null:
		if tool_slot.color.is_equal_approx(color):
			return

	image.lock()
	var processed := BitMap.new()
	processed.create(image.get_size())
	var q = [position]
	for n in q:
		if processed.get_bit(n):
			continue
		var west : Vector2 = n
		var east : Vector2 = n
		while west.x >= 0 && image.get_pixelv(west).is_equal_approx(color):
			west += Vector2.LEFT
		while east.x < project.size.x && image.get_pixelv(east).is_equal_approx(color):
			east += Vector2.RIGHT
		for px in range(west.x + 1, east.x):
			var p := Vector2(px, n.y)
			_set_pixel(image, p.x, p.y, tool_slot.color)
			processed.set_bit(p, true)
			var north := p + Vector2.UP
			var south := p + Vector2.DOWN
			if north.y >= 0 && image.get_pixelv(north).is_equal_approx(color):
				q.append(north)
			if south.y < project.size.y && image.get_pixelv(south).is_equal_approx(color):
				q.append(south)


func _set_pixel(image : Image, x : int, y : int, color : Color) -> void:
	var project : Project = Global.current_project
	if !project.can_pixel_get_drawn(Vector2(x, y)):
		return

	if _fill_with == 0 or _pattern == null:
		image.set_pixel(x, y, color)
	else:
		_pattern.image.lock()
		var size := _pattern.image.get_size()
		var px := int(x + _offset_x) % int(size.x)
		var py := int(y + _offset_y) % int(size.y)
		var pc := _pattern.image.get_pixel(px, py)
		image.set_pixel(x, y, pc)


func commit_undo(action : String, undo_data : Dictionary) -> void:
	var redo_data = _get_undo_data()
	var project : Project = Global.current_project
	var image : Image = project.frames[project.current_frame].cels[project.current_layer].image

	project.undos += 1
	project.undo_redo.create_action(action)
	project.undo_redo.add_do_property(image, "data", redo_data["image_data"])
	project.undo_redo.add_undo_property(image, "data", undo_data["image_data"])
	project.undo_redo.add_do_method(Global, "redo", project.current_frame, project.current_layer)
	project.undo_redo.add_undo_method(Global, "undo", project.current_frame, project.current_layer)
	project.undo_redo.commit_action()


func _get_undo_data() -> Dictionary:
	var data = {}
	var project : Project = Global.current_project
	var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	image.unlock()
	data["image_data"] = image.data
	image.lock()
	return data
