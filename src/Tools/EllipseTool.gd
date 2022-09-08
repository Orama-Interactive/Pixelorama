extends "res://src/Tools/ShapeDrawer.gd"


func _get_shape_points_filled(size: Vector2) -> PoolVector2Array:
	return DrawingAlgos.get_ellipse_points_filled(Vector2.ZERO, size, _thickness)


func _get_shape_points(size: Vector2) -> PoolVector2Array:
	# Return ellipse with thickness 1
	if _thickness == 1:
		return PoolVector2Array(DrawingAlgos.get_ellipse_points(Vector2.ZERO, size))

	var size_offset := Vector2.ONE * (_thickness - 1)
	var new_size := size + size_offset
	var inner_ellipse_size := new_size - size_offset

	# The inner ellipse is to small to create a gap in the middle of the ellipse,
	# just return a filled ellipse
	if inner_ellipse_size.x <= 2 and inner_ellipse_size.y <= 2:
		return _get_shape_points_filled(size)

	# Adapted scanline algorithm to fill between 2 ellipses, to create a thicker ellipse
	var res_array := []
	var border_ellipses := (
		DrawingAlgos.get_ellipse_points(Vector2.ZERO, new_size)
		+ DrawingAlgos.get_ellipse_points(size_offset, inner_ellipse_size)
	)  # Outer and inner ellipses
	var bitmap := _fill_bitmap_with_points(border_ellipses, new_size)
	var smallest_side := min(new_size.x, new_size.y)
	var largest_side := max(new_size.x, new_size.y)
	var scan_dir := Vector2(0, 1) if smallest_side == new_size.x else Vector2(1, 0)
	var iscan_dir := Vector2(1, 0) if smallest_side == new_size.x else Vector2(0, 1)
	var ie_relevant_offset_side = size_offset.x if smallest_side == new_size.x else size_offset.y
	var h_ls_c := ceil(largest_side / 2)

	for s in range(ceil(smallest_side / 2)):
		if s <= ie_relevant_offset_side:
			var draw := false
			for l in range(h_ls_c):
				var pos := scan_dir * l + iscan_dir * s
				if bitmap.get_bit(pos):
					draw = true
				if draw:
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
				if bitmap.get_bit(pos):
					l_o = l
					break
			# Find inner ellipse
			var li := 0
			for l in range(h_ls_c, 0, -1):
				var pos := scan_dir * l + iscan_dir * s
				if bitmap.get_bit(pos):
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

	return PoolVector2Array(res_array)
