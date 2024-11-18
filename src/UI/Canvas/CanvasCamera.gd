class_name CanvasCamera
extends Node2D

signal zoom_changed
signal rotation_changed
signal offset_changed

enum Cameras { MAIN, SECOND, SMALL }

const CAMERA_SPEED_RATE := 15.0

@export var index := 0

var zoom := Vector2.ONE:
	set(value):
		zoom = value
		Global.current_project.cameras_zoom[index] = zoom
		zoom_changed.emit()
		_update_viewport_transform()
var camera_angle := 0.0:
	set(value):
		camera_angle = wrapf(value, -PI, PI)
		camera_angle_degrees = rad_to_deg(camera_angle)
		Global.current_project.cameras_rotation[index] = camera_angle
		rotation_changed.emit()
		_update_viewport_transform()
var camera_angle_degrees := 0.0
var offset := Vector2.ZERO:
	set(value):
		offset = value
		Global.current_project.cameras_offset[index] = offset
		offset_changed.emit()
		_update_viewport_transform()
var camera_screen_center := Vector2.ZERO
var zoom_in_max := Vector2(500, 500)
var zoom_out_max := Vector2(0.01, 0.01)
var viewport_container: SubViewportContainer
var transparent_checker: ColorRect
var mouse_pos := Vector2.ZERO
var drag := false
var rotation_slider: ValueSlider
var zoom_slider: ValueSlider
var should_tween := true

@onready var viewport := get_viewport()


func _ready() -> void:
	viewport.size_changed.connect(_update_viewport_transform)
	Global.project_switched.connect(_project_switched)
	if not DisplayServer.is_touchscreen_available():
		set_process_input(false)
	if index == Cameras.MAIN:
		rotation_slider = Global.top_menu_container.get_node("%RotationSlider")
		rotation_slider.value_changed.connect(_rotation_slider_value_changed)
		zoom_slider = Global.top_menu_container.get_node("%ZoomSlider")
		zoom_slider.value_changed.connect(_zoom_slider_value_changed)
	zoom_changed.connect(_zoom_changed)
	rotation_changed.connect(_rotation_changed)
	viewport_container = get_viewport().get_parent()
	transparent_checker = get_viewport().get_node("TransparentChecker")
	update_transparent_checker_offset()


func _input(event: InputEvent) -> void:
	get_window().gui_release_focus()
	if !Global.can_draw:
		drag = false
		return
	mouse_pos = viewport_container.get_local_mouse_position()
	if event.is_action_pressed(&"pan"):
		drag = true
	elif event.is_action_released(&"pan"):
		drag = false
	elif event.is_action_pressed(&"zoom_in", false, true):  # Wheel Up Event
		zoom_camera(1)
	elif event.is_action_pressed(&"zoom_out", false, true):  # Wheel Down Event
		zoom_camera(-1)

	elif event is InputEventMagnifyGesture:  # Zoom gesture on touchscreens
		#zoom_camera(event.factor)
		if event.factor >= 1.0:  # Zoom in
			zoom_camera(event.factor * 0.3)
		else:  # Zoom out
			zoom_camera((event.factor * 0.7) - 1.0)
	elif event is InputEventPanGesture:
		# Pan gesture on touchscreens
		offset = offset + event.delta.rotated(camera_angle) * 2.0 / zoom
	elif event is InputEventMouseMotion:
		if drag:
			offset = offset - event.relative.rotated(camera_angle) / zoom
			update_transparent_checker_offset()
	else:
		var dir := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
		if dir != Vector2.ZERO and !_has_selection_tool():
			offset = offset + (dir.rotated(camera_angle) / zoom) * CAMERA_SPEED_RATE


func zoom_camera(dir: float) -> void:
	var viewport_size := viewport_container.size
	if Global.smooth_zoom:
		var zoom_margin := zoom * dir / 5
		var new_zoom := zoom + zoom_margin
		if Global.integer_zoom:
			new_zoom = (zoom + Vector2.ONE * dir).floor()
		if new_zoom < zoom_in_max && new_zoom > zoom_out_max:
			var new_offset := (
				offset
				+ (
					(-0.5 * viewport_size + mouse_pos).rotated(camera_angle)
					* (Vector2.ONE / zoom - Vector2.ONE / new_zoom)
				)
			)
			var tween := create_tween().set_parallel()
			tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
			tween.tween_property(self, "zoom", new_zoom, 0.05)
			tween.tween_property(self, "offset", new_offset, 0.05)
	else:
		var prev_zoom := zoom
		var zoom_margin := zoom * dir / 10
		if Global.integer_zoom:
			zoom_margin = (Vector2.ONE * dir).floor()
		if zoom + zoom_margin <= zoom_in_max:
			zoom += zoom_margin
		if zoom < zoom_out_max:
			if Global.integer_zoom:
				zoom = Vector2.ONE
			else:
				zoom = zoom_out_max
		offset = (
			offset
			+ (
				(-0.5 * viewport_size + mouse_pos).rotated(camera_angle)
				* (Vector2.ONE / prev_zoom - Vector2.ONE / zoom)
			)
		)


func zoom_100() -> void:
	zoom = Vector2.ONE
	offset = Global.current_project.size / 2


func fit_to_frame(size: Vector2) -> void:
	viewport_container = get_viewport().get_parent()
	var h_ratio := viewport_container.size.x / size.x
	var v_ratio := viewport_container.size.y / size.y
	var ratio := minf(h_ratio, v_ratio)
	if ratio == 0 or !viewport_container.visible:
		return
	# Temporarily disable integer zoom.
	var reset_integer_zoom := Global.integer_zoom
	if reset_integer_zoom:
		Global.integer_zoom = !Global.integer_zoom
	offset = size / 2

	# Adjust to the rotated size:
	if camera_angle != 0.0:
		# Calculating the rotated corners of the frame to find its rotated size.
		var a := Vector2.ZERO  # Top left
		var b := Vector2(size.x, 0).rotated(camera_angle)  # Top right.
		var c := Vector2(0, size.y).rotated(camera_angle)  # Bottom left.
		var d := Vector2(size.x, size.y).rotated(camera_angle)  # Bottom right.

		# Find how far apart each opposite point is on each axis, and take the longer one.
		size.x = maxf(absf(a.x - d.x), absf(b.x - c.x))
		size.y = maxf(absf(a.y - d.y), absf(b.y - c.y))

	ratio = clampf(ratio, 0.1, ratio)
	zoom = Vector2(ratio, ratio)
	if reset_integer_zoom:
		Global.integer_zoom = !Global.integer_zoom


func update_transparent_checker_offset() -> void:
	var o := get_global_transform_with_canvas().get_origin()
	var s := get_global_transform_with_canvas().get_scale()
	o.y = get_viewport_rect().size.y - o.y
	transparent_checker.update_offset(o, s)


## Updates the viewport's canvas transform, which is the area of the canvas that is
## currently visible. Called every time the camera's zoom, rotation or origin changes.
func _update_viewport_transform() -> void:
	if not is_instance_valid(viewport):
		return
	var zoom_scale := Vector2.ONE / zoom
	var viewport_size := get_viewport_rect().size
	var screen_offset := viewport_size * 0.5 * zoom_scale
	screen_offset = screen_offset.rotated(camera_angle)
	var screen_rect := Rect2(-screen_offset, viewport_size * zoom_scale)
	screen_rect.position += offset
	var xform := Transform2D(camera_angle, zoom_scale, 0, screen_rect.position)
	camera_screen_center = xform * (viewport_size * 0.5)
	viewport.canvas_transform = xform.affine_inverse()


func _zoom_changed() -> void:
	update_transparent_checker_offset()
	if index == Cameras.MAIN:
		should_tween = false
		zoom_slider.value = zoom.x * 100.0
		should_tween = true
		for guide in Global.current_project.guides:
			guide.width = 1.0 / zoom.x * 2


func _rotation_changed() -> void:
	if index == Cameras.MAIN:
		# Negative to make going up in value clockwise, and match the spinbox which does the same
		rotation_slider.value = -camera_angle_degrees


func _zoom_slider_value_changed(value: float) -> void:
	if value <= 0:
		value = 1
	var new_zoom := Vector2(value, value) / 100.0
	if zoom.is_equal_approx(new_zoom):
		return
	if Global.smooth_zoom and should_tween:
		var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "zoom", new_zoom, 0.05)
	else:
		zoom = new_zoom


func _rotation_slider_value_changed(value: float) -> void:
	# Negative makes going up rotate clockwise
	var angle := deg_to_rad(-value)
	var difference := angle - camera_angle
	var canvas_center: Vector2 = Global.current_project.size / 2
	offset = (offset - canvas_center).rotated(difference) + canvas_center
	camera_angle = angle


func _has_selection_tool() -> bool:
	for slot in Tools._slots.values():
		if slot.tool_node is BaseSelectionTool:
			return true
	return false


func _project_switched() -> void:
	offset = Global.current_project.cameras_offset[index]
	camera_angle = Global.current_project.cameras_rotation[index]
	zoom = Global.current_project.cameras_zoom[index]


func _rotate_camera_around_point(degrees: float, point: Vector2) -> void:
	var angle := deg_to_rad(degrees)
	offset = (offset - point).rotated(angle) + point
	camera_angle = camera_angle + angle
