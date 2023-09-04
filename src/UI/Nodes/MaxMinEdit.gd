# Code taken and modified from Material Maker, licensed under MIT
# gdlint: ignore=max-line-length
# https://github.com/RodZill4/material-maker/blob/master/material_maker/widgets/gradient_editor/gradient_editor.gd
class_name MaxMinEdit
extends Control

signal updated(zone)

@export var start := 0.0
@export var end := 1.0
@export var zone_col := Color.BLACK
@export var background_col := Color.GRAY

var active_cursor: GradientCursor  # Showing a color picker popup to change a cursor's color

@onready var x_offset: float = size.x - GradientCursor.WIDTH
@onready var texture_rect := $TextureRect as TextureRect
@onready var texture := texture_rect.texture as GradientTexture2D
@onready var gradient := texture.gradient as Gradient


class GradientCursor:
	extends Control

	const WIDTH := 10
	var color: Color
	var sliding := false

	@onready var parent: TextureRect = get_parent()
	@onready var grand_parent: Container = parent.get_parent()
	@onready var label: Label = parent.get_node("Value")

	func _ready() -> void:
		position = Vector2(0, 15)
		size = Vector2(WIDTH, 15)

	func _draw() -> void:
		var polygon := PackedVector2Array(
			[
				Vector2(0, 5),
				Vector2(WIDTH / 2.0, 0),
				Vector2(WIDTH, 5),
				Vector2(WIDTH, 15),
				Vector2(0, 15),
				Vector2(0, 5)
			]
		)
		var c := color
		c.a = 1.0
		draw_colored_polygon(polygon, c)
		draw_polyline(polygon, Color(0.0, 0.0, 0.0) if color.v > 0.5 else Color(1.0, 1.0, 1.0))

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			if ev.button_index == MOUSE_BUTTON_LEFT:
				if ev.pressed:
					sliding = true
					label.visible = true
					label.text = "%.03f" % get_caret_column()
				else:
					sliding = false
					label.visible = false
		elif (
			ev is InputEventMouseMotion
			and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
			and sliding
		):
			position.x += get_local_mouse_position().x
			if ev.ctrl_pressed:
				position.x = (roundi(get_caret_column() * 20.0) * 0.05 * (parent.size.x - WIDTH))
			position.x = mini(maxi(0, position.x), parent.size.x - size.x)
			grand_parent.update_from_value()
			label.text = "%.03f" % get_caret_column()

	func get_caret_column() -> float:
		return position.x / (parent.size.x - WIDTH)


func _ready() -> void:
	gradient = gradient.duplicate(true)
	texture.gradient = gradient
	gradient.offsets[1] = start
	gradient.offsets[2] = end
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradient.colors[0] = background_col
	gradient.colors[2] = background_col
	gradient.colors[1] = zone_col
	_create_cursors()


func _create_cursors() -> void:
	for c in texture_rect.get_children():
		if c is GradientCursor:
			texture_rect.remove_child(c)
			c.queue_free()
	for i in gradient.get_point_count():
		if i == 0:
			gradient.set_offset(0, 0)
		else:
			var p: float = gradient.get_offset(i)
			add_cursor(p * x_offset)


func update_from_value() -> void:
	gradient.offsets = [0.0]
	var cursors: Array[GradientCursor] = []
	for c in texture_rect.get_children():
		if c is GradientCursor:
			cursors.append(c)
	var point_1: float = cursors[0].position.x / x_offset
	var point_2: float = cursors[1].position.x / x_offset
	if cursors[1].get_caret_column() > cursors[0].get_caret_column():
		gradient.add_point(point_1, zone_col)
		gradient.add_point(point_2, background_col)
	else:
		gradient.add_point(point_1, background_col)
		gradient.add_point(point_2, zone_col)
	updated.emit(gradient.offsets[1], gradient.offsets[2])


func add_cursor(x: float) -> void:
	var cursor := GradientCursor.new()
	texture_rect.add_child(cursor)
	cursor.position.x = x
	cursor.color = zone_col


func _on_GradientEdit_resized() -> void:
	if not gradient:
		return
	x_offset = size.x - GradientCursor.WIDTH
	_create_cursors()
