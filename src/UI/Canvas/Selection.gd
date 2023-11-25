extends Node2D

enum SelectionOperation { ADD, SUBTRACT, INTERSECT }
const KEY_MOVE_ACTION_NAMES: PackedStringArray = ["ui_up", "ui_down", "ui_left", "ui_right"]
const CLIPBOARD_FILE_PATH := "user://clipboard.txt"

# flags (additional properties of selection that can be toggled)
var flag_tilemode := false

var is_moving_content := false
var arrow_key_move := false
var is_pasting := false
var big_bounding_rectangle := Rect2i():
	set(value):
		big_bounding_rectangle = value
		for slot in Tools._slots.values():
			if slot.tool_node is SelectionTool:
				slot.tool_node.set_spinbox_values()
		_update_gizmos()
var image_current_pixel := Vector2.ZERO  ## The ACTUAL pixel coordinate of image

var temp_rect := Rect2()
var rect_aspect_ratio := 0.0
var temp_rect_size := Vector2.ZERO
var temp_rect_pivot := Vector2.ZERO

var original_big_bounding_rectangle := Rect2i()
var original_preview_image := Image.new()
var original_bitmap := SelectionMap.new()
var original_offset := Vector2.ZERO

var preview_image := Image.new()
var preview_image_texture := ImageTexture.new()
var undo_data: Dictionary
var gizmos: Array[Gizmo] = []
var dragged_gizmo: Gizmo = null
var prev_angle := 0
var mouse_pos_on_gizmo_drag := Vector2.ZERO
var resize_keep_ratio := false

@onready var canvas: Canvas = get_parent()
@onready var marching_ants_outline: Sprite2D = $MarchingAntsOutline


class Gizmo:
	enum Type { SCALE, ROTATE }

	var rect: Rect2
	var direction := Vector2i.ZERO
	var type: int

	func _init(_type: int = Type.SCALE, _direction := Vector2i.ZERO) -> void:
		type = _type
		direction = _direction

	func get_cursor() -> Control.CursorShape:
		var cursor := Control.CURSOR_MOVE
		if direction == Vector2i.ZERO:
			return Control.CURSOR_POINTING_HAND
		elif direction == Vector2i(-1, -1) or direction == Vector2i(1, 1):  # Top left or bottom right
			if Global.mirror_view:
				cursor = Control.CURSOR_BDIAGSIZE
			else:
				cursor = Control.CURSOR_FDIAGSIZE
		elif direction == Vector2i(1, -1) or direction == Vector2i(-1, 1):  # Top right or bottom left
			if Global.mirror_view:
				cursor = Control.CURSOR_FDIAGSIZE
			else:
				cursor = Control.CURSOR_BDIAGSIZE
		elif direction == Vector2i(0, -1) or direction == Vector2i(0, 1):  # Center top or center bottom
			cursor = Control.CURSOR_VSIZE
		elif direction == Vector2i(-1, 0) or direction == Vector2i(1, 0):  # Center left or center right
			cursor = Control.CURSOR_HSIZE
		return cursor


func _ready() -> void:
	Global.camera.zoom_changed.connect(_update_on_zoom)
	gizmos.append(Gizmo.new(Gizmo.Type.SCALE, Vector2i(-1, -1)))  # Top left
	gizmos.append(Gizmo.new(Gizmo.Type.SCALE, Vector2i(0, -1)))  # Center top
	gizmos.append(Gizmo.new(Gizmo.Type.SCALE, Vector2i(1, -1)))  # Top right
	gizmos.append(Gizmo.new(Gizmo.Type.SCALE, Vector2i(1, 0)))  # Center right
	gizmos.append(Gizmo.new(Gizmo.Type.SCALE, Vector2i(1, 1)))  # Bottom right
	gizmos.append(Gizmo.new(Gizmo.Type.SCALE, Vector2i(0, 1)))  # Center bottom
	gizmos.append(Gizmo.new(Gizmo.Type.SCALE, Vector2i(-1, 1)))  # Bottom left
	gizmos.append(Gizmo.new(Gizmo.Type.SCALE, Vector2i(-1, 0)))  # Center left


#	gizmos.append(Gizmo.new(Gizmo.Type.ROTATE)) # Rotation gizmo (temp)


func _input(event: InputEvent) -> void:
	image_current_pixel = canvas.current_pixel
	if Global.mirror_view:
		image_current_pixel.x = Global.current_project.size.x - image_current_pixel.x
	if is_moving_content:
		if Input.is_action_just_pressed("transformation_confirm"):
			transform_content_confirm()
		elif Input.is_action_just_pressed("transformation_cancel"):
			transform_content_cancel()

	var project := Global.current_project
	if not project.layers[project.current_layer].can_layer_get_drawn():
		return
	if event is InputEventKey:
		_move_with_arrow_keys(event)

	if not event is InputEventMouse:
		return
	var gizmo_hover: Gizmo
	if big_bounding_rectangle.size != Vector2i.ZERO:
		for g in gizmos:
			if g.rect.has_point(image_current_pixel):
				gizmo_hover = Gizmo.new(g.type, g.direction)
				break

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if gizmo_hover and not dragged_gizmo:  # Select a gizmo
				Global.can_draw = false
				mouse_pos_on_gizmo_drag = image_current_pixel
				dragged_gizmo = gizmo_hover
				if Input.is_action_pressed("transform_move_selection_only"):
					transform_content_confirm()
				if not is_moving_content:
					if Input.is_action_pressed("transform_move_selection_only"):
						undo_data = get_undo_data(false)
						temp_rect = big_bounding_rectangle
					else:
						transform_content_start()
					project.selection_offset = Vector2.ZERO
					if dragged_gizmo.type == Gizmo.Type.ROTATE:
						var img_size := maxi(
							original_preview_image.get_width(), original_preview_image.get_height()
						)
						original_preview_image.crop(img_size, img_size)
				else:
					var prev_temp_rect := temp_rect
					dragged_gizmo.direction.x *= signi(temp_rect.size.x)
					dragged_gizmo.direction.y *= signi(temp_rect.size.y)
					temp_rect = big_bounding_rectangle
					# If prev_temp_rect, which used to be the previous temp_rect, has negative size,
					# switch the position and end point in temp_rect
					if prev_temp_rect.size.x < 0:
						var pos := temp_rect.position.x
						temp_rect.position.x = temp_rect.end.x
						temp_rect.end.x = pos
					if prev_temp_rect.size.y < 0:
						var pos := temp_rect.position.y
						temp_rect.position.y = temp_rect.end.y
						temp_rect.end.y = pos
				rect_aspect_ratio = absf(temp_rect.size.y / temp_rect.size.x)
				temp_rect_size = temp_rect.size
				temp_rect_pivot = (temp_rect.position + ((temp_rect.end - temp_rect.position) / 2))

		elif dragged_gizmo:  # Mouse released, deselect gizmo
			Global.can_draw = true
			dragged_gizmo = null
			if not is_moving_content:
				commit_undo("Select", undo_data)

	if dragged_gizmo:
		if dragged_gizmo.type == Gizmo.Type.SCALE:
			_gizmo_resize()
		else:
			_gizmo_rotate()
	else:  # Set the appropriate cursor
		if gizmo_hover:
			Global.main_viewport.mouse_default_cursor_shape = gizmo_hover.get_cursor()
		else:
			var cursor := Control.CURSOR_ARROW
			if Global.cross_cursor:
				cursor = Control.CURSOR_CROSS
			var layer: BaseLayer = project.layers[project.current_layer]
			if not layer.can_layer_get_drawn():
				cursor = Control.CURSOR_FORBIDDEN

			if Global.main_viewport.mouse_default_cursor_shape != cursor:
				Global.main_viewport.mouse_default_cursor_shape = cursor


func _move_with_arrow_keys(event: InputEvent) -> void:
	var selection_tool_selected := false
	for slot in Tools._slots.values():
		if slot.tool_node is SelectionTool:
			selection_tool_selected = true
			break
	if !selection_tool_selected:
		return
	if not Global.current_project.has_selection:
		return
	if !Global.current_project.layers[Global.current_project.current_layer].can_layer_get_drawn():
		return
	if _is_action_direction_pressed(event) and !arrow_key_move:
		arrow_key_move = true
		if Input.is_key_pressed(KEY_ALT):
			transform_content_confirm()
			move_borders_start()
		else:
			transform_content_start()
	if _is_action_direction_released(event) and arrow_key_move:
		arrow_key_move = false
		move_borders_end()

	if _is_action_direction(event) and arrow_key_move:
		var step := Vector2.ONE
		if Input.is_key_pressed(KEY_CTRL):
			step = Global.grid_size
		var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var move := input.rotated(snappedf(Global.camera.rotation, PI / 2))
		# These checks are needed to fix a bug where the selection got stuck
		# to the canvas boundaries when they were 1px away from them
		if is_equal_approx(absf(move.x), 0.0):
			move.x = 0
		if is_equal_approx(absf(move.y), 0.0):
			move.y = 0
		move_content(move * step)


# Check if an event is a ui_up/down/left/right event-press
func _is_action_direction_pressed(event: InputEvent) -> bool:
	for action in KEY_MOVE_ACTION_NAMES:
		if event.is_action_pressed(action):
			return true
	return false


# Check if an event is a ui_up/down/left/right event release
func _is_action_direction(event: InputEvent) -> bool:
	for action in KEY_MOVE_ACTION_NAMES:
		if event.is_action(action):
			return true
	return false


# Check if an event is a ui_up/down/left/right event release
func _is_action_direction_released(event: InputEvent) -> bool:
	for action in KEY_MOVE_ACTION_NAMES:
		if event.is_action_released(action):
			return true
	return false


func _draw() -> void:
	if big_bounding_rectangle.size == Vector2i.ZERO:
		return
	var position_tmp := position
	var scale_tmp := scale
	if Global.mirror_view:
		position_tmp.x = position_tmp.x + Global.current_project.size.x
		scale_tmp.x = -1
	draw_set_transform(position_tmp, rotation, scale_tmp)
	for gizmo in gizmos:  # Draw gizmos
		draw_rect(gizmo.rect, Global.selection_border_color_2)
		var filled_rect: Rect2 = gizmo.rect
		var filled_size: Vector2 = gizmo.rect.size * Vector2(0.2, 0.2)
		filled_rect.position += filled_size
		filled_rect.size -= filled_size * 2
		draw_rect(filled_rect, Global.selection_border_color_1)  # Filled white square

	if is_moving_content and !preview_image.is_empty():
		draw_texture(preview_image_texture, big_bounding_rectangle.position, Color(1, 1, 1, 0.5))
	draw_set_transform(position, rotation, scale)


func _update_gizmos() -> void:
	var rect_pos: Vector2 = big_bounding_rectangle.position
	var rect_end: Vector2 = big_bounding_rectangle.end
	var size: Vector2 = Vector2.ONE / Global.camera.zoom * 10
	# Clockwise, starting from top-left corner
	gizmos[0].rect = Rect2(rect_pos - size, size)
	gizmos[1].rect = Rect2(
		Vector2((rect_end.x + rect_pos.x - size.x) / 2, rect_pos.y - size.y), size
	)
	gizmos[2].rect = Rect2(Vector2(rect_end.x, rect_pos.y - size.y), size)
	gizmos[3].rect = Rect2(Vector2(rect_end.x, (rect_end.y + rect_pos.y - size.y) / 2), size)
	gizmos[4].rect = Rect2(rect_end, size)
	gizmos[5].rect = Rect2(Vector2((rect_end.x + rect_pos.x - size.x) / 2, rect_end.y), size)
	gizmos[6].rect = Rect2(Vector2(rect_pos.x - size.x, rect_end.y), size)
	gizmos[7].rect = Rect2(
		Vector2(rect_pos.x - size.x, (rect_end.y + rect_pos.y - size.y) / 2), size
	)

	# Rotation gizmo (temp)
#	gizmos[8].rect = Rect2(
#		Vector2((rect_end.x + rect_pos.x - size.x) / 2, rect_pos.y - size.y - (size.y * 2)), size
#	)
	queue_redraw()


func _update_on_zoom() -> void:
	var zoom := Global.camera.zoom.x
	var size := maxi(
		Global.current_project.selection_map.get_size().x,
		Global.current_project.selection_map.get_size().y
	)
	marching_ants_outline.material.set_shader_parameter("width", 1.0 / zoom)
	marching_ants_outline.material.set_shader_parameter("frequency", zoom * 10 * size / 64)
	for gizmo in gizmos:
		if gizmo.rect.size == Vector2.ZERO:
			return
	_update_gizmos()


func _gizmo_resize() -> void:
	var dir := dragged_gizmo.direction
	if Input.is_action_pressed("shape_center"):
		# Code inspired from https://github.com/GDQuest/godot-open-rpg
		if dir.x != 0 and dir.y != 0:  # Border gizmos
			temp_rect.size = ((image_current_pixel - temp_rect_pivot) * 2.0 * Vector2(dir))
		elif dir.y == 0:  # Center left and right gizmos
			temp_rect.size.x = (image_current_pixel.x - temp_rect_pivot.x) * 2.0 * dir.x
		elif dir.x == 0:  # Center top and bottom gizmos
			temp_rect.size.y = (image_current_pixel.y - temp_rect_pivot.y) * 2.0 * dir.y
		temp_rect = Rect2(-1.0 * temp_rect.size / 2 + temp_rect_pivot, temp_rect.size)
	else:
		_resize_rect(image_current_pixel, dir)

	if Input.is_action_pressed("shape_perfect") or resize_keep_ratio:  # Maintain aspect ratio
		var end_y := temp_rect.end.y
		if dir == Vector2i(1, -1) or dir.x == 0:  # Top right corner, center top and center bottom
			var size := temp_rect.size.y
			# Needed in order for resizing to work properly in negative sizes
			if signf(size) != signf(temp_rect.size.x):
				size = absf(size) if temp_rect.size.x > 0 else -absf(size)
			temp_rect.size.x = size / rect_aspect_ratio

		else:  # The rest of the corners
			var size := temp_rect.size.x
			# Needed in order for resizing to work properly in negative sizes
			if signf(size) != signf(temp_rect.size.y):
				size = absf(size) if temp_rect.size.y > 0 else -absf(size)
			temp_rect.size.y = size * rect_aspect_ratio

		# Inspired by the solution answered in https://stackoverflow.com/a/50271547
		if dir == Vector2i(-1, -1):  # Top left corner
			temp_rect.position.y = end_y - temp_rect.size.y

	big_bounding_rectangle = temp_rect.abs()
#	big_bounding_rectangle.position = Vector2(big_bounding_rectangle.position).ceil()
#	big_bounding_rectangle.size = big_bounding_rectangle.size.floor()
	if big_bounding_rectangle.size.x == 0:
		big_bounding_rectangle.size.x = 1
	if big_bounding_rectangle.size.y == 0:
		big_bounding_rectangle.size.y = 1

	big_bounding_rectangle = big_bounding_rectangle  # Call the setter method
	resize_selection()


func _resize_rect(pos: Vector2, dir: Vector2) -> void:
	if dir.x > 0:
		temp_rect.size.x = pos.x - temp_rect.position.x
	elif dir.x < 0:
		var end_x := temp_rect.end.x
		temp_rect.position.x = pos.x
		temp_rect.end.x = end_x
	else:
		temp_rect.size.x = temp_rect_size.x

	if dir.y > 0:
		temp_rect.size.y = pos.y - temp_rect.position.y
	elif dir.y < 0:
		var end_y := temp_rect.end.y
		temp_rect.position.y = pos.y
		temp_rect.end.y = end_y
	else:
		temp_rect.size.y = temp_rect_size.y


func resize_selection() -> void:
	var size := big_bounding_rectangle.size.abs()
	if is_moving_content:
		Global.current_project.selection_map.copy_from(original_bitmap)
		preview_image.copy_from(original_preview_image)
		preview_image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
		if temp_rect.size.x < 0:
			preview_image.flip_x()
		if temp_rect.size.y < 0:
			preview_image.flip_y()
		preview_image_texture = ImageTexture.create_from_image(preview_image)

	Global.current_project.selection_map.resize_bitmap_values(
		Global.current_project, size, temp_rect.size.x < 0, temp_rect.size.y < 0
	)
	Global.current_project.selection_map_changed()
	queue_redraw()
	Global.canvas.queue_redraw()


func _gizmo_rotate() -> void:  # Does not work properly yet
	var angle := image_current_pixel.angle_to_point(mouse_pos_on_gizmo_drag)
	angle = deg_to_rad(floorf(rad_to_deg(angle)))
	if angle == prev_angle:
		return
	prev_angle = angle
#	var img_size := max(original_preview_image.get_width(), original_preview_image.get_height())
#	var pivot = Vector2(original_preview_image.get_width()/2, original_preview_image.get_height()/2)
	var pivot := Vector2(big_bounding_rectangle.size.x / 2.0, big_bounding_rectangle.size.y / 2.0)
	preview_image.copy_from(original_preview_image)
	if original_big_bounding_rectangle.position != big_bounding_rectangle.position:
		preview_image.fill(Color(0, 0, 0, 0))
		var pos_diff := (
			(original_big_bounding_rectangle.position - big_bounding_rectangle.position).abs()
		)
#		pos_diff.y = 0
		preview_image.blit_rect(
			original_preview_image, Rect2(Vector2.ZERO, preview_image.get_size()), pos_diff
		)
	DrawingAlgos.nn_rotate(preview_image, angle, pivot)
	preview_image_texture = ImageTexture.create_from_image(preview_image)

	var bitmap_image := original_bitmap
	var bitmap_pivot := (
		original_big_bounding_rectangle.position
		+ ((original_big_bounding_rectangle.end - original_big_bounding_rectangle.position) / 2)
	)
	DrawingAlgos.nn_rotate(bitmap_image, angle, bitmap_pivot)
	Global.current_project.selection_map = bitmap_image
	Global.current_project.selection_map_changed()
	big_bounding_rectangle = bitmap_image.get_used_rect()
	queue_redraw()
	Global.canvas.queue_redraw()


func select_rect(rect: Rect2i, operation: int = SelectionOperation.ADD) -> void:
	var project := Global.current_project
	# Used only if the selection is outside of the canvas boundaries,
	# on the left and/or above (negative coords)
	var offset_position := Vector2i.ZERO
	if big_bounding_rectangle.position.x < 0:
		rect.position.x -= big_bounding_rectangle.position.x
		offset_position.x = big_bounding_rectangle.position.x
	if big_bounding_rectangle.position.y < 0:
		rect.position.y -= big_bounding_rectangle.position.y
		offset_position.y = big_bounding_rectangle.position.y

	if offset_position != Vector2i.ZERO:
		big_bounding_rectangle.position -= offset_position
		project.selection_map.move_bitmap_values(project)

	if operation == SelectionOperation.ADD:
		project.selection_map.fill_rect(rect, Color(1, 1, 1, 1))
	elif operation == SelectionOperation.SUBTRACT:
		project.selection_map.fill_rect(rect, Color(0))
	elif operation == SelectionOperation.INTERSECT:
		project.selection_map.clear()
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var pos := Vector2i(x, y)
				if !Rect2i(Vector2i.ZERO, project.selection_map.get_size()).has_point(pos):
					continue
				project.selection_map.select_pixel(
					pos, project.selection_map.is_pixel_selected(pos)
				)
	big_bounding_rectangle = project.selection_map.get_used_rect()

	if offset_position != Vector2i.ZERO:
		big_bounding_rectangle.position += offset_position
		project.selection_map.move_bitmap_values(project)

	big_bounding_rectangle = big_bounding_rectangle  # call getter method


func move_borders_start() -> void:
	undo_data = get_undo_data(false)


func move_borders(move: Vector2i) -> void:
	if move == Vector2i.ZERO:
		return
	marching_ants_outline.offset += Vector2(move)
	big_bounding_rectangle.position += move
	queue_redraw()


func move_borders_end() -> void:
	Global.current_project.selection_map.move_bitmap_values(Global.current_project)
	if not is_moving_content:
		commit_undo("Select", undo_data)
	else:
		Global.current_project.selection_map_changed()
	queue_redraw()
	Global.canvas.queue_redraw()


func transform_content_start() -> void:
	if is_moving_content:
		return
	undo_data = get_undo_data(true)
	temp_rect = big_bounding_rectangle
	_get_preview_image()
	if original_preview_image.is_empty():
		undo_data = get_undo_data(false)
		return
	is_moving_content = true
	original_bitmap.copy_from(Global.current_project.selection_map)
	original_big_bounding_rectangle = big_bounding_rectangle
	original_offset = Global.current_project.selection_offset
	queue_redraw()
	Global.canvas.queue_redraw()


func move_content(move: Vector2) -> void:
	move_borders(move)


func transform_content_confirm() -> void:
	if not is_moving_content:
		return
	var project := Global.current_project
	for cel in _get_selected_draw_cels():
		var cel_image: Image = cel.get_image()
		var src: Image = preview_image
		if not is_pasting:
			src.copy_from(cel.transformed_content)
			cel.transformed_content = null
			src.resize(
				big_bounding_rectangle.size.x,
				big_bounding_rectangle.size.y,
				Image.INTERPOLATE_NEAREST
			)
			if temp_rect.size.x < 0:
				src.flip_x()
			if temp_rect.size.y < 0:
				src.flip_y()

		cel_image.blit_rect_mask(
			src,
			src,
			Rect2i(Vector2i.ZERO, project.selection_map.get_size()),
			big_bounding_rectangle.position
		)
	project.selection_map.move_bitmap_values(project)
	commit_undo("Move Selection", undo_data)

	original_preview_image = Image.new()
	preview_image = Image.new()
	original_bitmap = SelectionMap.new()
	is_moving_content = false
	is_pasting = false
	queue_redraw()
	Global.canvas.queue_redraw()


func transform_content_cancel() -> void:
	if preview_image.is_empty():
		return
	var project := Global.current_project
	project.selection_offset = original_offset

	is_moving_content = false
	big_bounding_rectangle = original_big_bounding_rectangle
	project.selection_map.copy_from(original_bitmap)
	project.selection_map_changed()
	preview_image = original_preview_image
	for cel in _get_selected_draw_cels():
		var cel_image := cel.get_image()
		if !is_pasting:
			cel_image.blit_rect_mask(
				cel.transformed_content,
				cel.transformed_content,
				Rect2i(Vector2i.ZERO, Global.current_project.selection_map.get_size()),
				big_bounding_rectangle.position
			)
			cel.transformed_content = null
	for cel_index in project.selected_cels:
		canvas.update_texture(cel_index[1])
	original_preview_image = Image.new()
	preview_image = Image.new()
	original_bitmap = SelectionMap.new()
	is_pasting = false
	queue_redraw()
	Global.canvas.queue_redraw()


func commit_undo(action: String, undo_data_tmp: Dictionary) -> void:
	if !undo_data_tmp:
		print("No undo data found!")
		return
	var redo_data := get_undo_data(undo_data_tmp["undo_image"])
	var project := Global.current_project

	project.undos += 1
	project.undo_redo.create_action(action)
	Global.undo_redo_compress_images(redo_data, undo_data_tmp, project)
	project.undo_redo.add_do_property(
		self, "big_bounding_rectangle", redo_data["big_bounding_rectangle"]
	)
	project.undo_redo.add_do_property(project, "selection_offset", redo_data["outline_offset"])

	project.undo_redo.add_undo_property(
		self, "big_bounding_rectangle", undo_data_tmp["big_bounding_rectangle"]
	)
	project.undo_redo.add_undo_property(
		project, "selection_offset", undo_data_tmp["outline_offset"]
	)

	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_do_method(project.selection_map_changed)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_undo_method(project.selection_map_changed)
	project.undo_redo.commit_action()

	undo_data.clear()


func get_undo_data(undo_image: bool) -> Dictionary:
	var data := {}
	var project := Global.current_project
	data[project.selection_map] = project.selection_map.data
	data["big_bounding_rectangle"] = big_bounding_rectangle
	data["outline_offset"] = Global.current_project.selection_offset
	data["undo_image"] = undo_image

	if undo_image:
		var images := _get_selected_draw_images()
		for image in images:
			data[image] = image.data

	return data


func _get_selected_draw_cels() -> Array[BaseCel]:
	var cels: Array[BaseCel] = []
	var project := Global.current_project
	for cel_index in project.selected_cels:
		var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
		if not cel is PixelCel:
			continue
		if project.layers[cel_index[1]].can_layer_get_drawn():
			cels.append(cel)
	return cels


func _get_selected_draw_images() -> Array[Image]:
	var images: Array[Image] = []
	var project := Global.current_project
	for cel_index in project.selected_cels:
		var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
		if not cel is PixelCel:
			continue
		if project.layers[cel_index[1]].can_layer_get_drawn():
			images.append(cel.get_image())
	return images


## Returns the portion of current cel's image enclosed by the selection.
func get_enclosed_image() -> Image:
	var project := Global.current_project
	if !project.has_selection:
		return

	var image := project.get_current_cel().get_image()
	var enclosed_img := Image.new()
	if is_moving_content:
		enclosed_img.copy_from(preview_image)
		var selection_map_copy := SelectionMap.new()
		selection_map_copy.copy_from(project.selection_map)
		selection_map_copy.move_bitmap_values(project, false)
	else:
		enclosed_img = _get_selected_image(image)
	return enclosed_img


func cut() -> void:
	var project := Global.current_project
	if !project.layers[project.current_layer].can_layer_get_drawn():
		return
	copy()
	delete(false)


## Copies the selection content (works in or between pixelorama instances only).
func copy() -> void:
	var project := Global.current_project
	var cl_image := Image.new()
	var cl_selection_map := SelectionMap.new()
	var cl_big_bounding_rectangle := Rect2()
	var cl_selection_offset := Vector2.ZERO

	var image := project.get_current_cel().get_image()
	var to_copy := Image.new()
	if !project.has_selection:
		to_copy.copy_from(image)
		cl_selection_map.copy_from(project.selection_map)
		cl_selection_map.select_all()
		cl_big_bounding_rectangle = Rect2(Vector2.ZERO, project.size)
	else:
		if is_moving_content:
			to_copy.copy_from(preview_image)
			project.selection_map.move_bitmap_values(project, false)
			cl_selection_map = project.selection_map
		else:
			to_copy = image.get_region(big_bounding_rectangle)
			# Remove unincluded pixels if the selection is not a single rectangle
			var offset_pos := big_bounding_rectangle.position
			for x in to_copy.get_size().x:
				for y in to_copy.get_size().y:
					var pos := Vector2i(x, y)
					if offset_pos.x < 0:
						offset_pos.x = 0
					if offset_pos.y < 0:
						offset_pos.y = 0
					if not project.selection_map.is_pixel_selected(pos + offset_pos):
						to_copy.set_pixelv(pos, Color(0))
			cl_selection_map.copy_from(project.selection_map)
		cl_big_bounding_rectangle = big_bounding_rectangle

	cl_image = to_copy
	cl_selection_offset = project.selection_offset
	var transfer_clipboard := {
		"image": cl_image,
		"selection_map": cl_selection_map.data,
		"big_bounding_rectangle": cl_big_bounding_rectangle,
		"selection_offset": cl_selection_offset,
	}

	var clipboard_file := FileAccess.open(CLIPBOARD_FILE_PATH, FileAccess.WRITE)
	clipboard_file.store_var(transfer_clipboard, true)
	clipboard_file.close()

	if !to_copy.is_empty():
		var pattern: Patterns.Pattern = Global.patterns_popup.get_pattern(0)
		pattern.image = to_copy
		var tex := ImageTexture.create_from_image(to_copy)
		var container = Global.patterns_popup.get_node("ScrollContainer/PatternContainer")
		container.get_child(0).get_child(0).texture = tex


## Pastes the selection content.
func paste(in_place := false) -> void:
	if !FileAccess.file_exists(CLIPBOARD_FILE_PATH):
		return
	var clipboard_file := FileAccess.open(CLIPBOARD_FILE_PATH, FileAccess.READ)
	var clipboard = clipboard_file.get_var(true)
	clipboard_file.close()

	# Sanity checks
	if typeof(clipboard) != TYPE_DICTIONARY:
		return
	if !clipboard.has_all(["image", "selection_map", "big_bounding_rectangle", "selection_offset"]):
		return
	if clipboard.image.is_empty():
		return

	if is_moving_content:
		transform_content_confirm()
	undo_data = get_undo_data(true)
	clear_selection()
	var project := Global.current_project

	var clip_map := SelectionMap.new()
	clip_map.data = clipboard.selection_map
	var max_size := Vector2(
		max(clip_map.get_size().x, project.selection_map.get_size().x),
		max(clip_map.get_size().y, project.selection_map.get_size().y)
	)

	project.selection_map.copy_from(clip_map)
	project.selection_map.crop(max_size.x, max_size.y)
	project.selection_offset = clipboard.selection_offset
	big_bounding_rectangle = clipboard.big_bounding_rectangle
	if not in_place:  # If "Paste" is selected, and not "Paste in Place"
		var camera_center := Global.camera.get_screen_center_position()
		camera_center -= Vector2(big_bounding_rectangle.size) / 2.0
		var max_pos := project.size - big_bounding_rectangle.size
		if max_pos.x >= 0:
			camera_center.x = clampf(camera_center.x, 0, max_pos.x)
		else:
			camera_center.x = 0
		if max_pos.y >= 0:
			camera_center.y = clampf(camera_center.y, 0, max_pos.y)
		else:
			camera_center.y = 0
		big_bounding_rectangle.position = Vector2i(camera_center.floor())
		project.selection_map.move_bitmap_values(Global.current_project, false)

	big_bounding_rectangle = big_bounding_rectangle
	temp_rect = big_bounding_rectangle
	is_moving_content = true
	is_pasting = true
	original_preview_image = clipboard.image
	original_big_bounding_rectangle = big_bounding_rectangle
	original_offset = project.selection_offset
	original_bitmap.copy_from(project.selection_map)
	preview_image.copy_from(original_preview_image)
	preview_image_texture = ImageTexture.create_from_image(preview_image)
	project.selection_map_changed()


## Deletes the drawing enclosed within the selection's area.
func delete(selected_cels := true) -> void:
	var project := Global.current_project
	if !project.layers[project.current_layer].can_layer_get_drawn():
		return
	if is_moving_content:
		is_moving_content = false
		original_preview_image = Image.new()
		preview_image = Image.new()
		original_bitmap = SelectionMap.new()
		is_pasting = false
		queue_redraw()
		commit_undo("Draw", undo_data)
		return

	var undo_data_tmp := get_undo_data(true)
	var images: Array[Image]
	if selected_cels:
		images = _get_selected_draw_images()
	else:
		images = [project.get_current_cel().get_image()]

	if project.has_selection:
		var blank := Image.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
		var selection_map_copy := project.selection_map.return_cropped_copy(project.size)
		for image in images:
			image.blit_rect_mask(
				blank, selection_map_copy, big_bounding_rectangle, big_bounding_rectangle.position
			)
	else:
		for image in images:
			image.fill(0)
	commit_undo("Draw", undo_data_tmp)


## Makes a project brush out of the current selection's content.
func new_brush() -> void:
	var brush = get_enclosed_image()
	if brush and !brush.is_invisible():
		var brush_used: Image = brush.get_region(brush.get_used_rect())
		Global.current_project.brushes.append(brush_used)
		Brushes.add_project_brush(brush_used)


## Select the entire region of current cel.
func select_all() -> void:
	var undo_data_tmp := get_undo_data(false)
	clear_selection()
	var full_rect := Rect2i(Vector2.ZERO, Global.current_project.size)
	select_rect(full_rect)
	commit_undo("Select", undo_data_tmp)


## Inverts the selection.
func invert() -> void:
	transform_content_confirm()
	var project := Global.current_project
	var undo_data_tmp := get_undo_data(false)
	project.selection_map.crop(project.size.x, project.size.y)
	project.selection_map.invert()
	project.selection_map_changed()
	big_bounding_rectangle = project.selection_map.get_used_rect()
	project.selection_offset = Vector2.ZERO
	commit_undo("Select", undo_data_tmp)


## Clears the selection.
func clear_selection(use_undo := false) -> void:
	var project := Global.current_project
	if !project.has_selection:
		return
	transform_content_confirm()
	var undo_data_tmp := get_undo_data(false)
	project.selection_map.crop(project.size.x, project.size.y)
	project.selection_map.clear()

	big_bounding_rectangle = Rect2()
	project.selection_offset = Vector2.ZERO
	queue_redraw()
	if use_undo:
		commit_undo("Clear Selection", undo_data_tmp)


func _get_preview_image() -> void:
	var project := Global.current_project
	var blended_image := Image.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
	DrawingAlgos.blend_layers(
		blended_image, project.frames[project.current_frame], Vector2i.ZERO, project, true
	)
	if original_preview_image.is_empty():
		original_preview_image = Image.create(
			big_bounding_rectangle.size.x, big_bounding_rectangle.size.y, false, Image.FORMAT_RGBA8
		)
		var selection_map_copy := project.selection_map.return_cropped_copy(project.size)
		original_preview_image.blit_rect_mask(
			blended_image, selection_map_copy, big_bounding_rectangle, Vector2i.ZERO
		)
		if original_preview_image.is_invisible():
			original_preview_image = Image.new()
			return

		preview_image.copy_from(original_preview_image)
		preview_image_texture = ImageTexture.create_from_image(preview_image)

	var clear_image := Image.create(
		original_preview_image.get_width(),
		original_preview_image.get_height(),
		false,
		Image.FORMAT_RGBA8
	)
	for cel in _get_selected_draw_cels():
		var cel_image: Image = cel.get_image()
		cel.transformed_content = _get_selected_image(cel_image)
		cel_image.blit_rect_mask(
			clear_image,
			cel.transformed_content,
			Rect2i(Vector2i.ZERO, project.selection_map.get_size()),
			big_bounding_rectangle.position
		)
	for cel_index in project.selected_cels:
		canvas.update_texture(cel_index[1])


func _get_selected_image(cel_image: Image) -> Image:
	var project := Global.current_project
	var image := Image.create(
		big_bounding_rectangle.size.x, big_bounding_rectangle.size.y, false, Image.FORMAT_RGBA8
	)
	var selection_map_copy := project.selection_map.return_cropped_copy(project.size)
	image.blit_rect_mask(cel_image, selection_map_copy, big_bounding_rectangle, Vector2i.ZERO)
	return image
