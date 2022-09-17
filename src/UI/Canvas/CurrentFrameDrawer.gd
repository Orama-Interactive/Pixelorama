extends Node2D


func _draw() -> void:
	var current_cels: Array = Global.current_project.frames[Global.current_project.current_frame].cels
	for i in range(Global.current_project.layers.size()):
		if current_cels[i] is GroupCel:
			continue
		if (
			Global.current_project.layers[i].is_visible_in_hierarchy()
			and current_cels[i].opacity > 0
		):
			var modulate_color := Color(1, 1, 1, current_cels[i].opacity)
			draw_texture(current_cels[i].image_texture, Vector2.ZERO, modulate_color)
