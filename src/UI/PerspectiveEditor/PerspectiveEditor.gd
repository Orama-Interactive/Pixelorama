extends Control

onready var vanishing_point_container = $"%VanishingPointContainer"
var axes: Node2D
var do_pool = []  # A pool that stores data of points removed by undo
var delete_pool = []  # A pool that containg deleted data and their index


func _on_AddPoint_pressed() -> void:
	do_pool.clear()  # Reset
	var project = Global.current_project
	project.undos += 1
	project.undo_redo.create_action("Add Vanishing Point")
	project.undo_redo.add_do_method(self, "add_vanishing_point", true)
	project.undo_redo.add_undo_method(self, "undo_add_vanishing_point")
	project.undo_redo.commit_action()


func update():
	for c in vanishing_point_container.get_children():
		c.queue_free()
	for idx in Global.current_project.vanishing_points.size():
		var point_data = Global.current_project.vanishing_points[idx]
		var vanishing_point := preload("res://src/UI/PerspectiveEditor/VanishingPoint.tscn").instance()
		vanishing_point_container.add_child(vanishing_point)
		vanishing_point.initiate(point_data, idx)


func add_vanishing_point(is_redo := false):
	var vanishing_point := preload("res://src/UI/PerspectiveEditor/VanishingPoint.tscn").instance()
	vanishing_point_container.add_child(vanishing_point)
	if is_redo and !do_pool.empty():
		vanishing_point.initiate(do_pool.pop_back())
		vanishing_point.update_data_to_project()
	else:
		vanishing_point.initiate()


func undo_add_vanishing_point():
	var point = vanishing_point_container.get_child(vanishing_point_container.get_child_count() - 1)
	point.queue_free()
	do_pool.append(point.data.duplicate())
	point.update_data_to_project(true)


func delete_point(idx):
	var project = Global.current_project
	project.undos += 1
	project.undo_redo.create_action("Delete Vanishing Point")
	project.undo_redo.add_do_method(self, "do_delete_point", idx)
	project.undo_redo.add_undo_method(self, "undo_delete_point", idx)
	project.undo_redo.commit_action()


func do_delete_point(idx):
	var point = vanishing_point_container.get_child(idx)
	delete_pool.append(point.data)
	point.queue_free()
	point.update_data_to_project(true)


func undo_delete_point(idx):
	var point = delete_pool.pop_back()
	Global.current_project.vanishing_points.insert(idx, point)
	update()
