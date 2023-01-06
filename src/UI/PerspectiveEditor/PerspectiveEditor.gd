extends Control

onready var vanishing_point_container = $"%VanishingPointContainer"
var axes :Node2D

func _ready():
	axes = preload("res://src/UI/PerspectiveEditor/Axes.tscn").instance()
	Global.canvas.add_child(axes)


func _on_AddPoint_pressed() -> void:
	add_vanishing_point()


func _on_CheckButton_toggled(button_pressed):
	if button_pressed:
		axes.visible = true
	else:
		axes.visible = false


func update():
	for c in vanishing_point_container.get_children():
		c.queue_free()
	for vanishing_point in Global.current_project.vanishing_points:
		add_vanishing_point(vanishing_point)


func add_vanishing_point(data = null):
	var vanishing_point := preload(
		"res://src/UI/PerspectiveEditor/VanishingPoint.tscn"
	).instance()
	vanishing_point_container.add_child(vanishing_point)
	vanishing_point.initiate(data)
