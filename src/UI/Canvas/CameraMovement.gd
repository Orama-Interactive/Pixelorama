extends Camera2D


const low_speed_move_rate := 150.0
const medium_speed_move_rate := 750.0
const high_speed_move_rate := 3750.0

var tween : Tween
var zoom_min := Vector2(0.005, 0.005)
var zoom_max := Vector2.ONE
var viewport_container : ViewportContainer
var transparent_checker : ColorRect
var mouse_pos := Vector2.ZERO
var drag := false


func _ready() -> void:
	rotating = true
	viewport_container = get_parent().get_parent()
	transparent_checker = get_parent().get_node("TransparentChecker")
	tween = Tween.new()
	add_child(tween)
	tween.connect("tween_step", self, "_on_tween_step")
	update_transparent_checker_offset()

	# signals regarding rotation stats
	Global.rotation_level_button.connect("pressed",self,"rotation_button_pressed")
	Global.rotation_level_spinbox.connect("value_changed", self, "rotation_value_changed")
	Global.rotation_level_spinbox.get_child(0).connect("focus_exited", self, "rotation_focus_exited")

	# signals regarding zoom stats
	Global.zoom_level_button.connect("pressed",self,"zoom_button_pressed")
	Global.zoom_level_spinbox.connect("value_changed", self, "zoom_value_changed")
	Global.zoom_level_spinbox.max_value = 100.0/zoom_min.x
	Global.zoom_level_spinbox.get_child(0).connect("focus_exited", self, "zoom_focus_exited")


func rotation_button_pressed() -> void:
	Global.rotation_level_button.visible = false
	Global.rotation_level_spinbox.visible = true
	Global.rotation_level_spinbox.editable = true
	Global.rotation_level_spinbox.value = str2var(Global.rotation_level_button.text.replace("°",""))
	Global.rotation_level_spinbox.get_child(0).grab_focus() #since the actual lineedit is the first child of spinbox


func rotation_value_changed(value) -> void:
	if name == "Camera2D":
		set_camera_rotation_degrees(-value) # Negative makes going up rotate clockwise


func rotation_focus_exited() -> void:
	if Global.rotation_level_spinbox.value != rotation: #If user pressed enter while editing
		if name == "Camera2D":
			set_camera_rotation_degrees(-Global.rotation_level_spinbox.value) # Negative makes going up rotate clockwise
	Global.rotation_level_button.visible = true
	Global.rotation_level_spinbox.visible = false
	Global.rotation_level_spinbox.editable = false


func zoom_button_pressed() -> void:
	Global.zoom_level_button.visible = false
	Global.zoom_level_spinbox.visible = true
	Global.zoom_level_spinbox.editable = true
	Global.zoom_level_spinbox.value = str2var(Global.zoom_level_button.text.replace("%",""))
	Global.zoom_level_spinbox.get_child(0).grab_focus() #since the actual lineedit is the first child of spinbox


func zoom_value_changed(value) -> void:
	if name == "Camera2D":
		zoom_camera_percent(value)


func zoom_focus_exited() -> void:
	if Global.zoom_level_spinbox.value != round(100 / zoom.x): #If user pressed enter while editing
		if name == "Camera2D":
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
func dir_move_zoom_multiplier(press_time : float) -> float:
	if press_time < 0:
		return 0.0
	if Input.is_key_pressed(KEY_SHIFT) and Input.is_key_pressed(KEY_CONTROL) :
		return high_speed_move_rate
	elif Input.is_key_pressed(KEY_SHIFT):
		return medium_speed_move_rate
	elif !Input.is_key_pressed(KEY_CONTROL):
		# control + right/left is used to move frames so
		# we do this check to ensure that there is no conflict
		return low_speed_move_rate
	else:
		return 0.0


func reset_dir_move_time(direction) -> void:
	Global.key_move_press_time[direction] = 0.0


const key_move_action_names := ["ui_up", "ui_down", "ui_left", "ui_right"]

# Check if an event is a ui_up/down/left/right event-press :)
func is_action_direction_pressed(event : InputEvent, allow_echo: bool = true) -> bool:
	for slot in Tools._slots.values():
		if slot.tool_node is SelectionTool:
			return false
	for action in key_move_action_names:
		if event.is_action_pressed(action, allow_echo):
			return true
	return false


# Check if an event is a ui_up/down/left/right event release nya
func is_action_direction_released(event: InputEvent) -> bool:
	for slot in Tools._slots.values():
		if slot.tool_node is SelectionTool:
			return false
	for action in key_move_action_names:
		if event.is_action_released(action):
			return true
	return false


# get the Direction associated with the event.
# if not a direction event return null
func get_action_direction(event: InputEvent):  # -> Optional[Direction]
	if event.is_action("ui_up"):
		return Global.Direction.UP
	elif event.is_action("ui_down"):
		return Global.Direction.DOWN
	elif event.is_action("ui_left"):
		return Global.Direction.LEFT
	elif event.is_action("ui_right"):
		return Global.Direction.RIGHT
	return null


# Holds sign multipliers for the given directions nyaa
# (per the indices in Global.gd defined by Direction)
# UP, DOWN, LEFT, RIGHT in that order
const directional_sign_multipliers := [
	Vector2(0.0, -1.0),
	Vector2(0.0, 1.0),
	Vector2(-1.0, 0.0),
	Vector2(1.0, 0.0)
]


# Process an action event for a pressed direction
# action
func process_direction_action_pressed(event: InputEvent) -> void:
	var dir = get_action_direction(event)
	if dir == null:
		return
	var increment := get_process_delta_time()
	# Count the total time we've been doing this ^.^
	Global.key_move_press_time[dir] += increment
	var this_direction_press_time : float = Global.key_move_press_time[dir]
	var move_speed := dir_move_zoom_multiplier(this_direction_press_time)
	offset = offset + move_speed * increment * directional_sign_multipliers[dir].rotated(rotation) * zoom
	update_rulers()
	update_transparent_checker_offset()


# Process an action for a release direction action
func process_direction_action_released(event: InputEvent) -> void:
	var dir = get_action_direction(event)
	if dir == null:
		return
	reset_dir_move_time(dir)


func _input(event : InputEvent) -> void:
	mouse_pos = viewport_container.get_local_mouse_position()
	var viewport_size := viewport_container.rect_size
	if event.is_action_pressed("middle_mouse") || event.is_action_pressed("space"):
		drag = true
	elif event.is_action_released("middle_mouse") || event.is_action_released("space"):
		drag = false

	if Global.can_draw && Rect2(Vector2.ZERO, viewport_size).has_point(mouse_pos):
		if event.is_action_pressed("zoom_in"): # Wheel Up Event
			zoom_camera(-1)
		elif event.is_action_pressed("zoom_out"): # Wheel Down Event
			zoom_camera(1)
		elif event is InputEventMagnifyGesture: # Zoom Gesture on a Laptop touchpad
			if event.factor < 1:
				zoom_camera(1)
			else:
				zoom_camera(-1)
		elif event is InputEventPanGesture: # Pan Gesture on a Latop touchpad
			offset = offset + event.delta.rotated(rotation) * zoom * 7 # for moving the canvas
			if OS.get_name() == "Android":
				return
			offset = offset + event.delta * zoom * 7 # for moving the canvas
		elif event is InputEventMouseMotion && drag:
			offset = offset - event.relative.rotated(rotation) * zoom
			update_transparent_checker_offset()
			update_rulers()
		elif is_action_direction_pressed(event):
			process_direction_action_pressed(event)
		elif is_action_direction_released(event):
			process_direction_action_released(event)

		save_values_to_project()

# Rotate Camera
func rotate_camera_around_point(degrees: float, point: Vector2) -> void:
	offset = (offset - point).rotated(deg2rad(degrees)) + point
	rotation_degrees = wrapf(rotation_degrees + degrees, -180, 180)
	rotation_changed()

func set_camera_rotation_degrees(degrees: float) -> void:
	var difference :=  degrees - rotation_degrees
	var canvas_center := Global.current_project.size / 2
	offset = (offset - canvas_center).rotated(deg2rad(difference)) + canvas_center
	rotation_degrees = wrapf(degrees, -180, 180)
	rotation_changed()

func rotation_changed() -> void:
	if name == "Camera2D":
		# Negative to make going up in value clockwise, and match the spinbox which does the same
		Global.rotation_level_button.text = str(wrapi(round(-rotation_degrees), -180, 180)) + " °"
		update_rulers()


# Zoom Camera
func zoom_camera(dir : int) -> void:
	var viewport_size := viewport_container.rect_size
	if Global.smooth_zoom:
		var zoom_margin = zoom * dir / 5
		var new_zoom = zoom + zoom_margin
		if new_zoom > zoom_min && new_zoom < zoom_max:
			var new_offset = offset + (-0.5 * viewport_size + mouse_pos).rotated(rotation) * (zoom - new_zoom)
			tween.interpolate_property(self, "zoom", zoom, new_zoom, 0.05, Tween.TRANS_LINEAR, Tween.EASE_IN)
			tween.interpolate_property(self, "offset", offset, new_offset, 0.05, Tween.TRANS_LINEAR, Tween.EASE_IN)
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


func zoom_camera_percent(value : float) -> void:
	var percent :float = (100.0 / value)
	var new_zoom = Vector2(percent, percent)
	if Global.smooth_zoom:
		tween.interpolate_property(self, "zoom", zoom, new_zoom, 0.05, Tween.TRANS_LINEAR, Tween.EASE_IN)
		tween.start()
	else:
		zoom = new_zoom
		zoom_changed()


func zoom_changed() -> void:
	update_transparent_checker_offset()
	if name == "Camera2D":
		Global.zoom_level_button.text = str(round(100 / zoom.x)) + " %"
		Global.canvas.pixel_grid.update()
		update_rulers()
		for guide in Global.current_project.guides:
			guide.width = zoom.x * 2

		Global.canvas.selection.update_on_zoom(zoom.x)

	elif name == "CameraPreview":
		Global.preview_zoom_slider.value = -zoom.x


func update_rulers() -> void:
	Global.horizontal_ruler.update()
	Global.vertical_ruler.update()


func _on_tween_step(_object: Object, _key: NodePath, _elapsed: float, _value: Object) -> void:
	zoom_changed()



func zoom_100() -> void:
	zoom = Vector2.ONE
	offset = Global.current_project.size / 2
	zoom_changed()


func fit_to_frame(size : Vector2) -> void:
	offset = size / 2

	# Adjust to the rotated size:
	if rotation != 0.0:
		# Calculating the rotated corners of the frame to find its rotated size
		var a:= Vector2.ZERO # Top left
		var b:= Vector2(size.x, 0).rotated(rotation) # Top right
		var c:= Vector2(0, size.y).rotated(rotation) # Bottom left
		var d:= Vector2(size.x, size.y).rotated(rotation) # Bottom right

		# Find how far apart each opposite point is on each axis, and take the longer one
		size.x = max(abs(a.x - d.x), abs(b.x - c.x))
		size.y = max(abs(a.y - d.y), abs(b.y - c.y))

	viewport_container = get_parent().get_parent()
	var h_ratio := viewport_container.rect_size.x / size.x
	var v_ratio := viewport_container.rect_size.y / size.y
	var ratio := min(h_ratio, v_ratio)
	if ratio == 0:
		ratio = 0.1 # Set it to a non-zero value just in case
		# If the ratio is 0, it means that the viewport container is hidden
		# in that case, use the other viewport to get the ratio
		if name == "Camera2D":
			h_ratio = Global.second_viewport.rect_size.x / size.x
			v_ratio = Global.second_viewport.rect_size.y / size.y
			ratio = min(h_ratio, v_ratio)
		elif name == "Camera2D2":
			h_ratio = Global.main_viewport.rect_size.x / size.x
			v_ratio = Global.main_viewport.rect_size.y / size.y
			ratio = min(h_ratio, v_ratio)

	ratio = clamp(ratio, 0.1, ratio)
	zoom = Vector2(1 / ratio, 1 / ratio)
	zoom_changed()


func save_values_to_project() -> void:
	if name == "Camera2D":
		Global.current_project.cameras_rotation[0] = rotation
		Global.current_project.cameras_zoom[0] = zoom
		Global.current_project.cameras_offset[0] = offset
		Global.current_project.cameras_zoom_max[0] = zoom_max
	elif name == "Camera2D2":
		Global.current_project.cameras_rotation[1] = rotation
		Global.current_project.cameras_zoom[1] = zoom
		Global.current_project.cameras_offset[1] = offset
		Global.current_project.cameras_zoom_max[1] = zoom_max
	elif name == "CameraPreview":
		Global.current_project.cameras_rotation[2] = rotation
		Global.current_project.cameras_zoom[2] = zoom
		Global.current_project.cameras_offset[2] = offset
		Global.current_project.cameras_zoom_max[2] = zoom_max
