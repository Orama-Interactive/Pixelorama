extends Control

const CURSOR_COLOR := Color.BLUE
const CURSOR_WIDTH := 2
const TRIANGLE_SIZE := 8

@export var container: Control

var is_dragged := false


func _ready() -> void:
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragged = true
		else:
			is_dragged = false
	if event is InputEventMouseMotion and is_dragged:
		global_position.x = event.global_position.x
		if not is_instance_valid(container):
			return
		var container_pos := container.get_global_rect().position.x
		var container_end := container.get_global_rect().end.x
		global_position.x = clampf(global_position.x, container_pos, container_end)
		var frame := roundi((global_position.x - container_pos) / KeyframeTimeline.frame_ui_size)
		if frame >= Global.current_project.frames.size():
			return
		# Change frame
		Global.current_project.selected_cels.clear()
		var frame_layer := [frame, Global.current_project.current_layer]
		if !Global.current_project.selected_cels.has(frame_layer):
			Global.current_project.selected_cels.append(frame_layer)

		Global.current_project.change_cel(frame, -1)


func _draw() -> void:
	var cursor_pos := size.x / 2.0
	draw_line(Vector2(cursor_pos, 0), Vector2(cursor_pos, size.y), CURSOR_COLOR, CURSOR_WIDTH)

	var half := TRIANGLE_SIZE * 0.5
	var p1 := Vector2(cursor_pos, TRIANGLE_SIZE)
	var p2 := Vector2(cursor_pos - half, 0)
	var p3 := Vector2(cursor_pos + half, 0)

	draw_polygon([p1, p2, p3], [CURSOR_COLOR])
