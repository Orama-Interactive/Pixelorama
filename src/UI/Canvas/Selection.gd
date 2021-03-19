extends Node2D


class SelectionPolygon:
	var border := []
	var rect_outline : Rect2 setget _rect_outline_changed
	var gizmos := [Rect2(), Rect2(), Rect2(), Rect2(), Rect2(), Rect2(), Rect2(), Rect2()] # Array of Rect2s

	func _init(rect : Rect2) -> void:
		self.rect_outline = rect
		border.append(rect.position)
		border.append(Vector2(rect.end.x, rect.position.y))
		border.append(rect.end)
		border.append(Vector2(rect.position.x, rect.end.y))


	func set_rect(rect : Rect2) -> void:
		self.rect_outline = rect
		border[0] = rect.position
		border[1] = Vector2(rect.end.x, rect.position.y)
		border[2] = rect.end
		border[3] = Vector2(rect.position.x, rect.end.y)


	func _rect_outline_changed(value : Rect2) -> void:
		rect_outline = value
		var rect_pos : Vector2 = rect_outline.position
		var rect_end : Vector2 = rect_outline.end
		var size := Vector2.ONE
		# Clockwise, starting from top-left corner
		gizmos[0] = Rect2(rect_pos - size, size)
		gizmos[1] = Rect2(Vector2((rect_end.x + rect_pos.x - size.x) / 2, rect_pos.y - size.y), size)
		gizmos[2] = Rect2(Vector2(rect_end.x, rect_pos.y - size.y), size)
		gizmos[3] = Rect2(Vector2(rect_end.x, (rect_end.y + rect_pos.y - size.y) / 2), size)
		gizmos[4] = Rect2(rect_end, size)
		gizmos[5] = Rect2(Vector2((rect_end.x + rect_pos.x - size.x) / 2, rect_end.y), size)
		gizmos[6] = Rect2(Vector2(rect_pos.x - size.x, rect_end.y), size)
		gizmos[7] = Rect2(Vector2(rect_pos.x - size.x, (rect_end.y + rect_pos.y - size.y) / 2), size)


class Clipboard:
	var image := Image.new()
	var polygons := [] # Array of SelectionPolygons
	var position := Vector2.ZERO
	var selected_pixels := []


var clipboard := Clipboard.new()
var tween : Tween
var line_offset := Vector2.ZERO setget _offset_changed
var move_preview_location := Vector2.ZERO
var is_moving_content := false
var preview_image := Image.new()
var preview_image_texture : ImageTexture
var undo_data : Dictionary


func _ready() -> void:
	tween = Tween.new()
	tween.connect("tween_completed", self, "_offset_tween_completed")
	add_child(tween)
	tween.interpolate_property(self, "line_offset", Vector2.ZERO, Vector2(2, 2), 1)
	tween.start()


func _input(event : InputEvent):
	if event is InputEventKey:
		if is_moving_content:
			if event.scancode == 16777221:
				move_content_confirm()
			elif event.scancode == 16777217:
				move_content_cancel()


func _offset_tween_completed(_object, _key) -> void:
	self.line_offset = Vector2.ZERO
	tween.interpolate_property(self, "line_offset", Vector2.ZERO, Vector2(2, 2), 1)
	tween.start()


func _offset_changed(value : Vector2) -> void:
	line_offset = value
	update()


func move_borders_start() -> void:
	undo_data = _get_undo_data(false)


func move_borders(move : Vector2) -> void:
	for polygon in Global.current_project.selections:
		polygon.rect_outline.position += move
		var borders_copy = polygon.border.duplicate()
		for i in borders_copy.size():
			borders_copy[i] += move

		polygon.border = borders_copy


func move_borders_end(new_pos : Vector2, old_pos : Vector2) -> void:
	var diff := new_pos - old_pos
	var selected_pixels_copy = Global.current_project.selected_pixels.duplicate()
	for i in selected_pixels_copy.size():
		selected_pixels_copy[i] += diff

	Global.current_project.selected_pixels = selected_pixels_copy
	commit_undo("Rectangle Select", undo_data)


func select_rect(merge := true) -> void:
	var project : Project = Global.current_project
	var polygon : SelectionPolygon = Global.current_project.selections[-1]
	var selected_pixels_copy = project.selected_pixels.duplicate()
	var polygon_pixels := []
	for x in range(polygon.rect_outline.position.x, polygon.rect_outline.end.x):
		for y in range(polygon.rect_outline.position.y, polygon.rect_outline.end.y):
			var pos := Vector2(x, y)
			polygon_pixels.append(pos)
			if pos in selected_pixels_copy or !merge:
				continue
			selected_pixels_copy.append(pos)

	project.selected_pixels = selected_pixels_copy
	if polygon_pixels.size() == 0:
		project.selections.erase(polygon)
		return
	if merge:
		merge_selections(polygon)
	else:
		clip_selections(polygon, polygon_pixels)
		project.selections.erase(polygon)


func merge_selections(polygon : SelectionPolygon) -> void:
	if Global.current_project.selections.size() < 2:
		return
	var to_erase := []
	for p in Global.current_project.selections:
		if p == polygon:
			continue
		var arr := Geometry.merge_polygons_2d(polygon.border, p.border)
		if arr.size() == 1: # if the selections intersect
			polygon.border = arr[0]
			polygon.rect_outline = polygon.rect_outline.merge(p.rect_outline)
			to_erase.append(p)

	for p in to_erase:
		Global.current_project.selections.erase(p)


func clip_selections(polygon : SelectionPolygon, polygon_pixels : Array) -> void:
	var to_erase := []
	for p in Global.current_project.selections:
		if p == polygon:
			continue
		var arr := Geometry.clip_polygons_2d(p.border, polygon.border)
		if arr.size() == 0: # if the new selection completely overlaps the current
			to_erase.append(p)
		else:
			p.border = arr[0]
			p.rect_outline = get_bounding_rectangle(p.border)
			for i in range(1, arr.size()):
				var rect = get_bounding_rectangle(arr[i])
				var new_polygon := SelectionPolygon.new(rect)
				new_polygon.border = arr[i]
				Global.current_project.selections.append(new_polygon)

		var selected_pixels_copy = Global.current_project.selected_pixels.duplicate()
		for pixel in polygon_pixels:
			selected_pixels_copy.erase(pixel)
		Global.current_project.selected_pixels = selected_pixels_copy

	for p in to_erase:
		Global.current_project.selections.erase(p)


func move_content_start() -> void:
	if !is_moving_content:
		is_moving_content = true
		undo_data = _get_undo_data(true)
		get_preview_image()


func move_content(move : Vector2) -> void:
	move_borders(move)
	move_preview_location += move


func move_content_confirm() -> void:
	if !is_moving_content:
		return
	var project : Project = Global.current_project
	var cel_image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	cel_image.blit_rect_mask(preview_image, preview_image, Rect2(Vector2.ZERO, project.size), move_preview_location)
	var selected_pixels_copy = Global.current_project.selected_pixels.duplicate()
	for i in selected_pixels_copy.size():
		selected_pixels_copy[i] += move_preview_location
	Global.current_project.selected_pixels = selected_pixels_copy
	preview_image = Image.new()
	move_preview_location = Vector2.ZERO
	is_moving_content = false
	commit_undo("Move Selection", undo_data)


func move_content_cancel() -> void:
	if preview_image.is_empty():
		return
	for polygon in Global.current_project.selections:
		polygon.rect_outline.position -= move_preview_location
		var borders_copy = polygon.border.duplicate()
		for i in borders_copy.size():
			borders_copy[i] -= move_preview_location
		polygon.border = borders_copy

	move_preview_location = Vector2.ZERO
	is_moving_content = false
	var project : Project = Global.current_project
	var cel_image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	cel_image.blit_rect_mask(preview_image, preview_image, Rect2(Vector2.ZERO, project.size), move_preview_location)
	Global.canvas.update_texture(project.current_layer)
	preview_image = Image.new()


func commit_undo(action : String, _undo_data : Dictionary) -> void:
	var redo_data = _get_undo_data("image_data" in _undo_data)
	var project := Global.current_project

	project.undos += 1
	project.undo_redo.create_action(action)
	project.undo_redo.add_do_property(project, "selections", redo_data["selections"])
	project.undo_redo.add_do_property(project, "selected_pixels", redo_data["selected_pixels"])

	project.undo_redo.add_undo_property(project, "selections", _undo_data["selections"])
	project.undo_redo.add_undo_property(project, "selected_pixels", _undo_data["selected_pixels"])

	var i := 0
	for polygon in Global.current_project.selections:
		if "border_%s" % i in _undo_data:
			project.undo_redo.add_do_property(polygon, "border", redo_data["border_%s" % i])
			project.undo_redo.add_do_property(polygon, "rect_outline", redo_data["rect_outline_%s" % i])
			project.undo_redo.add_undo_property(polygon, "border", _undo_data["border_%s" % i])
			project.undo_redo.add_undo_property(polygon, "rect_outline", _undo_data["rect_outline_%s" % i])
		i += 1

	if "image_data" in _undo_data:
		var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
		project.undo_redo.add_do_property(image, "data", redo_data["image_data"])
		project.undo_redo.add_undo_property(image, "data", _undo_data["image_data"])
	project.undo_redo.add_do_method(Global, "redo", project.current_frame, project.current_layer)
	project.undo_redo.add_undo_method(Global, "undo", project.current_frame, project.current_layer)
	project.undo_redo.commit_action()

	undo_data.clear()


func _get_undo_data(undo_image : bool) -> Dictionary:
	var data := {}
	var project := Global.current_project
	var i := 0
	data["selections"] = project.selections
	data["selected_pixels"] = project.selected_pixels
	for polygon in Global.current_project.selections:
		data["border_%s" % i] = polygon.border
		data["rect_outline_%s" % i] = polygon.rect_outline
		i += 1

	if undo_image:
		var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
		image.unlock()
		data["image_data"] = image.data
		image.lock()
#	for d in data.keys():
#		print(d, data[d])
	return data


func cut() -> void:
	copy()
	delete()


func copy() -> void:
	var project := Global.current_project
	if project.selected_pixels.empty():
		return
	var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	var selection_rectangle := get_big_bounding_rectangle()
	var to_copy := Image.new()
	to_copy = image.get_rect(selection_rectangle)
	to_copy.lock()
	if project.selections.size() > 1 or project.selections[0].border.size() > 4:
		# Only remove unincluded pixels if the selection is not a single rectangle
		for x in to_copy.get_size().x:
			for y in to_copy.get_size().y:
				var pos := Vector2(x, y)
				if not (pos + selection_rectangle.position) in project.selected_pixels:
					to_copy.set_pixelv(pos, Color(0))
	to_copy.unlock()
	clipboard.image = to_copy
	for selection in project.selections:
		var selection_duplicate := SelectionPolygon.new(selection.rect_outline)
		selection_duplicate.border = selection.border
		clipboard.polygons.append(selection_duplicate)
	clipboard.position = selection_rectangle.position
	clipboard.selected_pixels = project.selected_pixels.duplicate()


func paste() -> void:
	if !clipboard.image:
		return
	var _undo_data = _get_undo_data(true)
	var project := Global.current_project
	var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	clear_selection()
	project.selections = clipboard.polygons.duplicate()
	project.selected_pixels = clipboard.selected_pixels.duplicate()
	image.blend_rect(clipboard.image, Rect2(Vector2.ZERO, project.size), clipboard.position)
	commit_undo("Draw", _undo_data)


func delete() -> void:
	var project := Global.current_project
	if project.selected_pixels.empty():
		return
	var _undo_data = _get_undo_data(true)
	var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	for pixel in project.selected_pixels:
		image.set_pixelv(pixel, Color(0))
	commit_undo("Draw", _undo_data)


func select_all() -> void:
	var project := Global.current_project
	var _undo_data = _get_undo_data(false)
	clear_selection()
	var full_rect = Rect2(Vector2.ZERO, project.size)
	var new_selection = SelectionPolygon.new(full_rect)
	var selections : Array = project.selections.duplicate()
	selections.append(new_selection)
	project.selections = selections
	select_rect()
	commit_undo("Rectangle Select", _undo_data)


func clear_selection(use_undo := false) -> void:
	move_content_confirm()
	var _undo_data = _get_undo_data(false)
	var selections : Array = Global.current_project.selections.duplicate()
	var selected_pixels : Array = Global.current_project.selected_pixels.duplicate()
	selected_pixels.clear()
	Global.current_project.selected_pixels = selected_pixels
	selections.clear()
	Global.current_project.selections = selections
	if use_undo:
		commit_undo("Clear Selection", _undo_data)


func _draw() -> void:
	var _position := position
	var _scale := scale
	if Global.mirror_view:
		_position.x = _position.x + Global.current_project.size.x
		_scale.x = -1
	draw_set_transform(_position, rotation, _scale)
	for p in Global.current_project.selections:
		var points : Array = p.border
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

		for gizmo in p.gizmos: # Draw gizmos
			draw_rect(gizmo, Color.black)
			var filled_rect : Rect2 = gizmo
			var filled_size := Vector2(0.2, 0.2)
			filled_rect.position += filled_size
			filled_rect.size -= filled_size * 2
			draw_rect(filled_rect, Color.white) # Filled white square



	if is_moving_content and !preview_image.is_empty():
		draw_texture(preview_image_texture, move_preview_location, Color(1, 1, 1, 0.5))
	draw_set_transform(position, rotation, scale)


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


func get_bounding_rectangle(borders : Array) -> Rect2:
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


func get_preview_image() -> void:
	var project : Project = Global.current_project
	var cel_image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	if preview_image.is_empty():
		preview_image.copy_from(cel_image)
		preview_image.lock()
		for x in range(0, project.size.x):
			for y in range(0, project.size.y):
				var pos := Vector2(x, y)
				if not pos in project.selected_pixels:
					preview_image.set_pixelv(pos, Color(0, 0, 0, 0))
		preview_image.unlock()
		preview_image_texture = ImageTexture.new()
		preview_image_texture.create_from_image(preview_image, 0)

	var clear_image := Image.new()
	clear_image.create(preview_image.get_width(), preview_image.get_height(), false, Image.FORMAT_RGBA8)
	cel_image.blit_rect_mask(clear_image, preview_image, Rect2(Vector2.ZERO, project.size), move_preview_location)
	Global.canvas.update_texture(project.current_layer)


func get_big_bounding_rectangle() -> Rect2:
	# Returns a rectangle that contains the entire selection, with multiple polygons
	var project : Project = Global.current_project
	var rect := Rect2()
	rect = project.selections[0].rect_outline
	for i in range(1, project.selections.size()):
		rect = rect.merge(project.selections[i].rect_outline)
	return rect
