extends ConfirmationDialog


var width := 64
var height := 64
var offset_x := 0
var offset_y := 0

onready var x_spinbox : SpinBox = $VBoxContainer/OptionsContainer/XSpinBox
onready var y_spinbox : SpinBox = $VBoxContainer/OptionsContainer/YSpinBox


func _on_ResizeCanvas_confirmed() -> void:
	DrawingAlgos.resize_canvas(width, height, offset_x, offset_y)


func _on_WidthValue_value_changed(value : int) -> void:
	width = value
	x_spinbox.min_value = min(width - Global.current_project.size.x, 0)
	x_spinbox.max_value = max(width - Global.current_project.size.x, 0)
	x_spinbox.value = clamp(x_spinbox.value, x_spinbox.min_value, x_spinbox.max_value)


func _on_HeightValue_value_changed(value : int) -> void:
	height = value
	y_spinbox.min_value = min(height - Global.current_project.size.y, 0)
	y_spinbox.max_value = max(height - Global.current_project.size.y, 0)
	y_spinbox.value = clamp(y_spinbox.value, y_spinbox.min_value, y_spinbox.max_value)


func _on_XSpinBox_value_changed(value : int) -> void:
	offset_x = value


func _on_YSpinBox_value_changed(value : int) -> void:
	offset_y = value


func _on_CenterButton_pressed() -> void:
	x_spinbox.value = (x_spinbox.min_value + x_spinbox.max_value) / 2
	y_spinbox.value = (y_spinbox.min_value + y_spinbox.max_value) / 2
