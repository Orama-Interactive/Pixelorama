# Code taken and modified from Material Maker, licensed under MIT
# gdlint: ignore=max-line-length
# https://github.com/RodZill4/material-maker/blob/master/material_maker/widgets/gradient_editor/gradient_editor.gd
class_name MaxMinEdit
extends Control

signal updated(zone)

export(float) var start = 0.0
export(float) var end = 1.0
export(Color) var zone_col = Color.black
export(Color) var background_col = Color.gray

var active_cursor: GradientCursor  # Showing a color picker popup to change a cursor's color

onready var x_offset: float = rect_size.x - GradientCursor.WIDTH
onready var texture_rect: TextureRect = $TextureRect
onready var texture: Texture = $TextureRect.texture
onready var gradient: Gradient = texture.gradient


class GradientCursor:
	extends Control

	const WIDTH := 10
	var color: Color
	var sliding := false

	onready var parent: TextureRect = get_parent()
	onready var grand_parent: Container = parent.get_parent()
	onready var label: Label = parent.get_node("Value")

	func _ready() -> void:
		rect_position = Vector2(0, 15)
		rect_size = Vector2(WIDTH, 15)

	func _draw() -> void:
# warning-ignore:integer_division
		var polygon := PoolVector2Array(
			[
				Vector2(0, 5),
				Vector2(WIDTH / 2, 0),
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
			if ev.button_index == BUTTON_LEFT:
				if ev.pressed:
					sliding = true
					label.visible = true
					label.text = "%.03f" % get_cursor_position()
				else:
					sliding = false
					label.visible = false
		elif ev is InputEventMouseMotion and (ev.button_mask & BUTTON_MASK_LEFT) != 0 and sliding:
			rect_position.x += get_local_mouse_position().x
			if ev.control:
				rect_position.x = (
					round(get_cursor_position() * 20.0)
					* 0.05
					* (parent.rect_size.x - WIDTH)
				)
			rect_position.x = min(max(0, rect_position.x), parent.rect_size.x - rect_size.x)
			grand_parent.update_from_value()
			label.text = "%.03f" % get_cursor_position()

	func get_cursor_position() -> float:
		return rect_position.x / (parent.rect_size.x - WIDTH)


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
	var cursors = []
	for c in texture_rect.get_children():
		if c is GradientCursor:
			cursors.append(c)
	var point_1: float = cursors[0].rect_position.x / x_offset
	var point_2: float = cursors[1].rect_position.x / x_offset
	if cursors[1].get_cursor_position() > cursors[0].get_cursor_position():
		gradient.add_point(point_1, zone_col)
		gradient.add_point(point_2, background_col)
	else:
		gradient.add_point(point_1, background_col)
		gradient.add_point(point_2, zone_col)
	emit_signal("updated", gradient.offsets[1], gradient.offsets[2])


func add_cursor(x: float) -> void:
	var cursor := GradientCursor.new()
	texture_rect.add_child(cursor)
	cursor.rect_position.x = x
	cursor.color = zone_col


func _on_GradientEdit_resized() -> void:
	if not gradient:
		return
	x_offset = rect_size.x - GradientCursor.WIDTH
	_create_cursors()
