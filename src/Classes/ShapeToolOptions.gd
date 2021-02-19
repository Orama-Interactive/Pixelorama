class_name ShapeToolOptions


class ShapeToolOption:
	var name: String

	func _init(n: String) -> void:
		name = n


	func _outline_point(p: Vector2, thickness: int = 1, include_p: bool = true) -> PoolVector2Array:
		var array := []

		if thickness != 1:
			var t_of = thickness - 1
			for x in range (-t_of, thickness):
				for y in range (-t_of, thickness):
					if x == 0 and y == 0 and not include_p:
						continue

					array.append(p + Vector2(x,y))


		elif include_p:
			array.append(p)
		return PoolVector2Array(array)


	func get_draw_points_filled(_size: Vector2, _thickness: int = 1) -> PoolVector2Array:
		return PoolVector2Array()


	func get_draw_points(_size: Vector2, _thickness: int = 1) -> PoolVector2Array:
		return PoolVector2Array()


class Rectangle extends ShapeToolOption:
	func _init().(tr("Rectangle")):
		pass


	func get_draw_points_filled(size: Vector2, thickness: int = 1) -> PoolVector2Array:
		var array := []
		var t_of := thickness - 1
		for y in range(- t_of, size.y + t_of):
			for x in range(-t_of, size.x + t_of):
				array.append(Vector2(x, y))

		return PoolVector2Array(array)


	func _get_unfilled_square_ps(pos: Vector2, size: Vector2):
		var array := []

		var y1 = size.y + pos.y - 1
		for x in range(pos.x, size.x + pos.x):
			var t := Vector2(x, pos.y)
			var b := Vector2(x, y1)
			array.append(t)
			array.append(b)

		var x1 = size.x + pos.x - 1
		for y in range(pos.y + 1, size.y + pos.y):
			var l := Vector2(pos.x, y)
			var r := Vector2(x1, y)
			array.append(l)
			array.append(r)

		return PoolVector2Array(array)


	func get_draw_points(size: Vector2, thickness: int = 1) -> PoolVector2Array:
		var t_of: int = thickness - 1

		if thickness == 1:
			return _get_unfilled_square_ps(Vector2(0, 0), size)
		else:
			var array := []
			for i in range(-t_of, thickness):
				array += Array(_get_unfilled_square_ps(Vector2(i, i), size - Vector2(2 * i, 2 * i)))

			return PoolVector2Array(array)


class Ellipse extends ShapeToolOption:
	func _init().(tr("Ellipse")):
		pass

# Probably a terrible way to do this, but I couldn't get any other algorithm to work correctly or that is consistent to the ellipse's get_draw_points
	func get_draw_points_filled(size: Vector2, thickness: int = 1) -> PoolVector2Array:
		var border := get_draw_points(size, thickness)
		var array := Array(border)
		var bitmap := BitMap.new()
		bitmap.create(size)

		for point in border:
			if point.x >= 0 and point.y >= 0 and point.x < size.x and point.y < size.y:
				bitmap.set_bit(point, 1)

		for x in range(1, ceil(size.x / 2)):
			var fill := false
			var prev_was_true := false
			for y in range(0, ceil(size.y / 2)):
				var top_l_p := Vector2(x, y)
				var bottom_l_p := Vector2(x, size.y - y - 1)
				var top_r_p := Vector2(size.x - x - 1, y)
				var bottom_r_p := Vector2(size.x - x - 1, size.y - y - 1)
				var bit := bitmap.get_bit(top_l_p)

				if bit and not prev_was_true and not fill:
					prev_was_true = true
				if not bit and (fill or prev_was_true):
					array.append(top_l_p)
					array.append(bottom_l_p)
					array.append(top_r_p)
					array.append(bottom_r_p)

					if prev_was_true:
						prev_was_true = false
						fill = true
				elif fill and bit:
					break

		return PoolVector2Array(array)


# Algorithm based on http://members.chello.at/easyfilter/bresenham.html
	func get_draw_points(_size: Vector2, thickness: int = 1) -> PoolVector2Array:
		var array := []
		var x0 := 0
		var x1 := int(_size.x - 1)
		var y0 := 0
		var y1 := int(_size.y - 1)
		var a := x1
		var b := y1
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
			array += Array(_outline_point(v1, thickness, false))
			array += Array(_outline_point(v2, thickness, false))
			array += Array(_outline_point(v3, thickness, false))
			array += Array(_outline_point(v4, thickness, false))

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
			array += Array(_outline_point(v1, thickness, false))
			array += Array(_outline_point(v2, thickness, false))
			array += Array(_outline_point(v3, thickness, false))
			array += Array(_outline_point(v4, thickness, false))
			y0+=1
			y1-=1


		return PoolVector2Array(array)
