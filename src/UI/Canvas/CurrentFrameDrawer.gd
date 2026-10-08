extends Node2D


func _draw() -> void:
	# Placeholder so we can have a material here
	var image_to_draw := Global.current_project.empty_image_texture
	draw_texture(image_to_draw, Vector2.ZERO)
