extends Node2D


class Clipboard:
	var image := Image.new()
	var selection_bitmap := BitMap.new()
	var big_bounding_rectangle := Rect2()
	var selection_offset := Vector2.ZERO


class Gizmo:
	enum Type {SCALE, ROTATE}

	var rect : Rect2
	var direction := Vector2.ZERO
	var type : int

	func _init(_type : int = Type.SCALE, _direction := Vector2.ZERO) -> void:
		type = _type
		direction = _direction


	func get_cursor() -> int:
		var cursor := Input.CURSOR_MOVE
		if direction == Vector2.ZERO:
			return Input.CURSOR_POINTING_HAND
		elif direction == Vector2(-1, -1) or direction == Vector2(1, 1): # Top left or bottom right
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
var temp_rect := Rect2()
var original_big_bounding_rectangle := Rect2()
var original_preview_image := Image.new()
var original_bitmap := BitMap.new()
var original_offset := Vector2.ZERO
var preview_image := Image.new()
var preview_image_texture := ImageTexture.new()
var undo_data : Dictionary
var drawn_rect := Rect2(0, 0, 0, 0)
var gizmos := [] # Array of Gizmos
var dragged_gizmo : Gizmo = null
var prev_angle := 0
var mouse_pos_on_gizmo_drag := Vector2.ZERO

onready var marching_ants_outline : Sprite = $MarchingAntsOutline


func _ready() -> void:
	gizmos.append(Gizmo.new(Gizmo.Type.SCALE, Vector2(-1, -1))) # Top left
	gizmos.append(Gizmo.new(Gizmo.Type.SCALE, Vector2(0, -1))) # Center top
	gizmos.append(Gizmo.new(Gizmo.Type.SCALE, Vector2(1, -1))) # Top right
	gizmos.append(Gizmo.new(Gizmo.Type.SCALE, Vector2(1, 0))) # Center right
	gizmos.append(Gizmo.new(Gizmo.Type.SCALE, Vector2(1, 1))) # Bottom right
	gizmos.append(Gizmo.new(Gizmo.Type.SCALE, Vector2(0, 1))) # Center bottom
	gizmos.append(Gizmo.new(Gizmo.Type.SCALE, Vector2(-1, 1))) # Bottom left
	gizmos.append(Gizmo.new(Gizmo.Type.SCALE, Vector2(-1, 0))) # Center left

	gizmos.append(Gizmo.new(Gizmo.Type.ROTATE)) # Rotation gizmo (temp)


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
			if event.pressed:
				if gizmo:
					Global.has_focus = false
					mouse_pos_on_gizmo_drag = Global.canvas.current_pixel
					dragged_gizmo = gizmo
					temp_rect = big_bounding_rectangle
					move_content_start()
					marching_ants_outline.offset = Vector2.ZERO
					if gizmo.type == Gizmo.Type.ROTATE:
						var img_size := max(original_preview_image.get_width(), original_preview_image.get_height())
						original_preview_image.crop(img_size, img_size)

			elif dragged_gizmo:
				Global.has_focus = true
				dragged_gizmo = null

		if dragged_gizmo:
			if dragged_gizmo.type == Gizmo.Type.SCALE:
				gizmo_resize()
			else:
				gizmo_rotate()


func _big_bounding_rectangle_changed(value : Rect2) -> void:
	big_bounding_rectangle = value
	update_gizmos()


func update_gizmos() -> void:
	var rect_pos : Vector2 = big_bounding_rectangle.position
	var rect_end : Vector2 = big_bounding_rectangle.end
	var size := Vector2.ONE * Global.camera.zoom * 10
	# Clockwise, starting from top-left corner
	gizmos[0].rect = Rect2(rect_pos - size, size)
	gizmos[1].rect = Rect2(Vector2((rect_end.x + rect_pos.x - size.x) / 2, rect_pos.y - size.y), size)
	gizmos[2].rect = Rect2(Vector2(rect_end.x, rect_pos.y - size.y), size)
	gizmos[3].rect = Rect2(Vector2(rect_end.x, (rect_end.y + rect_pos.y - size.y) / 2), size)
	gizmos[4].rect = Rect2(rect_end, size)
	gizmos[5].rect = Rect2(Vector2((rect_end.x + rect_pos.x - size.x) / 2, rect_end.y), size)
	gizmos[6].rect = Rect2(Vector2(rect_pos.x - size.x, rect_end.y), size)
	gizmos[7].rect = Rect2(Vector2(rect_pos.x - size.x, (rect_end.y + rect_pos.y - size.y) / 2), size)

	# Rotation gizmo (temp)
	gizmos[8].rect = Rect2(Vector2((rect_end.x + rect_pos.x - size.x) / 2, rect_pos.y - size.y - (size.y * 2)), size)
	update()


func gizmo_resize() -> void:
	var diff : Vector2 = (Global.canvas.current_pixel - mouse_pos_on_gizmo_drag) * dragged_gizmo.direction
	var dir := dragged_gizmo.direction
	if diff != Vector2.ZERO:
		mouse_pos_on_gizmo_drag = Global.canvas.current_pixel
	var left := 0.0 if dir.x >= 0 else diff.x
	var top := 0.0 if dir.y >= 0 else diff.y
	var right := diff.x if dir.x >= 0 else 0.0
	var bottom := diff.y if dir.y >= 0 else 0.0
	temp_rect = temp_rect.grow_individual(left, top, right, bottom)
	big_bounding_rectangle = temp_rect.abs()
	big_bounding_rectangle.position = big_bounding_rectangle.position.ceil()
	self.big_bounding_rectangle.size = big_bounding_rectangle.size.ceil()
	var size = big_bounding_rectangle.size.abs()
	preview_image.copy_from(original_preview_image)
	preview_image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	if temp_rect.size.x < 0:
		preview_image.flip_x()
	if temp_rect.size.y < 0:
		preview_image.flip_y()
	preview_image_texture.create_from_image(preview_image, 0)
	Global.current_project.selection_bitmap = Global.current_project.resize_bitmap_values(original_bitmap, size, temp_rect.size.x < 0, temp_rect.size.y < 0)
	Global.current_project.selection_bitmap_changed()
	update()


func gizmo_rotate() -> void:
	var angle := Global.canvas.current_pixel.angle_to_point(mouse_pos_on_gizmo_drag)
	angle = deg2rad(floor(rad2deg(angle)))
	if angle == prev_angle:
		return
	prev_angle = angle
#	print(rad2deg(angle))
#	var img_size := max(original_preview_image.get_width(), original_preview_image.get_height())
# warning-ignore:integer_division
# warning-ignore:integer_division
#	var pivot = Vector2(original_preview_image.get_width() / 2, original_preview_image.get_height() / 2)
	var pivot = Vector2(big_bounding_rectangle.size.x / 2, big_bounding_rectangle.size.y / 2)
	preview_image.copy_from(original_preview_image)
	if original_big_bounding_rectangle.position != big_bounding_rectangle.position:
		preview_image.fill(Color(0, 0, 0, 0))
		var pos_diff := (original_big_bounding_rectangle.position - big_bounding_rectangle.position).abs()
#		pos_diff.y = 0
		preview_image.blit_rect(original_preview_image, Rect2(Vector2.ZERO, preview_image.get_size()), pos_diff)
	DrawingAlgos.nn_rotate(preview_image, angle, pivot)
	preview_image_texture.create_from_image(preview_image, 0)

	var bitmap_image = Global.current_project.bitmap_to_image(original_bitmap)
	var bitmap_pivot = original_big_bounding_rectangle.position + ((original_big_bounding_rectangle.end - original_big_bounding_rectangle.position) / 2)
	DrawingAlgos.nn_rotate(bitmap_image, angle, bitmap_pivot)
	Global.current_project.selection_bitmap.create_from_image_alpha(bitmap_image)
	Global.current_project.selection_bitmap_changed()
	self.big_bounding_rectangle = bitmap_image.get_used_rect()
#	print(big_bounding_rectangle)
	update()


func move_borders_start() -> void:
	undo_data = _get_undo_data(false)


func move_borders(move : Vector2) -> void:
	marching_ants_outline.offset += move
	self.big_bounding_rectangle.position += move
	update()


func move_borders_end() -> void:
	marching_ants_outline.offset = Vector2.ZERO
	var selected_bitmap_copy = Global.current_project.selection_bitmap.duplicate()
	Global.current_project.move_bitmap_values(selected_bitmap_copy)

	Global.current_project.selection_bitmap = selected_bitmap_copy
	commit_undo("Rectangle Select", undo_data)
	update()


func select_rect(rect : Rect2, select := true) -> void:
	var project : Project = Global.current_project
	var selection_bitmap_copy : BitMap = project.selection_bitmap.duplicate()
	var offset_position := Vector2.ZERO # Used only if the selection is outside of the canvas boundaries, on the left and/or above (negative coords)
	if big_bounding_rectangle.position.x < 0:
		rect.position.x -= big_bounding_rectangle.position.x
		offset_position.x = big_bounding_rectangle.position.x
	if big_bounding_rectangle.position.y < 0:
		rect.position.y -= big_bounding_rectangle.position.y
		offset_position.y = big_bounding_rectangle.position.y

	if offset_position != Vector2.ZERO:
		big_bounding_rectangle.position -= offset_position
		project.move_bitmap_values(selection_bitmap_copy)

	selection_bitmap_copy.set_bit_rect(rect, select)
	big_bounding_rectangle = project.get_selection_rectangle(selection_bitmap_copy)

	if offset_position != Vector2.ZERO:
		big_bounding_rectangle.position += offset_position
		project.move_bitmap_values(selection_bitmap_copy)

	project.selection_bitmap = selection_bitmap_copy
	self.big_bounding_rectangle = big_bounding_rectangle # call getter method


func move_content_start() -> void:
	if !is_moving_content:
		is_moving_content = true
		undo_data = _get_undo_data(true)
		get_preview_image()
		original_bitmap = Global.current_project.selection_bitmap.duplicate()
		original_big_bounding_rectangle = big_bounding_rectangle
		original_offset = marching_ants_outline.offset
		update()


func move_content(move : Vector2) -> void:
	move_borders(move)


func move_content_confirm() -> void:
	if !is_moving_content:
		return
	var project : Project = Global.current_project
	var cel_image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	cel_image.blit_rect_mask(preview_image, preview_image, Rect2(Vector2.ZERO, Global.current_project.selection_bitmap.get_size()), big_bounding_rectangle.position)
	var selected_bitmap_copy = Global.current_project.selection_bitmap.duplicate()
	Global.current_project.move_bitmap_values(selected_bitmap_copy)
	Global.current_project.selection_bitmap = selected_bitmap_copy

	original_preview_image = Image.new()
	preview_image = Image.new()
	original_bitmap = BitMap.new()
#	marching_ants_outline.offset = Vector2.ZERO
	is_moving_content = false
	commit_undo("Move Selection", undo_data)
	update()


func move_content_cancel() -> void:
	if preview_image.is_empty():
		return
	marching_ants_outline.offset = original_offset

	is_moving_content = false
	self.big_bounding_rectangle = original_big_bounding_rectangle
	Global.current_project.selection_bitmap = original_bitmap
	Global.current_project.selection_bitmap_changed()
	preview_image = original_preview_image
	var project : Project = Global.current_project
	var cel_image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	cel_image.blit_rect_mask(preview_image, preview_image, Rect2(Vector2.ZERO, Global.current_project.selection_bitmap.get_size()), big_bounding_rectangle.position)
	Global.canvas.update_texture(project.current_layer)
	original_preview_image = Image.new()
	preview_image = Image.new()
	original_bitmap = BitMap.new()
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
			var offset_pos = big_bounding_rectangle.position
			if offset_pos.x < 0:
				offset_pos.x = 0
			if offset_pos.y < 0:
				offset_pos.y = 0
			if not project.selection_bitmap.get_bit(pos + offset_pos):
				to_copy.set_pixelv(pos, Color(0))
	to_copy.unlock()
	clipboard.image = to_copy
	clipboard.selection_bitmap = project.selection_bitmap.duplicate()
	clipboard.big_bounding_rectangle = big_bounding_rectangle
	clipboard.selection_offset = marching_ants_outline.offset


func paste() -> void:
	if !clipboard.image:
		return
	var _undo_data = _get_undo_data(true)
	var project := Global.current_project
	var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	clear_selection()
	project.selection_bitmap = clipboard.selection_bitmap.duplicate()
	self.big_bounding_rectangle = clipboard.big_bounding_rectangle
	marching_ants_outline.offset = clipboard.selection_offset
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
	move_content_confirm()
	var project := Global.current_project
	var _undo_data = _get_undo_data(false)
	var selection_bitmap_copy : BitMap = project.selection_bitmap.duplicate()
	selection_bitmap_copy = project.resize_bitmap(selection_bitmap_copy, project.size)
	project.invert_bitmap(selection_bitmap_copy)
	project.selection_bitmap = selection_bitmap_copy
	Global.current_project.selection_bitmap_changed()
	self.big_bounding_rectangle = project.get_selection_rectangle(selection_bitmap_copy)
	marching_ants_outline.offset = Vector2.ZERO
	commit_undo("Rectangle Select", _undo_data)


func clear_selection(use_undo := false) -> void:
	var project := Global.current_project
	if !project.has_selection:
		return
	move_content_confirm()
	var _undo_data = _get_undo_data(false)
	var selection_bitmap_copy : BitMap = project.selection_bitmap.duplicate()
	selection_bitmap_copy = project.resize_bitmap(selection_bitmap_copy, project.size)
	var full_rect = Rect2(Vector2.ZERO, selection_bitmap_copy.get_size())
	selection_bitmap_copy.set_bit_rect(full_rect, false)
	project.selection_bitmap = selection_bitmap_copy

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
	if big_bounding_rectangle.size != Vector2.ZERO:
		for gizmo in gizmos: # Draw gizmos
			draw_rect(gizmo.rect, Color.black)
			var filled_rect : Rect2 = gizmo.rect
			var filled_size : Vector2 = gizmo.rect.size * Vector2(0.2, 0.2)
			filled_rect.position += filled_size
			filled_rect.size -= filled_size * 2
			draw_rect(filled_rect, Color.white) # Filled white square

	if is_moving_content and !preview_image.is_empty():
		draw_texture(preview_image_texture, big_bounding_rectangle.position, Color(1, 1, 1, 0.5))
	draw_set_transform(position, rotation, scale)


func get_preview_image() -> void:
	var project : Project = Global.current_project
	var cel_image : Image = project.frames[project.current_frame].cels[project.current_layer].image
	if original_preview_image.is_empty():
#		original_preview_image.copy_from(cel_image)
		original_preview_image = cel_image.get_rect(big_bounding_rectangle)
		original_preview_image.lock()
		# For non-rectangular selections
		for x in range(0, big_bounding_rectangle.size.x):
			for y in range(0, big_bounding_rectangle.size.y):
				var pos := Vector2(x, y)
				if !project.can_pixel_get_drawn(pos + big_bounding_rectangle.position):
					original_preview_image.set_pixelv(pos, Color(0, 0, 0, 0))

		original_preview_image.unlock()
		preview_image.copy_from(original_preview_image)
		preview_image_texture.create_from_image(preview_image, 0)

	var clear_image := Image.new()
	clear_image.create(original_preview_image.get_width(), original_preview_image.get_height(), false, Image.FORMAT_RGBA8)
	cel_image.blit_rect_mask(clear_image, original_preview_image, Rect2(Vector2.ZERO, Global.current_project.selection_bitmap.get_size()), big_bounding_rectangle.position)
	Global.canvas.update_texture(project.current_layer)


func get_big_bounding_rectangle() -> Rect2:
	# Returns a rectangle that contains the entire selection, with multiple polygons
	var project : Project = Global.current_project
	var rect := Rect2()
	var image : Image = project.bitmap_to_image(project.selection_bitmap)
	rect = image.get_used_rect()
	return rect
