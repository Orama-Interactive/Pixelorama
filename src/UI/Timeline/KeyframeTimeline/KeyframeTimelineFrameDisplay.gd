class_name KeyframeTimelineFrameDisplay
extends Control

var x_offset := 0


func _ready() -> void:
	Global.cel_switched.connect(queue_redraw)


func _draw() -> void:
	var font := Themes.get_font()
	var color := Global.control.theme.get_color(&"font_color", &"Label")
	var project := Global.current_project
	for i in project.frames.size():
		var offset_i := i + KeyframeTimeline.TRACK_X_MARGIN
		var xx := offset_i * KeyframeTimeline.frame_ui_size - x_offset
		var x_next := (offset_i + 1) * KeyframeTimeline.frame_ui_size - x_offset
		if x_next > 1:
			# NOTE: We use maxf(1, ...) so that the line when xx = 0.0 is drawn properly.
			xx = maxf(1, xx)
		var width := 2 if i == project.current_frame else -1
		draw_line(Vector2(xx, 0), Vector2(xx, size.y), color, width)
		var pos := Vector2(xx + 2, 16)
		draw_string(font, pos, str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16 + width, color)
