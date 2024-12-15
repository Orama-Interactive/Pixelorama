# Code taken and modified from Material Maker, licensed under MIT
# gdlint: ignore=max-line-length
# https://github.com/RodZill4/material-maker/blob/master/material_maker/widgets/curve_edit/slope_point.gd
class_name CurveEditTangentPoint
extends Control

const OFFSET := Vector2(0, 0)

@export var distance := 30

var moving = false
@onready var parent := get_parent() as CurveEditControlPoint
@onready var grandparent := parent.get_parent() as Control


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	custom_minimum_size = Vector2(8, 8)
	if get_index() == 0:
		distance = -distance


func _draw() -> void:
	var color := Color.GRAY
	var current_scene := get_tree().current_scene
	if current_scene is Control:
		var current_theme := (current_scene as Control).theme
		color = current_theme.get_color("font_color", "Label")
	draw_circle(Vector2(3.0, 3.0), 3.0, color)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.double_click:
					var vector: Vector2
					if get_index() == 0:
						vector = (
							parent.position - grandparent.get_child(parent.get_index() - 1).position
						)
					else:
						vector = (
							grandparent.get_child(parent.get_index() + 1).position - parent.position
						)
					vector = distance * vector.normalized()
					position = vector - OFFSET
					if event.is_control_or_command_pressed():
						parent.get_child(1 - get_index()).position = -vector - OFFSET
					parent.update_tangents()
				else:
					moving = true
			else:
				moving = false
	elif moving and event is InputEventMouseMotion:
		var vector := get_global_mouse_position() - parent.get_global_rect().position + OFFSET
		vector *= signf(vector.x)
		vector = distance * vector.normalized()
		position = vector - OFFSET
		if event.is_command_or_control_pressed():
			parent.get_child(1 - get_index()).position = -vector - OFFSET
		parent.update_tangents()
