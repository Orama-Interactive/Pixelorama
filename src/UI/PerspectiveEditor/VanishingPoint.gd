extends VBoxContainer

var perspective_lines = []
var tracker_line: PerspectiveLine
var data = {
	"position_x": 0,
	"position_y": 0,
	"angles": [],
	"lengths": [],
	"color": Color(randf(), randf(), randf(), 0.9).to_html(),
}

onready var color_picker_button = $"%ColorPickerButton"
onready var title = $"%PointCollapseContainer"
onready var pos_x = $"%X"
onready var pos_y = $"%Y"
onready var line_buttons_container = $"%LinesContainer"


func initiate(start_data = null, idx = -1) -> void:
	if start_data:
		data = start_data.duplicate()
	add_line(null, true)
	for i in data.angles.size():
		var loaded_line_data = {
			"start": Vector2(data.position_x, data.position_y),
			"angle": data.angles[i],
			"length": data.lengths[i],
			"color": Color(data.color)
		}
		add_line(loaded_line_data)
	if idx != -1:
		title.point_text = str("Point: ", idx + 1)
	else:
		title.point_text = str("Point: ", get_parent().get_child_count())
	pos_x.value = data.position_x
	pos_y.value = data.position_y
	color_picker_button.color = Color(data.color)
	color_picker_button.connect("color_changed", self, "_on_color_changed")
	pos_x.connect("value_changed", self, "_on_X_value_changed")
	pos_y.connect("value_changed", self, "_on_Y_value_changed")
	if !start_data:
		update_data_to_project()


# Signals
func _on_AddLine_pressed() -> void:
	add_line()
	update_data_to_project()


func _on_Delete_pressed() -> void:
	Global.perspective_editor.delete_point(get_index())


func _on_color_changed(_color: Color):
	data.color = _color.to_html()
	refresh(-1)
	update_data_to_project()


func _on_X_value_changed(value: float) -> void:
	data.position_x = value
	refresh(-1)
	update_data_to_project()


func _on_Y_value_changed(value):
	data.position_y = value
	refresh(-1)
	update_data_to_project()


func _angle_changed(value: float, line_button):
	var line_index = line_button.get_index()
	data.angles[line_index] = value
	refresh(line_index)
	update_data_to_project()


func _length_changed(value: float, line_button):
	var line_index = line_button.get_index()
	data.lengths[line_index] = value
	refresh(line_index)
	update_data_to_project()


func _remove_line_pressed(line_button):
	var index = line_button.get_index()
	remove_line(index)
	line_button.queue_free()
	update_data_to_project()


# Methods
func add_line(loaded_line_data = null, is_tracker := false):
	var p_size = Global.current_project.size
	var default_line_data = {
		"start": Vector2(data.position_x, data.position_y),
		"angle": 0,
		"length": 19999,
		"color": Color(data.color)
	}
	if default_line_data.start.x > p_size.x / 2:
		# If new line is created ahed of half project distance then
		# reverse it's angle (for beautification)
		default_line_data.angle = 180

	# Check if we have loading data instead of creating line
	# Then THAT should be our data
	if loaded_line_data:
		default_line_data = loaded_line_data

	if is_tracker:  # if we are creating tracker line then length adjustment is not required
		if tracker_line != null:  # Also if the tracker line already exists then cancel creation
			return
	else:  # If we are not creating a perspective line then adjust it's length
		var suitable_length = sqrt(pow(p_size.x, 2) + pow(p_size.y, 2))
		default_line_data.length = suitable_length

	# Create the visual line
	var line = preload("res://src/UI/PerspectiveEditor/PerspectiveLine.tscn").instance()
	line.initiate(default_line_data)

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
			"Line", line_button.get_index() + 1, " (", int(default_line_data.angle), "°)"
		)
		line_button.text = line_name

		var remove_button = line_button.find_node("Delete")
		var angle_slider = line_button.find_node("AngleSlider")
		var length_slider = line_button.find_node("LengthSlider")

		angle_slider.value = default_line_data.angle
		length_slider.value = default_line_data.length
		if !loaded_line_data:
			data.angles.append(angle_slider.value)
			data.lengths.append(length_slider.value)

		angle_slider.connect("value_changed", self, "_angle_changed", [line_button])
		length_slider.connect("value_changed", self, "_length_changed", [line_button])
		remove_button.connect("pressed", self, "_remove_line_pressed", [line_button])
		perspective_lines.append(line)


func remove_line(line_index):
	var line_to_remove = perspective_lines[line_index]
	perspective_lines.remove(line_index)
	data.angles.remove(line_index)
	data.lengths.remove(line_index)
	line_to_remove.queue_free()


func update_data_to_project(removal := false):
	var project = Global.current_project
	var idx = get_index()
	if removal:
		project.vanishing_points.remove(idx)
		return
	if idx < project.vanishing_points.size():
		project.vanishing_points[idx] = data
	else:
		project.vanishing_points.append(data)
	Global.current_project.has_changed = true


func refresh(index: int):
	if index == -1:  # means all lines should be refreshed
		refresh_tracker()
		for i in data.angles.size():
			refresh_line(i)
	else:
		refresh_line(index)


func refresh_line(index: int):
	var line_data = {
		"start": Vector2(data.position_x, data.position_y),
		"angle": data.angles[index],
		"length": data.lengths[index],
		"color": Color(data.color)
	}
	var line_button = line_buttons_container.get_child(index)
	var line_name = str("Line", line_button.get_index() + 1, " (", int(line_data.angle), "°)")
	line_button.text = line_name
	perspective_lines[index].refresh(line_data)


func refresh_tracker():
	var line_data = {
		"start": Vector2(data.position_x, data.position_y),
		"angle": tracker_line._data.angle,
		"length": tracker_line._data.length,
		"color": Color(data.color)
	}
	tracker_line.refresh(line_data)


func _exit_tree() -> void:
	if tracker_line:
		tracker_line.queue_free()
		tracker_line = null
	for idx in perspective_lines.size():
		perspective_lines[idx].queue_free()
