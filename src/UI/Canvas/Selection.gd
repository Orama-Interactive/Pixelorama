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


enum SelectionOperation {ADD, SUBTRACT, INTERSECT}

const KEY_MOVE_ACTION_NAMES := ["ui_up", "ui_down", "ui_left", "ui_right"]

var clipboard := Clipboard.new()
var is_moving_content := false
var arrow_key_move := false
var is_pasting := false
var big_bounding_rectangle := Rect2() setget _big_bounding_rectangle_changed

var temp_rect := Rect2()
var temp_bitmap := BitMap.new()
var rect_aspect_ratio := 0.0
var temp_rect_size := Vector2.ZERO

var original_big_bounding_rectangle := Rect2()
var original_preview_image := Image.new()
var original_bitmap := BitMap.new()
var original_offset := Vector2.ZERO

var preview_image := Image.new()
var preview_image_texture := ImageTexture.new()
var undo_data : Dictionary
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

#	gizmos.append(Gizmo.new(Gizmo.Type.ROTATE)) # Rotation gizmo (temp)


func _input(event : InputEvent) -> void:
	if event is InputEventKey:
		if is_moving_content:
			if Input.is_action_just_pressed("enter"):
				transform_content_confirm()
			elif Input.is_action_just_pressed("escape"):
				transform_content_cancel()

		move_with_arrow_keys(event)

	elif event is InputEventMouse:
		var gizmo : Gizmo
		if big_bounding_rectangle.size != Vector2.ZERO:
			for g in gizmos:
				if g.rect.has_point(Global.canvas.current_pixel):
					gizmo = Gizmo.new(g.type, g.direction)
					break
		if !dragged_gizmo:
			if gizmo:
				Global.main_viewport.mouse_default_cursor_shape = gizmo.get_cursor()
			else:
				Global.main_viewport.mouse_default_cursor_shape = Input.CURSOR_CROSS

		if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
			if event.pressed:
				if gizmo:
					Global.has_focus = false
					mouse_pos_on_gizmo_drag = Global.canvas.current_pixel
					dragged_gizmo = gizmo
					if Input.is_action_pressed("alt"):
						transform_content_confirm()
					if !is_moving_content:
						if Input.is_action_pressed("alt"):
							undo_data = _get_undo_data(false)
							temp_rect = big_bounding_rectangle
							temp_bitmap = Global.current_project.selection_bitmap
						else:
							transform_content_start()
						Global.current_project.selection_offset = Vector2.ZERO
						if gizmo.type == Gizmo.Type.ROTATE:
							var img_size := max(original_preview_image.get_width(), original_preview_image.get_height())
							original_preview_image.crop(img_size, img_size)
					else:
						var prev_temp_rect := temp_rect
						dragged_gizmo.direction.x *= sign(temp_rect.size.x)
						dragged_gizmo.direction.y *= sign(temp_rect.size.y)
						temp_rect = big_bounding_rectangle
						# If prev_temp_rect, which used to be the previous temp_rect, has negative size,
						# switch the position and end point in temp_rect
						if prev_temp_rect.size.x < 0:
							var pos = temp_rect.position.x
							temp_rect.position.x = temp_rect.end.x
							temp_rect.end.x = pos
						if prev_temp_rect.size.y < 0:
							var pos = temp_rect.position.y
							temp_rect.position.y = temp_rect.end.y
							temp_rect.end.y = pos
					rect_aspect_ratio = abs(temp_rect.size.y / temp_rect.size.x)
					temp_rect_size = temp_rect.size

			elif dragged_gizmo:
				Global.has_focus = true
				dragged_gizmo = null
				if !is_moving_content:
					commit_undo("Rectangle Select", undo_data)

		if dragged_gizmo:
			if dragged_gizmo.type == Gizmo.Type.SCALE:
				gizmo_resize()
			else:
				gizmo_rotate()


func move_with_arrow_keys(event : InputEvent) -> void:
	var selection_tool_selected := false
	for slot in Tools._slots.values():
		if slot.tool_node is SelectionTool:
			selection_tool_selected = true
			break
	if !selection_tool_selected:
		return

	if Global.current_project.has_selection:
		if is_action_direction_pressed(event) and !arrow_key_move:
			arrow_key_move = true
			if Input.is_key_pressed(KEY_ALT):
				transform_content_confirm()
				move_borders_start()
			else:
				transform_content_start()
		if is_action_direction_released(event) and arrow_key_move:
			arrow_key_move = false
			move_borders_end()

		if is_action_direction(event) and arrow_key_move:
			var step := Vector2.ONE
			if Input.is_key_pressed(KEY_CONTROL):
				step = Vector2(Global.grid_width, Global.grid_height)
			move_content(Vector2(int(event.is_action("ui_right")) - int(event.is_action("ui_left")), int(event.is_action("ui_down")) - int(event.is_action("ui_up"))) * step)


# Check if an event is a ui_up/down/left/right event-press
func is_action_direction_pressed(event : InputEvent) -> bool:
	for action in KEY_MOVE_ACTION_NAMES:
		if event.is_action_pressed(action):
			return true
	return false


# Check if an event is a ui_up/down/left/right event release
func is_action_direction(event: InputEvent) -> bool:
	for action in KEY_MOVE_ACTION_NAMES:
		if event.is_action(action):
			return true
	return false


# Check if an event is a ui_up/down/left/right event release
func is_action_direction_released(event: InputEvent) -> bool:
	for action in KEY_MOVE_ACTION_NAMES:
		if event.is_action_released(action):
			return true
	return false


func _draw() -> void:
	var _position := position
	var _scale := scale
	if Global.mirror_view:
		_position.x = _position.x + Global.current_project.size.x
		_scale.x = -1
	draw_set_transform(_position, rotation, _scale)
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


func _big_bounding_rectangle_changed(value : Rect2) -> void:
	big_bounding_rectangle = value
	for slot in Tools._slots.values():
		if slot.tool_node is SelectionTool:
			slot.tool_node.set_spinbox_values()
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
#	gizmos[8].rect = Rect2(Vector2((rect_end.x + rect_pos.x - size.x) / 2, rect_pos.y - size.y - (size.y * 2)), size)
	update()


func update_on_zoom(zoom : float) -> void:
	var size := max(Global.current_project.selection_bitmap.get_size().x, Global.current_project.selection_bitmap.get_size().y)
	marching_ants_outline.material.set_shader_param("width", zoom)
	marching_ants_outline.material.set_shader_param("frequency", (1.0 / zoom) * 10 * size / 64)
	for gizmo in gizmos:
		if gizmo.rect.size == Vector2.ZERO:
			return
	update_gizmos()


func gizmo_resize() -> void:
	var dir := dragged_gizmo.direction
	if dir.x > 0:
		temp_rect.size.x = Global.canvas.current_pixel.x - temp_rect.position.x
	elif dir.x < 0:
		var end_x = temp_rect.end.x
		temp_rect.position.x = Global.canvas.current_pixel.x
		temp_rect.end.x = end_x
	else:
		temp_rect.size.x = temp_rect_size.x

	if dir.y > 0:
		temp_rect.size.y = Global.canvas.current_pixel.y - temp_rect.position.y
	elif dir.y < 0:
		var end_y = temp_rect.end.y
		temp_rect.position.y = Global.canvas.current_pixel.y
		temp_rect.end.y = end_y
	else:
		temp_rect.size.y = temp_rect_size.y

	if Input.is_action_pressed("shift"): # Maintain aspect ratio
		var end_y = temp_rect.end.y
		if dir == Vector2(1, -1) or dir.x == 0: # Top right corner, center top and center bottom
			var size := temp_rect.size.y
			if sign(size) != sign(temp_rect.size.x): # Needed in order for resizing to work properly in negative sizes
				if temp_rect.size.x > 0:
					size = abs(size)
				else:
					size = -abs(size)
			temp_rect.size.x = size / rect_aspect_ratio

		else: # The rest of the corners
			var size := temp_rect.size.x
			if sign(size) != sign(temp_rect.size.y): # Needed in order for resizing to work properly in negative sizes
				if temp_rect.size.y > 0:
					size = abs(size)
				else:
					size = -abs(size)
			temp_rect.size.y = size * rect_aspect_ratio

		if dir == Vector2(-1, -1): # Top left corner
			# Inspired by the solution answered in https://stackoverflow.com/questions/50230967/drag-resizing-rectangle-with-fixed-aspect-ratio-northwest-corner
			temp_rect.position.y = end_y - temp_rect.size.y

	big_bounding_rectangle = temp_rect.abs()
	big_bounding_rectangle.position = big_bounding_rectangle.position.ceil()
	big_bounding_rectangle.size = big_bounding_rectangle.size.floor()
	if big_bounding_rectangle.size.x == 0:
		big_bounding_rectangle.size.x = 1
	if big_bounding_rectangle.size.y == 0:
		big_bounding_rectangle.size.y = 1

	self.big_bounding_rectangle = big_bounding_rectangle # Call the setter method

	var size = big_bounding_rectangle.size.abs()
	if is_moving_content:
		preview_image.copy_from(original_preview_image)
		preview_image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
		if temp_rect.size.x < 0:
			preview_image.flip_x()
		if temp_rect.size.y < 0:
			preview_image.flip_y()
		preview_image_texture.create_from_image(preview_image, 0)
	Global.current_project.selection_bitmap = Global.current_project.resize_bitmap_values(temp_bitmap, size, temp_rect.size.x < 0, temp_rect.size.y < 0)
	Global.current_project.selection_bitmap_changed()
	update()


func gizmo_rotate() -> void: # Does not work properly yet
	var angle := Global.canvas.current_pixel.angle_to_point(mouse_pos_on_gizmo_drag)
	angle = deg2rad(floor(rad2deg(angle)))
	if angle == prev_angle:
		return
	prev_angle = angle
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
	update()


func select_rect(rect : Rect2, operation : int = SelectionOperation.ADD) -> void:
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

	if operation == SelectionOperation.ADD:
		selection_bitmap_copy.set_bit_rect(rect, true)
	elif operation == SelectionOperation.SUBTRACT:
		selection_bitmap_copy.set_bit_rect(rect, false)
	elif operation == SelectionOperation.INTERSECT:
		var full_rect = Rect2(Vector2.ZERO, selection_bitmap_copy.get_size())
		selection_bitmap_copy.set_bit_rect(full_rect, false)
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var pos := Vector2(x, y)
				if !Rect2(Vector2.ZERO, selection_bitmap_copy.get_size()).has_point(pos):
					continue
				selection_bitmap_copy.set_bit(pos, project.selection_bitmap.get_bit(pos))
	big_bounding_rectangle = project.get_selection_rectangle(selection_bitmap_copy)

	if offset_position != Vector2.ZERO:
		big_bounding_rectangle.position += offset_position
		project.move_bitmap_values(selection_bitmap_copy)

	project.selection_bitmap = selection_bitmap_copy
	self.big_bounding_rectangle = big_bounding_rectangle # call getter method



func move_borders_start() -> void:
	undo_data = _get_undo_data(false)


func move_borders(move : Vector2) -> void:
	if move == Vector2.ZERO:
		return
	marching_ants_outline.offset += move
	self.big_bounding_rectangle.position += move
	update()


func move_borders_end() -> void:
	var selected_bitmap_copy := Global.current_project.selection_bitmap.duplicate()
	Global.current_project.move_bitmap_values(selected_bitmap_copy)

	Global.current_project.selection_bitmap = selected_bitmap_copy
	if !is_moving_content:
		commit_undo("Rectangle Select", undo_data)
	else:
		Global.current_project.selection_bitmap_changed()
	update()


func transform_content_start() -> void:
	if !is_moving_content:
		undo_data = _get_undo_data(true)
		temp_rect = big_bounding_rectangle
		temp_bitmap = Global.current_project.selection_bitmap
		get_preview_image()
		if original_preview_image.is_empty():
			undo_data = _get_undo_data(false)
			return
		is_moving_content = true
		original_bitmap = Global.current_project.selection_bitmap.duplicate()
		original_big_bounding_rectangle = big_bounding_rectangle
		original_offset = Global.current_project.selection_offset
		update()


func move_content(move : Vector2) -> void:
	move_borders(move)


func transform_content_confirm() -> void:
	if !is_moving_content:
		return
	var project : Project = Global.current_project
	if project.current_frame < project.frames.size() and project.current_layer < project.layers.size():
		var cel_image : Image = project.frames[project.current_frame].cels[project.current_layer].image
		cel_image.blit_rect_mask(preview_image, preview_image, Rect2(Vector2.ZERO, project.selection_bitmap.get_size()), big_bounding_rectangle.position)
		var selected_bitmap_copy = project.selection_bitmap.duplicate()
		project.move_bitmap_values(selected_bitmap_copy)
		project.selection_bitmap = selected_bitmap_copy
		commit_undo("Move Selection", undo_data)

	original_preview_image = Image.new()
	preview_image = Image.new()
	original_bitmap = BitMap.new()
	is_moving_content = false
	is_pasting = false
	update()


func transform_content_cancel() -> void:
	if preview_image.is_empty():
		return
	var project : Project = Global.current_project
	project.selection_offset = original_offset

	is_moving_content = false
	self.big_bounding_rectangle = original_big_bounding_rectangle
	project.selection_bitmap = original_bitmap
	project.selection_bitmap_changed()
	preview_image = original_preview_image
	if !is_pasting:
		var cel_image : Image = project.frames[project.current_frame].cels[project.current_layer].image
		cel_image.blit_rect_mask(preview_image, preview_image, Rect2(Vector2.ZERO, Global.current_project.selection_bitmap.get_size()), big_bounding_rectangle.position)
		Global.canvas.update_texture(project.current_layer)
	original_preview_image = Image.new()
	preview_image = Image.new()
	original_bitmap = BitMap.new()
	is_pasting = false
	update()


func commit_undo(action : String, _undo_data : Dictionary) -> void:
	if !_undo_data:
		print("No undo data found!")
		return
	var redo_data = _get_undo_data("image_data" in _undo_data)
	var project := Global.current_project

	project.undos += 1
	project.undo_redo.create_action(action)
	project.undo_redo.add_do_property(project, "selection_bitmap", redo_data["selection_bitmap"])
	project.undo_redo.add_do_property(self, "big_bounding_rectangle", redo_data["big_bounding_rectangle"])
	project.undo_redo.add_do_property(project, "selection_offset", redo_data["outline_offset"])

	project.undo_redo.add_undo_property(project, "selection_bitmap", _undo_data["selection_bitmap"])
	project.undo_redo.add_undo_property(self, "big_bounding_rectangle", _undo_data["big_bounding_rectangle"])
	project.undo_redo.add_undo_property(project, "selection_offset", _undo_data["outline_offset"])


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
	data["outline_offset"] = Global.current_project.selection_offset

	if undo_image:
		var image : Image = project.frames[project.current_frame].cels[project.current_layer].image
		image.unlock()
		data["image_data"] = image.data
		image.lock()

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
	if is_moving_content:
		to_copy.copy_from(preview_image)
		var selected_bitmap_copy := project.selection_bitmap.duplicate()
		project.move_bitmap_values(selected_bitmap_copy, false)
		clipboard.selection_bitmap = selected_bitmap_copy
	else:
		to_copy = image.get_rect(big_bounding_rectangle)
		to_copy.lock()
		# Remove unincluded pixels if the selection is not a single rectangle
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
		clipboard.selection_bitmap = project.selection_bitmap.duplicate()
	clipboard.image = to_copy
	clipboard.big_bounding_rectangle = big_bounding_rectangle
	clipboard.selection_offset = project.selection_offset

	var brush : Image = to_copy.get_rect(to_copy.get_used_rect())
	project.brushes.append(brush)
	Brushes.add_project_brush(brush)


func paste() -> void:
	if !clipboard.image:
		return
	clear_selection()
	undo_data = _get_undo_data(true)
	var project := Global.current_project

	original_bitmap = project.selection_bitmap.duplicate()
	original_big_bounding_rectangle = big_bounding_rectangle
	original_offset = project.selection_offset

	project.selection_bitmap = clipboard.selection_bitmap.duplicate()
	self.big_bounding_rectangle = clipboard.big_bounding_rectangle
	project.selection_offset = clipboard.selection_offset

	is_moving_content = true
	is_pasting = true
	original_preview_image = clipboard.image
	preview_image.copy_from(original_preview_image)
	preview_image_texture.create_from_image(preview_image, 0)

	project.selection_bitmap_changed()


func delete() -> void:
	var project := Global.current_project
	if !project.has_selection:
		return
	if is_moving_content:
		is_moving_content = false
		original_preview_image = Image.new()
		preview_image = Image.new()
		original_bitmap = BitMap.new()
		is_pasting = false
		update()
		commit_undo("Draw", undo_data)
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
	transform_content_confirm()
	var project := Global.current_project
	var _undo_data = _get_undo_data(false)
	var selection_bitmap_copy : BitMap = project.selection_bitmap.duplicate()
	selection_bitmap_copy = project.resize_bitmap(selection_bitmap_copy, project.size)
	project.invert_bitmap(selection_bitmap_copy)
	project.selection_bitmap = selection_bitmap_copy
	project.selection_bitmap_changed()
	self.big_bounding_rectangle = project.get_selection_rectangle(selection_bitmap_copy)
	project.selection_offset = Vector2.ZERO
	commit_undo("Rectangle Select", _undo_data)


func clear_selection(use_undo := false) -> void:
	var project := Global.current_project
	if !project.has_selection:
		return
	transform_content_confirm()
	var _undo_data = _get_undo_data(false)
	var selection_bitmap_copy : BitMap = project.selection_bitmap.duplicate()
	selection_bitmap_copy = project.resize_bitmap(selection_bitmap_copy, project.size)
	var full_rect = Rect2(Vector2.ZERO, selection_bitmap_copy.get_size())
	selection_bitmap_copy.set_bit_rect(full_rect, false)
	project.selection_bitmap = selection_bitmap_copy

	self.big_bounding_rectangle = Rect2()
	project.selection_offset = Vector2.ZERO
	update()
	if use_undo:
		commit_undo("Clear Selection", _undo_data)


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
		if original_preview_image.is_invisible():
			original_preview_image = Image.new()
			return
		preview_image.copy_from(original_preview_image)
		preview_image_texture.create_from_image(preview_image, 0)

	var clear_image := Image.new()
	clear_image.create(original_preview_image.get_width(), original_preview_image.get_height(), false, Image.FORMAT_RGBA8)
	cel_image.blit_rect_mask(clear_image, original_preview_image, Rect2(Vector2.ZERO, Global.current_project.selection_bitmap.get_size()), big_bounding_rectangle.position)
	Global.canvas.update_texture(project.current_layer)
