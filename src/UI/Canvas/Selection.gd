extends Node2D


class SelectionPolygon:
#	var project : Project
	var border := PoolVector2Array()
	var rect_outline : Rect2
	var rects := [] # Array of Rect2s
	var selected_pixels := [] # Array of Vector2s - the selected pixels


var line_offset := Vector2.ZERO setget _offset_changed
var tween : Tween
var selection_polygons := [] # Array of SelectionPolygons


func _ready() -> void:
	tween = Tween.new()
	tween.connect("tween_completed", self, "_offset_tween_completed")
	add_child(tween)
	tween.interpolate_property(self, "line_offset", Vector2.ZERO, Vector2(2, 2), 1)
	tween.start()


func generate_polygons():
#	selection_polygons.clear()
#	selection_polygons.append(SelectionPolygon.new())
#	for pixel in Global.current_project.selected_pixels:
#		var current_polygon : SelectionPolygon = selection_polygons[0]
#		var rect = Rect2(pixel, Vector2.ONE)
#		var pixel_border = get_rect_border(rect)
#		var arr = Geometry.merge_polygons_2d(pixel_border, current_polygon.border)
##		print("Arr ", arr)
#		if arr.size() == 1: # if the selections intersect
##			current_polygon.rects.append(rect)
#			current_polygon.rect_outline.merge(rect)
#			current_polygon.border = arr[0]
#
#
#	return
	var selected_pixels_copy := Global.current_project.selected_pixels.duplicate()
	var rects := []
	while selected_pixels_copy.size() > 0:
		var rect : Rect2 = generate_rect(selected_pixels_copy)
		print("!!!")
		if !rect:
			break
		for pixel in Global.current_project.selected_pixels:
			if rect.has_point(pixel):
#				print("POINT")
				selected_pixels_copy.erase(pixel)

		rects.append(rect)

	print(rects)
#	print("e ", selected_pixels_copy)

	if !rects:
		return
#	var polygons := [SelectionPolygon.new()]
	selection_polygons.clear()
	var polygons := [SelectionPolygon.new()]
	var curr_polyg := 0

	if rects.size() == 1:
		polygons[0].rects.append(rects[0])
		polygons[0].rect_outline = rects[0]
		polygons[0].selected_pixels = Global.current_project.selected_pixels.duplicate()
		var border : PoolVector2Array = get_rect_border(rects[0])
		polygons[0].border = border
		selection_polygons = polygons
		return

	for i in rects.size():
		var current_polygon : SelectionPolygon = polygons[curr_polyg]
		var rect : Rect2 = rects[i]
		var outlines : PoolVector2Array = get_rect_border(rect)

#		var rect_prev : Rect2 = rects[i - 1]
#		var outlines_prev : PoolVector2Array = get_rect_border(rect_prev)

		var arr = Geometry.merge_polygons_2d(outlines, current_polygon.border)
		print("Arr ", arr)
		if arr.size() == 1: # if the selections intersect
			current_polygon.rects.append(rect)
#			if not rect_prev in current_polygon.rects:
#				current_polygon.rects.append(rect_prev)
			current_polygon.rect_outline.merge(rect)
			current_polygon.border = arr[0]

	selection_polygons = polygons


func generate_rect(pixels : Array) -> Rect2:
	if !pixels:
		return Rect2()
	var rect := Rect2()
	rect.position = pixels[0]
	var reached_bottom := false
	var bottom_right_corner
	var p = pixels[0]
	while p + Vector2.DOWN in pixels:
		p += Vector2.DOWN
#	while p + Vector2.RIGHT in pixels:
#		p += Vector2.RIGHT
	bottom_right_corner = p
#	for p in pixels:
#		if p + Vector2.DOWN in pixels:
#			continue
#		reached_bottom = true
#		if p + Vector2.RIGHT in pixels:
#			continue
#		if reached_bottom and !bottom_right_corner:
#			bottom_right_corner = p
	rect.end = bottom_right_corner + Vector2.ONE
	return rect


func get_rect_border(rect : Rect2) -> PoolVector2Array:
	var border := PoolVector2Array()
	border.append(rect.position)
	border.append(Vector2(rect.end.x, rect.position.y))
	border.append(rect.end)
	border.append(Vector2(rect.position.x, rect.end.y))
	return border


func _offset_tween_completed(_object, _key) -> void:
	self.line_offset = Vector2.ZERO
	tween.interpolate_property(self, "line_offset", Vector2.ZERO, Vector2(2, 2), 1)
	tween.start()


func _offset_changed(value : Vector2) -> void:
	line_offset = value
	update()


func _draw() -> void:
	for polygon in selection_polygons:
		var points : PoolVector2Array = polygon.border
#		print(points)
		for i in range(1, points.size() + 1):
			var point0 = points[i - 1]
			var point1
			if i >= points.size():
				point1 = points[0]
			else:
				point1 = points[i]
			var start_x = min(point0.x, point1.x)
			var start_y = min(point0.y, point1.y)
			var end_x = max(point0.x, point1.x)
			var end_y = max(point0.y, point1.y)

			var start := Vector2(start_x, start_y)
			var end := Vector2(end_x, end_y)
			draw_dashed_line(start, end, Color.white, Color.black, 1.0, 1.0, false)

		if !polygon.selected_pixels:
			return
#		draw_polygon(Global.current_project.get_selection_polygon(), [Color(1, 1, 1, 0.5)])
	#	var rect_pos := _selected_rect.position
	#	var rect_end := _selected_rect.end
	#	draw_circle(rect_pos, 1, Color.gray)
	#	draw_circle(Vector2((rect_end.x + rect_pos.x) / 2, rect_pos.y), 1, Color.gray)
	#	draw_circle(Vector2(rect_end.x, rect_pos.y), 1, Color.gray)
	#	draw_circle(Vector2(rect_end.x, (rect_end.y + rect_pos.y) / 2), 1, Color.gray)
	#	draw_circle(rect_end, 1, Color.gray)
	#	draw_circle(Vector2(rect_end.x, rect_end.y), 1, Color.gray)
	#	draw_circle(Vector2((rect_end.x + rect_pos.x) / 2, rect_end.y), 1, Color.gray)
	#	draw_circle(Vector2(rect_pos.x, rect_end.y), 1, Color.gray)
	#	draw_circle(Vector2(rect_pos.x, (rect_end.y + rect_pos.y) / 2), 1, Color.gray)

#		if _move_pixel:
#			draw_texture(_move_texture, _clipped_rect.position, Color(1, 1, 1, 0.5))


# Taken and modified from https://github.com/juddrgledhill/godot-dashed-line
func draw_dashed_line(from : Vector2, to : Vector2, color : Color, color2 : Color, width := 1.0, dash_length := 1.0, cap_end := false, antialiased := false) -> void:
	var length = (to - from).length()
	var normal = (to - from).normalized()
	var dash_step = normal * dash_length

	var horizontal : bool = from.y == to.y
	var _offset : Vector2
	if horizontal:
		_offset = Vector2(line_offset.x, 0)
	else:
		_offset = Vector2(0, line_offset.y)

	if length < dash_length: # not long enough to dash
		draw_line(from, to, color, width, antialiased)
		return

	else:
		var draw_flag = true
		var segment_start = from
		var steps = length/dash_length
		for _start_length in range(0, steps + 1):
			var segment_end = segment_start + dash_step

			var start = segment_start + _offset
			start.x = min(start.x, to.x)
			start.y = min(start.y, to.y)

			var end = segment_end + _offset
			end.x = min(end.x, to.x)
			end.y = min(end.y, to.y)
			if draw_flag:
				draw_line(start, end, color, width, antialiased)
			else:
				draw_line(start, end, color2, width, antialiased)
				if _offset.length() < 1:
					draw_line(from, from + _offset, color2, width, antialiased)
				else:
					var from_offseted : Vector2 = from + _offset
					var halfway_point : Vector2 = from_offseted
					if horizontal:
						halfway_point += Vector2.LEFT
					else:
						halfway_point += Vector2.UP

					from_offseted.x = min(from_offseted.x, to.x)
					from_offseted.y = min(from_offseted.y, to.y)
					draw_line(halfway_point, from_offseted, color2, width, antialiased)
					draw_line(from, halfway_point, color, width, antialiased)

			segment_start = segment_end
			draw_flag = !draw_flag

		if cap_end:
			draw_line(segment_start, to, color, width, antialiased)
