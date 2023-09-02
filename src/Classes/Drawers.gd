class_name Drawer

var pixel_perfect := false:
	set(value):
		pixel_perfect = value
		if pixel_perfect:
			drawers = pixel_perfect_drawers.duplicate()
		else:
			drawers = [simple_drawer, simple_drawer, simple_drawer, simple_drawer]
var horizontal_mirror := false
var vertical_mirror := false
var color_op := ColorOp.new()

var simple_drawer := SimpleDrawer.new()
var pixel_perfect_drawers: Array[PixelPerfectDrawer] = [
	PixelPerfectDrawer.new(),
	PixelPerfectDrawer.new(),
	PixelPerfectDrawer.new(),
	PixelPerfectDrawer.new()
]
var drawers := [simple_drawer, simple_drawer, simple_drawer, simple_drawer]


class ColorOp:
	var strength := 1.0

	func process(src: Color, _dst: Color) -> Color:
		return src


class SimpleDrawer:
	func set_pixel(image: Image, position: Vector2i, color: Color, op: ColorOp) -> void:
		var color_old := image.get_pixelv(position)
		var color_str = color.to_html()
		var color_new := op.process(Color(color_str), color_old)
		if not color_new.is_equal_approx(color_old):
			image.set_pixelv(position, color_new)


class PixelPerfectDrawer:
	const NEIGHBOURS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP]
	const CORNERS: Array[Vector2i] = [Vector2i.ONE, -Vector2i.ONE, Vector2i(-1, 1), Vector2i(1, -1)]
	var last_pixels := [null, null]

	func reset() -> void:
		last_pixels = [null, null]

	func set_pixel(image: Image, position: Vector2i, color: Color, op: ColorOp) -> void:
		var color_old := image.get_pixelv(position)
		var color_str := color.to_html()
		last_pixels.push_back([position, color_old])
		image.set_pixelv(position, op.process(Color(color_str), color_old))

		var corner = last_pixels.pop_front()
		var neighbour = last_pixels[0]

		if corner == null or neighbour == null:
			return

		if position - corner[0] in CORNERS and position - neighbour[0] in NEIGHBOURS:
			image.set_pixel(neighbour[0].x, neighbour[0].y, neighbour[1])
			last_pixels[0] = corner


func reset() -> void:
	for drawer in pixel_perfect_drawers:
		drawer.reset()


func set_pixel(image: Image, position: Vector2i, color: Color, ignore_mirroring := false) -> void:
	var project := Global.current_project
	drawers[0].set_pixel(image, position, color, color_op)
	if ignore_mirroring:
		return

	# Handle Mirroring
	var mirror_x := project.x_symmetry_point - position.x
	var mirror_y := project.y_symmetry_point - position.y

	if horizontal_mirror and project.can_pixel_get_drawn(Vector2i(mirror_x, position.y)):
		drawers[1].set_pixel(image, Vector2i(mirror_x, position.y), color, color_op)
		if vertical_mirror and project.can_pixel_get_drawn(Vector2i(position.x, mirror_y)):
			drawers[2].set_pixel(image, Vector2i(mirror_x, mirror_y), color, color_op)
	if vertical_mirror and project.can_pixel_get_drawn(Vector2i(position.x, mirror_y)):
		drawers[3].set_pixel(image, Vector2i(position.x, mirror_y), color, color_op)
