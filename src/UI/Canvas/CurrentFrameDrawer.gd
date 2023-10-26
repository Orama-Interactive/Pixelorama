extends Node2D


func _draw() -> void:
	# Placeholder so we can have a material here
	draw_texture(
		Global.current_project.frames[Global.current_project.current_frame].cels[0].image_texture,
		Vector2.ZERO
	)
