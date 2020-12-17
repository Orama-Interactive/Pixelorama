extends Node2D


var frame : int = 0
onready var animation_timer : Timer = $AnimationTimer

func _draw() -> void:
	var current_project : Project = Global.current_project
	if frame >= current_project.frames.size():
		frame = current_project.current_frame

	$AnimationTimer.wait_time = current_project.frames[frame].duration * (1 / Global.current_project.fps)

	if animation_timer.is_stopped():
		frame = current_project.current_frame
	var current_cels : Array = current_project.frames[frame].cels

	# Draw current frame layers
	for i in range(current_cels.size()):
		var modulate_color := Color(1, 1, 1, current_cels[i].opacity)
		if i < current_project.layers.size() and current_project.layers[i].visible:
			draw_texture(current_cels[i].image_texture, Vector2.ZERO, modulate_color)


func _on_AnimationTimer_timeout() -> void:
	var current_project : Project = Global.current_project
	if frame < current_project.frames.size() - 1:
		frame += 1
	else:
		frame = 0

	$AnimationTimer.set_one_shot(true)
	$AnimationTimer.wait_time = Global.current_project.frames[frame].duration * (1 / Global.current_project.fps)
	$AnimationTimer.start()
	update()
