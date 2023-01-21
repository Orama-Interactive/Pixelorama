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


func _on_ExtractFrom_item_selected(index):
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


func draw_start(position: Vector2) -> void:
	.draw_start(position)
	_pick_color(position)


func draw_move(position: Vector2) -> void:
	.draw_move(position)
	_pick_color(position)


func draw_end(position: Vector2) -> void:
	.draw_end(position)


func _pick_color(position: Vector2) -> void:
	var project: Project = Global.current_project
	position = project.tiles.get_canon_position(position)

	if position.x < 0 or position.y < 0:
		return

	var color := Color(0, 0, 0, 0)
	var image := Image.new()
	image.copy_from(_get_draw_image())
	if position.x > image.get_width() - 1 or position.y > image.get_height() - 1:
		return
	match _mode:
		TOP_COLOR:
			var curr_frame: Frame = project.frames[project.current_frame]
			for layer in project.layers.size():
				var idx = (project.layers.size() - 1) - layer
				if project.layers[idx].can_layer_get_drawn():
					image = curr_frame.cels[idx].get_image()
					image.lock()
					color = image.get_pixelv(position)
					image.unlock()
					if color != Color(0, 0, 0, 0):
						break
		CURRENT_LAYER:
			image.lock()
			color = image.get_pixelv(position)
			image.unlock()
	var button := BUTTON_LEFT if _color_slot == 0 else BUTTON_RIGHT
	Tools.assign_color(color, button, false)
