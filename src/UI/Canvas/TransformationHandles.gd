class_name TransformationHandles
extends Node2D

signal preview_transform_changed

const HANDLE_RADIUS := 1.0
const RS_HANDLE_DISTANCE := 2
const KEY_MOVE_ACTION_NAMES: PackedStringArray = [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]

var currently_transforming := false
var arrow_key_move := false
var only_transforms_selection := false
var transformed_selection_map: SelectionMap:
	set(value):
		transformed_selection_map = value
		if is_instance_valid(transformed_selection_map):
			pivot = transformed_selection_map.get_size() / 2
		else:
			_set_default_cursor()
		set_process_input(is_instance_valid(transformed_selection_map))
		queue_redraw()
var transformed_image := Image.new()
var pre_transformed_image := Image.new()
var pre_transform_selection_offset: Vector2
var pre_transform_tilemap_cells: Array[Array]
var image_texture := ImageTexture.new()

## Preview transform, not yet applied to the image.
var preview_transform := Transform2D():
	set(value):
		preview_transform = clamp_transform_image_space(value, pre_transformed_image.get_size())
		preview_transform_changed.emit()

var original_selection_transform := Transform2D()
var transformation_algorithm := 0:
	set(value):
		transformation_algorithm = value
		preview_transform_changed.emit()

## Tracking handles
var active_handle: TransformHandle:
	set(value):
		active_handle = value
		Global.can_draw = not is_instance_valid(active_handle)

var handles: Array[TransformHandle] = [
	TransformHandle.new(TransformHandle.Type.PIVOT),
	TransformHandle.new(TransformHandle.Type.SCALE, Vector2(0, 0)),  # Top left
	TransformHandle.new(TransformHandle.Type.SCALE, Vector2(0.5, 0)),  # Center top
	TransformHandle.new(TransformHandle.Type.SCALE, Vector2(1, 0)),  # Top right
	TransformHandle.new(TransformHandle.Type.SCALE, Vector2(1, 0.5)),  # Center right
	TransformHandle.new(TransformHandle.Type.SCALE, Vector2(1, 1)),  # Bottom right
	TransformHandle.new(TransformHandle.Type.SCALE, Vector2(0.5, 1)),  # Center bottom
	TransformHandle.new(TransformHandle.Type.SCALE, Vector2(0, 1)),  # Bottom left
	TransformHandle.new(TransformHandle.Type.SCALE, Vector2(0, 0.5)),  # Center left
	TransformHandle.new(TransformHandle.Type.ROTATE, Vector2(0, 0)),  # Top left
	TransformHandle.new(TransformHandle.Type.ROTATE, Vector2(1, 0)),  # Top right
	TransformHandle.new(TransformHandle.Type.ROTATE, Vector2(1, 1)),  # Bottom right
	TransformHandle.new(TransformHandle.Type.ROTATE, Vector2(0, 1)),  # Bottom left
	TransformHandle.new(TransformHandle.Type.SKEW, Vector2(0.5, 0)),  # Center top
	TransformHandle.new(TransformHandle.Type.SKEW, Vector2(1, 0.5)),  # Center right
	TransformHandle.new(TransformHandle.Type.SKEW, Vector2(0.5, 1)),  # Center bottom
	TransformHandle.new(TransformHandle.Type.SKEW, Vector2(0, 0.5))  # Center left
]
var drag_start: Vector2
var start_transform := Transform2D()

## The transformation's pivot. By default it is set to the center of the image.
var pivot := Vector2.ZERO:
	set(value):
		pivot = value
		if is_instance_valid(transformed_selection_map):
			var image_size := transformed_selection_map.get_size() as Vector2
			handles[0].pos = pivot / image_size

@onready var selection_node := get_parent() as SelectionNode
@onready var canvas := get_parent().get_parent() as Canvas


class TransformHandle:
	enum Type { SCALE, ROTATE, SKEW, PIVOT }

	var type := Type.SCALE
	var pos := Vector2(0.5, 0.5)

	func _init(_type: Type, _pos := Vector2(0.5, 0.5)) -> void:
		type = _type
		pos = _pos

	func get_anchor() -> Vector2:
		var anchor := pos
		if pos.x == 0:
			anchor.x = 1
		elif pos.x == 1:
			anchor.x = 0
		if pos.y == 0:
			anchor.y = 1
		elif pos.y == 1:
			anchor.y = 0
		return anchor

	func get_direction() -> Vector2:
		return pos * 2 - Vector2.ONE


func _ready() -> void:
	selection_node.transformation_confirmed.connect(func(): active_handle = null)
	selection_node.transformation_canceled.connect(func(): active_handle = null)
	preview_transform_changed.connect(_on_preview_transform_changed)
	Global.camera.zoom_changed.connect(queue_redraw)
	set_process_input(false)


func _input(event: InputEvent) -> void:
	var project := Global.current_project
	if not project.layers[project.current_layer].can_layer_get_drawn():
		return
	if event is InputEventKey:
		_move_with_arrow_keys(event)
	var mouse_pos := canvas.current_pixel
	if Global.mirror_view:
		mouse_pos.x = Global.current_project.size.x - mouse_pos.x
	var hovered_handle := _get_hovered_handle(mouse_pos)
	if is_instance_valid(hovered_handle):
		if hovered_handle.type == TransformHandle.Type.PIVOT:
			Input.set_default_cursor_shape(Input.CURSOR_MOVE)
		elif hovered_handle.type == TransformHandle.Type.ROTATE:
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		else:
			var cursor_shape := Input.CURSOR_POINTING_HAND
			var local_direction := hovered_handle.get_direction().normalized()
			var global_direction := preview_transform.basis_xform(local_direction.normalized())
			var angle := global_direction.angle()
			if hovered_handle.type == TransformHandle.Type.SKEW:
				angle += PI / 2
			cursor_shape = angle_to_cursor(angle)
			Input.set_default_cursor_shape(cursor_shape)
	else:
		_set_default_cursor()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_mouse_press(mouse_pos, hovered_handle)
		else:
			active_handle = null
	elif event is InputEventMouseMotion:
		if active_handle != null:
			_handle_mouse_drag(mouse_pos)


func _draw() -> void:
	if not is_instance_valid(transformed_selection_map):
		return
	var zoom_value := Vector2.ONE / Global.camera.zoom * 10
	var position_tmp := position
	var position_top_left := position + get_transform_top_left()
	var scale_tmp := scale
	if Global.mirror_view:
		position_tmp.x = Global.current_project.size.x - position_tmp.x
		position_top_left.x = Global.current_project.size.x - position_top_left.x
		scale_tmp.x = -1
	if is_instance_valid(transformed_image) and not transformed_image.is_empty():
		draw_set_transform(position_top_left, rotation, scale_tmp)
		var preview_color := Color(1, 1, 1, Global.transformation_preview_alpha)
		draw_texture(image_texture, Vector2.ZERO, preview_color)
	draw_set_transform(position_tmp, rotation, scale_tmp)
	# Draw handles
	for handle in handles:
		var pos := get_handle_position(handle)
		if handle.type == TransformHandle.Type.SCALE:
			draw_rect(
				_circle_to_square(pos, HANDLE_RADIUS * zoom_value), Global.selection_border_color_2
			)
			draw_rect(
				_circle_to_square(pos, (HANDLE_RADIUS - 0.3) * zoom_value),
				Global.selection_border_color_1
			)
		elif handle.type == TransformHandle.Type.PIVOT:
			if is_rotated_or_skewed():
				var final_size := HANDLE_RADIUS * zoom_value.x
				draw_circle(pos, final_size, Color.WHITE, false)
				draw_circle(pos, final_size * 0.25, Color.WHITE)


func _move_with_arrow_keys(event: InputEvent) -> void:
	var selection_tool_selected := false
	for slot in Tools._slots.values():
		if slot.tool_node is BaseSelectionTool:
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
		begin_transform()
	if _is_action_direction_released(event) and arrow_key_move:
		arrow_key_move = false

	if _is_action_direction(event) and arrow_key_move:
		var step := Vector2.ONE
		if Input.is_key_pressed(KEY_CTRL):
			step = Global.grids[0].grid_size
		var input := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
		var final_input := input.rotated(snappedf(Global.camera.camera_angle, PI / 2))
		# These checks are needed to fix a bug where the selection got stuck
		# to the canvas boundaries when they were 1px away from them
		if is_zero_approx(absf(final_input.x)):
			final_input.x = 0
		if is_zero_approx(absf(final_input.y)):
			final_input.y = 0
		var final_direction := (final_input * step).round()
		if Tools.is_placing_tiles():
			var tilemap_cel := Global.current_project.get_current_cel() as CelTileMap
			var grid_size := tilemap_cel.get_tile_size()
			final_direction *= Vector2(grid_size)
		move_transform(final_direction)


func _get_hovered_handle(mouse_pos: Vector2) -> TransformHandle:
	var zoom_value := Vector2.ONE / Global.camera.zoom * 10
	for handle in handles:
		if handle.type == TransformHandle.Type.PIVOT and not is_rotated_or_skewed():
			continue
		var total_radius := HANDLE_RADIUS * zoom_value.x
		if handle.type == TransformHandle.Type.ROTATE or handle.type == TransformHandle.Type.SKEW:
			total_radius *= 2
		if get_handle_position(handle).distance_to(mouse_pos) < total_radius:
			return handle
	return null


## Begin dragging handle.
func _handle_mouse_press(mouse_pos: Vector2, hovered_handle: TransformHandle) -> void:
	if hovered_handle != null:
		active_handle = hovered_handle
		begin_drag(mouse_pos)


## Update [member preview_transform] based which handle we're dragging.
func _handle_mouse_drag(mouse_pos: Vector2) -> void:
	var delta := mouse_pos - drag_start
	match active_handle.type:
		TransformHandle.Type.SCALE:
			preview_transform = resize_transform_handle(start_transform, active_handle, delta)
		TransformHandle.Type.ROTATE:
			preview_transform = rotate_transform_handle(start_transform, mouse_pos)
		TransformHandle.Type.SKEW:
			preview_transform = shear_transform_handle(start_transform, delta, active_handle)
		TransformHandle.Type.PIVOT:
			handle_pivot_drag(mouse_pos, start_transform)
	queue_redraw()


## Check if an event is a ui_up/down/left/right event pressed
func _is_action_direction_pressed(event: InputEvent) -> bool:
	for action in KEY_MOVE_ACTION_NAMES:
		if event.is_action_pressed(action, false, true):
			return true
	return false


## Check if an event is a ui_up/down/left/right event
func _is_action_direction(event: InputEvent) -> bool:
	for action in KEY_MOVE_ACTION_NAMES:
		if event.is_action(action, true):
			return true
	return false


## Check if an event is a ui_up/down/left/right event release
func _is_action_direction_released(event: InputEvent) -> bool:
	for action in KEY_MOVE_ACTION_NAMES:
		if event.is_action_released(action, true):
			return true
	return false


func clamp_transform_image_space(
	t: Transform2D, image_size: Vector2, min_pixels := 1.0
) -> Transform2D:
	var bounds := DrawingAlgos.get_transformed_bounds(image_size, t)
	var width := bounds.size.x
	var height := bounds.size.y

	if width < min_pixels or height < min_pixels:
		# Compute scale correction in local space to ensure 1-pixel size
		var scale_x := width < min_pixels and width != 0
		var scale_y := height < min_pixels and height != 0
		var sx := t.x.length()
		var sy := t.y.length()
		if scale_x:
			sx = sx * (min_pixels / width)
		if scale_y:
			sy = sy * (min_pixels / height)
		# Re-apply scale preserving direction and orientation
		t.x = t.x.normalized() * sx
		t.y = t.y.normalized() * sy

	return t


func _on_preview_transform_changed() -> void:
	if not pre_transformed_image.is_empty():
		transformed_image.copy_from(pre_transformed_image)
		var bounds := DrawingAlgos.get_transformed_bounds(
			transformed_selection_map.get_size(), preview_transform
		)
		if Tools.is_placing_tiles():
			for cel in selection_node.get_selected_draw_cels():
				if cel is not CelTileMap:
					continue
				var tilemap := cel as CelTileMap
				var horizontal_size := bounds.size.x / tilemap.get_tile_size().x
				var vertical_size := bounds.size.y / tilemap.get_tile_size().y
				var selected_cells := tilemap.resize_selection(
					pre_transform_tilemap_cells, horizontal_size, vertical_size
				)
				transformed_image.crop(bounds.size.x, bounds.size.y)
				tilemap.apply_resizing_to_image(transformed_image, selected_cells, bounds, false)
		else:
			bounds.position -= bounds.position
			bake_transform_to_image(transformed_image, bounds)
		image_texture.set_image(transformed_image)


func _set_default_cursor() -> void:
	var project := Global.current_project
	var cursor := Input.CURSOR_ARROW
	if Global.cross_cursor:
		cursor = Input.CURSOR_CROSS
	var layer: BaseLayer = project.layers[project.current_layer]
	if not layer.can_layer_get_drawn():
		cursor = Input.CURSOR_FORBIDDEN

	if DisplayServer.cursor_get_shape() != cursor:
		Input.set_default_cursor_shape(cursor)


func _circle_to_square(center: Vector2, radius: Vector2) -> Rect2:
	var rect := Rect2(center - radius / 2, radius)
	return rect


func is_rotated_or_skewed() -> bool:
	return preview_transform.get_rotation() != 0 or preview_transform.get_skew() != 0


func is_transforming_content() -> bool:
	return currently_transforming


func get_handle_position(handle: TransformHandle, t := preview_transform) -> Vector2:
	var image_size := transformed_selection_map.get_size()
	var local := Vector2(image_size.x * handle.pos.x, image_size.y * handle.pos.y)
	var world_pos := t * local
	if handle.type == TransformHandle.Type.ROTATE or handle.type == TransformHandle.Type.SKEW:
		var zoom_value := Vector2.ONE / Global.camera.zoom * 10
		var handle_distance := RS_HANDLE_DISTANCE * zoom_value
		# Determine direction of offset from center
		var rot_and_skew := DrawingAlgos.transform_remove_scale(t)
		var offset := rot_and_skew.basis_xform(handle.get_direction() * handle_distance)
		offset = offset.normalized() * handle_distance
		world_pos += offset
	return world_pos


## Apply an affine transform [param m] around [param pivot_local] onto [param t].
func transform_around(t: Transform2D, m: Transform2D, pivot_local: Vector2) -> Transform2D:
	var pivot_world := t * pivot_local
	var to_origin := Transform2D(Vector2(1, 0), Vector2(0, 1), -pivot_world)
	var back := Transform2D(Vector2(1, 0), Vector2(0, 1), pivot_world)
	return back * m * to_origin * t


func begin_drag(mouse_pos: Vector2) -> void:
	drag_start = mouse_pos
	start_transform = preview_transform
	begin_transform()


func move_transform(pos: Vector2) -> void:
	var final_pos := pos
	if Tools.is_placing_tiles():
		var grid_size := (Global.current_project.get_current_cel() as CelTileMap).get_tile_size()
		final_pos = Tools.snap_to_rectangular_grid_boundary(pos, grid_size)
	preview_transform = preview_transform.translated(final_pos)
	queue_redraw()


## Called by the sliders in the selection tool options.
func resize_transform(delta: Vector2) -> void:
	var bottom_right_handle := handles[5]
	preview_transform = resize_transform_handle(preview_transform, bottom_right_handle, delta)
	queue_redraw()


## Called by the sliders in the selection tool options.
func rotate_transform(angle: float) -> void:
	if Tools.is_placing_tiles():
		return
	var delta_ang := angle - preview_transform.get_rotation()
	var m := Transform2D().rotated(delta_ang)
	preview_transform = transform_around(preview_transform, m, pivot)
	queue_redraw()


## Called by the sliders in the selection tool options.
func shear_transform(angle: float) -> void:
	if Tools.is_placing_tiles():
		return
	var t_rotation := preview_transform.get_rotation()
	var t_scale := preview_transform.get_scale()
	var t_origin := preview_transform.origin

	preview_transform = Transform2D(t_rotation, t_scale, angle, t_origin)
	queue_redraw()


func resize_transform_handle(
	t: Transform2D, handle: TransformHandle, delta: Vector2
) -> Transform2D:
	if Tools.is_placing_tiles():
		var tilemap := Global.current_project.get_current_cel() as CelTileMap
		if tilemap.get_tile_shape() != TileSet.TILE_SHAPE_SQUARE:
			return t
		var offset := tilemap.offset % tilemap.get_tile_size()
		drag_start = drag_start.snapped(tilemap.get_tile_size()) + Vector2(offset)
		delta = delta.snapped(tilemap.get_tile_size()) + Vector2(offset)
	var image_size := transformed_selection_map.get_size() as Vector2
	# Step 1: Convert drag to local space
	var local_start := t.affine_inverse() * drag_start
	var local_now := t.affine_inverse() * (drag_start + delta)
	var local_delta := local_now - local_start

	# Step 2: Determine resize axis and direction
	var scale_x := 1.0
	var scale_y := 1.0
	var anchor := handle.get_anchor()
	if anchor.x == 0:
		scale_x = (image_size.x + local_delta.x) / image_size.x
	elif anchor.x == 1:
		scale_x = (image_size.x - local_delta.x) / image_size.x
	if anchor.y == 0:
		scale_y = (image_size.y + local_delta.y) / image_size.y
	elif anchor.y == 1:
		scale_y = (image_size.y - local_delta.y) / image_size.y

	if Input.is_action_pressed("shape_center"):
		anchor = Vector2(0.5, 0.5)
	if Input.is_action_pressed("shape_perfect"):
		var u := 1.0 + maxf(delta.x / image_size.x, delta.y / image_size.y)
		scale_x = u
		scale_y = u
	# Step 3: Build scaled basis vectors from original
	var bx := t.x.normalized() * t.x.length() * scale_x
	var by := t.y.normalized() * t.y.length() * scale_y
	var new_t := Transform2D(bx, by, t.origin)

	# Step 4: Keep anchor in place
	var local_anchor := anchor * image_size
	var world_anchor_before := t * local_anchor
	var world_anchor_after := new_t * local_anchor
	new_t.origin += world_anchor_before - world_anchor_after

	return new_t


## Rotation around pivot based on initial drag.
func rotate_transform_handle(t: Transform2D, mouse_pos: Vector2) -> Transform2D:
	if Tools.is_placing_tiles():
		return t
	# Compute initial and current angles
	var pivot_world := t * pivot
	var start_vec := drag_start - pivot_world
	var curr_vec := mouse_pos - pivot_world
	var delta_ang := fposmod(curr_vec.angle() - start_vec.angle(), TAU)
	if Input.is_action_pressed("shape_perfect"):
		delta_ang = snappedf(delta_ang, PI / 8)
	var m := Transform2D().rotated(delta_ang)
	return transform_around(t, m, pivot)


func shear_transform_handle(t: Transform2D, delta: Vector2, handle: TransformHandle) -> Transform2D:
	if Tools.is_placing_tiles():
		return t
	var image_size := transformed_selection_map.get_size() as Vector2
	var handle_global_position := get_handle_position(handle, t)
	var center := t * pivot
	var handle_vector := (handle_global_position - center).normalized()
	var handle_angle := rad_to_deg(fposmod(handle_vector.angle(), TAU))
	var is_horizontal := true
	if in_range(handle_angle, 315, 45):
		is_horizontal = false
	elif in_range(handle_angle, 45, 135):
		is_horizontal = true
	elif in_range(handle_angle, 135, 225):
		is_horizontal = false
		delta.y = -delta.y
	elif in_range(handle_angle, 225, 315):
		is_horizontal = true
		delta.x = -delta.x

	var shear_matrix := Transform2D.IDENTITY
	if is_horizontal:
		# Slant Y axis based on X movement (horizontal shear)
		var shear_amount := delta.x / image_size.x
		shear_matrix = Transform2D(Vector2(1, 0), Vector2(shear_amount, 1), Vector2())
	else:
		# Slant X axis based on Y movement (vertical shear)
		var shear_amount := delta.y / image_size.y
		shear_matrix = Transform2D(Vector2(1, shear_amount), Vector2(0, 1), Vector2())

	# Apply the shear matrix in local space around pivot
	return transform_around(t, shear_matrix, pivot)


func handle_pivot_drag(mouse_pos: Vector2, t: Transform2D) -> void:
	var local_mouse := t.affine_inverse() * mouse_pos
	pivot = local_mouse


## Checks if [param angle] is between [param lower] and [param upper] degrees.
func in_range(angle: float, lower: float, upper: float) -> bool:
	angle = fmod(angle, 360)
	lower = fmod(lower, 360)
	upper = fmod(upper, 360)
	if lower > upper:
		return angle >= lower or angle <= upper
	return angle > lower and angle < upper


func angle_to_cursor(angle: float) -> Input.CursorShape:
	var deg := fmod(rad_to_deg(angle) + 360.0, 360.0)

	if deg >= 337.5 or deg < 22.5:
		return Input.CURSOR_HSIZE  # Right
	if deg < 67.5:
		if Global.mirror_view:
			return Input.CURSOR_BDIAGSIZE
		return Input.CURSOR_FDIAGSIZE  # Bottom-right
	if deg < 112.5:
		return Input.CURSOR_VSIZE  # Down
	if deg < 157.5:
		if Global.mirror_view:
			return Input.CURSOR_FDIAGSIZE
		return Input.CURSOR_BDIAGSIZE  # Bottom-left
	if deg < 202.5:
		return Input.CURSOR_HSIZE  # Left
	if deg < 247.5:
		if Global.mirror_view:
			return Input.CURSOR_BDIAGSIZE
		return Input.CURSOR_FDIAGSIZE  # Top-left
	if deg < 292.5:
		return Input.CURSOR_VSIZE  # Up
	if deg < 337.5:
		if Global.mirror_view:
			return Input.CURSOR_FDIAGSIZE
		return Input.CURSOR_BDIAGSIZE  # Top-right

	return Input.CURSOR_ARROW


func set_selection(selection_map: SelectionMap, selection_rect: Rect2i) -> void:
	currently_transforming = false
	transformed_selection_map = selection_map
	pre_transformed_image = Image.new()
	transformed_image = Image.new()
	if is_instance_valid(transformed_selection_map):
		preview_transform = Transform2D().translated(selection_rect.position)
	else:
		preview_transform = Transform2D.IDENTITY
	original_selection_transform = preview_transform
	pre_transform_tilemap_cells.clear()
	queue_redraw()


## Called when a transformation begins to happen.
func begin_transform(
	image: Image = null,
	project := Global.current_project,
	force_move_content := false,
	force_move_selection_only := false
) -> void:
	currently_transforming = true
	var selection_only_action := Input.is_action_pressed(&"transform_move_selection_only", true)
	var move_selection_only := selection_only_action or force_move_selection_only
	if move_selection_only and not force_move_content:
		if not only_transforms_selection:
			selection_node.undo_data = selection_node.get_undo_data(false)
			only_transforms_selection = true
		return
	else:
		if only_transforms_selection:
			selection_node.transform_content_confirm()
			only_transforms_selection = false
	if not pre_transformed_image.is_empty():
		return
	if is_instance_valid(image):
		pre_transformed_image = image
		transformed_image.copy_from(pre_transformed_image)
		image_texture.set_image(transformed_image)
		return
	selection_node.undo_data = selection_node.get_undo_data(true)
	var map_copy := project.selection_map.return_cropped_copy(project, project.size)
	var selection_rect := map_copy.get_used_rect()
	var current_cel := project.get_current_cel()
	if current_cel is CelTileMap and Tools.is_placing_tiles():
		if current_cel.get_tile_shape() != TileSet.TILE_SHAPE_SQUARE:
			return
		pre_transform_tilemap_cells = (current_cel as CelTileMap).get_selected_cells(
			project.selection_map, selection_rect
		)
	var blended_image := project.new_empty_image()
	DrawingAlgos.blend_layers(
		blended_image, project.frames[project.current_frame], Vector2i.ZERO, project, true
	)
	pre_transformed_image = Image.create(
		selection_rect.size.x, selection_rect.size.y, false, project.get_image_format()
	)
	pre_transformed_image.blit_rect_mask(blended_image, map_copy, selection_rect, Vector2i.ZERO)
	image_texture.set_image(pre_transformed_image)
	if pre_transformed_image.is_empty():
		return
	transformed_image.copy_from(pre_transformed_image)
	queue_redraw()
	# Remove content from the cels
	var clear_image := Image.create(
		pre_transformed_image.get_width(),
		pre_transformed_image.get_height(),
		pre_transformed_image.has_mipmaps(),
		pre_transformed_image.get_format()
	)
	for cel in selection_node.get_selected_draw_cels():
		var cel_image := cel.get_image()
		cel.transformed_content = selection_node.get_selected_image(cel_image)
		cel_image.blit_rect_mask(
			clear_image,
			cel.transformed_content,
			Rect2i(Vector2i.ZERO, project.selection_map.get_size()),
			selection_rect.position
		)
	for cel_index in project.selected_cels:
		canvas.update_texture(cel_index[1])


func reset_transform() -> void:
	currently_transforming = false
	preview_transform = original_selection_transform
	if is_instance_valid(transformed_selection_map):
		pivot = transformed_selection_map.get_size() / 2
	pre_transformed_image = Image.new()
	transformed_image = Image.new()
	pre_transform_tilemap_cells.clear()
	for cel in selection_node.get_selected_draw_cels():
		cel.transformed_content = null
	queue_redraw()


func get_transform_top_left(size := transformed_selection_map.get_size()) -> Vector2:
	var bounds := DrawingAlgos.get_transformed_bounds(size, preview_transform)
	return bounds.position.ceil()


func bake_transform_to_image(image: Image, used_rect := Rect2i()) -> void:
	if used_rect.size.x < 1:
		used_rect.size.x = 1
	if used_rect.size.y < 1:
		used_rect.size.y = 1
	DrawingAlgos.transform_image_with_viewport(
		image, preview_transform, pivot, transformation_algorithm, used_rect
	)


func bake_transform_to_selection(map: SelectionMap, is_confirmed := false) -> void:
	var bounds := DrawingAlgos.get_transformed_bounds(
		transformed_selection_map.get_size(), preview_transform
	)
	var transformation_origin := get_transform_top_left().max(Vector2.ZERO)
	if is_confirmed:
		var position_top_left := position + get_transform_top_left()
		transformation_origin = position_top_left
		map.crop(Global.current_project.size.x, Global.current_project.size.y)
		Global.current_project.selection_offset = Vector2.ZERO
	else:
		map.ensure_selection_fits(Global.current_project, bounds)
	bounds.position -= bounds.position
	var transformed_selection := SelectionMap.new()
	transformed_selection.copy_from(transformed_selection_map)
	bake_transform_to_image(transformed_selection, bounds)
	var selection_size_rect := Rect2i(Vector2i.ZERO, transformed_selection.get_size())
	map.blit_rect_custom(transformed_selection, selection_size_rect, transformation_origin)
