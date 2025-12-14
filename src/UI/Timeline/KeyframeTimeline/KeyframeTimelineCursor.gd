extends Control

const CURSOR_WIDTH := 2
const TRIANGLE_SIZE := 8

@export var container: Control

var cursor_color := Color.BLUE
var is_dragged := false
var pos := global_position.x:
	set(value):
		pos = value
		global_position.x = pos


func _ready() -> void:
	get_parent().sort_children.connect(func(): global_position.x = pos)
	Global.cel_switched.connect(update_position)
	if is_instance_valid(container):
		container.gui_input.connect(_on_frames_container_gui_input)
		await get_tree().process_frame
		await get_tree().process_frame
		var container_pos := container.get_global_rect().position.x
		pos = container_pos


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		var pressed_cel_button_stylebox := get_theme_stylebox(&"pressed", &"CelButton")
		if pressed_cel_button_stylebox is StyleBoxFlat:
			cursor_color = pressed_cel_button_stylebox.border_color


func _on_frames_container_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragged = true
			_change_cel(event.global_position)
		else:
			is_dragged = false
	if event is InputEventMouseMotion and is_dragged:
		_change_cel(event.global_position)


func _change_cel(new_pos: Vector2) -> void:
	var container_pos := container.get_global_rect().position.x
	var container_end := container.get_global_rect().end.x
	pos = clampf(new_pos.x - (size.x / 2.0), container_pos, container_end)
	var frame := floori((pos - container_pos) / KeyframeTimeline.frame_ui_size)
	frame = clampi(frame, 0, Global.current_project.frames.size() - 1)
	# Change frame
	Global.current_project.selected_cels.clear()
	var frame_layer := [frame, Global.current_project.current_layer]
	if !Global.current_project.selected_cels.has(frame_layer):
		Global.current_project.selected_cels.append(frame_layer)
	Global.current_project.change_cel(frame, -1)


func update_position() -> void:
	if is_dragged:
		return
	var frame := Global.current_project.current_frame
	var container_pos := container.get_global_rect().position.x
	var container_end := container.get_global_rect().end.x
	pos = clampf(
		frame * KeyframeTimeline.frame_ui_size + container_pos, container_pos, container_end
	)


func _draw() -> void:
	var cursor_pos := size.x / 2.0
	draw_line(Vector2(cursor_pos, 0), Vector2(cursor_pos, size.y), cursor_color, CURSOR_WIDTH)

	var half := TRIANGLE_SIZE * 0.5
	var p1 := Vector2(cursor_pos, TRIANGLE_SIZE)
	var p2 := Vector2(cursor_pos - half, 0)
	var p3 := Vector2(cursor_pos + half, 0)

	draw_polygon([p1, p2, p3], [cursor_color])
