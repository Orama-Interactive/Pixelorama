extends Line2D
class_name Guide

enum TYPE {HORIZONTAL, VERTICAL}

var font := preload("res://Assets/Fonts/Roboto-Regular.tres")
var has_focus := true
var mouse_pos := Vector2.ZERO
var type = TYPE.HORIZONTAL

func _ready() -> void:
	width = 0.1

# warning-ignore:unused_argument
func _process(delta) -> void:
	width = Global.camera.zoom.x
	mouse_pos = get_local_mouse_position()
	var point0 := points[0]
	var point1 := points[1]
	if type == TYPE.HORIZONTAL:
		point0.y -= width * 3
		point1.y += width * 3
	else:
		point0.x -= width * 3
		point1.x += width * 3
	if point_in_rectangle(mouse_pos, point0, point1) && Input.is_action_just_pressed("left_mouse"):
		if !point_in_rectangle(Global.canvas.current_pixel, Global.canvas.location, Global.canvas.location + Global.canvas.size):
			has_focus = true
			Global.has_focus = false
			update()
	if has_focus && Input.is_action_pressed("left_mouse"):
		if type == TYPE.HORIZONTAL:
			points[0].y = round(mouse_pos.y)
			points[1].y = round(mouse_pos.y)
		else:
			points[0].x = round(mouse_pos.x)
			points[1].x = round(mouse_pos.x)
	if Input.is_action_just_released("left_mouse"):
		if has_focus:
			Global.has_focus = true
			has_focus = false
			update()
			if type == TYPE.HORIZONTAL:
				if points[0].y < 0 || points[0].y > Global.canvas.size.y:
					queue_free()
			else:
				if points[0].x < 0 || points[0].x > Global.canvas.size.x:
					queue_free()

func _draw() -> void:
	if has_focus:
		var viewport_size := Global.main_viewport.rect_size
		var zoom := Global.camera.zoom
		if type == TYPE.HORIZONTAL:
			draw_set_transform(Vector2(Global.camera.offset.x - (viewport_size.x / 2) * zoom.x, points[0].y + font.get_height() * zoom.x * 2), rotation, zoom * 2)
			draw_string(font, Vector2.ZERO, "%spx" % str(round(mouse_pos.y)))
		else:
			draw_set_transform(Vector2(points[0].x + font.get_height() * zoom.y, Global.camera.offset.y - (viewport_size.y / 2.25) * zoom.y), rotation, zoom * 2)
			draw_string(font, Vector2.ZERO, "%spx" % str(round(mouse_pos.x)))

func point_in_rectangle(p : Vector2, coord1 : Vector2, coord2 : Vector2) -> bool:
	return p.x > coord1.x && p.y > coord1.y && p.x < coord2.x && p.y < coord2.y