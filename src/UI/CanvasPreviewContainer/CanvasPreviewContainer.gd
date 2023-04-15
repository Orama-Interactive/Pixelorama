extends PanelContainer

onready var canvas_preview: Node2D = $"%CanvasPreview"
onready var camera: Camera2D = $"%CameraPreview"
onready var play_button: Button = $"%PlayButton"

onready var start_frame := $"%StartFrame" as ValueSlider
onready var end_frame := $"%EndFrame" as ValueSlider


func _on_PreviewZoomSlider_value_changed(value: float) -> void:
	camera.zoom = -Vector2(value, value)
	camera.save_values_to_project()
	camera.update_transparent_checker_offset()


func _on_PlayButton_toggled(button_pressed: bool) -> void:
	if button_pressed:
		if canvas_preview.mode == canvas_preview.Mode.TIMELINE:
			if Global.current_project.frames.size() <= 1:
				play_button.pressed = false
				return
		else:
			if start_frame.value == end_frame.value:
				play_button.pressed = false
				return
		canvas_preview.animation_timer.start()
		Global.change_button_texturerect(play_button.get_child(0), "pause.png")
	else:
		canvas_preview.animation_timer.stop()
		Global.change_button_texturerect(play_button.get_child(0), "play.png")


func _on_OptionButton_item_selected(index: int) -> void:
	play_button.pressed = false
	canvas_preview.mode = index
	$VBox/Animation/VBoxContainer/Options.visible = bool(index == 1)
	canvas_preview.update()


func _on_HFrames_value_changed(value: float) -> void:
	canvas_preview.h_frames = value
	var frames: int = canvas_preview.h_frames * canvas_preview.v_frames
	start_frame.max_value = frames
	end_frame.max_value = frames
	canvas_preview.update()


func _on_VFrames_value_changed(value: float) -> void:
	canvas_preview.v_frames = value
	var frames: int = canvas_preview.h_frames * canvas_preview.v_frames
	start_frame.max_value = frames
	end_frame.max_value = frames
	canvas_preview.update()


func _on_StartFrame_value_changed(value: float) -> void:
	canvas_preview.frame = value - 1
	canvas_preview.start_sprite_sheet_frame = value
	if end_frame.value < value:
		end_frame.value = value
	canvas_preview.update()


func _on_EndFrame_value_changed(value: float) -> void:
	canvas_preview.end_sprite_sheet_frame = value
	if start_frame.value > value:
		start_frame.value = value
		canvas_preview.frame = value - 1
	canvas_preview.update()
