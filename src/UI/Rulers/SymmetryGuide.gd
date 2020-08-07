class_name SymmetryGuide extends Guide


var _texture = preload("res://assets/graphics/dotted_line.png")


func _ready() -> void:
	._ready()
	has_focus = false
	visible = false
	texture = _texture
	texture_mode = Line2D.LINE_TEXTURE_TILE
	width = Global.camera.zoom.x * 4
	yield(get_tree().create_timer(0.01), "timeout")
	modulate = Global.guide_color


func _input(_event : InputEvent) -> void:
	._input(_event)
	if type == Types.HORIZONTAL:
		project.y_symmetry_point = points[0].y * 2 - 1
	elif type == Types.VERTICAL:
		project.x_symmetry_point = points[0].x * 2 - 1

	yield(get_tree().create_timer(0.01), "timeout")
	width = Global.camera.zoom.x * 4


func outside_canvas() -> bool:
	if type == Types.HORIZONTAL:
		points[0].y = clamp(points[0].y, 0, Global.current_project.size.y)
		points[1].y = clamp(points[1].y, 0, Global.current_project.size.y)
	elif type == Types.VERTICAL:
		points[0].x = clamp(points[0].x, 0, Global.current_project.size.x)
		points[1].x = clamp(points[1].x, 0, Global.current_project.size.x)

	return false
