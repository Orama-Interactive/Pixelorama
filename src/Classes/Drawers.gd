class_name Drawer

class SimpleDrawer:
	func set_pixel(_sprite: Image, _pos: Vector2, _new_color: Color) -> void:
		_sprite.set_pixel(_pos.x, _pos.y, _new_color)


class PixelPerfectDrawer:
	const neighbours = [Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)]
	const corners = [Vector2(1, 1), Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1)]
	var last_pixels = [null, null]


	func reset() -> void:
		last_pixels = [null, null]


	func set_pixel(_sprite: Image, _pos: Vector2, _new_color: Color) -> void:
		last_pixels.push_back([_pos, _sprite.get_pixel(_pos.x, _pos.y)])
		_sprite.set_pixel(_pos.x, _pos.y, _new_color)

		var corner = last_pixels.pop_front()
		var neighbour = last_pixels[0]

		if corner == null or neighbour == null:
			return

		if _pos - corner[0] in corners and _pos - neighbour[0] in neighbours:
			_sprite.set_pixel(neighbour[0].x, neighbour[0].y, neighbour[1])
			last_pixels[0] = corner


var pixel_perfect := false setget set_pixel_perfect
var h_mirror := false
var v_mirror := false

var simple_drawer := SimpleDrawer.new()
var pixel_perfect_drawers = [PixelPerfectDrawer.new(), PixelPerfectDrawer.new(), PixelPerfectDrawer.new(), PixelPerfectDrawer.new()]
var drawers = [simple_drawer, simple_drawer, simple_drawer, simple_drawer]


func reset() -> void:
	for drawer in pixel_perfect_drawers:
		drawer.reset()


func set_pixel_perfect(value: bool) -> void:
	pixel_perfect = value
	if pixel_perfect:
		drawers = pixel_perfect_drawers.duplicate()
	else:
		drawers = [simple_drawer, simple_drawer, simple_drawer, simple_drawer]


func set_pixel(_sprite: Image, _pos: Vector2, _new_color: Color) -> void:
	var mirror_x = Global.canvas.east_limit + Global.canvas.west_limit - _pos.x - 1
	var mirror_y = Global.canvas.south_limit + Global.canvas.north_limit - _pos.y - 1

	drawers[0].set_pixel(_sprite, _pos, _new_color)
	if h_mirror:
		drawers[1].set_pixel(_sprite, Vector2(mirror_x, _pos.y), _new_color)
		if v_mirror:
			drawers[2].set_pixel(_sprite, Vector2(mirror_x, mirror_y), _new_color)
	if v_mirror:
		drawers[3].set_pixel(_sprite, Vector2(_pos.x, mirror_y), _new_color)
