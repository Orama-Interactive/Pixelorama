extends VBoxContainer

var has_focus := false
var perspective_lines = []
var color := Color(randf(), randf(), randf(), 1)

var tracker_line: PerspectiveLine
onready var color_picker_button = $"%ColorPickerButton"
onready var title := $"%PointCollapseContainer"
onready var pos_x := $"%X"
onready var pos_y := $"%Y"
onready var line_buttons_container := $"%LinesContainer"
onready var boundary_l := $Content/BoundaryL
onready var boundary_r := $Content/BoundaryR
onready var boundary_b := $Content/VBoxContainer/BoundaryB


func serialize() -> Dictionary:
	var lines_data := []
	for line in perspective_lines:
		lines_data.append(line.serialize())
	var data = {
		"pos_x": pos_x.value,
		"pos_y": pos_y.value,
		"lines": lines_data,
		"color": color.to_html(),
	}
	return data


func deserialize(start_data: Dictionary):
	if start_data:  # Data is not {} means the project knows about this point
		if start_data.has("pos_x") and start_data.has("pos_y"):
			pos_x.value = start_data.pos_x
			pos_y.value = start_data.pos_y
		if start_data.has("color"):
			color = Color(start_data.color)
		# Add lines if their data is provided
		if start_data.has("lines"):
			for line_data in start_data["lines"]:
				add_line(line_data)
	else:  # If the project doesn't know about this point
		update_data_to_project()

	add_line({}, true)  # This is a tracker line (Always follows mouse)
	color_picker_button.color = color
	update_boundary_color()


func initiate(start_data: Dictionary = {}, idx = -1) -> void:
	deserialize(start_data)
	# Title of Vanishing point button
	if idx != -1:  # If the initialization is part of a Redo
		title.point_text = str("Point: ", idx + 1)
	else:
		title.point_text = str("Point: ", get_parent().get_child_count())
	# connect signals
	color_picker_button.connect("color_changed", self, "_on_color_changed")
	pos_x.connect("value_changed", self, "_on_pos_value_changed")
	pos_y.connect("value_changed", self, "_on_pos_value_changed")


func update_boundary_color():
	var luminance = (0.2126 * color.r) + (0.7152 * color.g) + (0.0722 * color.b)
	color.a = 0.9 - luminance * 0.4  # Interpolates between 0.5 to 0.9
	boundary_l.color = color
	boundary_r.color = color
	boundary_b.color = color


func _input(_event):
	var mouse_point = Global.canvas.current_pixel
	var project_size = Global.current_project.size
	var start = Vector2(pos_x.value, pos_y.value)
	if (
		Input.is_action_just_pressed("left_mouse")
		and Global.can_draw
		and Global.has_focus
		and mouse_point.distance_to(start) < Global.camera.zoom.x * 8
	):
		if (
			!Rect2(Vector2.ZERO, project_size).has_point(Global.canvas.current_pixel)
			or Global.move_guides_on_canvas
		):
			has_focus = true
			Global.has_focus = false
	if has_focus:
		if Input.is_action_pressed("left_mouse"):
			# rotation code here
			pos_x.value = mouse_point.x
			pos_y.value = mouse_point.y

		elif Input.is_action_just_released("left_mouse"):
			Global.has_focus = true
			has_focus = false


# Signals
func _on_AddLine_pressed() -> void:
	add_line()
	update_data_to_project()


func _on_Delete_pressed() -> void:
	Global.perspective_editor.delete_point(get_index())


func _on_color_changed(_color: Color):
	update_boundary_color()
	color = _color
	refresh(-1)
	update_data_to_project()


func _on_pos_value_changed(_value: float) -> void:
	refresh(-1)
	update_data_to_project()


func angle_changed(value: float, line_button):
	# check if the properties are changing the line or is the line changing properties
	var angle_slider = line_button.find_node("AngleSlider")
	if angle_slider.value != value:  # the line is changing the properties
		angle_slider.value = value
	else:
		var line_index = line_button.get_index()
		perspective_lines[line_index].angle = value
		refresh(line_index)
	update_data_to_project()


func length_changed(value: float, line_button):
	# check if the properties are changing the line or is the line changing properties
	var length_slider = line_button.find_node("LengthSlider")
	if length_slider.value != value:  # the line is changing the properties
		length_slider.value = value
	else:
		var line_index = line_button.get_index()
		perspective_lines[line_index].length = value
		refresh(line_index)
	update_data_to_project()


func _remove_line_pressed(line_button):
	var index = line_button.get_index()
	remove_line(index)
	line_button.queue_free()
	update_data_to_project()


# Methods
func generate_line_data(initial_data: Dictionary = {}) -> Dictionary:
	# The default data
	var line_data = {"angle": 0, "length": 19999}
	# If any data needs to be changed by initial_data from project (or possibly by redo data)
	if initial_data.has("angle"):
		line_data.angle = initial_data["angle"]
	if initial_data.has("length"):
		line_data.length = initial_data["length"]
	return line_data


func add_line(loaded_line_data := {}, is_tracker := false):
	var p_size = Global.current_project.size  # for use later in function

	# Note: line_data will automatically get default values if loaded_line_data = {}
	var line_data = generate_line_data(loaded_line_data)

	# This code in if block is purely for beautification
	if pos_x.value > p_size.x / 2 and !loaded_line_data:
		# If new line is created ahed of half project distance then
		# reverse it's angle
		line_data.angle = 180

	if is_tracker:  # if we are creating tracker line then length adjustment is not required
		if tracker_line != null:  # Also if the tracker line already exists then cancel creation
			return
	else:  # If we are not creating a perspective line then adjust it's length
		if !loaded_line_data:
			line_data.length = p_size.x

	# Create the visual line
	var line = preload("res://src/UI/PerspectiveEditor/PerspectiveLine.tscn").instance()
	line.initiate(line_data, self)

	# Set it's mode accordingly
	if is_tracker:  # Settings for Tracker mode
		line.track_mouse = true
		tracker_line = line
		tracker_line.hide_perspective_line()
	else:  # Settings for Normal mode
		var line_button = preload("res://src/UI/PerspectiveEditor/LineButton.tscn").instance()
		line_buttons_container.add_child(line_button)
		var index = line_button.get_parent().get_child_count() - 2
		line_button.get_parent().move_child(line_button, index)

		var line_name = str(
			"Line", line_button.get_index() + 1, " (", int(abs(line_data.angle)), "°)"
		)
		line_button.text = line_name

		var remove_button = line_button.find_node("Delete")
		var angle_slider = line_button.find_node("AngleSlider")
		var length_slider = line_button.find_node("LengthSlider")

		angle_slider.value = abs(line_data.angle)
		length_slider.value = line_data.length

		line.line_button = line_button  # In case we need to change properties from line
		angle_slider.connect("value_changed", self, "angle_changed", [line_button])
		length_slider.connect("value_changed", self, "length_changed", [line_button])
		remove_button.connect("pressed", self, "_remove_line_pressed", [line_button])
		perspective_lines.append(line)


func remove_line(line_index):
	var line_to_remove = perspective_lines[line_index]
	perspective_lines.remove(line_index)
	line_to_remove.queue_free()


func update_data_to_project(removal := false):
	var project = Global.current_project
	var idx = get_index()
	# If deletion is requested
	if removal:
		project.vanishing_points.remove(idx)
		return
	# If project knows about this vanishing point then update it
	var data = serialize()
	if idx < project.vanishing_points.size():
		project.vanishing_points[idx] = data
	# If project doesn't know about this vanishing point then NOW it knows
	else:
		project.vanishing_points.append(data)
	Global.current_project.has_changed = true


func refresh(index: int):
	if index == -1:  # means all lines should be refreshed (including the tracker line)
		refresh_tracker()
		for i in perspective_lines.size():
			refresh_line(i)
	else:
		refresh_line(index)


func refresh_line(index: int):
	var line_button = line_buttons_container.get_child(index)
	var line_data = perspective_lines[index].serialize()
	var line_name = str("Line", line_button.get_index() + 1, " (", int(abs(line_data.angle)), "°)")
	line_button.text = line_name
	perspective_lines[index].refresh()


func refresh_tracker():
	tracker_line.refresh()


func _exit_tree() -> void:
	if tracker_line:
		tracker_line.queue_free()
		tracker_line = null
	for idx in perspective_lines.size():
		perspective_lines[idx].queue_free()
