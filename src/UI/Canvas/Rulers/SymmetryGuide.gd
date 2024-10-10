class_name SymmetryGuide
extends Guide

var _texture := preload("res://assets/graphics/dotted_line.png")


func _ready() -> void:
	super._ready()
	has_focus = false
	visible = false
	texture = _texture
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_mode = Line2D.LINE_TEXTURE_TILE
	width = 4.0 / Global.camera.zoom.x
	set_color(Global.guide_color)


func _input(_event: InputEvent) -> void:
	if !visible:
		return
	super._input(_event)
	if type == Types.HORIZONTAL:
		project.y_symmetry_point = points[0].y * 2 - 1
		points[0].y = clampf(points[0].y, 0, project.size.y)
		points[1].y = clampf(points[1].y, 0, project.size.y)
	elif type == Types.VERTICAL:
		points[0].x = clampf(points[0].x, 0, project.size.x)
		points[1].x = clampf(points[1].x, 0, project.size.x)
		project.x_symmetry_point = points[0].x * 2 - 1


## Add a subtle difference to the normal guide color by mixing in some blue
func set_color(color: Color) -> void:
	default_color = color.lerp(Color(.2, .2, .65), .6)


func _outside_canvas() -> bool:
	return false
