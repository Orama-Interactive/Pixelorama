extends VBoxContainer

# The main data for the vanishing point is kept in "data" dictionary
# whenever you want to make the project aware of a change to the
var data = {
	"position_x": 0,
	"position_y": 0,
	"lines": [],
	"color": Color(randf(), randf(), randf(), 1).to_html(),
}

var perspective_lines = []
var tracker_line: PerspectiveLine

onready var color_picker_button = $"%ColorPickerButton"
onready var title = $"%PointCollapseContainer"
onready var pos_x = $"%X"
onready var pos_y = $"%Y"
onready var line_buttons_container = $"%LinesContainer"
onready var boundary_l = $Content/BoundaryL
onready var boundary_r = $Content/BoundaryR
onready var boundary_b = $Content/VBoxContainer/BoundaryB


class PerspectiveLineData:
	var angle: float = 0
	var length: float = 19999

	func _init(data: Dictionary = {}):
		deserialize(data)

	func serialize() -> Dictionary:
		var data = {
			"angle": angle,
			"length": length,
		}
		return data

	func deserialize(data) -> void:
		if data.has("angle"):
			angle = data["angle"]
		if data.has("length"):
			length = data["length"]


func initiate(start_data: Dictionary = {}, idx = -1) -> void:
	# If an initial vanishing point data is provided by project
	if start_data:
		data = start_data.duplicate()
		if data.has("lines"):
			for line in data["lines"]:
				# Get data from the line resource
				var loaded_line_data = line.serialize()
				# Construct a line using this information
				add_line(loaded_line_data)
	else:  # We are the ones sending the data
		update_data_to_project()

	add_line({}, true)  # This is a tracker line (Always follows mouse)

	# Title of Vanishing point button
	if idx != -1:  # If the initialization is part of a Redo
		title.point_text = str("Point: ", idx + 1)
	else:
		title.point_text = str("Point: ", get_parent().get_child_count())

	# Set-up the properties pannel of the vanishing point
	pos_x.value = data.position_x
	pos_y.value = data.position_y
	color_picker_button.color = Color(data.color)
	update_boundary_color(color_picker_button.color)
	color_picker_button.connect("color_changed", self, "_on_color_changed")
	pos_x.connect("value_changed", self, "_on_X_value_changed")
	pos_y.connect("value_changed", self, "_on_Y_value_changed")


func update_boundary_color(color: Color):
	var luminance = (0.2126 * color.r) + (0.7152 * color.g) + (0.0722 * color.b)
	color.a = 0.9 - luminance * 0.4  # Interpolates between 0.5 to 0.9
	boundary_l.color = color
	boundary_r.color = color
	boundary_b.color = color


# Signals
func _on_AddLine_pressed() -> void:
	add_line()
	update_data_to_project()


func _on_Delete_pressed() -> void:
	Global.perspective_editor.delete_point(get_index())


func _on_color_changed(_color: Color):
	update_boundary_color(_color)
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
	data.lines[line_index].angle = value
	refresh(line_index)
	update_data_to_project()


func _length_changed(value: float, line_button):
	var line_index = line_button.get_index()
	data.lines[line_index].length = value
	refresh(line_index)
	update_data_to_project()


func _remove_line_pressed(line_button):
	var index = line_button.get_index()
	remove_line(index)
	line_button.queue_free()
	update_data_to_project()


# Methods
func add_line(loaded_line_data := {}, is_tracker := false):
	var p_size = Global.current_project.size  # for use later in function

	var line_resource = PerspectiveLineData.new(loaded_line_data)
	# Note: line_data will automatically get default values if loaded_line_data = {}
	var line_data = line_resource.serialize()
	# add som keys that are part of vanishing point (start point and color)
	line_data["start"] = Vector2(data.position_x, data.position_y)
	line_data["color"] = Color(data.color)

	# This code in if block is purely for beautification
	if line_data.start.x > p_size.x / 2:
		# If new line is created ahed of half project distance then
		# reverse it's angle
		line_data.angle = 180
		line_resource.deserialize(line_data)

	if is_tracker:  # if we are creating tracker line then length adjustment is not required
		if tracker_line != null:  # Also if the tracker line already exists then cancel creation
			return
	else:  # If we are not creating a perspective line then adjust it's length
		var suitable_length = sqrt(pow(p_size.x, 2) + pow(p_size.y, 2))
		line_data.length = suitable_length

	# Create the visual line
	var line = preload("res://src/UI/PerspectiveEditor/PerspectiveLine.tscn").instance()
	line.initiate(line_data)

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

		var line_name = str("Line", line_button.get_index() + 1, " (", int(line_data.angle), "°)")
		line_button.text = line_name

		var remove_button = line_button.find_node("Delete")
		var angle_slider = line_button.find_node("AngleSlider")
		var length_slider = line_button.find_node("LengthSlider")

		angle_slider.value = line_data.angle
		length_slider.value = line_data.length
		if !loaded_line_data:
			data.lines.append(line_resource)

		angle_slider.connect("value_changed", self, "_angle_changed", [line_button])
		length_slider.connect("value_changed", self, "_length_changed", [line_button])
		remove_button.connect("pressed", self, "_remove_line_pressed", [line_button])
		perspective_lines.append(line)


func remove_line(line_index):
	var line_to_remove = perspective_lines[line_index]
	perspective_lines.remove(line_index)
	data.lines.remove(line_index)
	line_to_remove.queue_free()


func update_data_to_project(removal := false):
	var project = Global.current_project
	var idx = get_index()
	# If deletion is requested
	if removal:
		project.vanishing_points.remove(idx)
		return
	# If project knows about this vanishing point then update it
	if idx < project.vanishing_points.size():
		project.vanishing_points[idx] = data
	# If project doesn't know about this vanishing point then NOW it knows
	else:
		project.vanishing_points.append(data)
	Global.current_project.has_changed = true


func refresh(index: int):
	if index == -1:  # means all lines should be refreshed
		refresh_tracker()
		for i in data.lines.size():
			refresh_line(i)
	else:
		refresh_line(index)


func refresh_line(index: int):
	var line_resource = data.lines[index]
	var line_data = line_resource.serialize()
	# add some keys that are part of vanishing point (start point and color)
	line_data["start"] = Vector2(data.position_x, data.position_y)
	line_data["color"] = Color(data.color)
	var line_button = line_buttons_container.get_child(index)
	var line_name = str("Line", line_button.get_index() + 1, " (", int(line_data.angle), "°)")
	line_button.text = line_name
	perspective_lines[index].refresh(line_data)


func refresh_tracker():
	# tracker line has it's own data system (best leave it alone)
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
