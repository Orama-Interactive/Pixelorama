extends Node2D

var frame: int = 0
onready var animation_timer: Timer = $AnimationTimer


func _draw() -> void:
	var current_project: Project = Global.current_project
	if frame >= current_project.frames.size():
		frame = current_project.current_frame

	$AnimationTimer.wait_time = (
		current_project.frames[frame].duration
		* (1 / Global.current_project.fps)
	)

	if animation_timer.is_stopped():
		frame = current_project.current_frame
	var current_cels: Array = current_project.frames[frame].cels

	draw_texture(current_cels[0].image_texture, Vector2.ZERO, Color.white) # Placeholder


func _on_AnimationTimer_timeout() -> void:
	var current_project: Project = Global.current_project
	if frame < current_project.frames.size() - 1:
		frame += 1
	else:
		frame = 0

	$AnimationTimer.set_one_shot(true)
	$AnimationTimer.wait_time = (
		Global.current_project.frames[frame].duration
		* (1 / Global.current_project.fps)
	)
	$AnimationTimer.start()
	update()
