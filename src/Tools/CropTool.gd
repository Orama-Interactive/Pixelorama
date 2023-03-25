extends BaseTool
# Crop Tool, allows you to resize the canvas interactively

var _offset := Vector2.ZERO
var _crop: CropRect
var _start_pos: Vector2
var _syncing := false
var _locked_ratio := false


func _ready() -> void:
	_crop = Global.canvas.crop_rect
	_crop.connect("updated", self, "_sync_ui")
	_crop.tool_count += 1
	_sync_ui()


func _exit_tree() -> void:
	_crop.tool_count -= 1


func draw_start(position: Vector2) -> void:
	.draw_start(position)
	_offset = position - _crop.rect.position
	_start_pos = position


func draw_move(position: Vector2) -> void:
	.draw_move(position)
	if _crop.locked_size:
		_crop.rect.position = position - _offset
	else:
		if _crop.mode == CropRect.Mode.POSITION_SIZE and _locked_ratio:
			var ratio: Vector2 = $"%Size".ratio
			var distance := abs(_start_pos.x - position.x) + abs(_start_pos.y - position.y)
			_crop.rect.size.x = round(distance * ratio.x / (ratio.x + ratio.y))
			_crop.rect.size.y = round(distance * ratio.y / (ratio.x + ratio.y))
			if _start_pos.x < position.x:
				_crop.rect.position.x = _start_pos.x
			else:
				_crop.rect.position.x = _start_pos.x - _crop.rect.size.x
			if _start_pos.y < position.y:
				_crop.rect.position.y = _start_pos.y
			else:
				_crop.rect.position.y = _start_pos.y - _crop.rect.size.y
		else:
			_crop.rect.position.x = min(_start_pos.x, position.x)
			_crop.rect.position.y = min(_start_pos.y, position.y)
			_crop.rect.end.x = max(_start_pos.x, position.x)
			_crop.rect.end.y = max(_start_pos.y, position.y)
		# Ensure that the size is at least 1:
		_crop.rect.size.x = max(1, _crop.rect.size.x)
		_crop.rect.size.y = max(1, _crop.rect.size.y)
	_crop.emit_signal("updated")


func _sync_ui() -> void:
	_syncing = true
	$"%CropMode".selected = _crop.mode
	$"%SizeLock".pressed = _crop.locked_size
	match _crop.mode:
		CropRect.Mode.MARGINS:
			$"%MarginsContainer".show()
			$"%RatioContainer".hide()
			$"%PosSizeContainer".hide()
			$"%DimensionsLabel".show()
		CropRect.Mode.POSITION_SIZE:
			$"%MarginsContainer".hide()
			$"%PosSizeContainer".show()
			$"%DimensionsLabel".hide()

	$"%Top".max_value = Global.current_project.size.y - 1
	$"%Bottom".max_value = Global.current_project.size.y
	$"%Left".max_value = Global.current_project.size.x - 1
	$"%Right".max_value = Global.current_project.size.x
	$"%Top".value = _crop.rect.position.y
	$"%Bottom".value = _crop.rect.end.y
	$"%Left".value = _crop.rect.position.x
	$"%Right".value = _crop.rect.end.x

	$"%Position".max_value = Global.current_project.size - Vector2.ONE
	$"%Size".max_value = Global.current_project.size
	$"%Position".value = _crop.rect.position
	$"%Size".value = _crop.rect.size

	$"%DimensionsLabel".text = str(_crop.rect.size.x, " x ", _crop.rect.size.y)
	_syncing = false


# UI Signals:


func _on_CropMode_item_selected(index: int) -> void:
	if _syncing:
		return
	_crop.mode = index
	_crop.emit_signal("updated")


func _on_SizeLock_toggled(button_pressed: bool) -> void:
	if button_pressed:
		$"%SizeLock".icon = preload("res://assets/graphics/misc/locked_size.png")
	else:
		$"%SizeLock".icon = preload("res://assets/graphics/misc/unlocked_size.png")
	if _syncing:
		return
	_crop.locked_size = button_pressed
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
	var prev_ratio: Vector2 = $"%Size".ratio
	$"%Size".ratio.x = value
	_crop.rect.size.x = round(max(1, _crop.rect.size.y / prev_ratio.y * value))
	_crop.emit_signal("updated")


func _on_RatioY_value_changed(value: float) -> void:
	if _syncing:
		return
	var prev_ratio: Vector2 = $"%Size".ratio
	$"%Size".ratio.y = value
	_crop.rect.size.y = round(max(1, _crop.rect.size.x / prev_ratio.x * value))
	_crop.emit_signal("updated")


func _on_Position_value_changed(value: Vector2) -> void:
	if _syncing:
		return
	_crop.rect.position = value
	_crop.emit_signal("updated")


func _on_Size_value_changed(value: Vector2) -> void:
	if _syncing:
		return
	_crop.rect.size = value
	_crop.emit_signal("updated")


func _on_Size_ratio_toggled(button_pressed: bool) -> void:
	$"%RatioX".value = $"%Size".ratio.x
	$"%RatioY".value = $"%Size".ratio.y
	$"%RatioContainer".visible = button_pressed
	_locked_ratio = button_pressed


func _on_Apply_pressed() -> void:
	_crop.apply()
