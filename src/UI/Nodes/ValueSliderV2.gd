tool
class_name ValueSliderV2
extends HBoxContainer

signal value_changed(value)
signal ratio_toggled(button_pressed)

export var editable := true setget _set_editable
export var value := Vector2.ZERO setget _set_value
export var min_value := Vector2.ZERO setget _set_min_value
export var max_value := Vector2(100.0, 100.0) setget _set_max_value
export var step := 1.0 setget _set_step
export var allow_greater := false setget _set_allow_greater
export var allow_lesser := false setget _set_allow_lesser
export var show_ratio := false setget _set_show_ratio
export(int, 1, 2) var grid_columns := 1 setget _set_grid_columns
export var slider_min_size := Vector2(32, 24) setget _set_slider_min_size
export var snap_step := 1.0 setget _set_snap_step
export var snap_by_default := false setget _set_snap_by_default
export var prefix_x := "X:" setget _set_prefix_x
export var prefix_y := "Y:" setget _set_prefix_y
export var suffix_x := "" setget _set_suffix_x
export var suffix_y := "" setget _set_suffix_y

var ratio := Vector2.ONE
var _locked_ratio := false
var _can_emit_signal := true


func _ready() -> void:
	if not Engine.editor_hint:  # Pixelorama specific code
		$Ratio.modulate = Global.modulate_icon_color


func get_sliders() -> Array:
	return [$GridContainer/X, $GridContainer/Y]


func press_ratio_button(pressed: bool) -> void:
	$"%RatioButton".pressed = pressed


# Greatest common divisor
func _gcd(a: int, b: int) -> int:
	return a if b == 0 else _gcd(b, a % b)


func _on_X_value_changed(val: float) -> void:
	value.x = val
	if _locked_ratio:
		self.value.y = max(min_value.y, (value.x / ratio.x) * ratio.y)
	if _can_emit_signal:
		emit_signal("value_changed", value)


func _on_Y_value_changed(val: float) -> void:
	value.y = val
	if _locked_ratio:
		self.value.x = max(min_value.x, (value.y / ratio.y) * ratio.x)
	if _can_emit_signal:
		emit_signal("value_changed", value)


func _on_RatioButton_toggled(button_pressed: bool) -> void:
	_locked_ratio = button_pressed
	var divisor := _gcd(value.x, value.y)
	if divisor == 0:
		ratio = Vector2.ONE
	else:
		ratio = value / divisor
	emit_signal("ratio_toggled", button_pressed)


# Setters


func _set_editable(val: bool) -> void:
	editable = val
	for slider in get_sliders():
		slider.editable = val
	$"%RatioButton".disabled = not val


func _set_value(val: Vector2) -> void:
	value = val
	_can_emit_signal = false
	$GridContainer/X.value = value.x
	$GridContainer/Y.value = value.y
	_can_emit_signal = true


func _set_min_value(val: Vector2) -> void:
	min_value = val
	$GridContainer/X.min_value = val.x
	$GridContainer/Y.min_value = val.y


func _set_max_value(val: Vector2) -> void:
	max_value = val
	$GridContainer/X.max_value = val.x
	$GridContainer/Y.max_value = val.y


func _set_step(val: float) -> void:
	step = val
	for slider in get_sliders():
		slider.step = val


func _set_allow_greater(val: bool) -> void:
	allow_greater = val
	for slider in get_sliders():
		slider.allow_greater = val


func _set_allow_lesser(val: bool) -> void:
	allow_lesser = val
	for slider in get_sliders():
		slider.allow_lesser = val


func _set_show_ratio(val: bool) -> void:
	show_ratio = val
	$Ratio.visible = val


func _set_grid_columns(val: int) -> void:
	grid_columns = val
	$GridContainer.columns = val


func _set_slider_min_size(val: Vector2) -> void:
	slider_min_size = val
	for slider in get_sliders():
		slider.rect_min_size = val


func _set_snap_step(val: float) -> void:
	snap_step = val
	for slider in get_sliders():
		slider.snap_step = val


func _set_snap_by_default(val: bool) -> void:
	snap_by_default = val
	for slider in get_sliders():
		slider.snap_by_default = val


func _set_prefix_x(val: String) -> void:
	prefix_x = val
	$GridContainer/X.prefix = val


func _set_prefix_y(val: String) -> void:
	prefix_y = val
	$GridContainer/Y.prefix = val


func _set_suffix_x(val: String) -> void:
	suffix_x = val
	$GridContainer/X.suffix = val


func _set_suffix_y(val: String) -> void:
	suffix_y = val
	$GridContainer/Y.suffix = val
