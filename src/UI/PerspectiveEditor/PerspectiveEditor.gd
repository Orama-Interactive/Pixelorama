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
	Global.project_switched.connect(_recreate_points)
	$VBoxContainer/TrackerLines.button_pressed = !tracker_disabled


func _on_AddPoint_pressed() -> void:
	do_pool.clear()  # Reset (clears Redo history of vanishing points)
	var project := Global.current_project
	project.undo_redo.create_action("Add Vanishing Point")
	project.undo_redo.add_do_method(
		# Do: Adding vanishing point
		func():
			var vanishing_point := vanishing_point_res.instantiate()
			vanishing_point_container.add_child(vanishing_point)
			if !do_pool.is_empty():
				# if it's a redo then initialize it with the redo data
				vanishing_point.initiate(do_pool.pop_back())
				vanishing_point.update_data_to_project()
			else:
				vanishing_point.initiate()
	)
	project.undo_redo.add_undo_method(
		# Undo: Adding vanishing point
		func():
			var point = vanishing_point_container.get_child(
				vanishing_point_container.get_child_count() - 1
			)
			do_pool.append(point.serialize())
			point.update_data_to_project(true)
	)
	project.undo_redo.commit_action()


func _on_TrackerLines_toggled(button_pressed: bool) -> void:
	tracker_disabled = !button_pressed


func delete_point(idx: int) -> void:
	var project := Global.current_project
	project.undo_redo.create_action("Delete Vanishing Point")
	project.undo_redo.add_do_method(
		# Do: Delete vanishing point
		func ():
			var point := vanishing_point_container.get_child(idx)
			delete_pool.append(point.serialize())
			point.update_data_to_project(true)
	)
	project.undo_redo.add_undo_method(
		# Undo: Delete vanishing point
		func ():
			var point = delete_pool.pop_back()
			Global.current_project.vanishing_points.insert(idx, point)
			_recreate_points()
	)
	project.undo_redo.commit_action()


func _recreate_points() -> void:
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
