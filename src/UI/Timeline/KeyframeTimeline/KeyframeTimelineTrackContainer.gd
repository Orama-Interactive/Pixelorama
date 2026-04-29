extends Control

@export var timeline: KeyframeTimeline

var box_selecting := false
var box_rect := Rect2()
var box_color := Color.SKY_BLUE


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		var pressed_cel_button_stylebox := get_theme_stylebox(&"pressed", &"CelButton")
		if pressed_cel_button_stylebox is StyleBoxFlat:
			box_color = pressed_cel_button_stylebox.bg_color


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				box_selecting = true
				box_rect = Rect2()
				box_rect.position = event.position
			else:
				box_selecting = false
				timeline.unselect_keyframe()
				timeline.append_keyframes_to_selection(box_rect.abs())
				queue_redraw()
	elif event is InputEventMouseMotion:
		if box_selecting:
			box_rect.end = event.position
			queue_redraw()


func _draw() -> void:
	if box_selecting:
		draw_rect(box_rect, box_color)
