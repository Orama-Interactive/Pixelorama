@tool
class_name BasisSliders
extends HBoxContainer

signal value_changed(value: Basis)

@export var value: Basis:
	set(val):
		value = val
		_can_emit_signal = false
		get_sliders()[0].value = value.x
		get_sliders()[1].value = value.y
		get_sliders()[2].value = value.z
		_can_emit_signal = true
@export var min_value := Vector3.ZERO:
	set(val):
		min_value = val
		get_sliders()[0].min_value = val
		get_sliders()[1].min_value = val
		get_sliders()[2].min_value = val
@export var max_value := Vector3(100.0, 100.0, 100.0):
	set(val):
		max_value = val
		get_sliders()[0].max_value = val
		get_sliders()[1].max_value = val
		get_sliders()[2].max_value = val
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

var _can_emit_signal := true


func get_sliders() -> Array[ValueSliderV3]:
	return [$XSlider, $YSlider, $ZSlider]


func _on_x_slider_value_changed(val: Vector3) -> void:
	value.x = val
	if _can_emit_signal:
		value_changed.emit(value)


func _on_y_slider_value_changed(val: Vector3) -> void:
	value.y = val
	if _can_emit_signal:
		value_changed.emit(value)


func _on_z_slider_value_changed(val: Vector3) -> void:
	value.z = val
	if _can_emit_signal:
		value_changed.emit(value)
