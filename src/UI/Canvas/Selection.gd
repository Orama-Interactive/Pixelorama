extends Node2D


class Clipboard:
	var image := Image.new()
	var selection_bitmap := BitMap.new()
	var big_bounding_rectangle := Rect2()


class Gizmo:
	var rect : Rect2
	var direction := Vector2.ZERO

	func _init(_direction : Vector2) -> void:
		direction = _direction


	func get_cursor() -> int:
		var cursor := Input.CURSOR_MOVE
		if direction == Vector2(-1, -1) or direction == Vector2(1, 1): # Top left or bottom right
			cursor = Input.CURSOR_FDIAGSIZE
		elif direction == Vector2(1, -1) or direction == Vector2(-1, 1): # Top right or bottom left
			cursor = Input.CURSOR_BDIAGSIZE
		elif direction == Vector2(0, -1) or direction == Vector2(0, 1): # Center top or center bottom
			cursor = Input.CURSOR_VSIZE
		elif direction == Vector2(-1, 0) or direction == Vector2(1, 0): # Center left or center right
			cursor = Input.CURSOR_HSIZE
		return cursor


var clipboard := Clipboard.new()
var is_moving_content := false
var big_bounding_rectangle := Rect2() setget _big_bounding_rectangle_changed
var preview_image := Image.new()
var preview_image_texture : ImageTexture
var undo_data : Dictionary
var drawn_rect := Rect2(0, 0, 0, 0)
var gizmos := [] # Array of Gizmos
var dragged_gizmo : Gizmo = null
var mouse_pos_on_gizmo_drag := Vector2.ZERO

onready var marching_ants_outline : Sprite = $MarchingAntsOutline


func _ready() -> void:
	gizmos.append(Gizmo.new(Vector2(-1, -1))) # Top left
	gizmos.append(Gizmo.new(Vector2(0, -1))) # Center top
	gizmos.append(Gizmo.new(Vector2(1, -1))) # Top right
	gizmos.append(Gizmo.new(Vector2(1, 0))) # Center right
	gizmos.append(Gizmo.new(Vector2(1, 1))) # Bottom right
	gizmos.append(Gizmo.new(Vector2(0, 1))) # Center bottom
	gizmos.append(Gizmo.new(Vector2(-1, 1))) # Bottom left
	gizmos.append(Gizmo.new(Vector2(-1, 0))) # Center left


func _input(event : InputEvent) -> void:
	if event is InputEventKey:
		if is_moving_content: # Temporary code
			if event.scancode == 16777221:
				move_content_confirm()
			elif event.scancode == 16777217:
				move_content_cancel()
	elif event is InputEventMouse:
		var gizmo
		for g in gizmos:
			if g.rect.has_point(Global.canvas.current_pixel):
				gizmo = g
				break
		if gizmo:
			Global.main_viewport.mouse_default_cursor_shape = gizmo.get_cursor()
		elif !dragged_gizmo:
			Global.main_viewport.mouse_default_cursor_shape = Input.CURSOR_CROSS

		if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
			if gizmo and event.pressed:
				Global.has_focus = false
				dragged_gizmo = gizmo
				mouse_pos_on_gizmo_drag = Global.canvas.current_pixel
			elif dragged_gizmo:
				Global.has_focus = true
				var diff : Vector2 = (Global.canvas.current_pixel - mouse_pos_on_gizmo_drag) * dragged_gizmo.direction
				diff = diff.round()
				print(diff)
				print(preview_image.get_size())
				var left := 0.0 if dragged_gizmo.direction.x >= 0 else diff.x
				var top := 0.0 if dragged_gizmo.direction.y >= 0 else diff.y
				var right := diff.x if dragged_gizmo.direction.x >= 0 else 0.0
				var bottom := diff.y if dragged_gizmo.direction.y >= 0 else 0.0
				self.big_bounding_rectangle = big_bounding_rectangle.grow_individual(left, top, right, bottom)
				preview_image.resize(big_bounding_rectangle.size.x, big_bounding_rectangle.size.y, Image.INTERPOLATE_NEAREST)
				preview_image_texture.create_from_image(preview_image, 0)
				var selected_bitmap_copy = Global.current_project.selection_bitmap.duplicate()
				Global.current_project.resize_bitmap_values(selected_bitmap_copy, big_bounding_rectangle.size)
				Global.current_project.selection_bitmap = selected_bitmap_copy
				Global.current_project.selection_bitmap_changed()
				dragged_gizmo = null
				update()


func _big_bounding_rectangle_changed(value : Rect2) -> void:
	big_bounding_rectangle = value
	var rect_pos : Vector2 = big_bounding_rectangle.position
	var rect_end : Vector2 = big_bounding_rectangle.end
	var size := Vector2.ONE
	# Clockwise, starting from top-left corner
	gizmos[0].rect = Rect2(rect_pos - size, size)
	gizmos[1].rect = Rect2(Vector2((rect_end.x + rect_pos.x - size.x) / 2, rect_pos.y - size.y), size)
	gizmos[2].rect = Rect2(Vector2(rect_end.x, rect_pos.y - size.y), size)
	gizmos[3].rect = Rect2(Vector2(rect_end.x, (rect_end.y + rect_pos.y - size.y) / 2), size)
	gizmos[4].rect = Rect2(rect_end, size)
	gizmos[5].rect = Rect2(Vector2((rect_end.x + rect_pos.x - size.x) / 2, rect_end.y), size)
	gizmos[6].rect = Rect2(Vector2(rect_pos.x - size.x, rect_end.y), size)
	gizmos[7].rect = Rect2(Vector2(rect_pos.x - size.x, (rect_end.y + rect_pos.y - size.y) / 2), size)


func move_borders_start() -> void:
	undo_data = _get_undo_data(false)


func move_borders(move : Vector2) -> void:
	marching_ants_outline.offset += move
	self.big_bounding_rectangle.position += move
	update()


func move_borders_end(new_pos : Vector2, old_pos : Vector2) -> void:
	marching_ants_outline.offset = Vector2.ZERO
	var diff := new_pos - old_pos
	var selected_bitmap_copy = Global.current_project.selection_bitmap.duplicate()
	Global.current_project.move_bitmap_values(selected_bitmap_copy, diff)

	Global.current_project.selection_bitmap = selected_bitmap_copy
	commit_undo("Rectangle Select", undo_data)
	update()


func select_rect(rect : Rect2, select := true) -> void:
	var project : Project = Global.current_project
	var selection_bitmap_copy : BitMap = project.selection_bitmap.duplicate()
	var offset_position := Vector2.ZERO
	if big_bounding_rectangle.position.x < 0:
		rect.position.x -= big_bounding_rectangle.position.x
		offset_position.x = big_bounding_rectangle.position.x
	if big_bounding_rectangle.position.y < 0:
		rect.position.y -= big_bounding_rectangle.position.y
		offset_position.y = big_bounding_rectangle.position.y

	if offset_position != Vector2.ZERO:
		big_bounding_rectangle.position -= offset_position
		project.move_bitmap_values(selection_bitmap_copy, -offset_position)

	selection_bitmap_copy.set_bit_rect(rect, select)
	big_bounding_rectangle = project.get_selection_rectangle(selection_bitmap_copy)

	if offset_position != Vector2.ZERO:
		big_bounding_rectangle.position += offset_position
		project.move_bitmap_values(selection_bitmap_copy, offset_position)

	project.selection_bitmap = selection_bitmap_copy
	self.big_bounding_rectangle = big_bounding_rectangle # call getter method


func move_content_start() -> void:
	if !is_moving_content:
		is_moving_content = true
		undo_data = _get_undo_data(true)
		get_preview_image()
		update()


func move_content(move : Vector2) -> void:
	move_borders(move)


func move_content_confirm() -> void:
	if !is_moving_content:
		return
	var project : Project = Global.current_project
	var cel_image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	cel_image.blit_rect_mask(preview_image, preview_image, Rect2(Vector2.ZERO, project.size), big_bounding_rectangle.position)
	var selected_bitmap_copy = Global.current_project.selection_bitmap.duplicate()
	Global.current_project.move_bitmap_values(selected_bitmap_copy, marching_ants_outline.offset)
	Global.current_project.selection_bitmap = selected_bitmap_copy

	preview_image = Image.new()
	marching_ants_outline.offset = Vector2.ZERO
	is_moving_content = false
	commit_undo("Move Selection", undo_data)
	update()


func move_content_cancel() -> void:
	if preview_image.is_empty():
		return
	self.big_bounding_rectangle.position -= marching_ants_outline.offset
	marching_ants_outline.offset = Vector2.ZERO

	is_moving_content = false
	var project : Project = Global.current_project
	var cel_image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	cel_image.blit_rect_mask(preview_image, preview_image, Rect2(Vector2.ZERO, project.size), big_bounding_rectangle.position)
	Global.canvas.update_texture(project.current_layer)
	preview_image = Image.new()
	update()


func commit_undo(action : String, _undo_data : Dictionary) -> void:
	var redo_data = _get_undo_data("image_data" in _undo_data)
	var project := Global.current_project

	project.undos += 1
	project.undo_redo.create_action(action)
	project.undo_redo.add_do_property(project, "selection_bitmap", redo_data["selection_bitmap"])
	project.undo_redo.add_do_property(self, "big_bounding_rectangle", redo_data["big_bounding_rectangle"])
	project.undo_redo.add_do_property(marching_ants_outline, "offset", redo_data["outline_offset"])

	project.undo_redo.add_undo_property(project, "selection_bitmap", _undo_data["selection_bitmap"])
	project.undo_redo.add_undo_property(self, "big_bounding_rectangle", _undo_data["big_bounding_rectangle"])
	project.undo_redo.add_undo_property(marching_ants_outline, "offset", _undo_data["outline_offset"])


	if "image_data" in _undo_data:
		var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
		project.undo_redo.add_do_property(image, "data", redo_data["image_data"])
		project.undo_redo.add_undo_property(image, "data", _undo_data["image_data"])
	project.undo_redo.add_do_method(Global, "redo", project.current_frame, project.current_layer)
	project.undo_redo.add_do_method(project, "selection_bitmap_changed")
	project.undo_redo.add_undo_method(Global, "undo", project.current_frame, project.current_layer)
	project.undo_redo.add_undo_method(project, "selection_bitmap_changed")
	project.undo_redo.commit_action()

	undo_data.clear()


func _get_undo_data(undo_image : bool) -> Dictionary:
	var data := {}
	var project := Global.current_project
	data["selection_bitmap"] = project.selection_bitmap
	data["big_bounding_rectangle"] = big_bounding_rectangle
	data["outline_offset"] = marching_ants_outline.offset

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
	if !project.has_selection:
		return
	var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	var to_copy := Image.new()
	to_copy = image.get_rect(big_bounding_rectangle)
	to_copy.lock()
	# Only remove unincluded pixels if the selection is not a single rectangle
	for x in to_copy.get_size().x:
		for y in to_copy.get_size().y:
			var pos := Vector2(x, y)
			if not project.selection_bitmap.get_bit(pos + big_bounding_rectangle.position):
				to_copy.set_pixelv(pos, Color(0))
	to_copy.unlock()
	clipboard.image = to_copy
	clipboard.selection_bitmap = project.selection_bitmap.duplicate()
	clipboard.big_bounding_rectangle = big_bounding_rectangle


func paste() -> void:
	if !clipboard.image:
		return
	var _undo_data = _get_undo_data(true)
	var project := Global.current_project
	var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	clear_selection()
	project.selection_bitmap = clipboard.selection_bitmap.duplicate()
	self.big_bounding_rectangle = clipboard.big_bounding_rectangle
	image.blend_rect(clipboard.image, Rect2(Vector2.ZERO, project.size), big_bounding_rectangle.position)
	commit_undo("Draw", _undo_data)


func delete() -> void:
	var project := Global.current_project
	if !project.has_selection:
		return
	var _undo_data = _get_undo_data(true)
	var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	for x in big_bounding_rectangle.size.x:
		for y in big_bounding_rectangle.size.y:
			var pos := Vector2(x, y) + big_bounding_rectangle.position
			if project.can_pixel_get_drawn(pos):
				image.set_pixelv(pos, Color(0))
	commit_undo("Draw", _undo_data)


func select_all() -> void:
	var project := Global.current_project
	var _undo_data = _get_undo_data(false)
	clear_selection()
	var full_rect = Rect2(Vector2.ZERO, project.size)
	select_rect(full_rect)
	commit_undo("Rectangle Select", _undo_data)


func invert() -> void:
	var project := Global.current_project
	var _undo_data = _get_undo_data(false)
	var selection_bitmap_copy : BitMap = project.selection_bitmap.duplicate()
	project.invert_bitmap(selection_bitmap_copy)
	project.selection_bitmap = selection_bitmap_copy
	self.big_bounding_rectangle = project.get_selection_rectangle(selection_bitmap_copy)
	commit_undo("Rectangle Select", _undo_data)


func clear_selection(use_undo := false) -> void:
	var project := Global.current_project
	if !project.has_selection:
		return
	move_content_confirm()
	var full_rect = Rect2(Vector2.ZERO, project.selection_bitmap.get_size())
	var _undo_data = _get_undo_data(false)
	select_rect(full_rect, false)

	self.big_bounding_rectangle = Rect2()
	marching_ants_outline.offset = Vector2.ZERO
	update()
	if use_undo:
		commit_undo("Clear Selection", _undo_data)


func _draw() -> void:
	var _position := position
	var _scale := scale
	if Global.mirror_view:
		_position.x = _position.x + Global.current_project.size.x
		_scale.x = -1
	draw_set_transform(_position, rotation, _scale)
	draw_rect(drawn_rect, Color.black, false)
	if big_bounding_rectangle.size > Vector2.ZERO:
		for gizmo in gizmos: # Draw gizmos
			draw_rect(gizmo.rect, Color.black)
			var filled_rect : Rect2 = gizmo.rect
			var filled_size := Vector2(0.2, 0.2)
			filled_rect.position += filled_size
			filled_rect.size -= filled_size * 2
			draw_rect(filled_rect, Color.white) # Filled white square

	if is_moving_content and !preview_image.is_empty():
		draw_texture(preview_image_texture, big_bounding_rectangle.position, Color(1, 1, 1, 0.5))
	draw_set_transform(position, rotation, scale)


func get_preview_image() -> void:
	var project : Project = Global.current_project
	var cel_image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	if preview_image.is_empty():
#		preview_image.copy_from(cel_image)
		preview_image = cel_image.get_rect(big_bounding_rectangle)
		preview_image.lock()
		for x in range(0, big_bounding_rectangle.size.x):
			for y in range(0, big_bounding_rectangle.size.y):
				var pos := Vector2(x, y)
				if not project.selection_bitmap.get_bit(pos + big_bounding_rectangle.position):
					preview_image.set_pixelv(pos, Color(0, 0, 0, 0))
		preview_image.unlock()
		preview_image_texture = ImageTexture.new()
		preview_image_texture.create_from_image(preview_image, 0)

	var clear_image := Image.new()
	clear_image.create(preview_image.get_width(), preview_image.get_height(), false, Image.FORMAT_RGBA8)
	cel_image.blit_rect_mask(clear_image, preview_image, Rect2(Vector2.ZERO, project.size), big_bounding_rectangle.position)
	Global.canvas.update_texture(project.current_layer)


func get_big_bounding_rectangle() -> Rect2:
	# Returns a rectangle that contains the entire selection, with multiple polygons
	var project : Project = Global.current_project
	var rect := Rect2()
	var image : Image = project.bitmap_to_image(project.selection_bitmap)
	rect = image.get_used_rect()
	return rect
