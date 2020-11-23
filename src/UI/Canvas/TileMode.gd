extends Node2D


var location := Vector2.ZERO


func _draw() -> void:
	var current_cels : Array = Global.current_project.frames[Global.current_project.current_frame].cels
	var size : Vector2 = Global.current_project.size
	var positions : Array = get_tile_positions(size)
	var tilemode_opacity = 1.0 - Global.tilemode_opacity

	var _position := position
	var _scale := scale
	if Global.mirror_view:
		_position.x = _position.x + Global.current_project.size.x
		_scale.x = -1
	draw_set_transform(_position, rotation, _scale)

	for i in range(Global.current_project.layers.size()):
		var modulate_color := Color(1, 1, 1, current_cels[i].opacity - tilemode_opacity)
		if Global.current_project.layers[i].visible: # if it's visible
			if Global.current_project.tile_mode:
				for pos in positions:
					draw_texture(current_cels[i].image_texture, pos, modulate_color)

	draw_set_transform(position, rotation, scale)


func get_tile_positions(size):
	match Global.current_project.tile_mode:
		1:
			return [
				Vector2(location.x, location.y + size.y), # Down
				Vector2(location.x - size.x, location.y + size.y), # Down left
				Vector2(location.x - size.x, location.y), # Left
				location - size, # Up left
				Vector2(location.x, location.y - size.y), # Up
				Vector2(location.x + size.x, location.y - size.y), # Up right
				Vector2(location.x + size.x, location.y), # Right
				location + size # Down right
			]
		2:
			return [
				Vector2(location.x + size.x, location.y), # Right
				Vector2(location.x - size.x, location.y), # Left
			]
		3:
			return [
				Vector2(location.x, location.y + size.y), # Down
				Vector2(location.x, location.y - size.y), # Up
			]
		_:
			return []
