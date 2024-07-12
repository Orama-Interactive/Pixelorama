extends BaseTool
## Crop Tool, allows you to resize the canvas interactively

var _offset := Vector2i.ZERO
var _crop: CropRect
var _start_pos: Vector2
var _syncing := false
var _locked_ratio := false


func _ready() -> void:
	super._ready()
	_crop = Global.canvas.crop_rect
	_crop.updated.connect(_sync_ui)
	_crop.tool_count += 1
	_sync_ui()


func _exit_tree() -> void:
	super._exit_tree()
	_crop.tool_count -= 1


func draw_start(pos: Vector2i) -> void:
	super.draw_start(pos)
	_offset = pos - _crop.rect.position
	_start_pos = pos


func draw_move(pos: Vector2i) -> void:
	super.draw_move(pos)
	if _crop.locked_size:
		_crop.rect.position = pos - _offset
	else:
		if _crop.mode == CropRect.Mode.POSITION_SIZE and _locked_ratio:
			var ratio: Vector2 = $"%Size".ratio
			var distance := absf(_start_pos.x - pos.x) + absf(_start_pos.y - pos.y)
			_crop.rect.size.x = roundi(distance * ratio.x / (ratio.x + ratio.y))
			_crop.rect.size.y = roundi(distance * ratio.y / (ratio.x + ratio.y))
			if _start_pos.x < pos.x:
				_crop.rect.position.x = _start_pos.x
			else:
				_crop.rect.position.x = _start_pos.x - _crop.rect.size.x
			if _start_pos.y < pos.y:
				_crop.rect.position.y = _start_pos.y
			else:
				_crop.rect.position.y = _start_pos.y - _crop.rect.size.y
		else:
			_crop.rect.position.x = mini(_start_pos.x, pos.x)
			_crop.rect.position.y = mini(_start_pos.y, pos.y)
			_crop.rect.end.x = maxi(_start_pos.x, pos.x)
			_crop.rect.end.y = maxi(_start_pos.y, pos.y)
		# Ensure that the size is at least 1:
		_crop.rect.size.x = maxi(1, _crop.rect.size.x)
		_crop.rect.size.y = maxi(1, _crop.rect.size.y)
	_crop.updated.emit()


func _sync_ui() -> void:
	_syncing = true
	$"%CropMode".selected = _crop.mode
	$"%SizeLock".button_pressed = _crop.locked_size
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

	$"%Top".max_value = (Global.current_project.size.y * 2) - 1
	$"%Bottom".max_value = Global.current_project.size.y * 2
	$"%Left".max_value = (Global.current_project.size.x * 2) - 1
	$"%Right".max_value = Global.current_project.size.x * 2
	$"%Top".min_value = -Global.current_project.size.y + 1
	$"%Bottom".min_value = -Global.current_project.size.y
	$"%Left".min_value = -Global.current_project.size.x + 1
	$"%Right".min_value = -Global.current_project.size.x
	$"%Top".value = _crop.rect.position.y
	$"%Bottom".value = _crop.rect.end.y
	$"%Left".value = _crop.rect.position.x
	$"%Right".value = _crop.rect.end.x

	$"%Position".max_value = (Global.current_project.size * 2) - Vector2i.ONE
	$"%Size".max_value = Global.current_project.size * 2
	$"%Position".min_value = -Global.current_project.size + Vector2i.ONE
	$"%Size".min_value = -Global.current_project.size
	$"%Position".value = _crop.rect.position
	$"%Size".value = _crop.rect.size

	$"%DimensionsLabel".text = str(_crop.rect.size.x, " x ", _crop.rect.size.y)
	_syncing = false


# UI Signals:


func _on_CropMode_item_selected(index: CropRect.Mode) -> void:
	if _syncing:
		return
	_crop.mode = index
	_crop.updated.emit()


func _on_SizeLock_toggled(button_pressed: bool) -> void:
	if button_pressed:
		$"%SizeLock".icon = preload("res://assets/graphics/misc/locked_size.png")
	else:
		$"%SizeLock".icon = preload("res://assets/graphics/misc/unlocked_size.png")
	if _syncing:
		return
	_crop.locked_size = button_pressed
	_crop.updated.emit()


func _on_Top_value_changed(value: float) -> void:
	if _syncing:
		return
	var difference := value - _crop.rect.position.y
	_crop.rect.size.y = max(1, _crop.rect.size.y - difference)
	_crop.rect.position.y = value
	_crop.updated.emit()


func _on_Bottom_value_changed(value: float) -> void:
	if _syncing:
		return
	_crop.rect.position.y = mini(value - 1, _crop.rect.position.y)
	_crop.rect.end.y = value
	_crop.updated.emit()


func _on_Left_value_changed(value: float) -> void:
	if _syncing:
		return
	var difference := value - _crop.rect.position.x
	_crop.rect.size.x = maxi(1, _crop.rect.size.x - difference)
	_crop.rect.position.x = value
	_crop.updated.emit()


func _on_Right_value_changed(value: float) -> void:
	if _syncing:
		return
	_crop.rect.position.x = mini(value - 1, _crop.rect.position.x)
	_crop.rect.end.x = value
	_crop.updated.emit()


func _on_RatioX_value_changed(value: float) -> void:
	if _syncing:
		return
	var prev_ratio: Vector2 = $"%Size".ratio
	$"%Size".ratio.x = value
	_crop.rect.size.x = roundi(maxf(1, _crop.rect.size.y / prev_ratio.y * value))
	_crop.updated.emit()


func _on_RatioY_value_changed(value: float) -> void:
	if _syncing:
		return
	var prev_ratio: Vector2 = $"%Size".ratio
	$"%Size".ratio.y = value
	_crop.rect.size.y = roundi(maxf(1, _crop.rect.size.x / prev_ratio.x * value))
	_crop.updated.emit()


func _on_Position_value_changed(value: Vector2i) -> void:
	if _syncing:
		return
	_crop.rect.position = value
	_crop.updated.emit()


func _on_Size_value_changed(value: Vector2i) -> void:
	if _syncing:
		return
	_crop.rect.size = value
	_crop.updated.emit()


func _on_Size_ratio_toggled(button_pressed: bool) -> void:
	$"%RatioX".value = $"%Size".ratio.x
	$"%RatioY".value = $"%Size".ratio.y
	$"%RatioContainer".visible = button_pressed
	_locked_ratio = button_pressed


func _on_Apply_pressed() -> void:
	_crop.apply()
