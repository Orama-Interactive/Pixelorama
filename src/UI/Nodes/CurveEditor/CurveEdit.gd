# Code taken and modified from Material Maker, licensed under MIT
# gdlint: ignore=max-line-length
# https://github.com/RodZill4/material-maker/blob/master/material_maker/widgets/curve_edit/curve_view.gd
# and
# gdlint: ignore=max-line-length
# https://github.com/RodZill4/material-maker/blob/master/material_maker/widgets/curve_edit/curve_editor.gd
@tool
class_name CurveEdit
extends Control

signal value_changed(value: Curve)

@export var show_axes := true
@export var curve: Curve:
	set(value):
		curve = value
		queue_redraw()
		update_controls()


func _ready() -> void:
	if not is_instance_valid(curve):
		curve = Curve.new()
	gui_input.connect(_on_gui_input)
	resized.connect(_on_resize)
	queue_redraw()
	update_controls()


func update_controls() -> void:
	for c in get_children():
		c.queue_free()
	for i in curve.point_count:
		var p := curve.get_point_position(i)
		var control_point := CurveEditControlPoint.new()
		add_child(control_point)
		control_point.initialize(curve, i)
		control_point.position = transform_point(p) - control_point.OFFSET
		if i == 0 or i == curve.point_count - 1:
			control_point.set_constraint(
				control_point.position.x,
				control_point.position.x,
				-control_point.OFFSET.y,
				size.y - control_point.OFFSET.y
			)
			if i == 0:
				control_point.set_control_point_visibility(true, false)
			else:
				control_point.set_control_point_visibility(false, false)
		else:
			var min_x := transform_point(curve.get_point_position(i - 1)).x + 1
			var max_x := transform_point(curve.get_point_position(i + 1)).x - 1
			control_point.set_constraint(
				min_x, max_x, -control_point.OFFSET.y, size.y - control_point.OFFSET.y
			)
		control_point.moved.connect(_on_control_point_moved)
		control_point.removed.connect(_on_control_point_removed)
	value_changed.emit(curve)


static func to_texture(from_curve: Curve, width := 256) -> CurveTexture:
	var texture := CurveTexture.new()
	texture.texture_mode = CurveTexture.TEXTURE_MODE_RED
	texture.curve = from_curve
	texture.width = width
	return texture


func transform_point(p: Vector2) -> Vector2:
	return (Vector2(0.0, 1.0) + Vector2(1.0, -1.0) * p) * size


func reverse_transform_point(p: Vector2) -> Vector2:
	return Vector2(0.0, 1.0) + Vector2(1.0, -1.0) * p / size


func _draw() -> void:
	var bg := Color.DARK_GRAY
	var fg := Color.GRAY
	var current_scene := get_tree().current_scene
	if current_scene is Control:
		var current_theme := (current_scene as Control).theme
		var panel_stylebox := current_theme.get_stylebox("panel", "Panel")
		if panel_stylebox is StyleBoxFlat:
			bg = panel_stylebox.bg_color
		fg = current_theme.get_color("font_color", "Label")
	var axes_color := bg.lerp(fg, 0.25)
	var curve_color := bg.lerp(fg, 0.75)
	if show_axes:
		for i in range(5):
			var p := transform_point(0.25 * Vector2(i, i))
			draw_line(Vector2(p.x, 0), Vector2(p.x, size.y - 1), axes_color)
			draw_line(Vector2(0, p.y), Vector2(size.x - 1, p.y), axes_color)
	var points := PackedVector2Array()
	for i in range(curve.point_count - 1):
		var p1 := curve.get_point_position(i)
		var p2 := curve.get_point_position(i + 1)
		var d := (p2.x - p1.x) / 3.0
		var yac := p1.y + d * curve.get_point_right_tangent(i)
		var ybc := p2.y - d * curve.get_point_left_tangent(i + 1)
		var p := transform_point(p1)
		if points.is_empty():
			points.push_back(p)
		var count := maxi(1, transform_point(p2).x - p.x / 5.0)
		for tt in range(count):
			var t := (tt + 1.0) / count
			var omt := 1.0 - t
			var omt2 := omt * omt
			var omt3 := omt2 * omt
			var t2 := t * t
			var t3 := t2 * t
			var x := p1.x + (p2.x - p1.x) * t
			var y := p1.y * omt3 + yac * omt2 * t * 3.0 + ybc * omt * t2 * 3.0 + p2.y * t3
			p = transform_point(Vector2(x, y))
			points.push_back(p)
	draw_polyline(points, curve_color)


func _on_control_point_moved(index: int) -> void:
	var control_point := get_child(index) as CurveEditControlPoint
	var new_point := reverse_transform_point(control_point.position + control_point.OFFSET)
	curve.set_point_offset(index, new_point.x)
	curve.set_point_value(index, new_point.y)
	if is_instance_valid(control_point.left_slope):
		var slope_vector := control_point.left_slope.position / size
		if slope_vector.x != 0:
			curve.set_point_left_tangent(index, -slope_vector.y / slope_vector.x)
	if is_instance_valid(control_point.right_slope):
		var slope_vector := control_point.right_slope.position / size
		if slope_vector.x != 0:
			curve.set_point_right_tangent(index, -slope_vector.y / slope_vector.x)
	queue_redraw()
	value_changed.emit(curve)


func _on_control_point_removed(index: int) -> void:
	if index > 0 and index < curve.point_count:
		curve.remove_point(index)
		queue_redraw()
		update_controls()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			var new_point_position := reverse_transform_point(get_local_mouse_position())
			curve.add_point(new_point_position, 0.0, 0.0)
			update_controls()


func _on_resize() -> void:
	queue_redraw()
	update_controls()
