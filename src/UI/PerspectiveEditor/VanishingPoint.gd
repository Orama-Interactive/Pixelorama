extends VBoxContainer

onready var color_picker_button = $"%ColorPickerButton"
onready var title = $"%Title"
onready var pos_x = $"%X"
onready var pos_y = $"%Y"

var perspective_lines = []
var tracker_line :PerspectiveLine
var data = {
	"position_x": 0,
	"position_y": 0,
	"angles": [],
	"radii": [],
	"color": Color(randf(), randf(), randf(), 0.9).to_html(),
	}


func initiate(start_data = null) -> void:
	if start_data:
		data = start_data.duplicate()
	add_line(null ,true)
	for i in data.angles.size():
		var loaded_line_data = {
			"start": Vector2(data.position_x, data.position_y),
			"angle": data.angles[i],
			"radius": data.radii[i],
			"color" : Color(data.color)
		}
		add_line(loaded_line_data)
	title.text = str("Point: ",get_parent().get_child_count())
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
	queue_free()
	update_data_to_project(true)


func _on_color_changed(_color :Color):
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


func _radius_changed(value: float, line_button):
	var line_index = line_button.get_index()
	data.radii[line_index] = value
	refresh(line_index)
	update_data_to_project()


func _remove_line_pressed(line_button):
	var index = line_button.get_index()
	remove_line(index)
	line_button.queue_free()
	update_data_to_project()


# Methods
func add_line(loaded_line_data = null ,is_tracker := false):
	var default_line_data = {
		"start": Vector2(data.position_x, data.position_y),
		"angle": 0,
		"radius": 19999,
		"color" : Color(data.color)
	}
	# Check if we want the data to be something else
	if loaded_line_data:
		default_line_data = loaded_line_data

	if is_tracker and tracker_line != null:
		# if we want tracker line and it's already present
		return

	# Create the visual line
	var line = preload(
		"res://src/UI/PerspectiveEditor/PerspectiveLine.tscn"
	).instance()
	line.initiate(default_line_data)

	if is_tracker: # It is a line which always follow the mouse
		line.track_mouse = true
		tracker_line = line
	else: # Follow the usuall procedure
		var line_button = preload("res://src/UI/PerspectiveEditor/LineButton.tscn").instance()
		get_node("HBoxContainer/Angles/HBoxContainer").add_child(line_button)
		var index = line_button.get_parent().get_child_count() - 2
		line_button.get_parent().move_child(line_button, index)
		line_button.text = str("Line", line_button.get_index() + 1)

		var properties = line_button.find_node("Properties")
		var remove_button = properties.add_button("Delete", false, "Delete")
		var angle_slider = properties.find_node("AngleSlider")
		var radius_slider = properties.find_node("RadiusSlider")

		angle_slider.value = default_line_data.angle
		radius_slider.value = default_line_data.radius
		if !loaded_line_data:
			data.angles.append(angle_slider.value)
			data.radii.append(radius_slider.value)

		angle_slider.connect("value_changed", self, "_angle_changed", [line_button])
		radius_slider.connect("value_changed", self, "_radius_changed", [line_button])
		remove_button.connect("pressed", self, "_remove_line_pressed", [line_button])
		perspective_lines.append(line)


func remove_line(line_index):
	var line_to_remove = perspective_lines[line_index]
	perspective_lines.remove(line_index)
	data.angles.remove(line_index)
	data.radii.remove(line_index)
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


func refresh(index :int):
	if index == -1: # means all lines should be refreshed
		refresh_tracker()
		for i in data.angles.size():
			refresh_line(i)
	else:
		refresh_line(index)


func refresh_line(index :int):
	var line_data = {
		"start": Vector2(data.position_x, data.position_y),
		"angle": data.angles[index],
		"radius": data.radii[index],
		"color" : Color(data.color)
	}
	perspective_lines[index].refresh(line_data)


func refresh_tracker():
	var line_data = {
		"start": Vector2(data.position_x, data.position_y),
		"angle": tracker_line._data.angle,
		"radius": tracker_line._data.radius,
		"color" : Color(data.color)
	}
	tracker_line.refresh(line_data)


func _exit_tree() -> void:
	if tracker_line:
		tracker_line.queue_free()
		tracker_line = null
	for idx in perspective_lines.size():
		perspective_lines[idx].queue_free()
