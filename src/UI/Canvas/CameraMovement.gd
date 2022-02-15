extends Camera2D

enum Cameras { MAIN, SECOND, SMALL }
enum Direction { UP, DOWN, LEFT, RIGHT }

const LOW_SPEED_MOVE_RATE := 150.0
const MEDIUM_SPEED_MOVE_RATE := 750.0
const HIGH_SPEED_MOVE_RATE := 3750.0
const KEY_MOVE_ACTION_NAMES := ["ui_up", "ui_down", "ui_left", "ui_right"]
# Holds sign multipliers for the given directions nyaa
# (per the indices defined by Direction)
# UP, DOWN, LEFT, RIGHT in that order
const DIRECTIONAL_SIGN_MULTIPLIERS := [
	Vector2(0.0, -1.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0), Vector2(1.0, 0.0)
]

# Indices are as in the Direction enum
# This is the total time the key for that direction has been pressed.
var key_move_press_time := [0.0, 0.0, 0.0, 0.0]
var tween: Tween
var zoom_min := Vector2(0.005, 0.005)
var zoom_max := Vector2.ONE
var viewport_container: ViewportContainer
var transparent_checker: ColorRect
var mouse_pos := Vector2.ZERO
var drag := false
var index := 0


func _ready() -> void:
	rotating = true
	viewport_container = get_parent().get_parent()
	transparent_checker = get_parent().get_node("TransparentChecker")
	tween = Tween.new()
	add_child(tween)
	tween.connect("tween_step", self, "_on_tween_step")
	update_transparent_checker_offset()

	# signals regarding rotation stats
	Global.rotation_level_button.connect("pressed", self, "_rotation_button_pressed")
	Global.rotation_level_spinbox.connect("value_changed", self, "_rotation_value_changed")
	Global.rotation_level_spinbox.get_child(0).connect(
		"focus_exited", self, "_rotation_focus_exited"
	)

	# signals regarding zoom stats
	Global.zoom_level_button.connect("pressed", self, "_zoom_button_pressed")
	Global.zoom_level_spinbox.connect("value_changed", self, "_zoom_value_changed")
	Global.zoom_level_spinbox.max_value = 100.0 / zoom_min.x
	Global.zoom_level_spinbox.get_child(0).connect("focus_exited", self, "_zoom_focus_exited")


func _rotation_button_pressed() -> void:
	Global.rotation_level_button.visible = false
	Global.rotation_level_spinbox.visible = true
	Global.rotation_level_spinbox.editable = true
	Global.rotation_level_spinbox.value = str2var(
		Global.rotation_level_button.text.replace("°", "")
	)
	# Since the actual LineEdit is the first child of SpinBox
	Global.rotation_level_spinbox.get_child(0).grab_focus()


func _rotation_value_changed(value) -> void:
	if index == Cameras.MAIN:
		_set_camera_rotation_degrees(-value)  # Negative makes going up rotate clockwise


func _rotation_focus_exited() -> void:
	if Global.rotation_level_spinbox.value != rotation:  # If user pressed enter while editing
		if index == Cameras.MAIN:
			# Negative makes going up rotate clockwise
			_set_camera_rotation_degrees(-Global.rotation_level_spinbox.value)
	Global.rotation_level_button.visible = true
	Global.rotation_level_spinbox.visible = false
	Global.rotation_level_spinbox.editable = false


func _zoom_button_pressed() -> void:
	Global.zoom_level_button.visible = false
	Global.zoom_level_spinbox.visible = true
	Global.zoom_level_spinbox.editable = true
	Global.zoom_level_spinbox.value = str2var(Global.zoom_level_button.text.replace("%", ""))
	# Since the actual LineEdit is the first child of SpinBox
	Global.zoom_level_spinbox.get_child(0).grab_focus()


func _zoom_value_changed(value) -> void:
	if index == Cameras.MAIN:
		zoom_camera_percent(value)


func _zoom_focus_exited() -> void:
	if Global.zoom_level_spinbox.value != round(100 / zoom.x):  # If user pressed enter while editing
		if index == Cameras.MAIN:
			zoom_camera_percent(Global.zoom_level_spinbox.value)
	Global.zoom_level_button.visible = true
	Global.zoom_level_spinbox.visible = false
	Global.zoom_level_spinbox.editable = false


func update_transparent_checker_offset() -> void:
	var o = get_global_transform_with_canvas().get_origin()
	var s = get_global_transform_with_canvas().get_scale()
	o.y = get_viewport_rect().size.y - o.y
	transparent_checker.update_offset(o, s)


# Get the speed multiplier for when you've pressed
# a movement key for the given amount of time
func _dir_move_zoom_multiplier(press_time: float) -> float:
	if press_time < 0:
		return 0.0
	if Input.is_key_pressed(KEY_SHIFT) and Input.is_key_pressed(KEY_CONTROL):
		return HIGH_SPEED_MOVE_RATE
	elif Input.is_key_pressed(KEY_SHIFT):
		return MEDIUM_SPEED_MOVE_RATE
	elif !Input.is_key_pressed(KEY_CONTROL):
		# control + right/left is used to move frames so
		# we do this check to ensure that there is no conflict
		return LOW_SPEED_MOVE_RATE
	else:
		return 0.0


func _reset_dir_move_time(direction) -> void:
	key_move_press_time[direction] = 0.0


# Check if an event is a ui_up/down/left/right event-press :)
func _is_action_direction_pressed(event: InputEvent, allow_echo: bool = true) -> bool:
	for slot in Tools._slots.values():
		if slot.tool_node is SelectionTool:
			return false
	for action in KEY_MOVE_ACTION_NAMES:
		if event.is_action_pressed(action, allow_echo):
			return true
	return false


# Check if an event is a ui_up/down/left/right event release nya
func _is_action_direction_released(event: InputEvent) -> bool:
	for slot in Tools._slots.values():
		if slot.tool_node is SelectionTool:
			return false
	for action in KEY_MOVE_ACTION_NAMES:
		if event.is_action_released(action):
			return true
	return false


# get the Direction associated with the event.
# if not a direction event return null
func _get_action_direction(event: InputEvent):  # -> Optional[Direction]
	if event.is_action("ui_up"):
		return Direction.UP
	elif event.is_action("ui_down"):
		return Direction.DOWN
	elif event.is_action("ui_left"):
		return Direction.LEFT
	elif event.is_action("ui_right"):
		return Direction.RIGHT
	return null


# Process an action event for a pressed direction
# action
func _process_direction_action_pressed(event: InputEvent) -> void:
	var dir = _get_action_direction(event)
	if dir == null:
		return
	var increment := get_process_delta_time()
	# Count the total time we've been doing this ^.^
	key_move_press_time[dir] += increment
	var this_direction_press_time: float = key_move_press_time[dir]
	var move_speed := _dir_move_zoom_multiplier(this_direction_press_time)
	offset = (
		offset
		+ move_speed * increment * DIRECTIONAL_SIGN_MULTIPLIERS[dir].rotated(rotation) * zoom
	)
	_update_rulers()
	update_transparent_checker_offset()


# Process an action for a release direction action
func _process_direction_action_released(event: InputEvent) -> void:
	var dir = _get_action_direction(event)
	if dir == null:
		return
	_reset_dir_move_time(dir)


func _input(event: InputEvent) -> void:
	if !Global.can_draw:
		drag = false
		return
	mouse_pos = viewport_container.get_local_mouse_position()
	var viewport_size := viewport_container.rect_size
	if !Rect2(Vector2.ZERO, viewport_size).has_point(mouse_pos):
		drag = false
		return

	if event.is_action_pressed("middle_mouse") || event.is_action_pressed("space"):
		drag = true
	elif event.is_action_released("middle_mouse") || event.is_action_released("space"):
		drag = false
	elif event.is_action_pressed("zoom_in"):  # Wheel Up Event
		zoom_camera(-1)
	elif event.is_action_pressed("zoom_out"):  # Wheel Down Event
		zoom_camera(1)
	elif event is InputEventMagnifyGesture:  # Zoom Gesture on a Laptop touchpad
		if event.factor < 1:
			zoom_camera(1)
		else:
			zoom_camera(-1)
	elif event is InputEventPanGesture and OS.get_name() != "Android":
		# Pan Gesture on a Latop touchpad
		offset = offset + event.delta.rotated(rotation) * zoom * 7  # for moving the canvas
	elif event is InputEventMouseMotion && drag:
		offset = offset - event.relative.rotated(rotation) * zoom
		update_transparent_checker_offset()
		_update_rulers()
	elif event is InputEventKey:
		if _is_action_direction_pressed(event):
			_process_direction_action_pressed(event)
		elif _is_action_direction_released(event):
			_process_direction_action_released(event)

	save_values_to_project()


# Rotate Camera
func _rotate_camera_around_point(degrees: float, point: Vector2) -> void:
	offset = (offset - point).rotated(deg2rad(degrees)) + point
	rotation_degrees = wrapf(rotation_degrees + degrees, -180, 180)
	rotation_changed()


func _set_camera_rotation_degrees(degrees: float) -> void:
	var difference := degrees - rotation_degrees
	var canvas_center: Vector2 = Global.current_project.size / 2
	offset = (offset - canvas_center).rotated(deg2rad(difference)) + canvas_center
	rotation_degrees = wrapf(degrees, -180, 180)
	rotation_changed()


func rotation_changed() -> void:
	if index == Cameras.MAIN:
		# Negative to make going up in value clockwise, and match the spinbox which does the same
		Global.rotation_level_button.text = str(wrapi(round(-rotation_degrees), -180, 180)) + " °"
		_update_rulers()


# Zoom Camera
func zoom_camera(dir: int) -> void:
	var viewport_size := viewport_container.rect_size
	if Global.smooth_zoom:
		var zoom_margin = zoom * dir / 5
		var new_zoom = zoom + zoom_margin
		if new_zoom > zoom_min && new_zoom < zoom_max:
			var new_offset = (
				offset
				+ (-0.5 * viewport_size + mouse_pos).rotated(rotation) * (zoom - new_zoom)
			)
			tween.interpolate_property(
				self, "zoom", zoom, new_zoom, 0.05, Tween.TRANS_LINEAR, Tween.EASE_IN
			)
			tween.interpolate_property(
				self, "offset", offset, new_offset, 0.05, Tween.TRANS_LINEAR, Tween.EASE_IN
			)
			tween.start()

	else:
		var prev_zoom := zoom
		var zoom_margin = zoom * dir / 10
		if zoom + zoom_margin > zoom_min:
			zoom += zoom_margin

		if zoom > zoom_max:
			zoom = zoom_max

		offset = offset + (-0.5 * viewport_size + mouse_pos).rotated(rotation) * (prev_zoom - zoom)
		zoom_changed()


func zoom_camera_percent(value: float) -> void:
	var percent: float = 100.0 / value
	var new_zoom = Vector2(percent, percent)
	if Global.smooth_zoom:
		tween.interpolate_property(
			self, "zoom", zoom, new_zoom, 0.05, Tween.TRANS_LINEAR, Tween.EASE_IN
		)
		tween.start()
	else:
		zoom = new_zoom
		zoom_changed()


func zoom_changed() -> void:
	update_transparent_checker_offset()
	if index == Cameras.MAIN:
		Global.zoom_level_button.text = str(round(100 / zoom.x)) + " %"
		Global.canvas.pixel_grid.update()
		_update_rulers()
		for guide in Global.current_project.guides:
			guide.width = zoom.x * 2

		Global.canvas.selection.update_on_zoom(zoom.x)

	elif index == Cameras.SMALL:
		Global.preview_zoom_slider.value = -zoom.x


func _update_rulers() -> void:
	Global.horizontal_ruler.update()
	Global.vertical_ruler.update()


func _on_tween_step(_object: Object, _key: NodePath, _elapsed: float, _value: Object) -> void:
	zoom_changed()


func zoom_100() -> void:
	zoom = Vector2.ONE
	offset = Global.current_project.size / 2
	zoom_changed()


func fit_to_frame(size: Vector2) -> void:
	offset = size / 2

	# Adjust to the rotated size:
	if rotation != 0.0:
		# Calculating the rotated corners of the frame to find its rotated size
		var a := Vector2.ZERO  # Top left
		var b := Vector2(size.x, 0).rotated(rotation)  # Top right
		var c := Vector2(0, size.y).rotated(rotation)  # Bottom left
		var d := Vector2(size.x, size.y).rotated(rotation)  # Bottom right

		# Find how far apart each opposite point is on each axis, and take the longer one
		size.x = max(abs(a.x - d.x), abs(b.x - c.x))
		size.y = max(abs(a.y - d.y), abs(b.y - c.y))

	viewport_container = get_parent().get_parent()
	var h_ratio := viewport_container.rect_size.x / size.x
	var v_ratio := viewport_container.rect_size.y / size.y
	var ratio := min(h_ratio, v_ratio)
	if ratio == 0 or !viewport_container.visible:
		ratio = 0.1  # Set it to a non-zero value just in case
		# If the ratio is 0, it means that the viewport container is hidden
		# in that case, use the other viewport to get the ratio
		if index == Cameras.MAIN:
			h_ratio = Global.second_viewport.rect_size.x / size.x
			v_ratio = Global.second_viewport.rect_size.y / size.y
			ratio = min(h_ratio, v_ratio)
		elif index == Cameras.SECOND:
			h_ratio = Global.main_viewport.rect_size.x / size.x
			v_ratio = Global.main_viewport.rect_size.y / size.y
			ratio = min(h_ratio, v_ratio)

	ratio = clamp(ratio, 0.1, ratio)
	zoom = Vector2(1 / ratio, 1 / ratio)
	zoom_changed()


func save_values_to_project() -> void:
	Global.current_project.cameras_rotation[index] = rotation
	Global.current_project.cameras_zoom[index] = zoom
	Global.current_project.cameras_offset[index] = offset
	Global.current_project.cameras_zoom_max[index] = zoom_max
