# Code taken and modified from Material Maker, licensed under MIT
# gdlint: ignore=max-line-length
# https://github.com/RodZill4/material-maker/blob/master/material_maker/widgets/curve_edit/curve_view.gd
# and
# gdlint: ignore=max-line-length
# https://github.com/RodZill4/material-maker/blob/master/material_maker/widgets/curve_edit/curve_editor.gd
@tool
class_name CurveEdit
extends VBoxContainer

signal value_changed(value: Curve)

## Array of dictionaries of key [String] and value [Array] of type [CurveEdit.CurvePoint].
static var presets: Array[Dictionary] = [
	{"Linear": [CurvePoint.new(0.0, 0.0, 0.0, 1.0), CurvePoint.new(1.0, 1.0, 1.0, 0.0)]},
	{
		"Ease out":
		[
			CurvePoint.new(0.0, 0.0, 0.0, 4.0),
			CurvePoint.new(0.292893, 0.707107, 1.0, 1.0),
			CurvePoint.new(1.0, 1.0, 0.0, 0.0)
		]
	},
	{
		"Ease in out":
		[
			CurvePoint.new(0.0, 0.0, 0.0, 0.0),
			CurvePoint.new(0.5, 0.5, 3.0, 3.0),
			CurvePoint.new(1.0, 1.0, 0.0, 0.0)
		]
	},
	{
		"Ease in":
		[
			CurvePoint.new(0.0, 0.0, 0.0, 0.0),
			CurvePoint.new(0.707107, 0.292893, 1.0, 1.0),
			CurvePoint.new(1.0, 1.0, 4.0, 0.0)
		]
	},
	{
		"Sawtooth":
		[
			CurvePoint.new(0.0, 0.0, 0.0, 2.0),
			CurvePoint.new(0.5, 1.0, 2.0, -2.0),
			CurvePoint.new(1.0, 0.0, -2.0, 0.0)
		]
	},
	{
		"Bounce":
		[
			CurvePoint.new(0.0, 0.0, 0.0, 5.0),
			CurvePoint.new(0.15, 0.65, 2.45201, 2.45201),
			CurvePoint.new(0.5, 1.0, 0.0, 0.0),
			CurvePoint.new(0.85, 0.65, -2.45201, -2.45201),
			CurvePoint.new(1.0, 0.0, -5.0, 0.0)
		]
	},
	{
		"Bevel":
		[
			CurvePoint.new(0.0, 0.0, 0.0, 2.38507),
			CurvePoint.new(0.292893, 0.707107, 2.34362, 0.428147),
			CurvePoint.new(1.0, 1.0, 0.410866, 0.0)
		]
	}
]
@export var show_axes := true
@export var curve: Curve:
	set(value):
		curve = value
		_on_resize()
var curve_editor := Control.new()
var hbox := HBoxContainer.new()


class CurvePoint:
	var pos: Vector2
	var left_tangent: float
	var right_tangent: float

	func _init(x: float, y: float, _left_tangent := 0.0, _right_tangent := 0.0) -> void:
		pos = Vector2(x, y)
		left_tangent = _left_tangent
		right_tangent = _right_tangent


func _ready() -> void:
	if not is_instance_valid(curve):
		curve = Curve.new()
	if custom_minimum_size.is_zero_approx():
		custom_minimum_size = Vector2(32, 150)
	curve_editor.gui_input.connect(_on_gui_input)
	resized.connect(_on_resize)
	curve_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(curve_editor)
	add_child(hbox)
	var presets_button := MenuButton.new()
	presets_button.text = "Presets"
	presets_button.flat = false
	presets_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	presets_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	presets_button.get_popup().id_pressed.connect(_on_presets_item_selected)
	for preset in presets:
		presets_button.get_popup().add_item(preset.keys()[0])
	var invert_button := Button.new()
	invert_button.text = "Invert"
	invert_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	invert_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	invert_button.pressed.connect(_on_invert_button_pressed)
	hbox.add_child(presets_button)
	hbox.add_child(invert_button)
	_on_resize.call_deferred()


func update_controls() -> void:
	for c in curve_editor.get_children():
		if c is CurveEditControlPoint:
			c.queue_free()
	for i in curve.point_count:
		var p := curve.get_point_position(i)
		var control_point := CurveEditControlPoint.new()
		curve_editor.add_child(control_point)
		control_point.initialize(curve, i)
		control_point.position = transform_point(p) - control_point.OFFSET
		if i == 0 or i == curve.point_count - 1:
			control_point.set_constraint(
				control_point.position.x,
				control_point.position.x,
				-control_point.OFFSET.y,
				available_size().y - control_point.OFFSET.y
			)
			if i == 0:
				control_point.set_control_point_visibility(true, false)
			else:
				control_point.set_control_point_visibility(false, false)
		else:
			var min_x := transform_point(curve.get_point_position(i - 1)).x + 1
			var max_x := transform_point(curve.get_point_position(i + 1)).x - 1
			control_point.set_constraint(
				min_x, max_x, -control_point.OFFSET.y, available_size().y - control_point.OFFSET.y
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


static func set_curve_preset(curve_to_edit: Curve, preset_index: int) -> void:
	curve_to_edit.clear_points()
	var preset_points: Array = presets[preset_index].values()[0]
	for point: CurvePoint in preset_points:
		curve_to_edit.add_point(point.pos, point.left_tangent, point.right_tangent)


func set_default_curve() -> void:
	if not is_instance_valid(curve):
		curve = Curve.new()
	_on_presets_item_selected(0)


func available_size() -> Vector2:
	if curve_editor.size.is_zero_approx():
		return Vector2.ONE
	return curve_editor.size


func transform_point(p: Vector2) -> Vector2:
	return (Vector2(0.0, 1.0) + Vector2(1.0, -1.0) * p) * available_size()


func reverse_transform_point(p: Vector2) -> Vector2:
	return Vector2(0.0, 1.0) + Vector2(1.0, -1.0) * p / available_size()


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
			draw_line(Vector2(p.x, 0), Vector2(p.x, available_size().y - 1), axes_color)
			draw_line(Vector2(0, p.y), Vector2(available_size().x - 1, p.y), axes_color)
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
	if points.size() > 1:
		draw_polyline(points, curve_color)


func _on_control_point_moved(index: int) -> void:
	var control_point := curve_editor.get_child(index) as CurveEditControlPoint
	var new_point := reverse_transform_point(control_point.position + control_point.OFFSET)
	curve.set_point_offset(index, new_point.x)
	curve.set_point_value(index, new_point.y)
	if is_instance_valid(control_point.left_slope):
		var slope_vector := control_point.left_slope.position / available_size()
		if slope_vector.x != 0:
			curve.set_point_left_tangent(index, -slope_vector.y / slope_vector.x)
	if is_instance_valid(control_point.right_slope):
		var slope_vector := control_point.right_slope.position / available_size()
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
			queue_redraw()
			update_controls()


func _on_resize() -> void:
	queue_redraw()
	update_controls()


func _on_presets_item_selected(index: int) -> void:
	set_curve_preset(curve, index)
	curve = curve  # Call setter


func _on_invert_button_pressed() -> void:
	var copy_curve := curve.duplicate() as Curve
	curve.clear_points()
	for i in copy_curve.point_count:
		var point := copy_curve.get_point_position(i)
		point.y = 1.0 - point.y
		var left_tangent := -copy_curve.get_point_left_tangent(i)
		var right_tangent := -copy_curve.get_point_right_tangent(i)
		curve.add_point(point, left_tangent, right_tangent)
	curve = curve  # Call setter
