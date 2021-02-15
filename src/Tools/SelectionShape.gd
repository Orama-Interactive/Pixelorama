class_name SelectionShape extends Polygon2D


var line_offset := Vector2.ZERO setget _offset_changed
var tween : Tween
var local_selected_pixels := [] setget _local_selected_pixels_changed # Array of Vector2s
var clear_selection_on_tree_exit := true
var _selected_rect := Rect2(0, 0, 0, 0)
var _clipped_rect := Rect2(0, 0, 0, 0)
var _move_image := Image.new()
var _move_texture := ImageTexture.new()
var _clear_image := Image.new()
var _move_pixel := false
var _clipboard := Image.new()
var _undo_data := {}


func _ready() -> void:
	tween = Tween.new()
	tween.connect("tween_completed", self, "_offset_tween_completed")
	add_child(tween)
	tween.interpolate_property(self, "line_offset", Vector2.ZERO, Vector2(2, 2), 1)
	tween.start()
	_clear_image.create(1, 1, false, Image.FORMAT_RGBA8)
	_clear_image.fill(Color(0, 0, 0, 0))


func _offset_tween_completed(_object, _key) -> void:
	self.line_offset = Vector2.ZERO
	tween.interpolate_property(self, "line_offset", Vector2.ZERO, Vector2(2, 2), 1)
	tween.start()


func _offset_changed(value : Vector2) -> void:
	line_offset = value
	update()


func _draw() -> void:
	var points : PoolVector2Array = polygon
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

	if !local_selected_pixels:
		return
#	draw_polygon(Global.current_project.get_selection_polygon(), [Color(1, 1, 1, 0.5)])
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

	if _move_pixel:
		draw_texture(_move_texture, _clipped_rect.position, Color(1, 1, 1, 0.5))


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


func _local_selected_pixels_changed(value : Array) -> void:
	for pixel in local_selected_pixels:
		if pixel in Global.current_project.selected_pixels:
			Global.current_project.selected_pixels.erase(pixel)

	local_selected_pixels = value

	for pixel in local_selected_pixels:
		if pixel in Global.current_project.selected_pixels:
			continue
		else:
			Global.current_project.selected_pixels.append(pixel)

#	if value:
#		Global.canvas.get_node("Selection").generate_polygons()


func has_point(position : Vector2) -> bool:
	return Geometry.is_point_in_polygon(position, polygon)


func get_rect() -> Rect2:
	return _selected_rect


func set_rect(rect : Rect2) -> void:
	_selected_rect = rect
	polygon[0] = rect.position
	polygon[1] = Vector2(rect.end.x, rect.position.y)
	polygon[2] = rect.end
	polygon[3] = Vector2(rect.position.x, rect.end.y)
#	visible = not rect.has_no_area()


func move_polygon(move : Vector2) -> void:
	_selected_rect.position += move
	_clipped_rect.position += move
	for i in polygon.size():
		polygon[i] += move
#	set_rect(_selected_rect)


func move_polygon_end(new_pos : Vector2, old_pos : Vector2) -> void:
	var diff := new_pos - old_pos
	var selected_pixels_copy = local_selected_pixels.duplicate()
	for i in selected_pixels_copy.size():
		selected_pixels_copy[i] += diff

	self.local_selected_pixels = selected_pixels_copy


func select_rect(merge := true) -> void:
	var project : Project = Global.current_project
	self.local_selected_pixels = []
	var selected_pixels_copy = local_selected_pixels.duplicate()
	for x in range(_selected_rect.position.x, _selected_rect.end.x):
		for y in range(_selected_rect.position.y, _selected_rect.end.y):
			var pos := Vector2(x, y)
#			if polygon.size() > 4: # if it's not a rectangle
#				if !Geometry.is_point_in_polygon(pos, polygon):
#					continue
			if x < 0 or x >= project.size.x:
				continue
			if y < 0 or y >= project.size.y:
				continue
			selected_pixels_copy.append(pos)

	self.local_selected_pixels = selected_pixels_copy
	if local_selected_pixels.size() == 0:
		queue_free()
		return
	merge_multiple_selections(merge)
#	var undo_data = _get_undo_data(false)
#	Global.current_project.selected_rect = _selected_rect
#	commit_undo("Rectangle Select", undo_data)


func merge_multiple_selections(merge := true) -> void:
	if Global.current_project.selections.size() < 2:
		return
	for selection in Global.current_project.selections:
		if selection == self:
			continue
		if merge:
			var arr = Geometry.merge_polygons_2d(polygon, selection.polygon)
			if arr.size() == 1: # if the selections intersect
				set_polygon(arr[0])
				_selected_rect = _selected_rect.merge(selection._selected_rect)
				var selected_pixels_copy = local_selected_pixels.duplicate()
				for pixel in selection.local_selected_pixels:
					selected_pixels_copy.append(pixel)
				selection.clear_selection_on_tree_exit = false
				selection.queue_free()
				self.local_selected_pixels = selected_pixels_copy
		else:
			var arr = Geometry.clip_polygons_2d(selection.polygon, polygon)
			if arr.size() == 1: # if the selections intersect
				selection.set_polygon(arr[0])
				var selected_pixels_copy = selection.local_selected_pixels.duplicate()
				for pixel in local_selected_pixels:
					selected_pixels_copy.erase(pixel)
				selection.local_selected_pixels = selected_pixels_copy
				queue_free()

func move_start(move_pixel : bool) -> void:
	if not move_pixel:
		return

	_undo_data = _get_undo_data(true)
	var project := Global.current_project
	var image : Image = project.frames[project.current_frame].cels[project.current_layer].image

	var rect = Rect2(Vector2.ZERO, project.size)
	_clipped_rect = rect.clip(_selected_rect)
	_move_image = image.get_rect(_clipped_rect)
	_move_texture.create_from_image(_move_image, 0)

	var size := _clipped_rect.size
	rect = Rect2(Vector2.ZERO, size)
	_clear_image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	image.blit_rect(_clear_image, rect, _clipped_rect.position)
	Global.canvas.update_texture(project.current_layer)

	_move_pixel = true
	update()


func move_end() -> void:
	var undo_data = _undo_data if _move_pixel else _get_undo_data(false)

	if _move_pixel:
		var project := Global.current_project
		var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
		var size := _clipped_rect.size
		var rect = Rect2(Vector2.ZERO, size)
		image.blit_rect_mask(_move_image, _move_image, rect, _clipped_rect.position)
		_move_pixel = false
		update()

	Global.current_project.selected_rect = _selected_rect
	commit_undo("Rectangle Select", undo_data)
	_undo_data.clear()


func copy() -> void:
	if _selected_rect.has_no_area():
		return

	var project := Global.current_project
	var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	_clipboard = image.get_rect(_selected_rect)
	if _clipboard.is_invisible():
		return
	var brush = _clipboard.get_rect(_clipboard.get_used_rect())
	project.brushes.append(brush)
	Brushes.add_project_brush(brush)

func cut() -> void: # This is basically the same as copy + delete
	if _selected_rect.has_no_area():
		return

	var undo_data = _get_undo_data(true)
	var project := Global.current_project
	var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	var size := _selected_rect.size
	var rect = Rect2(Vector2.ZERO, size)
	_clipboard = image.get_rect(_selected_rect)
	if _clipboard.is_invisible():
		return

	_clear_image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	var brush = _clipboard.get_rect(_clipboard.get_used_rect())
	project.brushes.append(brush)
	Brushes.add_project_brush(brush)
	move_end() # The selection_rectangle can be used while is moving, this prevents malfunctioning
	image.blit_rect(_clear_image, rect, _selected_rect.position)
	commit_undo("Draw", undo_data)

func paste() -> void:
	if _clipboard.get_size() <= Vector2.ZERO:
		return

	var undo_data = _get_undo_data(true)
	var project := Global.current_project
	var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	var size := _selected_rect.size
	var rect = Rect2(Vector2.ZERO, size)
	image.blend_rect(_clipboard, rect, _selected_rect.position)
	move_end() # The selection_rectangle can be used while is moving, this prevents malfunctioning
	commit_undo("Draw", undo_data)


func delete() -> void:
	var undo_data = _get_undo_data(true)
	var project := Global.current_project
	var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	var size := _selected_rect.size
	var rect = Rect2(Vector2.ZERO, size)
	_clear_image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	image.blit_rect(_clear_image, rect, _selected_rect.position)
	move_end() # The selection_rectangle can be used while is moving, this prevents malfunctioning
	commit_undo("Draw", undo_data)


func commit_undo(action : String, undo_data : Dictionary) -> void:
	var redo_data = _get_undo_data("image_data" in undo_data)
	var project := Global.current_project

	project.undos += 1
	project.undo_redo.create_action(action)
	project.undo_redo.add_do_property(project, "selected_rect", redo_data["selected_rect"])
	project.undo_redo.add_undo_property(project, "selected_rect", undo_data["selected_rect"])
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
	data["selected_rect"] = Global.current_project.selected_rect
	if undo_image:
		var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
		image.unlock()
		data["image_data"] = image.data
		image.lock()
	return data


func _on_SelectionShape_tree_exiting() -> void:
	Global.current_project.selections.erase(self)
	if clear_selection_on_tree_exit:
		self.local_selected_pixels = []
