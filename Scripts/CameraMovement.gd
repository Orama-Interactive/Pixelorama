extends Camera2D

var zoom_min := Vector2(0.005, 0.005)
var zoom_max := Vector2.ONE
var viewport_container : ViewportContainer
var drag := false

func _ready() -> void:
	viewport_container = get_parent().get_parent()

func _input(event) -> void:
	var mouse_pos := viewport_container.get_local_mouse_position()
	var viewport_size := viewport_container.rect_size
	if event.is_action_pressed("camera_drag"):
		drag = true
	elif event.is_action_released("camera_drag"):
		drag = false

	if Global.can_draw && Global.has_focus && Rect2(Vector2.ZERO, viewport_size).has_point(mouse_pos):
		if event.is_action_pressed("zoom_in"): # Wheel Up Event
			zoom_camera(-1)
		elif event.is_action_pressed("zoom_out"): # Wheel Down Event
			zoom_camera(1)
		elif event is InputEventMouseMotion && drag:
			offset = offset - event.relative * zoom

# Zoom Camera
func zoom_camera(dir : int) -> void:
	var zoom_margin = zoom * dir / 10
	#if zoom + zoom_margin > zoom_min && zoom + zoom_margin < zoom_max:
	if zoom + zoom_margin > zoom_min:
		zoom += zoom_margin

	if zoom > zoom_max:
		zoom = zoom_max
	if name == "Camera2D":
		Global.zoom_level_label.text = "Zoom: x%s" % [stepify(1 / zoom.x, 0.01)]
