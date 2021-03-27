class_name Drawer


class ColorOp:
	var strength := 1.0


	func process(src: Color, _dst: Color) -> Color:
		return src


class SimpleDrawer:
	func set_pixel(image: Image, position: Vector2, color: Color, op : ColorOp) -> void:
		var color_old := image.get_pixelv(position)
		var color_new := op.process(color, color_old)
		if not color_new.is_equal_approx(color_old):
			image.set_pixelv(position, color_new)


class PixelPerfectDrawer:
	const neighbours = [Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)]
	const corners = [Vector2(1, 1), Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1)]
	var last_pixels = [null, null]


	func reset() -> void:
		last_pixels = [null, null]


	func set_pixel(image: Image, position: Vector2, color: Color, op : ColorOp) -> void:
		var color_old = image.get_pixelv(position)
		last_pixels.push_back([position, color_old])
		image.set_pixelv(position, op.process(color, color_old))

		var corner = last_pixels.pop_front()
		var neighbour = last_pixels[0]

		if corner == null or neighbour == null:
			return

		if position - corner[0] in corners and position - neighbour[0] in neighbours:
			image.set_pixel(neighbour[0].x, neighbour[0].y, neighbour[1])
			last_pixels[0] = corner


var pixel_perfect := false setget set_pixel_perfect
var horizontal_mirror := false
var vertical_mirror := false
var color_op := ColorOp.new()

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


func set_pixel(image: Image, position: Vector2, color: Color) -> void:
	var project : Project = Global.current_project
	drawers[0].set_pixel(image, position, color, color_op)

	# Handle Mirroring
	var mirror_x = project.x_symmetry_point - position.x
	var mirror_y = project.y_symmetry_point - position.y
	var mirror_x_inside : bool
	var mirror_y_inside : bool
	mirror_x_inside = project.can_pixel_get_drawn(Vector2(mirror_x, position.y))
	mirror_y_inside = project.can_pixel_get_drawn(Vector2(position.x, mirror_y))


	if horizontal_mirror and mirror_x_inside:
		drawers[1].set_pixel(image, Vector2(mirror_x, position.y), color, color_op)
		if vertical_mirror and mirror_y_inside:
			drawers[2].set_pixel(image, Vector2(mirror_x, mirror_y), color, color_op)
	if vertical_mirror and mirror_y_inside:
		drawers[3].set_pixel(image, Vector2(position.x, mirror_y), color, color_op)
