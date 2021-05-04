extends "res://src/Tools/Draw.gd"


var _last_position := Vector2.INF
var _clear_image := Image.new()
var _changed := false


class EraseOp extends Drawer.ColorOp:
	var changed := false


	func process(_src: Color, _dst: Color) -> Color:
		changed = true
#		dst.a -= src.a * strength
#		return dst
		return Color(0, 0, 0, 0)


func _init() -> void:
	_drawer.color_op = EraseOp.new()
	_clear_image.create(1, 1, false, Image.FORMAT_RGBA8)
	_clear_image.fill(Color(0, 0, 0, 0))


func draw_start(position : Vector2) -> void:
	Global.canvas.selection.transform_content_confirm()
	update_mask()
	_changed = false
	_drawer.color_op.changed = false

	prepare_undo()
	_drawer.reset()

	_draw_line = Tools.shift
	if _draw_line:
		_line_start = position
		_line_end = position
		update_line_polylines(_line_start, _line_end)
	else:
		draw_tool(position)
		_last_position = position
		Global.canvas.sprite_changed_this_frame = true
	cursor_text = ""


func draw_move(position : Vector2) -> void:
	if _draw_line:
		var d = _line_angle_constraint(_line_start, position)
		_line_end = d.position
		cursor_text = d.text
		update_line_polylines(_line_start, _line_end)
	else:
		draw_fill_gap(_last_position, position)
		_last_position = position
		cursor_text = ""
		Global.canvas.sprite_changed_this_frame = true


func draw_end(_position : Vector2) -> void:
	if _draw_line:
		draw_tool(_line_start)
		draw_fill_gap(_line_start, _line_end)
		_draw_line = false
	if _changed or _drawer.color_op.changed:
		commit_undo("Draw")
	cursor_text = ""
	update_random_image()


func _draw_brush_image(_image : Image, src_rect: Rect2, dst: Vector2) -> void:
	_changed = true
	var size := _image.get_size()
	if _clear_image.get_size() != size:
		_clear_image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	_get_draw_image().blit_rect_mask(_clear_image, _image, src_rect, dst)
