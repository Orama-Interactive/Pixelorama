class_name TransformationHandles
extends Node2D

signal preview_transform_changed

const HANDLE_RADIUS := 1.0
const RS_HANDLE_DISTANCE := 2

var transformed_selection_map: SelectionMap:
	set(value):
		transformed_selection_map = value
		if is_instance_valid(transformed_selection_map):
			pivot = transformed_selection_map.get_size() / 2
		set_process_input(is_instance_valid(transformed_selection_map))
		queue_redraw()
var transformed_image := Image.new()
var pre_transformed_image := Image.new()
var pre_transform_selection_offset: Vector2
var image_texture := ImageTexture.new()

## Preview transform, not yet applied to the image.
var preview_transform := Transform2D():
	set(value):
		preview_transform = value
		preview_transform_changed.emit()
		if not pre_transformed_image.is_empty():
			transformed_image.copy_from(pre_transformed_image)
			var bounds := DrawingAlgos.get_transformed_bounds(transformed_selection_map.get_size(), preview_transform)
			bounds.position -= bounds.position
			bake_transform_to_image(transformed_image, bounds)
			image_texture.set_image(transformed_image)

var original_selection_transform := Transform2D()

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
	Global.camera.zoom_changed.connect(queue_redraw)
	set_process_input(false)


func _input(event: InputEvent) -> void:
	var project := Global.current_project
	if not project.layers[project.current_layer].can_layer_get_drawn():
		return
	var mouse_pos := canvas.current_pixel
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
	if is_instance_valid(transformed_image) and not transformed_image.is_empty():
		#draw_set_transform_matrix(preview_transform)
		draw_set_transform_matrix(Transform2D.IDENTITY.translated(get_transform_top_left()))
		draw_texture(image_texture, Vector2.ZERO, Color(1, 1, 1, 0.5))
		draw_set_transform_matrix(Transform2D.IDENTITY)

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
		elif handle.type == TransformHandle.Type.ROTATE:
			draw_circle(pos, HANDLE_RADIUS * zoom_value.x, Color.ORANGE)
		elif handle.type == TransformHandle.Type.SKEW:
			draw_circle(pos, HANDLE_RADIUS * zoom_value.x, Color.GREEN)
		elif handle.type == TransformHandle.Type.PIVOT:
			draw_circle(pos, HANDLE_RADIUS * zoom_value.x, Color.WHITE)


func _get_hovered_handle(mouse_pos: Vector2) -> TransformHandle:
	var zoom_value := Vector2.ONE / Global.camera.zoom * 10
	for handle in handles:
		if get_handle_position(handle).distance_to(mouse_pos) < HANDLE_RADIUS * zoom_value.x:
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
			preview_transform = apply_resize(start_transform, active_handle, delta)
		TransformHandle.Type.ROTATE:
			preview_transform = apply_rotate(start_transform, mouse_pos)
		TransformHandle.Type.SKEW:
			preview_transform = apply_shear(start_transform, delta, active_handle)
		TransformHandle.Type.PIVOT:
			handle_pivot_drag(mouse_pos, start_transform)
	queue_redraw()


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


func is_transforming_content() -> bool:
	if selection_node.is_pasting:
		return true
	return preview_transform != original_selection_transform


func is_position_inside_selection(pos: Vector2) -> bool:
	if not is_instance_valid(transformed_selection_map):
		return false
	var local_click := preview_transform.affine_inverse() * pos
	var img_rect := Rect2(Vector2.ZERO, transformed_selection_map.get_size())
	return img_rect.has_point(local_click)


func get_handle_position(handle: TransformHandle, t := preview_transform) -> Vector2:
	var image_size := transformed_selection_map.get_size()
	var local := Vector2(image_size.x * handle.pos.x, image_size.y * handle.pos.y)
	var world_pos := t * local
	if handle.type == TransformHandle.Type.ROTATE or handle.type == TransformHandle.Type.SKEW:
		# Determine direction of offset from center
		var rot_and_skew := transform_remove_scale(t)
		var offset := rot_and_skew.basis_xform(handle.get_direction() * RS_HANDLE_DISTANCE)
		offset = offset.normalized() * RS_HANDLE_DISTANCE
		world_pos += offset
	return world_pos


func transform_remove_scale(t: Transform2D) -> Transform2D:
	var x := t.x.normalized()
	var y := t.y.normalized()
	return Transform2D(x, y, Vector2.ZERO)


## Apply an affine transform [param m] around [param pivot_local] onto [param t].
func transform_around(t: Transform2D, m: Transform2D, pivot_local: Vector2) -> Transform2D:
	var pivot_world := t * pivot_local
	var to_origin := Transform2D(Vector2(1, 0), Vector2(0, 1), -pivot_world)
	var back := Transform2D(Vector2(1, 0), Vector2(0, 1), pivot_world)
	return back * m * to_origin * t


func get_no_pivot_transform(pivot_transform := preview_transform, pivot_local := pivot) -> Transform2D:
	var pivot_world := pivot_transform * pivot_local
	var to_origin := Transform2D(Vector2(1, 0), Vector2(0, 1), -pivot_world)
	var back := Transform2D(Vector2(1, 0), Vector2(0, 1), pivot_world)
	return back.affine_inverse() * pivot_transform * to_origin.affine_inverse()


func begin_drag(mouse_pos: Vector2) -> void:
	drag_start = mouse_pos
	start_transform = preview_transform
	begin_transform()


func move(pos: Vector2) -> void:
	preview_transform = preview_transform.translated(pos)
	queue_redraw()


func apply_resize(t: Transform2D, handle: TransformHandle, delta: Vector2) -> Transform2D:
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
func apply_rotate(t: Transform2D, mouse_pos: Vector2) -> Transform2D:
	# Compute initial and current angles
	var pivot_world := t * pivot
	var start_vec := drag_start - pivot_world
	var curr_vec := mouse_pos - pivot_world
	var delta_ang := fposmod(curr_vec.angle() - start_vec.angle(), TAU)
	var m := Transform2D().rotated(delta_ang)
	return transform_around(t, m, pivot)


func handle_pivot_drag(mouse_pos: Vector2, t: Transform2D) -> void:
	var local_mouse := t.affine_inverse() * mouse_pos
	pivot = local_mouse


func apply_shear(t: Transform2D, delta: Vector2, handle: TransformHandle) -> Transform2D:
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
		return Input.CURSOR_FDIAGSIZE  # Bottom-right
	if deg < 112.5:
		return Input.CURSOR_VSIZE  # Down
	if deg < 157.5:
		return Input.CURSOR_BDIAGSIZE  # Bottom-left
	if deg < 202.5:
		return Input.CURSOR_HSIZE  # Left
	if deg < 247.5:
		return Input.CURSOR_FDIAGSIZE  # Top-left
	if deg < 292.5:
		return Input.CURSOR_VSIZE  # Up
	if deg < 337.5:
		return Input.CURSOR_BDIAGSIZE  # Top-right

	return Input.CURSOR_ARROW


func set_selection(selection_map: SelectionMap, selection_rect: Rect2i) -> void:
	transformed_selection_map = selection_map
	pre_transformed_image = Image.new()
	transformed_image = Image.new()
	if is_instance_valid(transformed_selection_map):
		preview_transform = Transform2D().translated(selection_rect.position)
	else:
		preview_transform = Transform2D.IDENTITY
	original_selection_transform = preview_transform
	queue_redraw()


func begin_transform(image: Image = null, project := Global.current_project) -> void:
	if not pre_transformed_image.is_empty():
		return
	if is_instance_valid(image):
		pre_transformed_image = image
		transformed_image.copy_from(pre_transformed_image)
		image_texture.set_image(transformed_image)
		return
	var blended_image := project.new_empty_image()
	DrawingAlgos.blend_layers(
		blended_image, project.frames[project.current_frame], Vector2i.ZERO, project, true
	)
	var map_copy := project.selection_map.return_cropped_copy(project, project.size)
	var selection_rect := map_copy.get_used_rect()
	pre_transformed_image = Image.create(
		selection_rect.size.x, selection_rect.size.y, false, project.get_image_format()
	)
	pre_transformed_image.blit_rect_mask(blended_image, map_copy, selection_rect, Vector2i.ZERO)
	image_texture.set_image(pre_transformed_image)
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
	preview_transform = Transform2D()
	if is_instance_valid(transformed_selection_map):
		pivot = transformed_selection_map.get_size() / 2
	pre_transformed_image = Image.new()
	transformed_image = Image.new()
	queue_redraw()


func get_transform_top_left(size := transformed_selection_map.get_size()) -> Vector2:
	var bounds := DrawingAlgos.get_transformed_bounds(size, preview_transform)
	return bounds.position.ceil()


func bake_transform_to_image(image: Image, used_rect := Rect2i()) -> void:
	DrawingAlgos.transform_image_with_transform2d(image, preview_transform, pivot, used_rect)


func bake_transform_to_selection(map: SelectionMap) -> void:
	var transformed_selection := SelectionMap.new()
	transformed_selection.copy_from(transformed_selection_map)
	var transformation_origin := get_transform_top_left()
	bake_transform_to_image(transformed_selection)
	var selection_size_rect := Rect2i(Vector2i.ZERO, transformed_selection.get_size())
	map.blit_rect_custom(transformed_selection, selection_size_rect, transformation_origin)
