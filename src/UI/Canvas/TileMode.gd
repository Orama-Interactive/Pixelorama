extends Node2D


var location := Vector2.ZERO


func _draw() -> void:
	var size : Vector2 = Global.current_project.size
	var positions : Array = get_tile_positions(size)
	var tilemode_opacity := Global.tilemode_opacity

	var _position := position
	var _scale := scale
	if Global.mirror_view:
		_position.x = _position.x + Global.current_project.size.x
		_scale.x = -1
	draw_set_transform(_position, rotation, _scale)

	var modulate_color := Color(tilemode_opacity, tilemode_opacity, tilemode_opacity, tilemode_opacity) # premultiply alpha blending is applied
	var current_frame_texture: Texture = Global.canvas.currently_visible_frame.get_texture()
	for pos in positions:
		draw_texture(current_frame_texture, pos, modulate_color)

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
