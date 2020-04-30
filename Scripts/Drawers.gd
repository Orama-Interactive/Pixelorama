class Drawer:
	func reset() -> void:
		pass

	func set_pixel(sprite: Image, pos: Vector2, new_color: Color) -> void:
		pass


class SimpleDrawer extends Drawer:
	func reset() -> void:
		pass

	func set_pixel(sprite: Image, pos: Vector2, new_color: Color) -> void:
		sprite.set_pixel(pos.x, pos.y, new_color)


class PixelPerfectDrawer extends Drawer:
	const neighbours = [Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)]
	const corners = [Vector2(1, 1), Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1)]
	var last_pixels = [null, null]

	func reset():
		last_pixels = [null, null]

	func set_pixel(sprite: Image, pos: Vector2, new_color: Color) -> void:
		last_pixels.push_back([pos, sprite.get_pixel(pos.x, pos.y)])
		sprite.set_pixel(pos.x, pos.y, new_color)

		var corner = last_pixels.pop_front()
		var neighbour = last_pixels[0]

		if corner == null or neighbour == null:
			return

		if pos - corner[0] in corners and pos - neighbour[0] in neighbours:
			sprite.set_pixel(neighbour[0].x, neighbour[0].y, neighbour[1])
			last_pixels[0] = corner
