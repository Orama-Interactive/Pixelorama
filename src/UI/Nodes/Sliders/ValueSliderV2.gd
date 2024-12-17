@tool
class_name ValueSliderV2
extends HBoxContainer
## A class that combines two ValueSlider nodes, for easy usage with Vector2 values.
## Also supports aspect ratio locking.

signal value_changed(value: Vector2)
signal ratio_toggled(button_pressed: bool)

@export var editable := true:
	set(val):
		editable = val
		for slider in get_sliders():
			slider.editable = val
		$"%RatioButton".disabled = not val
@export var value := Vector2.ZERO:
	set(val):
		value = val
		_can_emit_signal = false
		$GridContainer/X.value = value.x
		$GridContainer/Y.value = value.y
		_can_emit_signal = true
@export var min_value := Vector2.ZERO:
	set(val):
		min_value = val
		$GridContainer/X.min_value = val.x
		$GridContainer/Y.min_value = val.y
		value = value  # Call value setter
@export var max_value := Vector2(100.0, 100.0):
	set(val):
		max_value = val
		$GridContainer/X.max_value = val.x
		$GridContainer/Y.max_value = val.y
		value = value  # Call value setter
@export var step := 1.0:
	set(val):
		step = val
		for slider in get_sliders():
			slider.step = val
@export var allow_greater := false:
	set(val):
		allow_greater = val
		for slider in get_sliders():
			slider.allow_greater = val
@export var allow_lesser := false:
	set(val):
		allow_lesser = val
		for slider in get_sliders():
			slider.allow_lesser = val
@export var show_ratio := false:
	set(val):
		show_ratio = val
		$Ratio.visible = val
@export var grid_columns := 1:
	set(val):
		grid_columns = val
		$GridContainer.columns = val
@export var slider_min_size := Vector2(32, 24):
	set(val):
		slider_min_size = val
		for slider in get_sliders():
			slider.custom_minimum_size = val
@export var snap_step := 1.0:
	set(val):
		snap_step = val
		for slider in get_sliders():
			slider.snap_step = val
@export var snap_by_default := false:
	set(val):
		snap_by_default = val
		for slider in get_sliders():
			slider.snap_by_default = val
@export var prefix_x := "X:":
	set(val):
		prefix_x = val
		$GridContainer/X.prefix = val
@export var prefix_y := "Y:":
	set(val):
		prefix_y = val
		$GridContainer/Y.prefix = val
@export var suffix_x := "":
	set(val):
		suffix_x = val
		$GridContainer/X.suffix = val
@export var suffix_y := "":
	set(val):
		suffix_y = val
		$GridContainer/Y.suffix = val

var ratio := Vector2.ONE
var _locked_ratio := false
var _can_emit_signal := true


func _ready() -> void:
	if not Engine.is_editor_hint():  # Pixelorama specific code
		$Ratio.modulate = Global.modulate_icon_color


func get_sliders() -> Array[ValueSlider]:
	return [$GridContainer/X, $GridContainer/Y]


func press_ratio_button(pressed: bool) -> void:
	$"%RatioButton".button_pressed = pressed


## Greatest common divisor
func _gcd(a: int, b: int) -> int:
	return a if b == 0 else _gcd(b, a % b)


func _on_X_value_changed(val: float) -> void:
	value.x = val
	if _locked_ratio:
		value.y = maxf(min_value.y, (value.x / ratio.x) * ratio.y)
	if _can_emit_signal:
		value_changed.emit(value)


func _on_Y_value_changed(val: float) -> void:
	value.y = val
	if _locked_ratio:
		value.x = maxf(min_value.x, (value.y / ratio.y) * ratio.x)
	if _can_emit_signal:
		value_changed.emit(value)


func _on_RatioButton_toggled(button_pressed: bool) -> void:
	_locked_ratio = button_pressed
	var divisor := _gcd(value.x, value.y)
	if divisor == 0:
		ratio = Vector2.ONE
	else:
		ratio = value / divisor
	ratio_toggled.emit(button_pressed)
