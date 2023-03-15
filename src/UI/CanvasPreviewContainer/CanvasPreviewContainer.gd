extends PanelContainer

onready var canvas_preview: Node2D = $"%CanvasPreview"
onready var camera: Camera2D = $"%CameraPreview"
onready var play_button: Button = $"%PlayButton"

onready var h_frames: SpinBox = $"%HFrames"
onready var v_frames: SpinBox = $"%VFrames"
onready var start: SpinBox = $"%Start"
onready var end: SpinBox = $"%End"


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
			if start.value == end.value:
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
	var frames = canvas_preview.h_frames * canvas_preview.v_frames
	start.max_value = frames
	end.max_value = frames
	canvas_preview.update()


func _on_VFrames_value_changed(value: float) -> void:
	canvas_preview.v_frames = value
	var frames = canvas_preview.h_frames * canvas_preview.v_frames
	start.max_value = frames
	end.max_value = frames
	canvas_preview.update()


func _on_Start_value_changed(value: float) -> void:
	canvas_preview.frame = value - 1
	canvas_preview.start_sprite_sheet_frame = value
	if end.value < value:
		end.value = value
	canvas_preview.update()


func _on_End_value_changed(value: float) -> void:
	canvas_preview.end_sprite_sheet_frame = value
	if start.value > value:
		start.value = value
		canvas_preview.frame = value - 1
	canvas_preview.update()
