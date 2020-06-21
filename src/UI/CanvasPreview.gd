extends Node2D


func _draw() -> void:
	var current_project : Project = Global.current_project
	var frame : int = current_project.current_frame
	var current_cels : Array = current_project.frames[frame].cels

	# Draw current frame layers
	for i in range(current_cels.size()):
		var modulate_color := Color(1, 1, 1, current_cels[i].opacity)
		if i < current_project.layers.size() and current_project.layers[i].visible: # if it's visible
			draw_texture(current_cels[i].image_texture, Vector2.ZERO, modulate_color)
