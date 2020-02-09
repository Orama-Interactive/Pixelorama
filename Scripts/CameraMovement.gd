extends Camera2D

var tween : Tween
var zoom_min := Vector2(0.005, 0.005)
var zoom_max := Vector2.ONE
var viewport_container : ViewportContainer
var mouse_pos := Vector2.ZERO
var drag := false

func _ready() -> void:
	viewport_container = get_parent().get_parent()
	tween = Tween.new()
	add_child(tween)

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
		elif event is InputEventMouseMotion && drag:
			offset = offset - event.relative * zoom

# Zoom Camera
func zoom_camera(dir : int) -> void:
	var viewport_size := viewport_container.rect_size
	if Global.smooth_zoom:
		var zoom_margin = zoom * dir / 5
		var new_zoom = zoom + zoom_margin
		if new_zoom > zoom_min && new_zoom < zoom_max:
			var new_offset = offset + (-0.5 * viewport_size + mouse_pos) * (zoom - new_zoom)
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

		offset = offset + (-0.5 * viewport_size + mouse_pos) * (prev_zoom - zoom)

	if name == "Camera2D":
		Global.zoom_level_label.text = str(round(100 / Global.camera.zoom.x)) + " %"
