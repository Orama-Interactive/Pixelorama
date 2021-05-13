extends BaseTool


var _color_slot := 0


func _on_Options_item_selected(id : int) -> void:
	_color_slot = id
	update_config()
	save_config()


func get_config() -> Dictionary:
	return {
		"color_slot" : _color_slot,
	}


func set_config(config : Dictionary) -> void:
	_color_slot = config.get("color_slot", _color_slot)


func update_config() -> void:
	$ColorPicker/Options.selected = _color_slot


func draw_start(position : Vector2) -> void:
	_pick_color(position)


func draw_move(position : Vector2) -> void:
	_pick_color(position)


func draw_end(_position : Vector2) -> void:
	pass


func _pick_color(position : Vector2) -> void:
	if position.x < 0 or position.y < 0:
		return

	var image := Image.new()
	image.copy_from(_get_draw_image())
	if position.x > image.get_width() - 1 or position.y > image.get_height() - 1:
		return

	image.lock()
	var color := image.get_pixelv(position)
	image.unlock()
	var button := BUTTON_LEFT if _color_slot == 0 else BUTTON_RIGHT
	Tools.assign_color(color, button, false)
