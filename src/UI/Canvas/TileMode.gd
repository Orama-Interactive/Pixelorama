extends Node2D


var location := Vector2.ZERO


func _draw() -> void:
	var current_cels : Array = Global.current_project.frames[Global.current_project.current_frame].cels
	var size : Vector2 = Global.current_project.size
	var positions := [
		Vector2(location.x, location.y + size.y), # Down
		Vector2(location.x - size.x, location.y + size.y), # Down left
		Vector2(location.x - size.x, location.y), # Left
		location - size, # Up left
		Vector2(location.x, location.y - size.y), # Up
		Vector2(location.x + size.x, location.y - size.y), # Up right
		Vector2(location.x + size.x, location.y), # Right
		location + size # Down right
	]

	for pos in positions:
		# Draw a blank rectangle behind the textures
		# Mostly used to hide the grid if it goes outside the canvas boundaries
		draw_rect(Rect2(pos, size), Global.default_clear_color)

	for i in range(Global.current_project.layers.size()):
		var modulate_color := Color(1, 1, 1, current_cels[i].opacity)
		if Global.current_project.layers[i].visible: # if it's visible
			if Global.tile_mode:
				for pos in positions:
					draw_texture(current_cels[i].image_texture, pos, modulate_color)
