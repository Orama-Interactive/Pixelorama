extends "res://src/Tools/BaseShapeDrawer.gd"


func _get_shape_points_filled(shape_size: Vector2i) -> Array[Vector2i]:
	return DrawingAlgos.get_ellipse_points_filled(Vector2i.ZERO, shape_size, _thickness)


func _get_shape_points(shape_size: Vector2i) -> Array[Vector2i]:
	# Return ellipse with thickness 1
	if _thickness == 1:
		return DrawingAlgos.get_ellipse_points(Vector2i.ZERO, shape_size)

	var size_offset := Vector2i.ONE * (_thickness - 1)
	var new_size := shape_size + size_offset
	var inner_ellipse_size := new_size - 2 * size_offset

	# The inner ellipse is to small to create a gap in the middle of the ellipse,
	# just return a filled ellipse
	if inner_ellipse_size.x <= 2 and inner_ellipse_size.y <= 2:
		return _get_shape_points_filled(shape_size)

	# Adapted scanline algorithm to fill between 2 ellipses, to create a thicker ellipse
	var res_array: Array[Vector2i] = []
	var border_ellipses := (
		DrawingAlgos.get_ellipse_points(Vector2i.ZERO, new_size)
		+ DrawingAlgos.get_ellipse_points(size_offset, inner_ellipse_size)
	)  # Outer and inner ellipses
	var bitmap := _fill_bitmap_with_points(border_ellipses, new_size)
	var smallest_side := mini(new_size.x, new_size.y)
	var largest_side := maxi(new_size.x, new_size.y)
	var scan_dir := Vector2i(0, 1) if smallest_side == new_size.x else Vector2i(1, 0)
	var iscan_dir := Vector2i(1, 0) if smallest_side == new_size.x else Vector2i(0, 1)
	var ie_relevant_offset_side := size_offset.x if smallest_side == new_size.x else size_offset.y
	var h_ls_c := ceili(largest_side / 2.0)

	for s in range(ceili(smallest_side / 2.0)):
		if s <= ie_relevant_offset_side:
			var can_draw := false
			for l in range(h_ls_c):
				var pos := scan_dir * l + iscan_dir * s
				if bitmap.get_bitv(pos):
					can_draw = true
				if can_draw:
					var mirror_smallest_side := iscan_dir * (smallest_side - 1 - 2 * s)
					var mirror_largest_side := scan_dir * (largest_side - 1 - 2 * l)
					res_array.append(pos)
					res_array.append(pos + mirror_largest_side)
					res_array.append(pos + mirror_smallest_side)
					res_array.append(pos + mirror_smallest_side + mirror_largest_side)
		else:
			# Find outer ellipse
			var l_o := 0
			for l in range(h_ls_c):
				var pos := scan_dir * l + iscan_dir * s
				if bitmap.get_bitv(pos):
					l_o = l
					break
			# Find inner ellipse
			var li := 0
			for l in range(h_ls_c, 0, -1):
				var pos := scan_dir * l + iscan_dir * s
				if bitmap.get_bitv(pos):
					li = l
					break
			# Fill between both
			for l in range(l_o, li + 1):
				var pos := scan_dir * l + iscan_dir * s
				var mirror_smallest_side := iscan_dir * (smallest_side - 1 - 2 * s)
				var mirror_largest_side := scan_dir * (largest_side - 1 - 2 * l)
				res_array.append(pos)
				res_array.append(pos + mirror_largest_side)
				res_array.append(pos + mirror_smallest_side)
				res_array.append(pos + mirror_smallest_side + mirror_largest_side)

	return res_array
