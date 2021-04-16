extends Node2D


#class SelectionPolygon:
##	var project : Project
#	var border := PoolVector2Array()
#	var rect_outline : Rect2
#	var rects := [] # Array of Rect2s
#	var selected_pixels := [] # Array of Vector2s - the selected pixels


func move_borders_start() -> void:
	for shape in get_children():
		shape.temp_polygon = shape.polygon


func move_borders(move : Vector2) -> void:
	for shape in get_children():
		shape._selected_rect.position += move
		for i in shape.polygon.size():
			shape.polygon[i] += move


func move_borders_end(new_pos : Vector2, old_pos : Vector2) -> void:
#	for shape in get_children():
#		var diff := new_pos - old_pos
#		for i in shape.polygon.size():
#			shape.polygon[i] -= diff # Temporarily set the polygon back to be used for undoredo
	var undo_data = _get_undo_data(false)
	for shape in get_children():
		shape.temp_polygon = shape.polygon
		var diff := new_pos - old_pos
		var selected_pixels_copy = shape.local_selected_pixels.duplicate()
		for i in selected_pixels_copy.size():
			selected_pixels_copy[i] += diff

		shape.local_selected_pixels = selected_pixels_copy
	commit_undo("Rectangle Select", undo_data)


func move_content_start() -> void:
	move_borders_start()
	for shape in get_children():
		if !shape.local_image.is_empty():
			return
		shape.local_image = shape.get_image()
		shape.local_image_texture.create_from_image(shape.local_image, 0)
		var project : Project = Global.current_project
		var cel_image : Image = project.frames[project.current_frame].cels[project.current_layer].image
		shape._clear_image.resize(shape._selected_rect.size.x, shape._selected_rect.size.y, Image.INTERPOLATE_NEAREST)
		cel_image.blit_rect_mask(shape._clear_image, shape.local_image, Rect2(Vector2.ZERO, shape._selected_rect.size), shape._selected_rect.position)
		Global.canvas.update_texture(project.current_layer)


func move_content_end() -> void:
	for shape in get_children():
		if shape.local_image.is_empty():
			return
		var project : Project = Global.current_project
		var cel_image : Image = project.frames[project.current_frame].cels[project.current_layer].image
		cel_image.blit_rect_mask(shape.local_image, shape.local_image, Rect2(Vector2.ZERO, shape._selected_rect.size), shape._selected_rect.position)
		Global.canvas.update_texture(project.current_layer)
		shape.local_image = Image.new()
		shape.local_image_texture = ImageTexture.new()


func commit_undo(action : String, undo_data : Dictionary) -> void:
	var redo_data = _get_undo_data("image_data" in undo_data)
	var project := Global.current_project

	project.undos += 1
	project.undo_redo.create_action(action)
	var i := 0
	for shape in get_children():
		project.undo_redo.add_do_property(shape, "temp_polygon", redo_data["temp_polygon_%s" % i])
		project.undo_redo.add_do_property(shape, "_selected_rect", redo_data["_selected_rect_%s" % i])
		project.undo_redo.add_do_property(shape, "local_selected_pixels", redo_data["local_selected_pixels_%s" % i])
		project.undo_redo.add_undo_property(shape, "temp_polygon", undo_data["temp_polygon_%s" % i])
		project.undo_redo.add_undo_property(shape, "_selected_rect", undo_data["_selected_rect_%s" % i])
		project.undo_redo.add_undo_property(shape, "local_selected_pixels", undo_data["local_selected_pixels_%s" % i])
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
	for shape in get_children():
		data["temp_polygon_%s" % i] = shape.temp_polygon
		data["_selected_rect_%s" % i] = shape._selected_rect
		data["local_selected_pixels_%s" % i] = shape.local_selected_pixels
		i += 1
#	data["selected_rect"] = Global.current_project.selected_rect
	if undo_image:
		var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
		image.unlock()
		data["image_data"] = image.data
		image.lock()
	for d in data.keys():
		print(d, data[d])
	return data


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
