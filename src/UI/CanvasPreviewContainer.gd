extends HBoxContainer


onready var canvas_preview = $PreviewContainer/PreviewViewportContainer/Viewport/CanvasPreview
onready var camera : Camera2D = $PreviewContainer/PreviewViewportContainer/Viewport/CameraPreview
onready var play_button : Button = $SettingsContainer/VBoxContainer/PlayButton


func _on_PreviewZoomSlider_value_changed(value : float) -> void:
	camera.zoom = -Vector2(value, value)
	camera.save_values_to_project()


func _on_PlayButton_toggled(button_pressed : bool) -> void:
	if button_pressed:
		canvas_preview.animation_timer.start()
		Global.change_button_texturerect(play_button.get_child(0), "pause.png")
	else:
		canvas_preview.animation_timer.stop()
		Global.change_button_texturerect(play_button.get_child(0), "play.png")
