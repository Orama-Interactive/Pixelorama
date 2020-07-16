class_name SymmetryGuide extends Guide


func _ready() -> void:
	._ready()
	has_focus = false


func _input(_event : InputEvent) -> void:
	._input(_event)
	if type == Types.HORIZONTAL:
		project.y_symmetry_point = points[0].y * 2 - 1
	elif type == Types.VERTICAL:
		project.x_symmetry_point = points[0].x * 2 - 1


func outside_canvas() -> bool:
	if type == Types.HORIZONTAL:
		points[0].y = clamp(points[0].y, 0, Global.current_project.size.y)
		points[1].y = clamp(points[1].y, 0, Global.current_project.size.y)
	elif type == Types.VERTICAL:
		points[0].x = clamp(points[0].x, 0, Global.current_project.size.x)
		points[1].x = clamp(points[1].x, 0, Global.current_project.size.x)

	return false
