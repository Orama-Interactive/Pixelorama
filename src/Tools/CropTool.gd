extends BaseTool
# Crop Tool, allows you to resize the canvas interactively

var _crop: CropRect
var _start_pos: Vector2
var _syncing := false

func _ready() -> void:
	_crop = Global.canvas.crop_rect
	_crop.connect("updated", self, "_sync_ui")
	_crop.tool_count += 1
	_sync_ui()


func _exit_tree() -> void:
	_crop.tool_count -= 1


func _sync_ui() -> void:
	_syncing = true
	$"%CropMode".selected = _crop.mode

	match _crop.mode:
		CropRect.Mode.SIDES:
			$"%SidesContainer".show()
			$"%RatioContainer".hide()
			$"%ResolutionContainer".hide()
			$"%DimensionsLabel".show()
		CropRect.Mode.RESOLUTION, CropRect.Mode.LOCKED_RESOLUTION:
			$"%SidesContainer".hide()
			$"%RatioContainer".hide()
			$"%ResolutionContainer".show()
			$"%DimensionsLabel".hide()
		CropRect.Mode.LOCKED_ASPECT_RATIO:
			$"%SidesContainer".hide()
			$"%RatioContainer".show()
			$"%ResolutionContainer".show()
			$"%DimensionsLabel".hide()

	$"%Top".max_value = Global.current_project.size.y - 1
	$"%Bottom".max_value = Global.current_project.size.y
	$"%Left".max_value = Global.current_project.size.x - 1
	$"%Right".max_value = Global.current_project.size.x
	$"%Top".value = _crop.rect.position.y
	$"%Bottom".value = _crop.rect.end.y
	$"%Left".value = _crop.rect.position.x
	$"%Right".value = _crop.rect.end.x

	$"%RatioX".value = _crop.ratio.x
	$"%RatioY".value = _crop.ratio.y

	$"%PositionX".max_value = Global.current_project.size.x - 1
	$"%PositionY".max_value = Global.current_project.size.y - 1
	$"%Width".max_value = Global.current_project.size.x
	$"%Height".max_value = Global.current_project.size.y
	$"%PositionX".value = _crop.rect.position.x
	$"%PositionY".value = _crop.rect.position.y
	$"%Width".value = _crop.rect.size.x
	$"%Height".value = _crop.rect.size.y

	$"%DimensionsLabel".text = str(_crop.rect.size.x, " x ", _crop.rect.size.y)
	_syncing = false


func draw_start(position: Vector2) -> void:
	.draw_start(position)
	_start_pos = position
	if _crop.mode == CropRect.Mode.LOCKED_RESOLUTION:
		_crop.rect.position = position
		_crop.emit_signal("updated")


func draw_move(position: Vector2) -> void:
	.draw_move(position)
	match _crop.mode:
		CropRect.Mode.SIDES, CropRect.Mode.RESOLUTION:
			_crop.rect.position.x = min(_start_pos.x, position.x)
			_crop.rect.position.y = min(_start_pos.y, position.y)
			_crop.rect.end.x = max(_start_pos.x, position.x)
			_crop.rect.end.y = max(_start_pos.y, position.y)
		CropRect.Mode.LOCKED_RESOLUTION:
			_crop.rect.position = position
		CropRect.Mode.LOCKED_ASPECT_RATIO:
			var distance = abs(_start_pos.x - position.x) + abs(_start_pos.y - position.y)
			_crop.rect.size.x = round(distance * _crop.ratio.x / (_crop.ratio.x + _crop.ratio.y))
			_crop.rect.size.y = round(distance * _crop.ratio.y / (_crop.ratio.x + _crop.ratio.y))
			if _start_pos.x < position.x:
				_crop.rect.position.x = _start_pos.x
			else:
				_crop.rect.position.x = _start_pos.x - _crop.rect.size.x
			if _start_pos.y < position.y:
				_crop.rect.position.y = _start_pos.y
			else:
				_crop.rect.position.y = _start_pos.y - _crop.rect.size.y
	# Ensure that the size is at least 1:
	_crop.rect.size.x = max(1, _crop.rect.size.x)
	_crop.rect.size.y = max(1, _crop.rect.size.y)
	_crop.emit_signal("updated")


# UI Signals:

func _on_CropMode_item_selected(index: int) -> void:
	if _syncing:
		return
	_crop.mode = index
	_crop.emit_signal("updated")


func _on_Top_value_changed(value: float) -> void:
	if _syncing:
		return
	var difference := value - _crop.rect.position.y
	_crop.rect.size.y = max(1, _crop.rect.size.y - difference)
	_crop.rect.position.y = value
	_crop.emit_signal("updated")


func _on_Bottom_value_changed(value: float) -> void:
	if _syncing:
		return
	_crop.rect.position.y = min(value - 1, _crop.rect.position.y)
	_crop.rect.end.y = value
	_crop.emit_signal("updated")


func _on_Left_value_changed(value: float) -> void:
	if _syncing:
		return
	var difference := value - _crop.rect.position.x
	_crop.rect.size.x = max(1, _crop.rect.size.x - difference)
	_crop.rect.position.x = value
	_crop.emit_signal("updated")


func _on_Right_value_changed(value: float) -> void:
	if _syncing:
		return
	_crop.rect.position.x = min(value - 1, _crop.rect.position.x)
	_crop.rect.end.x = value
	_crop.emit_signal("updated")


func _on_RatioX_value_changed(value: float) -> void:
	if _syncing:
		return
	_crop.rect.size.x = round(max(1, _crop.rect.size.y / _crop.ratio.y * value))
	_crop.ratio.x = value
	_crop.emit_signal("updated")


func _on_RatioY_value_changed(value: float) -> void:
	if _syncing:
		return
	_crop.rect.size.y = round(max(1, _crop.rect.size.x / _crop.ratio.x * value))
	_crop.ratio.y = value
	_crop.emit_signal("updated")


func _on_PositionX_value_changed(value: float) -> void:
	if _syncing:
		return
	_crop.rect.position.x = value
	_crop.emit_signal("updated")


func _on_PositionY_value_changed(value: float) -> void:
	if _syncing:
		return
	_crop.rect.position.y = value
	_crop.emit_signal("updated")


func _on_Width_value_changed(value: float) -> void:
	if _syncing:
		return
	if _crop.mode == CropRect.Mode.LOCKED_ASPECT_RATIO:
		_crop.rect.size.y = round(max(1, (value / _crop.ratio.x) * _crop.ratio.y))
	_crop.rect.size.x = value
	_crop.emit_signal("updated")


func _on_Height_value_changed(value: float) -> void:
	if _syncing:
		return
	if _crop.mode == CropRect.Mode.LOCKED_ASPECT_RATIO:
		_crop.rect.size.x = round(max(1, (value / _crop.ratio.y) * _crop.ratio.x))
	_crop.rect.size.y = value
	_crop.emit_signal("updated")


func _on_Apply_pressed() -> void:
	_crop.apply()
