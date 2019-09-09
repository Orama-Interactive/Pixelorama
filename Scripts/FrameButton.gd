extends Button

var frame := 0

func _on_FrameButton_pressed() -> void:
	Global.current_frame = frame
	#print(len(Global.canvases))
	Global.change_frame()