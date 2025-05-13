class_name TransformationHandles
extends Node2D

const ICON := preload("res://assets/graphics/splash_screen/orama_64x64.png")
const HANDLE_RADIUS := 2.0
const RS_HANDLE_DISTANCE := 0.1

# Raw image data and baked texture
var base_image: Image
var image_texture: ImageTexture

# Preview transform, not yet applied to base_image
var preview_transform := Transform2D()

# Tracking handles
var active_handle: TransformHandle

var handles: Array[TransformHandle] = [
	TransformHandle.new(TransformHandle.Type.MOVE),  # Not a visible handle
	TransformHandle.new(TransformHandle.Type.SCALE, Vector2(0, 0)),  # Top left
	TransformHandle.new(TransformHandle.Type.SCALE, Vector2(0.5, 0)),  # Center top
	TransformHandle.new(TransformHandle.Type.SCALE, Vector2(1, 0)),  # Top right
	TransformHandle.new(TransformHandle.Type.SCALE, Vector2(1, 0.5)),  # Center right
	TransformHandle.new(TransformHandle.Type.SCALE, Vector2(1, 1)),  # Bottom right
	TransformHandle.new(TransformHandle.Type.SCALE, Vector2(0.5, 1)),  # Center bottom
	TransformHandle.new(TransformHandle.Type.SCALE, Vector2(0, 1)),  # Bottom left
	TransformHandle.new(TransformHandle.Type.SCALE, Vector2(0, 0.5)),  # Center left

	TransformHandle.new(TransformHandle.Type.ROTATE, Vector2(0 - RS_HANDLE_DISTANCE, 0 - RS_HANDLE_DISTANCE)),  # Top left
	TransformHandle.new(TransformHandle.Type.ROTATE, Vector2(1 + RS_HANDLE_DISTANCE, 0 - RS_HANDLE_DISTANCE)),  # Top right
	TransformHandle.new(TransformHandle.Type.ROTATE, Vector2(1 + RS_HANDLE_DISTANCE, 1 + RS_HANDLE_DISTANCE)),  # Bottom right
	TransformHandle.new(TransformHandle.Type.ROTATE, Vector2(0 - RS_HANDLE_DISTANCE, 1 + RS_HANDLE_DISTANCE)),  # Bottom left

	TransformHandle.new(TransformHandle.Type.SKEW, Vector2(0.5, 0 - RS_HANDLE_DISTANCE)),  # Center top
	TransformHandle.new(TransformHandle.Type.SKEW, Vector2(1 + RS_HANDLE_DISTANCE, 0.5)),  # Center right
	TransformHandle.new(TransformHandle.Type.SKEW, Vector2(0.5, 1 + RS_HANDLE_DISTANCE)),  # Center bottom
	TransformHandle.new(TransformHandle.Type.SKEW, Vector2(0 - RS_HANDLE_DISTANCE, 0.5))  # Center left
]
var drag_start: Vector2
var start_transform := Transform2D()

## The transformation's pivot. By default it is set to the center of the image.
var pivot := Vector2.ZERO
@onready var canvas := get_parent().get_parent() as Canvas

class TransformHandle:
	enum Type { SCALE, ROTATE, SKEW, MOVE }

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


func _ready() -> void:
	var img := ICON.get_image()
	base_image = Image.create_from_data(ICON.get_width(), ICON.get_height(), false, img.get_format(), img.get_data())
	image_texture = ImageTexture.create_from_image(base_image)
	pivot = base_image.get_size() / 2
	queue_redraw()


func _input(event: InputEvent):
	var mouse_pos := canvas.current_pixel
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_mouse_press(mouse_pos)
		else:
		# On release, bake the transform if needed
			#if active_handle != -1:
				#bake_transform()
			active_handle = null
	elif event is InputEventMouseMotion and active_handle != null:
		_handle_mouse_drag(mouse_pos)
	elif event.is_action_pressed(&"ui_accept"):  # TEMP
		bake_transform()


func _handle_mouse_press(mouse_pos: Vector2) -> void:
	# Begin dragging handle or moving the image.
	var clicked_handle: TransformHandle = null
	for handle in handles:
		if get_handle_position(handle).distance_to(mouse_pos) < HANDLE_RADIUS:
			clicked_handle = handle
			break
	if clicked_handle != null:
		active_handle = clicked_handle
	else:
		# Start moving if clicked inside image.
		var local_click := preview_transform.affine_inverse() * mouse_pos
		var img_rect := Rect2(Vector2.ZERO, base_image.get_size())
		if img_rect.has_point(local_click):
			active_handle = handles[0]
		else:
			active_handle = null
	if active_handle != null:
		drag_start = mouse_pos
		start_transform = preview_transform


func _handle_mouse_drag(mouse_pos: Vector2) -> void:
	# Update preview_transform based which handle we're dragging, or moving the image
	preview_transform = start_transform
	var delta := mouse_pos - drag_start
	match active_handle.type:
		TransformHandle.Type.MOVE:
			preview_transform = preview_transform.translated(delta)
		TransformHandle.Type.SCALE:
			preview_transform = apply_resize(preview_transform, active_handle, delta)
		TransformHandle.Type.ROTATE:
			preview_transform = apply_rotate(preview_transform, mouse_pos)
		TransformHandle.Type.SKEW:
			preview_transform = apply_shear(preview_transform, delta, active_handle)
	queue_redraw()


func _draw() -> void:
	image_texture.set_image(base_image)
	draw_set_transform_matrix(preview_transform)
	draw_texture(image_texture, Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)

	# Draw handles
	for handle in handles:
		var pos := get_handle_position(handle)
		var color := Color.RED
		if handle.type == TransformHandle.Type.MOVE:
			continue
		elif handle.type == TransformHandle.Type.ROTATE:
			color = Color.ORANGE
		elif handle.type == TransformHandle.Type.SKEW:
			color = Color.GREEN
		draw_circle(pos, HANDLE_RADIUS, color)


func get_handle_position(handle: TransformHandle) -> Vector2:
	var image_size := base_image.get_size()
	var local := Vector2(image_size.x * handle.pos.x, image_size.y * handle.pos.y)
	return preview_transform * local


## Apply an affine transform [param m] around [param pivot_local] onto [param t].
func transform_around(t: Transform2D, m: Transform2D, pivot_local: Vector2) -> Transform2D:
	var pivot_world := t * pivot_local
	var to_origin := Transform2D(Vector2(1, 0), Vector2(0, 1), -pivot_world)
	var back := Transform2D(Vector2(1, 0), Vector2(0, 1), pivot_world)
	return back * m * to_origin * t


func apply_resize(t: Transform2D, handle: TransformHandle, delta: Vector2) -> Transform2D:
	var image_size := base_image.get_size() as Vector2
	# Step 1: Convert drag to local space
	var local_start := t.affine_inverse() * drag_start
	var local_now := t.affine_inverse() * (drag_start + delta)
	var local_delta := local_now - local_start

	# Step 2: Determine resize axis and direction
	var scale_x := 1.0
	var scale_y := 1.0
	var anchor_norm := handle.get_anchor()
	if anchor_norm.x == 0:
		scale_x = (image_size.x + local_delta.x) / image_size.x
	elif anchor_norm.x == 1:
		scale_x = (image_size.x - local_delta.x) / image_size.x
	if anchor_norm.y == 0:
		scale_y = (image_size.y + local_delta.y) / image_size.y
	elif anchor_norm.y == 1:
		scale_y = (image_size.y - local_delta.y) / image_size.y

	if Input.is_action_pressed("shape_center"):
		anchor_norm = Vector2(0.5, 0.5)
	if Input.is_action_pressed("shape_perfect"):
		var u := 1.0 + maxf(local_delta.x / image_size.x, local_delta.y / image_size.y)
		scale_x = u
		scale_y = u
	# Step 3: Build scaled basis vectors from original
	var bx := t.x.normalized() * t.x.length() * scale_x
	var by := t.y.normalized() * t.y.length() * scale_y
	var new_t := Transform2D(bx, by, t.origin)

	# Step 4: Keep anchor in place
	var local_anchor := anchor_norm * image_size
	var world_anchor_before := t * local_anchor
	var world_anchor_after := new_t * local_anchor
	new_t.origin += world_anchor_before - world_anchor_after

	return new_t


## Rotation around pivot based on initial drag.
func apply_rotate(t: Transform2D, mouse_pos: Vector2) -> Transform2D:
	# Compute initial and current angles
	var start_vec := drag_start - pivot
	var curr_vec := mouse_pos - pivot
	var delta_ang := fposmod(curr_vec.angle() - start_vec.angle(), TAU)
	var m := Transform2D().rotated(delta_ang)
	return transform_around(t, m, pivot)


func apply_shear(t: Transform2D, delta: Vector2, handle: TransformHandle) -> Transform2D:
	var image_size := base_image.get_size() as Vector2
	var handle_global_position := get_handle_position(handle)
	var center := pivot * t
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
	return transform_around(start_transform, shear_matrix, pivot)


## Checks if [param angle] is between [param lower] and [param upper] degrees.
func in_range(angle: float, lower: float, upper: float) -> bool:
	angle = fmod(angle, 360)
	lower = fmod(lower, 360)
	upper = fmod(upper, 360)
	if lower > upper:
		return angle >= lower or angle <= upper
	return angle > lower and angle < upper


func bake_transform() -> void:
	# Destructively apply preview_transform to base_image
	DrawingAlgos.transform_image_with_transform2d(base_image, preview_transform, pivot)
	pivot = base_image.get_size() / 2
	# Reset preview_transform
	#var offset := preview_transform.get_origin()
	preview_transform = Transform2D()
	#preview_transform = Transform2D().translated(offset)
	queue_redraw()
