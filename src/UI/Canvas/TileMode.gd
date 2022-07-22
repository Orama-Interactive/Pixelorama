extends Node2D

var tiles: Tiles
var draw_center := false


func _draw() -> void:
	var positions := get_tile_positions()
	var tilemode_opacity := Global.tilemode_opacity

	if Global.mirror_view:
		var position_tmp := Vector2(Global.current_project.size.x, 0)
		var scale_tmp := Vector2(-1, 1)
		draw_set_transform(position_tmp, 0, scale_tmp)

	var modulate_color := Color(
		tilemode_opacity, tilemode_opacity, tilemode_opacity, tilemode_opacity
	)  # premultiply alpha blending is applied
	var current_frame_texture: Texture = Global.canvas.currently_visible_frame.get_texture()
	for pos in positions:
		draw_texture(current_frame_texture, pos, modulate_color)

	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func get_tile_positions() -> Array:
	var defaulted_tiles := tiles
	if defaulted_tiles == null:
		defaulted_tiles = Global.current_project.tiles

	var x_basis: Vector2 = defaulted_tiles.x_basis
	var y_basis: Vector2 = defaulted_tiles.y_basis
	var tile_mode: int = defaulted_tiles.mode

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
			if not draw_center and r == 0 and c == 0:
				continue
			var position: Vector2 = r * y_basis + c * x_basis
			positions.append(position)
	return positions
