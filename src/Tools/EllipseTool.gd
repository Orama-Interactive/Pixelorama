extends "res://src/Tools/ShapeDrawer.gd"


func _get_shape_points_filled(size: Vector2) -> PoolVector2Array:
	var offseted_size := size + Vector2(2, 2) * (_thickness - 1)
	var border := _get_ellipse_points(Vector2.ZERO, offseted_size)
	var filling := []
	var bitmap := _fill_bitmap_with_points(border, offseted_size)

	for x in range(1, ceil(offseted_size.x / 2)):
		var fill := false
		var prev_is_true := false
		for y in range(0, ceil(offseted_size.y / 2)):
			var top_l_p := Vector2(x, y)
			var bit := bitmap.get_bit(top_l_p)

			if bit and not fill:
				prev_is_true = true
				continue

			if not bit and (fill or prev_is_true):
				filling.append(top_l_p)
				filling.append(Vector2(x, offseted_size.y - y - 1))
				filling.append(Vector2(offseted_size.x - x - 1, y))
				filling.append(Vector2(offseted_size.x - x - 1, offseted_size.y - y - 1))

				if prev_is_true:
					fill = true
					prev_is_true = false
			elif bit and fill:
				break

	return PoolVector2Array(border + filling)


func _get_shape_points(size: Vector2) -> PoolVector2Array:
	# Return ellipse with thickness 1
	if _thickness == 1:
		return PoolVector2Array(_get_ellipse_points(Vector2.ZERO, size))

	var size_offset := Vector2.ONE * 2 * (_thickness - 1)
	var new_size := size + size_offset
	var inner_ellipse_size = new_size - 2 * size_offset

	# The inner ellipse is to small to create a gap in the middle of the ellipse, just return a filled ellipse
	if inner_ellipse_size.x <= 2 and inner_ellipse_size.y <= 2:
		return _get_shape_points_filled(size)

	# Adapted scanline algorithm to fill between 2 ellipses, to create a thicker ellipse
	var res_array := []
	var border_ellipses :=  _get_ellipse_points(Vector2.ZERO, new_size) + _get_ellipse_points(size_offset, inner_ellipse_size) # Outer and inner ellipses
	var bitmap := _fill_bitmap_with_points(border_ellipses, new_size)
	var smallest_side := min (new_size.x, new_size.y)
	var largest_side := max (new_size.x, new_size.y)
	var scan_dir := Vector2(0, 1) if smallest_side == new_size.x else Vector2(1,0)
	var iscan_dir := Vector2(1, 0) if smallest_side == new_size.x else Vector2(0,1)
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
			for l in range (h_ls_c):
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


# Algorithm based on http://members.chello.at/easyfilter/bresenham.html
func _get_ellipse_points (pos: Vector2, size: Vector2) -> Array:
	var array := []
	var x0 := int(pos.x)
	var x1 := pos.x + int(size.x - 1)
	var y0 := int(pos.y)
	var y1 := int(pos.y) + int(size.y - 1)
	var a := int(abs(x1 - x0))
	var b := int(abs(y1 - x0))
	var b1 := b & 1
	var dx := 4*(1-a)*b*b
	var dy := 4*(b1+1)*a*a
	var err := dx+dy+b1*a*a
	var e2 := 0

	if x0 > x1:
		x0 = x1
		x1 += a

	if y0 > y1:
		y0 = y1

# warning-ignore:integer_division
	y0 += (b+1) / 2
	y1 = y0-b1
	a *= 8*a
	b1 = 8*b*b

	while x0 <= x1:
		var v1 := Vector2(x1, y0)
		var v2 := Vector2(x0, y0)
		var v3 := Vector2(x0, y1)
		var v4 := Vector2(x1, y1)
		array.append(v1)
		array.append(v2)
		array.append(v3)
		array.append(v4)

		e2 = 2*err;

		if e2 <= dy:
			y0 += 1
			y1 -= 1
			dy += a
			err += dy

		if e2 >= dx || 2*err > dy:
			x0+=1
			x1-=1
			dx += b1
			err += dx

	while y0-y1 < b:
		var v1 := Vector2(x0-1, y0)
		var v2 := Vector2(x1+1, y0)
		var v3 := Vector2(x0-1, y1)
		var v4 := Vector2(x1+1, y1)
		array.append(v1)
		array.append(v2)
		array.append(v3)
		array.append(v4)
		y0+=1
		y1-=1

	return array


func _fill_bitmap_with_points(points: Array, size: Vector2) -> BitMap:
	var bitmap := BitMap.new()
	bitmap.create(size)

	for point in points:
		bitmap.set_bit(point, 1)

	return bitmap
