extends PanelContainer


onready var canvas_preview = $HBoxContainer/PreviewViewportContainer/Viewport/CanvasPreview
onready var camera : Camera2D = $HBoxContainer/PreviewViewportContainer/Viewport/CameraPreview
onready var play_button : Button = $HBoxContainer/VBoxContainer/PlayButton


func _on_PreviewZoomSlider_value_changed(value : float) -> void:
	camera.zoom = -Vector2(value, value)
	camera.save_values_to_project()
	camera.update_transparent_checker_offset()


func _on_PlayButton_toggled(button_pressed : bool) -> void:
	if button_pressed:
		if Global.current_project.frames.size() <= 1:
			play_button.pressed = false
			return
		canvas_preview.animation_timer.start()
		Global.change_button_texturerect(play_button.get_child(0), "pause.png")
	else:
		canvas_preview.animation_timer.stop()
		Global.change_button_texturerect(play_button.get_child(0), "play.png")
