class_name Drawer

const NUMBER_OF_DRAWERS := 8

var pixel_perfect := false:
	set(value):
		pixel_perfect = value
		if pixel_perfect:
			drawers = pixel_perfect_drawers.duplicate()
		else:
			_create_simple_drawers()
var color_op := ColorOp.new()

var simple_drawer := SimpleDrawer.new()
var pixel_perfect_drawers: Array[PixelPerfectDrawer] = []
var drawers := []


class ColorOp:
	var strength := 1.0

	func process(src: Color, _dst: Color) -> Color:
		return src


class SimpleDrawer:
	func set_pixel(image: ImageExtended, position: Vector2i, color: Color, op: ColorOp) -> void:
		var color_old := image.get_pixelv(position)
		var color_str := color.to_html()
		var color_new := op.process(Color(color_str), color_old)
		if not color_new.is_equal_approx(color_old):
			image.set_pixelv_custom(position, color_new)
		else:
			image.set_pixelv_custom(position, color_new, image.is_indexed)


class PixelPerfectDrawer:
	const NEIGHBOURS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP]
	const CORNERS: Array[Vector2i] = [Vector2i.ONE, -Vector2i.ONE, Vector2i(-1, 1), Vector2i(1, -1)]
	var last_pixels := [null, null]

	func reset() -> void:
		last_pixels = [null, null]

	func set_pixel(image: ImageExtended, position: Vector2i, color: Color, op: ColorOp) -> void:
		var color_old := image.get_pixelv(position)
		var color_str := color.to_html()
		last_pixels.push_back([position, color_old])
		image.set_pixelv_custom(position, op.process(Color(color_str), color_old))

		var corner = last_pixels.pop_front()
		var neighbour = last_pixels[0]

		if corner == null or neighbour == null:
			return

		if position - corner[0] in CORNERS and position - neighbour[0] in NEIGHBOURS:
			image.set_pixel_custom(neighbour[0].x, neighbour[0].y, neighbour[1])
			last_pixels[0] = corner


func _init() -> void:
	drawers.resize(NUMBER_OF_DRAWERS)
	pixel_perfect_drawers.resize(NUMBER_OF_DRAWERS)
	for i in NUMBER_OF_DRAWERS:
		drawers[i] = simple_drawer
		pixel_perfect_drawers[i] = PixelPerfectDrawer.new()


func _create_simple_drawers() -> void:
	drawers = []
	drawers.resize(NUMBER_OF_DRAWERS)
	for i in NUMBER_OF_DRAWERS:
		drawers[i] = simple_drawer


func reset() -> void:
	for drawer in pixel_perfect_drawers:
		drawer.reset()


func set_pixel(image: Image, position: Vector2i, color: Color, ignore_mirroring := false) -> void:
	var project := Global.current_project
	if not Tools.check_alpha_lock(image, position):
		drawers[0].set_pixel(image, position, color, color_op)
	SteamManager.set_achievement("ACH_FIRST_PIXEL")
	if ignore_mirroring:
		return
	if (
		not Tools.horizontal_mirror
		and not Tools.vertical_mirror
		and not Tools.diagonal_xy_mirror
		and not Tools.diagonal_x_minus_y_mirror
	):
		return
	# Handle mirroring
	var mirrored_positions := Tools.get_mirrored_positions(position, project)
	for i in mirrored_positions.size():
		var mirror_pos := mirrored_positions[i]
		if project.can_pixel_get_drawn(mirror_pos) && not Tools.check_alpha_lock(image, mirror_pos):
			drawers[i + 1].set_pixel(image, mirror_pos, color, color_op)
