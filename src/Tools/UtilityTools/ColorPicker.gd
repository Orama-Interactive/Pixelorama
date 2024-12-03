extends BaseTool

enum { TOP_COLOR, CURRENT_LAYER }

var _prev_mode := 0
var _color_slot := 0
var _mode := 0


func _input(event: InputEvent) -> void:
	var options: OptionButton = $ColorPicker/Options

	if event.is_action_pressed("change_tool_mode"):
		_prev_mode = options.selected
	if event.is_action("change_tool_mode"):
		options.selected = _prev_mode ^ 1
		_color_slot = options.selected
	if event.is_action_released("change_tool_mode"):
		options.selected = _prev_mode
		_color_slot = options.selected


func _on_Options_item_selected(id: int) -> void:
	_color_slot = id
	update_config()
	save_config()


func _on_ExtractFrom_item_selected(index: int) -> void:
	_mode = index
	update_config()
	save_config()


func get_config() -> Dictionary:
	return {"color_slot": _color_slot, "mode": _mode}


func set_config(config: Dictionary) -> void:
	_color_slot = config.get("color_slot", _color_slot)
	_mode = config.get("mode", _mode)


func update_config() -> void:
	$ColorPicker/Options.selected = _color_slot
	$ColorPicker/ExtractFrom.selected = _mode


func draw_start(pos: Vector2i) -> void:
	super.draw_start(pos)
	_pick_color(pos)


func draw_move(pos: Vector2i) -> void:
	super.draw_move(pos)
	_pick_color(pos)


func draw_end(pos: Vector2i) -> void:
	super.draw_end(pos)


func _pick_color(pos: Vector2i) -> void:
	var project := Global.current_project
	pos = project.tiles.get_canon_position(pos)
	if pos.x < 0 or pos.y < 0:
		return
	if Tools.is_placing_tiles():
		var cel := Global.current_project.get_current_cel() as CelTileMap
		Tools.selected_tile_index_changed.emit(cel.get_cell_index_at_coords(pos))
		return
	var image := Image.new()
	image.copy_from(_get_draw_image())
	if pos.x > image.get_width() - 1 or pos.y > image.get_height() - 1:
		return

	var color := Color(0, 0, 0, 0)
	var palette_index = -1
	match _mode:
		TOP_COLOR:
			var curr_frame := project.frames[project.current_frame]
			for layer in project.layers.size():
				var idx := (project.layers.size() - 1) - layer
				if project.layers[idx].is_visible_in_hierarchy():
					var cel := curr_frame.cels[idx]
					image = cel.get_image()
					color = image.get_pixelv(pos)
					# If image is indexed then get index as well
					if cel is PixelCel:
						if cel.image.is_indexed:
							palette_index = cel.image.indices_image.get_pixel(pos.x, pos.y).r8 - 1
					if not is_zero_approx(color.a):
						break
		CURRENT_LAYER:
			color = image.get_pixelv(pos)
			var current_cel = Global.current_project.get_current_cel()
			if current_cel is PixelCel:
				if current_cel.image.is_indexed:
					palette_index = current_cel.image.index_image.get_pixel(pos.x, pos.y).r8 - 1
	var button := MOUSE_BUTTON_LEFT if _color_slot == 0 else MOUSE_BUTTON_RIGHT
	Tools.assign_color(color, button, false, palette_index)
