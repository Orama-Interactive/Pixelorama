extends Camera2D

signal zoom_changed
signal rotation_changed

enum Cameras { MAIN, SECOND, SMALL }

const CAMERA_SPEED_RATE := 15.0

@export var index := 0

var zoom_in_max := Vector2(500, 500)
var zoom_out_max := Vector2(0.01, 0.01)
var viewport_container: SubViewportContainer
var transparent_checker: ColorRect
var mouse_pos := Vector2.ZERO
var drag := false
var rotation_slider: ValueSlider
var zoom_slider: ValueSlider
var should_tween := true


func _ready() -> void:
	set_process_input(false)
	if index == Cameras.MAIN:
		rotation_slider = Global.top_menu_container.get_node("%RotationSlider")
		rotation_slider.value_changed.connect(_rotation_value_changed)
		zoom_slider = Global.top_menu_container.get_node("%ZoomSlider")
		zoom_slider.value_changed.connect(_zoom_value_changed)
	zoom_changed.connect(_zoom_changed)
	rotation_changed.connect(_rotation_changed)
	ignore_rotation = false
	viewport_container = get_parent().get_parent()
	transparent_checker = get_parent().get_node("TransparentChecker")
	update_transparent_checker_offset()


func _rotation_value_changed(value: float) -> void:
	# Negative makes going up rotate clockwise
	var degrees := -value
	var difference := degrees - rotation_degrees
	var canvas_center: Vector2 = Global.current_project.size / 2
	offset = (offset - canvas_center).rotated(deg_to_rad(difference)) + canvas_center
	rotation_degrees = wrapf(degrees, -180, 180)
	rotation_changed.emit()


func _zoom_value_changed(value: float) -> void:
	if value <= 0:
		value = 1
	var new_zoom := Vector2(value, value) / 100.0
	if zoom == new_zoom:
		return
	if Global.smooth_zoom and should_tween:
		var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
		tween.step_finished.connect(_on_tween_step)
		tween.tween_property(self, "zoom", new_zoom, 0.05)
	else:
		zoom = new_zoom
		zoom_changed.emit()


func update_transparent_checker_offset() -> void:
	var o := get_global_transform_with_canvas().get_origin()
	var s := get_global_transform_with_canvas().get_scale()
	o.y = get_viewport_rect().size.y - o.y
	transparent_checker.update_offset(o, s)


func _input(event: InputEvent) -> void:
	if !Global.can_draw:
		drag = false
		return
	mouse_pos = viewport_container.get_local_mouse_position()
	if event.is_action_pressed("pan"):
		drag = true
	elif event.is_action_released("pan"):
		drag = false
	elif event.is_action_pressed("zoom_in", false, true):  # Wheel Up Event
		zoom_camera(1)
	elif event.is_action_pressed("zoom_out", false, true):  # Wheel Down Event
		zoom_camera(-1)

	elif event is InputEventMagnifyGesture:  # Zoom Gesture on a laptop touchpad
		if event.factor < 1:
			zoom_camera(1)
		else:
			zoom_camera(-1)
	elif event is InputEventPanGesture and OS.get_name() != "Android":
		# Pan Gesture on a laptop touchpad
		offset = offset + event.delta.rotated(rotation) * 7.0 / zoom
	elif event is InputEventMouseMotion:
		if drag:
			offset = offset - event.relative.rotated(rotation) / zoom
			update_transparent_checker_offset()
			_update_rulers()
	else:
		var velocity := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
		if velocity != Vector2.ZERO and !_has_selection_tool():
			offset += (velocity.rotated(rotation) / zoom) * CAMERA_SPEED_RATE
			_update_rulers()

	save_values_to_project()


func _has_selection_tool() -> bool:
	for slot in Tools._slots.values():
		if slot.tool_node is SelectionTool:
			return true
	return false


# Rotate Camera
func _rotate_camera_around_point(degrees: float, point: Vector2) -> void:
	offset = (offset - point).rotated(deg_to_rad(degrees)) + point
	rotation_degrees = wrapf(rotation_degrees + degrees, -180, 180)
	rotation_changed.emit()


func _rotation_changed() -> void:
	if index == Cameras.MAIN:
		# Negative to make going up in value clockwise, and match the spinbox which does the same
		var degrees := wrapf(-rotation_degrees, -180, 180)
		rotation_slider.value = degrees
		_update_rulers()


func zoom_camera(dir: int) -> void:
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
					(-0.5 * viewport_size + mouse_pos).rotated(rotation)
					* (Vector2.ONE / zoom - Vector2.ONE / new_zoom)
				)
			)
			var tween := create_tween().set_parallel()
			tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
			tween.step_finished.connect(_on_tween_step)
			tween.tween_property(self, "zoom", new_zoom, 0.05)
			tween.tween_property(self, "offset", new_offset, 0.05)
	else:
		var prev_zoom := zoom
		var zoom_margin := zoom * dir / 10
		if Global.integer_zoom:
			zoom_margin = (Vector2.ONE * dir).floor()
		if zoom + zoom_margin < zoom_in_max:
			zoom += zoom_margin
		if zoom < zoom_out_max:
			zoom = zoom_out_max
		offset = (
			offset
			+ (
				(-0.5 * viewport_size + mouse_pos).rotated(rotation)
				* (Vector2.ONE / prev_zoom - Vector2.ONE / zoom)
			)
		)
		zoom_changed.emit()


func _zoom_changed() -> void:
	update_transparent_checker_offset()
	if index == Cameras.MAIN:
		zoom_slider.value = zoom.x * 100.0
		_update_rulers()
		for guide in Global.current_project.guides:
			guide.width = 1.0 / zoom.x * 2


func _update_rulers() -> void:
	Global.horizontal_ruler.queue_redraw()
	Global.vertical_ruler.queue_redraw()


func _on_tween_step(_idx: int) -> void:
	should_tween = false
	zoom_changed.emit()
	should_tween = true


func zoom_100() -> void:
	zoom = Vector2.ONE
	offset = Global.current_project.size / 2
	zoom_changed.emit()


func fit_to_frame(size: Vector2) -> void:
	# temporarily disable integer zoom
	var reset_integer_zoom := Global.integer_zoom
	if reset_integer_zoom:
		Global.integer_zoom = !Global.integer_zoom
	offset = size / 2

	# Adjust to the rotated size:
	if rotation != 0.0:
		# Calculating the rotated corners of the frame to find its rotated size
		var a := Vector2.ZERO  # Top left
		var b := Vector2(size.x, 0).rotated(rotation)  # Top right
		var c := Vector2(0, size.y).rotated(rotation)  # Bottom left
		var d := Vector2(size.x, size.y).rotated(rotation)  # Bottom right

		# Find how far apart each opposite point is on each axis, and take the longer one
		size.x = maxf(absf(a.x - d.x), absf(b.x - c.x))
		size.y = maxf(absf(a.y - d.y), absf(b.y - c.y))

	viewport_container = get_parent().get_parent()
	var h_ratio := viewport_container.size.x / size.x
	var v_ratio := viewport_container.size.y / size.y
	var ratio := minf(h_ratio, v_ratio)
	if ratio == 0 or !viewport_container.visible:
		ratio = 0.1  # Set it to a non-zero value just in case
		# If the ratio is 0, it means that the viewport container is hidden
		# in that case, use the other viewport to get the ratio
		if index == Cameras.MAIN:
			h_ratio = Global.second_viewport.size.x / size.x
			v_ratio = Global.second_viewport.size.y / size.y
			ratio = minf(h_ratio, v_ratio)
		elif index == Cameras.SECOND:
			h_ratio = Global.main_viewport.size.x / size.x
			v_ratio = Global.main_viewport.size.y / size.y
			ratio = minf(h_ratio, v_ratio)

	ratio = clampf(ratio, 0.1, ratio)
	zoom = Vector2(ratio, ratio)
	zoom_changed.emit()
	if reset_integer_zoom:
		Global.integer_zoom = !Global.integer_zoom


func save_values_to_project() -> void:
	Global.current_project.cameras_rotation[index] = rotation
	Global.current_project.cameras_zoom[index] = zoom
	Global.current_project.cameras_offset[index] = offset
