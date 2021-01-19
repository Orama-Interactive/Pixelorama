extends Node2D


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
		Global.TileMode.BOTH:
			return [
				Vector2(0, size.y), # Down
				Vector2(-size.x, size.y), # Down left
				Vector2(-size.x, 0), # Left
				-size, # Up left
				Vector2(0, -size.y), # Up
				Vector2(size.x, -size.y), # Up right
				Vector2(size.x, 0), # Right
				size # Down right
			]
		Global.TileMode.X_AXIS:
			return [
				Vector2(size.x, 0), # Right
				Vector2(-size.x, 0), # Left
			]
		Global.TileMode.Y_AXIS:
			return [
				Vector2(0, size.y), # Down
				Vector2(0, -size.y), # Up
			]
		_:
			return []
