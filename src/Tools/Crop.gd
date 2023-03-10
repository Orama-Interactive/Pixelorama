extends BaseTool
# Crop Tool, allows you to resize the canvas interactively

var _crop_rect: CropRect
var _start_pos: Vector2

func _ready():
	_crop_rect = Global.canvas.crop_rect
	_crop_rect.connect("updated", self, "_rect_updated")
	_crop_rect.tool_count += 1
	_rect_updated()


func _exit_tree():
	_crop_rect.tool_count -= 1


func _rect_updated():
	$"%Top".max_value = Global.current_project.size.y - 1
	$"%Bottom".max_value = Global.current_project.size.y
	$"%Left".max_value = Global.current_project.size.x - 1
	$"%Right".max_value = Global.current_project.size.x
	$"%Top".value = _crop_rect.top
	$"%Bottom".value = _crop_rect.bottom
	$"%Left".value = _crop_rect.left
	$"%Right".value = _crop_rect.right
	$"%DimensionsLabel".text = str(_crop_rect.right - _crop_rect.left, " x ", _crop_rect.bottom - _crop_rect.top)


func draw_start(position: Vector2) -> void:
	.draw_start(position)
	_start_pos = position


func draw_move(position: Vector2) -> void:
	.draw_move(position)
	_crop_rect.top = min(_start_pos.y, position.y)
	_crop_rect.bottom = max(_start_pos.y, position.y)
	_crop_rect.left = min(_start_pos.x, position.x)
	_crop_rect.right = max(_start_pos.x, position.x)
	_crop_rect.emit_signal("updated")


# UI Signals:

func _on_Top_value_changed(value: float) -> void:
	_crop_rect.top = value
	_crop_rect.bottom = max(_crop_rect.top + 1, _crop_rect.bottom)
	_crop_rect.emit_signal("updated")


func _on_Bottom_value_changed(value: float) -> void:
	_crop_rect.bottom = value
	_crop_rect.top = min(_crop_rect.bottom - 1, _crop_rect.top)
	_crop_rect.emit_signal("updated")


func _on_Left_value_changed(value: float) -> void:
	_crop_rect.left = value
	_crop_rect.right = max(_crop_rect.left + 1, _crop_rect.right)
	_crop_rect.emit_signal("updated")


func _on_Right_value_changed(value: float) -> void:
	_crop_rect.right = value
	_crop_rect.left = min(_crop_rect.right - 1, _crop_rect.left)
	_crop_rect.emit_signal("updated")


func _on_Apply_pressed():
	_crop_rect.apply()
