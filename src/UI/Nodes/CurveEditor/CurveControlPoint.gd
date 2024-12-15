# Code taken and modified from Material Maker, licensed under MIT
# gdlint: ignore=max-line-length
# https://github.com/RodZill4/material-maker/blob/master/material_maker/widgets/curve_edit/control_point.gd
class_name CurveEditControlPoint
extends Control

signal moved(index: int)
signal removed(index: int)

const OFFSET := Vector2(3, 3)

var moving := false

var min_x: float
var max_x: float
var min_y: float
var max_y: float
var left_slope: CurveEditTangentPoint
var right_slope: CurveEditTangentPoint

@onready var parent := get_parent() as Control
@onready var grandparent := parent.get_parent() as CurveEdit


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	custom_minimum_size = Vector2(8, 8)
	left_slope = CurveEditTangentPoint.new()
	right_slope = CurveEditTangentPoint.new()
	add_child(left_slope)
	add_child(right_slope)


func _draw() -> void:
	var color := Color.GRAY
	var current_scene := get_tree().current_scene
	if current_scene is Control:
		var current_theme := (current_scene as Control).theme
		color = current_theme.get_color("font_color", "Label")
	for c: CurveEditTangentPoint in get_children():
		if c.visible:
			draw_line(OFFSET, c.position + OFFSET, color)
	draw_rect(Rect2(0, 0, 7, 7), color)


func initialize(curve: Curve, index: int) -> void:
	if not is_instance_valid(parent):
		await ready
	position = grandparent.transform_point(curve.get_point_position(index)) - OFFSET
	var left_tangent := curve.get_point_left_tangent(index)
	var right_tangent := curve.get_point_right_tangent(index)
	if left_tangent != INF:
		left_slope.position = (
			left_slope.distance * (parent.size * Vector2(1.0, -left_tangent)).normalized()
		)
	if right_tangent != INF:
		right_slope.position = (
			right_slope.distance * (parent.size * Vector2(1.0, -right_tangent)).normalized()
		)


func set_control_point_visibility(left: bool, new_visible: bool) -> void:
	if not is_instance_valid(left_slope):
		await ready
	if left:
		left_slope.visible = new_visible
	else:
		right_slope.visible = new_visible


func set_constraint(new_min_x: float, new_max_x: float, new_min_y: float, new_max_y: float) -> void:
	min_x = new_min_x
	max_x = new_max_x
	min_y = new_min_y
	max_y = new_max_y


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				moving = true
			else:
				moving = false
				grandparent.update_controls()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			removed.emit(get_index())
	elif moving and event is InputEventMouseMotion:
		position += event.relative
		if position.x < min_x:
			position.x = min_x
		elif position.x > max_x:
			position.x = max_x
		if position.y < min_y:
			position.y = min_y
		elif position.y > max_y:
			position.y = max_y
		moved.emit(get_index())


func update_tangents() -> void:
	queue_redraw()
	moved.emit(get_index())
