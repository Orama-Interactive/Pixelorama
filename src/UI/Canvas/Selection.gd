extends Node2D


class SelectionPolygon:
#	var project : Project
	var border := []
	var rect_outline : Rect2
#	var rects := [] # Array of Rect2s
	var selected_pixels := [] setget _selected_pixels_changed # Array of Vector2s - the selected pixels
	var image := Image.new() setget _image_changed
	var image_texture := ImageTexture.new()

	func _init(rect : Rect2) -> void:
		rect_outline = rect
		border.append(rect.position)
		border.append(Vector2(rect.end.x, rect.position.y))
		border.append(rect.end)
		border.append(Vector2(rect.position.x, rect.end.y))


	func set_rect(rect : Rect2) -> void:
		rect_outline = rect
		border[0] = rect.position
		border[1] = Vector2(rect.end.x, rect.position.y)
		border[2] = rect.end
		border[3] = Vector2(rect.position.x, rect.end.y)


	func _selected_pixels_changed(value : Array) -> void:
		for pixel in selected_pixels:
			if pixel in Global.current_project.selected_pixels:
				Global.current_project.selected_pixels.erase(pixel)

		selected_pixels = value

		for pixel in selected_pixels:
			if pixel in Global.current_project.selected_pixels:
				continue
			else:
				Global.current_project.selected_pixels.append(pixel)


	func _image_changed(value : Image) -> void:
		image = value
		image_texture = ImageTexture.new()
		image_texture.create_from_image(image, 0)


var polygons := [] # Array of SelectionPolygon(s)
var tween : Tween
var line_offset := Vector2.ZERO setget _offset_changed


func _ready() -> void:
	tween = Tween.new()
	tween.connect("tween_completed", self, "_offset_tween_completed")
	add_child(tween)
	tween.interpolate_property(self, "line_offset", Vector2.ZERO, Vector2(2, 2), 1)
	tween.start()


func _offset_tween_completed(_object, _key) -> void:
	self.line_offset = Vector2.ZERO
	tween.interpolate_property(self, "line_offset", Vector2.ZERO, Vector2(2, 2), 1)
	tween.start()


func _offset_changed(value : Vector2) -> void:
	line_offset = value
	update()


func move_borders_start() -> void:
	pass
#	for shape in get_children():
#		shape.temp_polygon = shape.polygon


func move_borders(move : Vector2) -> void:
	for polygon in polygons:
		polygon.rect_outline.position += move
		for i in polygon.border.size():
			polygon.border[i] += move


func move_borders_end(new_pos : Vector2, old_pos : Vector2) -> void:
#	for shape in get_children():
#		var diff := new_pos - old_pos
#		for i in shape.polygon.size():
#			shape.polygon[i] -= diff # Temporarily set the polygon back to be used for undoredo
	var undo_data = _get_undo_data(false)
	for polygon in polygons:
#		polygon.temp_polygon = polygon.polygon
		var diff := new_pos - old_pos
		var selected_pixels_copy = polygon.selected_pixels.duplicate()
		for i in selected_pixels_copy.size():
			selected_pixels_copy[i] += diff

		polygon.selected_pixels = selected_pixels_copy
	commit_undo("Rectangle Select", undo_data)


func select_rect(merge := true) -> void:
	var project : Project = Global.current_project
	var polygon : SelectionPolygon = polygons[-1]
	polygon.selected_pixels = []
	project.selections.append(polygon)
	var selected_pixels_copy = polygon.selected_pixels.duplicate()
	for x in range(polygon.rect_outline.position.x, polygon.rect_outline.end.x):
		for y in range(polygon.rect_outline.position.y, polygon.rect_outline.end.y):
			var pos := Vector2(x, y)
			selected_pixels_copy.append(pos)

	polygon.selected_pixels = selected_pixels_copy
	if polygon.selected_pixels.size() == 0:
		polygons.erase(polygon)
		return
	merge_multiple_selections(polygon, merge)
	if not merge:
		polygon.selected_pixels = []
		polygons.erase(polygon)


func merge_multiple_selections(polygon : SelectionPolygon, merge := true) -> void:
	if polygons.size() < 2:
		return
	var to_erase := []
	for p in polygons:
		if p == polygon:
			continue
		if merge:
			var arr = Geometry.merge_polygons_2d(polygon.border, p.border)
#			print(arr.size())
			if arr.size() == 1: # if the selections intersect
				polygon.border = arr[0]
				polygon.rect_outline = polygon.rect_outline.merge(p.rect_outline)
				var selected_pixels_copy = polygon.selected_pixels.duplicate()
				for pixel in p.selected_pixels:
					selected_pixels_copy.append(pixel)
#				selection.clear_selection_on_tree_exit = false
#				selection.queue_free()
#				polygons.erase(p)
				to_erase.append(p)
				polygon.selected_pixels = selected_pixels_copy
		else:
			var arr = Geometry.clip_polygons_2d(p.border, polygon.border)
			if arr.size() == 0: # if the new selection completely overlaps the current
				p.selected_pixels = []
				to_erase.append(p)
			else: # if the selections intersect
				p.border = arr[0]
				var selected_pixels_copy = p.selected_pixels.duplicate()
				for pixel in polygon.selected_pixels:
					selected_pixels_copy.erase(pixel)
				p.selected_pixels = selected_pixels_copy
				for i in range(1, arr.size()):
					var rect = get_bounding_rectangle(arr[i])
					var new_polygon := SelectionPolygon.new(rect)
					new_polygon.border = arr[i]
					polygons.append(new_polygon)

	for p in to_erase:
		polygons.erase(p)


func move_content_start() -> void:
	move_borders_start()
	for p in polygons:
		if !p.image.is_empty():
			return
		p.image = get_image_from_polygon(p)
		var project : Project = Global.current_project
		var cel_image : Image = project.frames[project.current_frame].cels[project.current_layer].image
#		shape._clear_image.resize(shape._selected_rect.size.x, shape._selected_rect.size.y, Image.INTERPOLATE_NEAREST)
		var clear_image := Image.new()
		clear_image.create(p.image.get_width(), p.image.get_height(), false, Image.FORMAT_RGBA8)
		cel_image.blit_rect_mask(clear_image, p.image, Rect2(Vector2.ZERO, p.rect_outline.size), p.rect_outline.position)
		Global.canvas.update_texture(project.current_layer)


func move_content_end() -> void:
	for p in polygons:
		if p.image.is_empty():
			return
		var project : Project = Global.current_project
		var cel_image : Image = project.frames[project.current_frame].cels[project.current_layer].image
		cel_image.blit_rect_mask(p.image, p.image, Rect2(Vector2.ZERO, p.rect_outline.size), p.rect_outline.position)
		Global.canvas.update_texture(project.current_layer)
		p.image = Image.new()


func commit_undo(action : String, undo_data : Dictionary) -> void:
	var redo_data = _get_undo_data("image_data" in undo_data)
	var project := Global.current_project

	project.undos += 1
	project.undo_redo.create_action(action)
	project.undo_redo.add_do_property(project, "selections", redo_data["selections"])
	project.undo_redo.add_undo_property(project, "selections", undo_data["selections"])
	var i := 0
	for polygon in polygons:
		project.undo_redo.add_do_property(polygon, "border", redo_data["border_%s" % i])
		project.undo_redo.add_do_property(polygon, "rect_outline", redo_data["rect_outline_%s" % i])
		project.undo_redo.add_do_property(polygon, "selected_pixels", redo_data["selected_pixels_%s" % i])
		project.undo_redo.add_undo_property(polygon, "border", undo_data["border_%s" % i])
		project.undo_redo.add_undo_property(polygon, "rect_outline", undo_data["rect_outline_%s" % i])
		project.undo_redo.add_undo_property(polygon, "selected_pixels", undo_data["selected_pixels_%s" % i])
		i += 1

	if "image_data" in undo_data:
		var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
		project.undo_redo.add_do_property(image, "data", redo_data["image_data"])
		project.undo_redo.add_undo_property(image, "data", undo_data["image_data"])
	project.undo_redo.add_do_method(Global, "redo", project.current_frame, project.current_layer)
	project.undo_redo.add_undo_method(Global, "undo", project.current_frame, project.current_layer)
	project.undo_redo.commit_action()


func _get_undo_data(undo_image : bool) -> Dictionary:
	var data = {}
	var project := Global.current_project
	var i := 0
	data["selections"] = project.selections
	for polygon in polygons:
		data["border_%s" % i] = polygon.border
		data["rect_outline_%s" % i] = polygon.rect_outline
		data["selected_pixels_%s" % i] = polygon.selected_pixels
		i += 1
#	data["selected_rect"] = Global.current_project.selected_rect
	if undo_image:
		var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
		image.unlock()
		data["image_data"] = image.data
		image.lock()
#	for d in data.keys():
#		print(d, data[d])
	return data


func _draw() -> void:
	for p in polygons:
		var points : Array = p.border
#		print(polygon)
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

			if !p.image.is_empty():
				draw_texture(p.image_texture, p.rect_outline.position, Color(1, 1, 1, 1))

#		if !polygon.selected_pixels:
#			return
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


	#	if _move_pixel:
	#		draw_texture(_move_texture, _clipped_rect.position, Color(1, 1, 1, 0.5))


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


func get_bounding_rectangle(borders : PoolVector2Array) -> Rect2:
	var rect := Rect2()
	var xmin = borders[0].x
	var xmax = borders[0].x
	var ymin = borders[0].y
	var ymax = borders[0].y
	for edge in borders:
		if edge.x < xmin:
			xmin = edge.x
		if edge.x > xmax:
			xmax = edge.x
		if edge.y < ymin:
			ymin = edge.y
		if edge.y > ymax:
			ymax = edge.y
	rect.position = Vector2(xmin, ymin)
	rect.end = Vector2(xmax, ymax)
	return rect


func get_image_from_polygon(polygon : SelectionPolygon) -> Image:
	var rect : Rect2 = polygon.rect_outline
	var project : Project = Global.current_project
	var cel_image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	var image := Image.new()
	image = cel_image.get_rect(rect)
	if polygon.border.size() > 4:
		image.lock()
		var image_pixel := Vector2.ZERO
		for x in range(rect.position.x, rect.end.x):
			image_pixel.y = 0
			for y in range(rect.position.y, rect.end.y):
				var pos := Vector2(x, y)
				if not pos in polygon.selected_pixels:
					image.set_pixelv(image_pixel, Color(0, 0, 0, 0))
				image_pixel.y += 1
			image_pixel.x += 1

		image.unlock()
#	image.create(_selected_rect.size.x, _selected_rect.size.y, false, Image.FORMAT_RGBA8)

	return image


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


#func generate_polygons():
##	selection_polygons.clear()
##	selection_polygons.append(SelectionPolygon.new())
##	for pixel in Global.current_project.selected_pixels:
##		var current_polygon : SelectionPolygon = selection_polygons[0]
##		var rect = Rect2(pixel, Vector2.ONE)
##		var pixel_border = get_rect_border(rect)
##		var arr = Geometry.merge_polygons_2d(pixel_border, current_polygon.border)
###		print("Arr ", arr)
##		if arr.size() == 1: # if the selections intersect
###			current_polygon.rects.append(rect)
##			current_polygon.rect_outline.merge(rect)
##			current_polygon.border = arr[0]
##
##
##	return
#	var selected_pixels_copy := Global.current_project.selected_pixels.duplicate()
#	var rects := []
#	while selected_pixels_copy.size() > 0:
#		var rect : Rect2 = generate_rect(selected_pixels_copy)
#		print("!!!")
#		if !rect:
#			break
#		for pixel in Global.current_project.selected_pixels:
#			if rect.has_point(pixel):
##				print("POINT")
#				selected_pixels_copy.erase(pixel)
#
#		rects.append(rect)
#
#	print(rects)
##	print("e ", selected_pixels_copy)
#
#	if !rects:
#		return
##	var polygons := [SelectionPolygon.new()]
#	selection_polygons.clear()
#	var polygons := [SelectionPolygon.new()]
#	var curr_polyg := 0
#
#	if rects.size() == 1:
#		polygons[0].rects.append(rects[0])
#		polygons[0].rect_outline = rects[0]
#		polygons[0].selected_pixels = Global.current_project.selected_pixels.duplicate()
#		var border : PoolVector2Array = get_rect_border(rects[0])
#		polygons[0].border = border
#		selection_polygons = polygons
#		return
#
#	for i in rects.size():
#		var current_polygon : SelectionPolygon = polygons[curr_polyg]
#		var rect : Rect2 = rects[i]
#		var outlines : PoolVector2Array = get_rect_border(rect)
#
##		var rect_prev : Rect2 = rects[i - 1]
##		var outlines_prev : PoolVector2Array = get_rect_border(rect_prev)
#
#		var arr = Geometry.merge_polygons_2d(outlines, current_polygon.border)
#		print("Arr ", arr)
#		if arr.size() == 1: # if the selections intersect
#			current_polygon.rects.append(rect)
##			if not rect_prev in current_polygon.rects:
##				current_polygon.rects.append(rect_prev)
#			current_polygon.rect_outline.merge(rect)
#			current_polygon.border = arr[0]
#
#	selection_polygons = polygons
