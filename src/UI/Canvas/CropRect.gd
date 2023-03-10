class_name CropRect
extends Node2D
# Draws the rectangle overlay for the crop tool
# Stores the shared settings between left and right crop tools

signal updated

const RECT_COLOR = Color.white

var top := 0
var bottom := 0
var left := 0
var right := 0

# How many crop tools are active (0-2), setter makes this visible if not 0
var tool_count := 0 setget _set_tool_count


func _ready():
	connect("updated", self, "update")
	Global.connect("project_changed", self, "reset")
	reset()


func _draw():
	draw_rect(Rect2(left, top, (right - left), (bottom - top)), RECT_COLOR, false)


func apply():
	DrawingAlgos.resize_canvas((right - left), (bottom - top), -left, -top)


func reset():
	top = 0
	bottom = Global.current_project.size.y
	left = 0
	right = Global.current_project.size.x
	emit_signal("updated")


func _set_tool_count(value: int):
	if tool_count == 0 and value > 0:
		reset() # Reset once 1 tool becomes the crop tool
	tool_count = value
	visible = tool_count
