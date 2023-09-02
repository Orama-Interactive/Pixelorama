class_name CropRect
extends Node2D
## Draws the rectangle overlay for the crop tool
## Stores the shared settings between left and right crop tools

signal updated

enum Mode { MARGINS, POSITION_SIZE }

const BIG := 100000  ## Size of big rectangles used to darken background.
const DARKEN_COLOR := Color(0, 0, 0, 0.5)
const LINE_COLOR := Color.WHITE

var mode := Mode.MARGINS:
	set(value):
		mode = value
var locked_size := false
var rect := Rect2i(0, 0, 1, 1)

## How many crop tools are active (0-2), setter makes this visible if not 0
var tool_count := 0:
	set(value):
		if tool_count == 0 and value > 0:
			reset()  # Reset once 1 tool becomes the crop tool
		tool_count = value
		visible = tool_count


func _ready() -> void:
	updated.connect(queue_redraw)
	Global.project_changed.connect(reset)
	mode = Global.config_cache.get_value("preferences", "crop_mode", 0)
	locked_size = Global.config_cache.get_value("preferences", "crop_locked_size", false)
	reset()


func _exit_tree():
	Global.config_cache.set_value("preferences", "crop_mode", mode)
	Global.config_cache.set_value("preferences", "crop_locked_size", locked_size)


func _draw() -> void:
	# Darken the background by drawing big rectangles around it (top/bottomm/left/right):
	draw_rect(
		Rect2(rect.position.x - BIG, rect.position.y - BIG, BIG * 2 + rect.size.x, BIG),
		DARKEN_COLOR
	)
	draw_rect(Rect2(rect.position.x - BIG, rect.end.y, BIG * 2 + rect.size.x, BIG), DARKEN_COLOR)
	draw_rect(Rect2(rect.position.x - BIG, rect.position.y, BIG, rect.size.y), DARKEN_COLOR)
	draw_rect(Rect2(rect.end.x, rect.position.y, BIG, rect.size.y), DARKEN_COLOR)

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


func reset() -> void:
	rect.position = Vector2.ZERO
	rect.size = Global.current_project.size
	updated.emit()
