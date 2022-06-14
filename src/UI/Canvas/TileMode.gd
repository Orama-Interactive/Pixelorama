extends Node2D


func _draw() -> void:
	var positions := get_tile_positions()
	var tilemode_opacity := Global.tilemode_opacity

	var position_tmp := position
	var scale_tmp := scale
	if Global.mirror_view:
		position_tmp.x = position_tmp.x + Global.current_project.size.x
		scale_tmp.x = -1
	draw_set_transform(position_tmp, rotation, scale_tmp)

	var modulate_color := Color(
		tilemode_opacity, tilemode_opacity, tilemode_opacity, tilemode_opacity
	)  # premultiply alpha blending is applied
	var current_frame_texture: Texture = Global.canvas.currently_visible_frame.get_texture()
	for pos in positions:
		draw_texture(current_frame_texture, pos, modulate_color)

	draw_set_transform(position, rotation, scale)


func get_tile_positions() -> Array:
	var x_basis: Vector2 = Global.current_project.tiles.get_x_basis()
	var y_basis: Vector2 = Global.current_project.tiles.get_y_basis()
	var tile_mode: int = Global.current_project.tiles.mode
	var x_range := (
		range(-1, 2)
		if tile_mode in [Tiles.MODE.X_AXIS, Tiles.MODE.BOTH]
		else range(0, 1)
	)
	var y_range := (
		range(-1, 2)
		if tile_mode in [Tiles.MODE.Y_AXIS, Tiles.MODE.BOTH]
		else range(0, 1)
	)
	var positions := []
	for r in y_range:
		for c in x_range:
			var position: Vector2 = r * y_basis + c * x_basis
			positions.append(position)
	return positions
