extends BaseTool

var _top := 0
var _bottom := 0
var _left := 0
var _right := 0

var _start_pos: Vector2

func _ready():
	$"%Top".max_value = Global.current_project.size.y - 1
	$"%Bottom".max_value = Global.current_project.size.y
	$"%Left".max_value = Global.current_project.size.x - 1
	$"%Right".max_value = Global.current_project.size.x

func draw_start(position: Vector2) -> void:
	.draw_start(position)
	_start_pos = position


func draw_move(position: Vector2) -> void:
	.draw_move(position)
	_top = min(_start_pos.y, position.y)
	_bottom = max(_start_pos.y, position.y)
	_left = min(_start_pos.x, position.x)
	_right = max(_start_pos.x, position.x)
	$"%Top".value = _top
	$"%Bottom".value = _bottom
	$"%Left".value = _left
	$"%Right".value = _right
	_update_crop_rect_indicator()


func apply() -> void:
	DrawingAlgos.resize_canvas((_right - _left), (_bottom - _top), -_left, -_top)
	Global.canvas.crop_rect.hide()


func _update_crop_rect_indicator():
	Global.canvas.crop_rect.show()
	Global.canvas.crop_rect.top = _top
	Global.canvas.crop_rect.bottom = _bottom
	Global.canvas.crop_rect.left = _left
	Global.canvas.crop_rect.right = _right
	Global.canvas.crop_rect.update()


func _on_Top_value_changed(value: float) -> void:
	_top = value
	_bottom = max(_top + 1, _bottom)
	$"%Bottom".value = _bottom
	_update_crop_rect_indicator()


func _on_Bottom_value_changed(value: float) -> void:
	_bottom = value
	_top = min(_bottom - 1, _top)
	$"%Top".value = _top
	_update_crop_rect_indicator()


func _on_Left_value_changed(value: float) -> void:
	_left = value
	_right = max(_left + 1, _right)
	$"%Right".value = _right
	_update_crop_rect_indicator()


func _on_Right_value_changed(value: float) -> void:
	_right = value
	_left = min(_right - 1, _left)
	$"%Left".value = _left
	_update_crop_rect_indicator()
