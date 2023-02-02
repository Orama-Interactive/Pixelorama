class_name SymmetryGuide
extends Guide

var _texture: Texture = preload("res://assets/graphics/dotted_line.png")


func _ready() -> void:
	has_focus = false
	visible = false
	texture = _texture
	texture_mode = Line2D.LINE_TEXTURE_TILE
	width = Global.camera.zoom.x * 4
	# Add a subtle difference to the normal guide color by mixing in some blue
	default_color = Global.guide_color.linear_interpolate(Color(0.2, 0.2, .65), .6)


func _input(_event: InputEvent) -> void:
	if !visible:
		return
	._input(_event)
	if type == Types.HORIZONTAL:
		project.y_symmetry_point = points[0].y * 2 - 1
		points[0].y = clamp(points[0].y, 0, Global.current_project.size.y)
		points[1].y = clamp(points[1].y, 0, Global.current_project.size.y)
	elif type == Types.VERTICAL:
		points[0].x = clamp(points[0].x, 0, Global.current_project.size.x)
		points[1].x = clamp(points[1].x, 0, Global.current_project.size.x)
		project.x_symmetry_point = points[0].x * 2 - 1


func _outside_canvas() -> bool:
	return false
