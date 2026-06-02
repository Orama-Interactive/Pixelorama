class_name KeyframeTimelineFrameDisplay
extends Control

var x_offset := 0


func _ready() -> void:
	Global.cel_switched.connect(queue_redraw)


func _draw() -> void:
	var font := Themes.get_font()
	var project := Global.current_project
	for i in project.frames.size():
		var xx := i * KeyframeTimeline.frame_ui_size - x_offset
		draw_line(Vector2(xx, 0), Vector2(xx, size.y), Color.WHITE)
		draw_string(font, Vector2(xx + 2, 16), str(i + 1))
