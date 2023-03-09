extends Node2D

const RECT_COLOR = Color.white

var top := 0
var bottom := 0
var left := 0
var right := 0

func _draw():
	draw_rect(Rect2(left, top, (right - left), (bottom - top)), RECT_COLOR, false)
