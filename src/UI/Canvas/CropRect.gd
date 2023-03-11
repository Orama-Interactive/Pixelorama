class_name CropRect # TODO: Rename to just Crop
extends Node2D
# Draws the rectangle overlay for the crop tool
# Stores the shared settings between left and right crop tools

enum Mode { SIDES, RESOLUTION, LOCKED_RESOLUTION, LOCKED_ASPECT_RATIO }

signal updated

const BIG = 100000 # Size of big rectangles used to darken background.
const DARKEN_COLOR = Color(0, 0, 0, 0.5)
const LINE_COLOR = Color.white

var mode := 0 setget _set_mode
var rect := Rect2(0, 0, 1, 1)
var ratio := Vector2.ONE

# How many crop tools are active (0-2), setter makes this visible if not 0
var tool_count := 0 setget _set_tool_count


func _ready() -> void:
	connect("updated", self, "update")
	Global.connect("project_changed", self, "reset")
	reset()


func _draw() -> void:
	# Darken the background by drawing very big rectangles around the crop rect:
	draw_rect(Rect2(rect.end.x - BIG, rect.position.y - BIG, BIG, BIG), DARKEN_COLOR)
	draw_rect(Rect2(rect.end.x, rect.end.y - BIG, BIG, BIG), DARKEN_COLOR)
	draw_rect(Rect2(rect.position.x, rect.end.y, BIG, BIG), DARKEN_COLOR)
	draw_rect(Rect2(rect.position.x - BIG, rect.position.y, BIG, BIG), DARKEN_COLOR)

	# Rect:
	draw_rect(rect, LINE_COLOR, false)

	# Horizontal rule of thirds lines:
	var third: float = rect.position.y + rect.size.y * 0.333
	draw_line(Vector2(rect.position.x, third), Vector2(rect.end.x, third), LINE_COLOR)
	third = rect.position.y + rect.size.y * 0.667
	draw_line(Vector2(rect.position.x, third), Vector2(rect.end.x, third), LINE_COLOR)

	# Vertical rule of thirds lines:
	third = rect.position.x + rect.size.x * 0.333
	draw_line(Vector2(third, rect.position.y), Vector2(third, rect.end.y), LINE_COLOR)
	third = rect.position.x + rect.size.x * 0.667
	draw_line(Vector2(third, rect.position.y), Vector2(third, rect.end.y), LINE_COLOR)


func apply() -> void:
	DrawingAlgos.resize_canvas(rect.size.x, rect.size.y, -rect.position.x, -rect.position.y)

# TODO: Reset needs to be called when opening a project (that is the current and project_changed isn't emitted?)
func reset() -> void:
	rect.position = Vector2.ZERO
	rect.size = Global.current_project.size
	if mode == Mode.LOCKED_ASPECT_RATIO:
		_auto_ratio_from_resolution()
	emit_signal("updated")


func _auto_ratio_from_resolution() -> void:
	var divisor := _gcd(rect.size.x, rect.size.y)
	ratio = rect.size / divisor


# Greatest common divisor
func _gcd(a: int, b: int) -> int:
	return a if b == 0 else _gcd(b, a % b)


# Setters

func _set_mode(value: int) -> void:
	if value == Mode.LOCKED_ASPECT_RATIO and mode != Mode.LOCKED_ASPECT_RATIO:
		_auto_ratio_from_resolution()
	mode = value


func _set_tool_count(value: int) -> void:
	if tool_count == 0 and value > 0:
		reset() # Reset once 1 tool becomes the crop tool
	tool_count = value
	visible = tool_count

