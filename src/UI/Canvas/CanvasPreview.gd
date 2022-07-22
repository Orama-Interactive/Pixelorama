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

	# Draw current frame layers
	for i in range(current_cels.size()):
		if current_cels[i] is GroupCel:
			continue
		var modulate_color := Color(1, 1, 1, current_cels[i].opacity)
		if i < current_project.layers.size() and current_project.layers[i].is_visible_in_hierarchy():
			draw_texture(current_cels[i].image_texture, Vector2.ZERO, modulate_color)


func _on_AnimationTimer_timeout() -> void:
	var first_frame := 0
	var last_frame: int = Global.current_project.frames.size() - 1
	var current_project: Project = Global.current_project

	if Global.play_only_tags:
		for tag in current_project.animation_tags:
			if (
				current_project.current_frame + 1 >= tag.from
				&& current_project.current_frame + 1 <= tag.to
			):
				first_frame = tag.from - 1
				last_frame = min(current_project.frames.size() - 1, tag.to - 1)

	if frame < last_frame:
		frame += 1
	else:
		frame = first_frame

	$AnimationTimer.set_one_shot(true)
	$AnimationTimer.wait_time = (
		Global.current_project.frames[frame].duration
		* (1 / Global.current_project.fps)
	)
	$AnimationTimer.start()
	update()
