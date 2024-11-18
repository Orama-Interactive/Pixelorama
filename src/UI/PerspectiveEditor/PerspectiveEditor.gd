extends PanelContainer

var axes: Node2D
var do_pool := []  ## A pool that stores data of points removed by undo
var delete_pool := []  ## A pool that contains deleted data and their index
## The vanishing point UI resource
var vanishing_point_res := preload("res://src/UI/PerspectiveEditor/VanishingPoint.tscn")
## Option to show/hide tracker guides. (guides whose end points follow the mouse)
var tracker_disabled := false
@onready var vanishing_point_container = $"%VanishingPointContainer"


func _ready() -> void:
	Global.project_switched.connect(_update_points)
	$VBoxContainer/TrackerLines.button_pressed = !tracker_disabled


func _on_AddPoint_pressed() -> void:
	do_pool.clear()  # Reset (clears Redo history of vanishing points)
	var project := Global.current_project
	project.undos += 1
	project.undo_redo.create_action("Add Vanishing Point")
	project.undo_redo.add_do_method(add_vanishing_point.bind(true))
	project.undo_redo.add_undo_method(undo_add_vanishing_point)
	project.undo_redo.commit_action()


func _on_TrackerLines_toggled(button_pressed: bool) -> void:
	tracker_disabled = !button_pressed


func add_vanishing_point(is_redo := false) -> void:
	var vanishing_point := vanishing_point_res.instantiate()
	vanishing_point_container.add_child(vanishing_point)
	if is_redo and !do_pool.is_empty():
		# if it's a redo then initialize it with the redo data
		vanishing_point.initiate(do_pool.pop_back())
		vanishing_point.update_data_to_project()
	else:
		vanishing_point.initiate()


func undo_add_vanishing_point() -> void:
	var point = vanishing_point_container.get_child(vanishing_point_container.get_child_count() - 1)
	point.queue_free()
	do_pool.append(point.serialize())
	point.update_data_to_project(true)


func delete_point(idx: int) -> void:
	var project := Global.current_project
	project.undos += 1
	project.undo_redo.create_action("Delete Vanishing Point")
	project.undo_redo.add_do_method(do_delete_point.bind(idx))
	project.undo_redo.add_undo_method(undo_delete_point.bind(idx))
	project.undo_redo.commit_action()


func do_delete_point(idx: int) -> void:
	var point := vanishing_point_container.get_child(idx)
	delete_pool.append(point.serialize())
	point.queue_free()
	point.update_data_to_project(true)


func undo_delete_point(idx: int) -> void:
	var point = delete_pool.pop_back()
	Global.current_project.vanishing_points.insert(idx, point)
	_update_points()


func _update_points() -> void:
	# Delete old vanishing points
	for c in vanishing_point_container.get_children():
		c.queue_free()
	# Add the "updated" vanishing points from the current_project
	for idx in Global.current_project.vanishing_points.size():
		# Create the point
		var vanishing_point := vanishing_point_res.instantiate()
		vanishing_point_container.add_child(vanishing_point)
		# Initialize it
		var point_data = Global.current_project.vanishing_points[idx]
		vanishing_point.initiate(point_data, idx)
