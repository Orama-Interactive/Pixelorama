class_name KeyframeTimelineFrameDisplay
extends Control

var x_offset := 0


func _ready() -> void:
	Global.cel_switched.connect(queue_redraw)


func _draw() -> void:
	var font := Themes.get_font()
	var project := Global.current_project
	for i in project.frames.size():
		# NOTE: We use maxf(1, ...) so that the line next to frame 1 is drawn properly.
		var xx := maxf(1, i * KeyframeTimeline.frame_ui_size - x_offset)
		var width: int = -1
		if i == project.current_frame:
			width = 2
		draw_line(Vector2(xx, 0), Vector2(xx, size.y), Color.WHITE, width)
		draw_string(
			font, Vector2(xx + 2, 16), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16 + width
		)
