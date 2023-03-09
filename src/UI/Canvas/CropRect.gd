extends Node2D

const WIDTH = 1
const LINE_COLOR = Color.white

var top := 0
var bottom := 0
var left := 0
var right := 0

func _draw():
	# Horizontal lines, top to bottom:
	draw_line(Vector2(left, top), Vector2(right, top), LINE_COLOR, WIDTH)
	draw_line(Vector2(left, bottom), Vector2(right, bottom), LINE_COLOR, WIDTH)
	# Vertical lines, left to right:
	draw_line(Vector2(left, top), Vector2(left, bottom), LINE_COLOR, WIDTH)
	draw_line(Vector2(right, top), Vector2(right, bottom), LINE_COLOR, WIDTH)
