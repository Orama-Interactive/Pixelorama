extends Camera2D

var zoom_min := Vector2(0.005, 0.005)
var zoom_max := Vector2(0.8, 0.8)

var drag := false

func _input(event) -> void:
	if Global.can_draw && Global.has_focus:
		if event.is_action_pressed("camera_drag"):
			drag = true
		elif event.is_action_released("camera_drag"):
			drag = false
		elif event.is_action_pressed("zoom_in"): # Wheel Up Event
			zoom_camera(-1)
		elif event.is_action_pressed("zoom_out"): # Wheel Down Event
			zoom_camera(1)
		elif event is InputEventMouseMotion && drag:
			offset = offset - event.relative * zoom

# Zoom Camera
func zoom_camera(dir : int) -> void:
	var zoom_margin = zoom * dir / 10
	if zoom + zoom_margin > zoom_min && zoom + zoom_margin < zoom_max:
		zoom += zoom_margin