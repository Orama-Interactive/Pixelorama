class_name Guide
extends Line2D

enum Types {HORIZONTAL, VERTICAL}

var font := preload("res://Assets/Fonts/Roboto-Regular.tres")
var has_focus := true
var mouse_pos := Vector2.ZERO
var previous_points := points
var type = Types.HORIZONTAL

func _ready() -> void:
	width = 0.1
	default_color = Global.guide_color


func _input(_event : InputEvent):
	width = Global.camera.zoom.x * 2
	mouse_pos = get_local_mouse_position()
	var point0 := points[0]
	var point1 := points[1]
	if type == Types.HORIZONTAL:
		point0.y -= width * 3
		point1.y += width * 3
	else:
		point0.x -= width * 3
		point1.x += width * 3
	if Global.can_draw and Global.has_focus and point_in_rectangle(mouse_pos, point0, point1) and Input.is_action_just_pressed("left_mouse"):
		if !point_in_rectangle(Global.canvas.current_pixel, Global.canvas.location, Global.canvas.location + Global.canvas.size):
			has_focus = true
			Global.has_focus = false
			update()
	if has_focus:
		if Input.is_action_just_pressed("left_mouse"):
			previous_points = points
		if Input.is_action_pressed("left_mouse"):
			if type == Types.HORIZONTAL:
				points[0].y = round(mouse_pos.y)
				points[1].y = round(mouse_pos.y)
			else:
				points[0].x = round(mouse_pos.x)
				points[1].x = round(mouse_pos.x)
		if Input.is_action_just_released("left_mouse"):
			Global.has_focus = true
			has_focus = false
			if !outside_canvas():
				Global.undos += 1
				Global.undo_redo.create_action("Move Guide")
				Global.undo_redo.add_do_method(self, "outside_canvas")
				Global.undo_redo.add_do_property(self, "points", points)
				Global.undo_redo.add_undo_property(self, "points", previous_points)
				Global.undo_redo.add_undo_method(self, "outside_canvas", true)
				Global.undo_redo.commit_action()
				update()


func _draw() -> void:
	if has_focus:
		var viewport_size: Vector2 = Global.main_viewport.rect_size
		var zoom: Vector2 = Global.camera.zoom
		if type == Types.HORIZONTAL:
			draw_set_transform(Vector2(Global.camera.offset.x - (viewport_size.x / 2) * zoom.x, points[0].y + font.get_height() * zoom.x * 2), rotation, zoom * 2)
			draw_string(font, Vector2.ZERO, "%spx" % str(round(mouse_pos.y)))
		else:
			draw_set_transform(Vector2(points[0].x + font.get_height() * zoom.y, Global.camera.offset.y - (viewport_size.y / 2.25) * zoom.y), rotation, zoom * 2)
			draw_string(font, Vector2.ZERO, "%spx" % str(round(mouse_pos.x)))

func outside_canvas(undo := false) -> bool:
	if undo:
		Global.undos -= 1
		Global.notification_label("Move Guide")
	if Global.control.redone:
		if Global.undos < Global.undo_redo.get_version(): # If we did undo and then redo
			Global.undos = Global.undo_redo.get_version()
			Global.notification_label("Move Guide")
	if type == Types.HORIZONTAL:
		if points[0].y < 0 || points[0].y > Global.canvas.size.y:
			queue_free()
			return true
	else:
		if points[0].x < 0 || points[0].x > Global.canvas.size.x:
			queue_free()
			return true
	return false

func point_in_rectangle(p : Vector2, coord1 : Vector2, coord2 : Vector2) -> bool:
	return p.x > coord1.x && p.y > coord1.y && p.x < coord2.x && p.y < coord2.y
