extends Node

enum GradientDirection { TOP, BOTTOM, LEFT, RIGHT }
# Continuation from Image.Interpolation
enum Interpolation { SCALE3X = 5, CLEANEDGE = 6, OMNISCALE = 7 }
var clean_edge_shader: Shader = preload("res://src/Shaders/Rotation/cleanEdge.gdshader")
var omniscale_shader: Shader


func _ready() -> void:
	if OS.get_current_video_driver() == OS.VIDEO_DRIVER_GLES3:
		omniscale_shader = load("res://src/Shaders/Rotation/OmniScale.gdshader")


# Algorithm based on http://members.chello.at/easyfilter/bresenham.html
func get_ellipse_points(pos: Vector2, size: Vector2) -> Array:
	var array := []
	var x0 := int(pos.x)
	var x1 := pos.x + int(size.x - 1)
	var y0 := int(pos.y)
	var y1 := int(pos.y) + int(size.y - 1)
	var a := int(abs(x1 - x0))
	var b := int(abs(y1 - x0))
	var b1 := b & 1
	var dx := 4 * (1 - a) * b * b
	var dy := 4 * (b1 + 1) * a * a
	var err := dx + dy + b1 * a * a
	var e2 := 0

	if x0 > x1:
		x0 = x1
		x1 += a

	if y0 > y1:
		y0 = y1

# warning-ignore:integer_division
	y0 += (b + 1) / 2
	y1 = y0 - b1
	a *= 8 * a
	b1 = 8 * b * b

	while x0 <= x1:
		var v1 := Vector2(x1, y0)
		var v2 := Vector2(x0, y0)
		var v3 := Vector2(x0, y1)
		var v4 := Vector2(x1, y1)
		array.append(v1)
		array.append(v2)
		array.append(v3)
		array.append(v4)

		e2 = 2 * err
		if e2 <= dy:
			y0 += 1
			y1 -= 1
			dy += a
			err += dy

		if e2 >= dx || 2 * err > dy:
			x0 += 1
			x1 -= 1
			dx += b1
			err += dx

	while y0 - y1 < b:
		var v1 := Vector2(x0 - 1, y0)
		var v2 := Vector2(x1 + 1, y0)
		var v3 := Vector2(x0 - 1, y1)
		var v4 := Vector2(x1 + 1, y1)
		array.append(v1)
		array.append(v2)
		array.append(v3)
		array.append(v4)
		y0 += 1
		y1 -= 1

	return array


func get_ellipse_points_filled(pos: Vector2, size: Vector2, thickness := 1) -> PoolVector2Array:
	var offsetted_size := size + Vector2.ONE * (thickness - 1)
	var border := get_ellipse_points(pos, offsetted_size)
	var filling := []

	for x in range(1, ceil(offsetted_size.x / 2)):
		var fill := false
		var prev_is_true := false
		for y in range(0, ceil(offsetted_size.y / 2)):
			var top_l_p := Vector2(x, y)
			var bit := border.has(pos + top_l_p)

			if bit and not fill:
				prev_is_true = true
				continue

			if not bit and (fill or prev_is_true):
				filling.append(pos + top_l_p)
				filling.append(pos + Vector2(x, offsetted_size.y - y - 1))
				filling.append(pos + Vector2(offsetted_size.x - x - 1, y))
				filling.append(pos + Vector2(offsetted_size.x - x - 1, offsetted_size.y - y - 1))

				if prev_is_true:
					fill = true
					prev_is_true = false
			elif bit and fill:
				break

	return PoolVector2Array(border + filling)


func scale_3x(sprite: Image, tol: float = 50) -> Image:
	var scaled := Image.new()
	scaled.create(sprite.get_width() * 3, sprite.get_height() * 3, false, Image.FORMAT_RGBA8)
	scaled.lock()
	sprite.lock()
	var a: Color
	var b: Color
	var c: Color
	var d: Color
	var e: Color
	var f: Color
	var g: Color
	var h: Color
	var i: Color

	for x in range(0, sprite.get_width()):
		for y in range(0, sprite.get_height()):
			var xs: float = 3 * x
			var ys: float = 3 * y

			a = sprite.get_pixel(max(x - 1, 0), max(y - 1, 0))
			b = sprite.get_pixel(min(x, sprite.get_width() - 1), max(y - 1, 0))
			c = sprite.get_pixel(min(x + 1, sprite.get_width() - 1), max(y - 1, 0))
			d = sprite.get_pixel(max(x - 1, 0), min(y, sprite.get_height() - 1))
			e = sprite.get_pixel(min(x, sprite.get_width() - 1), min(y, sprite.get_height() - 1))
			f = sprite.get_pixel(
				min(x + 1, sprite.get_width() - 1), min(y, sprite.get_height() - 1)
			)
			g = sprite.get_pixel(max(x - 1, 0), min(y + 1, sprite.get_height() - 1))
			h = sprite.get_pixel(
				min(x, sprite.get_width() - 1), min(y + 1, sprite.get_height() - 1)
			)
			i = sprite.get_pixel(
				min(x + 1, sprite.get_width() - 1), min(y + 1, sprite.get_height() - 1)
			)

			var db: bool = similar_colors(d, b, tol)
			var dh: bool = similar_colors(d, h, tol)
			var bf: bool = similar_colors(f, b, tol)
			var ec: bool = similar_colors(e, c, tol)
			var ea: bool = similar_colors(e, a, tol)
			var fh: bool = similar_colors(f, h, tol)
			var eg: bool = similar_colors(e, g, tol)
			var ei: bool = similar_colors(e, i, tol)

			scaled.set_pixel(max(xs - 1, 0), max(ys - 1, 0), d if (db and !dh and !bf) else e)
			scaled.set_pixel(
				xs,
				max(ys - 1, 0),
				b if (db and !dh and !bf and !ec) or (bf and !db and !fh and !ea) else e
			)
			scaled.set_pixel(xs + 1, max(ys - 1, 0), f if (bf and !db and !fh) else e)
			scaled.set_pixel(
				max(xs - 1, 0),
				ys,
				d if (dh and !fh and !db and !ea) or (db and !dh and !bf and !eg) else e
			)
			scaled.set_pixel(xs, ys, e)
			scaled.set_pixel(
				xs + 1, ys, f if (bf and !db and !fh and !ei) or (fh and !bf and !dh and !ec) else e
			)
			scaled.set_pixel(max(xs - 1, 0), ys + 1, d if (dh and !fh and !db) else e)
			scaled.set_pixel(
				xs, ys + 1, h if (fh and !bf and !dh and !eg) or (dh and !fh and !db and !ei) else e
			)
			scaled.set_pixel(xs + 1, ys + 1, f if (fh and !bf and !dh) else e)

	scaled.unlock()
	sprite.unlock()
	return scaled


func rotxel(sprite: Image, angle: float, pivot: Vector2) -> void:
	# If angle is simple, then nn rotation is the best
	if angle == 0 || angle == PI / 2 || angle == PI || angle == 2 * PI:
		nn_rotate(sprite, angle, pivot)
		return

	var aux: Image = Image.new()
	aux.copy_from(sprite)
	var ox: int
	var oy: int
	var p: Color
	aux.lock()
	sprite.lock()
	for x in sprite.get_size().x:
		for y in sprite.get_size().y:
			var dx = 3 * (x - pivot.x)
			var dy = 3 * (y - pivot.y)
			var found_pixel: bool = false
			for k in range(9):
				var i = -1 + k % 3
# warning-ignore:integer_division
				var j = -1 + int(k / 3)
				var dir = atan2(dy + j, dx + i)
				var mag = sqrt(pow(dx + i, 2) + pow(dy + j, 2))
				dir -= angle
				ox = round(pivot.x * 3 + 1 + mag * cos(dir))
				oy = round(pivot.y * 3 + 1 + mag * sin(dir))

				if sprite.get_width() % 2 != 0:
					ox += 1
					oy += 1

				if (
					ox >= 0
					&& ox < sprite.get_width() * 3
					&& oy >= 0
					&& oy < sprite.get_height() * 3
				):
					found_pixel = true
					break

			if !found_pixel:
				sprite.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var fil: int = oy % 3
			var col: int = ox % 3
			var index: int = col + 3 * fil

			ox = round((ox - 1) / 3.0)
			oy = round((oy - 1) / 3.0)
			var a: Color
			var b: Color
			var c: Color
			var d: Color
			var e: Color
			var f: Color
			var g: Color
			var h: Color
			var i: Color
			if ox == 0 || ox == sprite.get_width() - 1 || oy == 0 || oy == sprite.get_height() - 1:
				p = aux.get_pixel(ox, oy)
			else:
				a = aux.get_pixel(ox - 1, oy - 1)
				b = aux.get_pixel(ox, oy - 1)
				c = aux.get_pixel(ox + 1, oy - 1)
				d = aux.get_pixel(ox - 1, oy)
				e = aux.get_pixel(ox, oy)
				f = aux.get_pixel(ox + 1, oy)
				g = aux.get_pixel(ox - 1, oy + 1)
				h = aux.get_pixel(ox, oy + 1)
				i = aux.get_pixel(ox + 1, oy + 1)

				match index:
					0:
						p = (
							d
							if (
								similar_colors(d, b)
								&& !similar_colors(d, h)
								&& !similar_colors(b, f)
							)
							else e
						)
					1:
						p = (
							b
							if (
								(
									similar_colors(d, b)
									&& !similar_colors(d, h)
									&& !similar_colors(b, f)
									&& !similar_colors(e, c)
								)
								|| (
									similar_colors(b, f)
									&& !similar_colors(d, b)
									&& !similar_colors(f, h)
									&& !similar_colors(e, a)
								)
							)
							else e
						)
					2:
						p = (
							f
							if (
								similar_colors(b, f)
								&& !similar_colors(d, b)
								&& !similar_colors(f, h)
							)
							else e
						)
					3:
						p = (
							d
							if (
								(
									similar_colors(d, h)
									&& !similar_colors(f, h)
									&& !similar_colors(d, b)
									&& !similar_colors(e, a)
								)
								|| (
									similar_colors(d, b)
									&& !similar_colors(d, h)
									&& !similar_colors(b, f)
									&& !similar_colors(e, g)
								)
							)
							else e
						)
					4:
						p = e
					5:
						p = (
							f
							if (
								(
									similar_colors(b, f)
									&& !similar_colors(d, b)
									&& !similar_colors(f, h)
									&& !similar_colors(e, i)
								)
								|| (
									similar_colors(f, h)
									&& !similar_colors(b, f)
									&& !similar_colors(d, h)
									&& !similar_colors(e, c)
								)
							)
							else e
						)
					6:
						p = (
							d
							if (
								similar_colors(d, h)
								&& !similar_colors(f, h)
								&& !similar_colors(d, b)
							)
							else e
						)
					7:
						p = (
							h
							if (
								(
									similar_colors(f, h)
									&& !similar_colors(f, b)
									&& !similar_colors(d, h)
									&& !similar_colors(e, g)
								)
								|| (
									similar_colors(d, h)
									&& !similar_colors(f, h)
									&& !similar_colors(d, b)
									&& !similar_colors(e, i)
								)
							)
							else e
						)
					8:
						p = (
							f
							if (
								similar_colors(f, h)
								&& !similar_colors(f, b)
								&& !similar_colors(d, h)
							)
							else e
						)
			sprite.set_pixel(x, y, p)
	sprite.unlock()
	aux.unlock()


func fake_rotsprite(sprite: Image, angle: float, pivot: Vector2) -> void:
	var selected_sprite := Image.new()
	selected_sprite.copy_from(sprite)
	selected_sprite.copy_from(scale_3x(selected_sprite))
	nn_rotate(selected_sprite, angle, pivot * 3)
# warning-ignore:integer_division
# warning-ignore:integer_division
	selected_sprite.resize(selected_sprite.get_width() / 3, selected_sprite.get_height() / 3, 0)
	sprite.blit_rect(selected_sprite, Rect2(Vector2.ZERO, selected_sprite.get_size()), Vector2.ZERO)


func nn_rotate(sprite: Image, angle: float, pivot: Vector2) -> void:
	var aux: Image = Image.new()
	aux.copy_from(sprite)
	sprite.lock()
	aux.lock()
	var ox: int
	var oy: int
	for x in range(sprite.get_width()):
		for y in range(sprite.get_height()):
			ox = (x - pivot.x) * cos(angle) + (y - pivot.y) * sin(angle) + pivot.x
			oy = -(x - pivot.x) * sin(angle) + (y - pivot.y) * cos(angle) + pivot.y
			if ox >= 0 && ox < sprite.get_width() && oy >= 0 && oy < sprite.get_height():
				sprite.set_pixel(x, y, aux.get_pixel(ox, oy))
			else:
				sprite.set_pixel(x, y, Color(0, 0, 0, 0))
	sprite.unlock()
	aux.unlock()


func similar_colors(c1: Color, c2: Color, tol: float = 100) -> bool:
	var dist = color_distance(c1, c2)
	return dist <= tol


func color_distance(c1: Color, c2: Color) -> float:
	return sqrt(
		(
			pow((c1.r - c2.r) * 255, 2)
			+ pow((c1.g - c2.g) * 255, 2)
			+ pow((c1.b - c2.b) * 255, 2)
			+ pow((c1.a - c2.a) * 255, 2)
		)
	)


# Image effects


func scale_image(width: int, height: int, interpolation: int) -> void:
	general_do_scale(width, height)

	for f in Global.current_project.frames:
		for i in range(f.cels.size() - 1, -1, -1):
			if f.cels[i] is GroupCel:
				continue
			var sprite := Image.new()
			sprite.copy_from(f.cels[i].image)
			if interpolation == Interpolation.SCALE3X:
				var times: Vector2 = Vector2(
					ceil(width / (3.0 * sprite.get_width())),
					ceil(height / (3.0 * sprite.get_height()))
				)
				for _j in range(max(times.x, times.y)):
					sprite.copy_from(scale_3x(sprite))
				sprite.resize(width, height, 0)
			elif interpolation == Interpolation.CLEANEDGE:
				var params := {"angle": 0, "slope": true, "cleanup": true, "preview": false}
				var gen := ShaderImageEffect.new()
				gen.generate_image(sprite, clean_edge_shader, params, Vector2(width, height))
			elif interpolation == Interpolation.OMNISCALE and omniscale_shader:
				var params := {"angle": 0, "preview": false}
				var gen := ShaderImageEffect.new()
				gen.generate_image(sprite, omniscale_shader, params, Vector2(width, height))
			else:
				sprite.resize(width, height, interpolation)
			Global.current_project.undo_redo.add_do_property(f.cels[i].image, "data", sprite.data)
			Global.current_project.undo_redo.add_undo_property(
				f.cels[i].image, "data", f.cels[i].image.data
			)

	general_undo_scale()


func centralize() -> void:
	Global.canvas.selection.transform_content_confirm()
	# Find used rect of the current frame (across all of the layers)
	var used_rect := Rect2()
	for cel in Global.current_project.frames[Global.current_project.current_frame].cels:
		if not cel is PixelCel:
			continue
		var cel_rect: Rect2 = cel.image.get_used_rect()
		if not cel_rect.has_no_area():
			used_rect = cel_rect if used_rect.has_no_area() else used_rect.merge(cel_rect)
	if used_rect.has_no_area():
		return

	var offset: Vector2 = (0.5 * (Global.current_project.size - used_rect.size)).floor()
	general_do_centralize()
	for cel in Global.current_project.frames[Global.current_project.current_frame].cels:
		if not cel is PixelCel:
			continue
		var sprite := Image.new()
		sprite.create(
			Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_RGBA8
		)
		sprite.blend_rect(cel.image, used_rect, offset)
		Global.current_project.undo_redo.add_do_property(cel.image, "data", sprite.data)
		Global.current_project.undo_redo.add_undo_property(cel.image, "data", cel.image.data)
	general_undo_centralize()


func crop_image() -> void:
	Global.canvas.selection.transform_content_confirm()
	var used_rect := Rect2()
	for f in Global.current_project.frames:
		for cel in f.cels:
			if not cel is PixelCel:
				continue
			cel.image.unlock()  # May be unneeded now, but keep it just in case
			var cel_used_rect: Rect2 = cel.image.get_used_rect()
			if cel_used_rect == Rect2(0, 0, 0, 0):  # If the cel has no content
				continue

			if used_rect == Rect2(0, 0, 0, 0):  # If we still haven't found the first cel with content
				used_rect = cel_used_rect
			else:
				used_rect = used_rect.merge(cel_used_rect)

	# If no layer has any content, just return
	if used_rect == Rect2(0, 0, 0, 0):
		return

	var width := used_rect.size.x
	var height := used_rect.size.y
	general_do_scale(width, height)
	# Loop through all the cels to crop them
	for f in Global.current_project.frames:
		for cel in f.cels:
			if not cel is PixelCel:
				continue
			var sprite: Image = cel.image.get_rect(used_rect)
			Global.current_project.undo_redo.add_do_property(cel.image, "data", sprite.data)
			Global.current_project.undo_redo.add_undo_property(cel.image, "data", cel.image.data)

	general_undo_scale()


func resize_canvas(width: int, height: int, offset_x: int, offset_y: int) -> void:
	general_do_scale(width, height)
	for f in Global.current_project.frames:
		for c in f.cels:
			if not c is PixelCel:
				continue
			var sprite := Image.new()
			sprite.create(width, height, false, Image.FORMAT_RGBA8)
			sprite.blend_rect(
				c.image,
				Rect2(Vector2.ZERO, Global.current_project.size),
				Vector2(offset_x, offset_y)
			)
			Global.current_project.undo_redo.add_do_property(c.image, "data", sprite.data)
			Global.current_project.undo_redo.add_undo_property(c.image, "data", c.image.data)

	general_undo_scale()


func general_do_scale(width: int, height: int) -> void:
	var project: Project = Global.current_project
	var size := Vector2(width, height).floor()
	var x_ratio = project.size.x / width
	var y_ratio = project.size.y / height

	var selection_map_copy := SelectionMap.new()
	selection_map_copy.copy_from(project.selection_map)
	selection_map_copy.crop(size.x, size.y)

	var new_x_symmetry_point = project.x_symmetry_point / x_ratio
	var new_y_symmetry_point = project.y_symmetry_point / y_ratio
	var new_x_symmetry_axis_points = project.x_symmetry_axis.points
	var new_y_symmetry_axis_points = project.y_symmetry_axis.points
	new_x_symmetry_axis_points[0].y /= y_ratio
	new_x_symmetry_axis_points[1].y /= y_ratio
	new_y_symmetry_axis_points[0].x /= x_ratio
	new_y_symmetry_axis_points[1].x /= x_ratio

	project.undos += 1
	project.undo_redo.create_action("Scale")
	project.undo_redo.add_do_property(project, "size", size)
	project.undo_redo.add_do_property(project, "selection_map", selection_map_copy)
	project.undo_redo.add_do_property(project, "x_symmetry_point", new_x_symmetry_point)
	project.undo_redo.add_do_property(project, "y_symmetry_point", new_y_symmetry_point)
	project.undo_redo.add_do_property(project.x_symmetry_axis, "points", new_x_symmetry_axis_points)
	project.undo_redo.add_do_property(project.y_symmetry_axis, "points", new_y_symmetry_axis_points)


func general_undo_scale() -> void:
	var project: Project = Global.current_project
	project.undo_redo.add_undo_property(project, "size", project.size)
	project.undo_redo.add_undo_property(project, "selection_map", project.selection_map)
	project.undo_redo.add_undo_property(project, "x_symmetry_point", project.x_symmetry_point)
	project.undo_redo.add_undo_property(project, "y_symmetry_point", project.y_symmetry_point)
	project.undo_redo.add_undo_property(
		project.x_symmetry_axis, "points", project.x_symmetry_axis.points
	)
	project.undo_redo.add_undo_property(
		project.y_symmetry_axis, "points", project.y_symmetry_axis.points
	)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.commit_action()


func general_do_centralize() -> void:
	var project: Project = Global.current_project
	project.undos += 1
	project.undo_redo.create_action("Centralize")


func general_undo_centralize() -> void:
	var project: Project = Global.current_project
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.commit_action()


func generate_outline(
	image: Image,
	affect_selection: bool,
	project: Project,
	outline_color: Color,
	thickness: int,
	diagonal: bool,
	inside_image: bool
) -> void:
	if image.is_invisible():
		return
	var new_image := Image.new()
	new_image.copy_from(image)
	new_image.lock()
	image.lock()

	for x in project.size.x:
		for y in project.size.y:
			var pos := Vector2(x, y)
			var current_pixel := image.get_pixelv(pos)
			if affect_selection and !project.can_pixel_get_drawn(pos):
				continue
			if current_pixel.a == 0:
				continue

			for i in range(1, thickness + 1):
				if inside_image:
					var outline_pos: Vector2 = pos + Vector2.LEFT  # Left
					if outline_pos.x < 0 || image.get_pixelv(outline_pos).a == 0:
						var new_pos: Vector2 = pos + Vector2.RIGHT * (i - 1)
						if new_pos.x < Global.current_project.size.x:
							var new_pixel = image.get_pixelv(new_pos)
							if new_pixel.a > 0:
								new_image.set_pixelv(new_pos, outline_color)

					outline_pos = pos + Vector2.RIGHT  # Right
					if (
						outline_pos.x >= Global.current_project.size.x
						|| image.get_pixelv(outline_pos).a == 0
					):
						var new_pos: Vector2 = pos + Vector2.LEFT * (i - 1)
						if new_pos.x >= 0:
							var new_pixel = image.get_pixelv(new_pos)
							if new_pixel.a > 0:
								new_image.set_pixelv(new_pos, outline_color)

					outline_pos = pos + Vector2.UP  # Up
					if outline_pos.y < 0 || image.get_pixelv(outline_pos).a == 0:
						var new_pos: Vector2 = pos + Vector2.DOWN * (i - 1)
						if new_pos.y < Global.current_project.size.y:
							var new_pixel = image.get_pixelv(new_pos)
							if new_pixel.a > 0:
								new_image.set_pixelv(new_pos, outline_color)

					outline_pos = pos + Vector2.DOWN  # Down
					if (
						outline_pos.y >= Global.current_project.size.y
						|| image.get_pixelv(outline_pos).a == 0
					):
						var new_pos: Vector2 = pos + Vector2.UP * (i - 1)
						if new_pos.y >= 0:
							var new_pixel = image.get_pixelv(new_pos)
							if new_pixel.a > 0:
								new_image.set_pixelv(new_pos, outline_color)

					if diagonal:
						outline_pos = pos + (Vector2.LEFT + Vector2.UP)  # Top left
						if (
							(outline_pos.x < 0 && outline_pos.y < 0)
							|| image.get_pixelv(outline_pos).a == 0
						):
							var new_pos: Vector2 = pos + (Vector2.RIGHT + Vector2.DOWN) * (i - 1)
							if (
								new_pos.x < Global.current_project.size.x
								&& new_pos.y < Global.current_project.size.y
							):
								var new_pixel = image.get_pixelv(new_pos)
								if new_pixel.a > 0:
									new_image.set_pixelv(new_pos, outline_color)

						outline_pos = pos + (Vector2.LEFT + Vector2.DOWN)  # Bottom left
						if (
							(outline_pos.x < 0 && outline_pos.y >= Global.current_project.size.y)
							|| image.get_pixelv(outline_pos).a == 0
						):
							var new_pos: Vector2 = pos + (Vector2.RIGHT + Vector2.UP) * (i - 1)
							if new_pos.x < Global.current_project.size.x && new_pos.y >= 0:
								var new_pixel = image.get_pixelv(new_pos)
								if new_pixel.a > 0:
									new_image.set_pixelv(new_pos, outline_color)

						outline_pos = pos + (Vector2.RIGHT + Vector2.UP)  # Top right
						if (
							(outline_pos.x >= Global.current_project.size.x && outline_pos.y < 0)
							|| image.get_pixelv(outline_pos).a == 0
						):
							var new_pos: Vector2 = pos + (Vector2.LEFT + Vector2.DOWN) * (i - 1)
							if new_pos.x >= 0 && new_pos.y < Global.current_project.size.y:
								var new_pixel = image.get_pixelv(new_pos)
								if new_pixel.a > 0:
									new_image.set_pixelv(new_pos, outline_color)

						outline_pos = pos + (Vector2.RIGHT + Vector2.DOWN)  # Bottom right
						if (
							(
								outline_pos.x >= Global.current_project.size.x
								&& outline_pos.y >= Global.current_project.size.y
							)
							|| image.get_pixelv(outline_pos).a == 0
						):
							var new_pos: Vector2 = pos + (Vector2.LEFT + Vector2.UP) * (i - 1)
							if new_pos.x >= 0 && new_pos.y >= 0:
								var new_pixel = image.get_pixelv(new_pos)
								if new_pixel.a > 0:
									new_image.set_pixelv(new_pos, outline_color)

				else:
					var new_pos: Vector2 = pos + Vector2.LEFT * i  # Left
					if new_pos.x >= 0:
						var new_pixel = image.get_pixelv(new_pos)
						if new_pixel.a == 0:
							new_image.set_pixelv(new_pos, outline_color)

					new_pos = pos + Vector2.RIGHT * i  # Right
					if new_pos.x < Global.current_project.size.x:
						var new_pixel = image.get_pixelv(new_pos)
						if new_pixel.a == 0:
							new_image.set_pixelv(new_pos, outline_color)

					new_pos = pos + Vector2.UP * i  # Up
					if new_pos.y >= 0:
						var new_pixel = image.get_pixelv(new_pos)
						if new_pixel.a == 0:
							new_image.set_pixelv(new_pos, outline_color)

					new_pos = pos + Vector2.DOWN * i  # Down
					if new_pos.y < Global.current_project.size.y:
						var new_pixel = image.get_pixelv(new_pos)
						if new_pixel.a == 0:
							new_image.set_pixelv(new_pos, outline_color)

					if diagonal:
						new_pos = pos + (Vector2.LEFT + Vector2.UP) * i  # Top left
						if new_pos.x >= 0 && new_pos.y >= 0:
							var new_pixel = image.get_pixelv(new_pos)
							if new_pixel.a == 0:
								new_image.set_pixelv(new_pos, outline_color)

						new_pos = pos + (Vector2.LEFT + Vector2.DOWN) * i  # Bottom left
						if new_pos.x >= 0 && new_pos.y < Global.current_project.size.y:
							var new_pixel = image.get_pixelv(new_pos)
							if new_pixel.a == 0:
								new_image.set_pixelv(new_pos, outline_color)

						new_pos = pos + (Vector2.RIGHT + Vector2.UP) * i  # Top right
						if new_pos.x < Global.current_project.size.x && new_pos.y >= 0:
							var new_pixel = image.get_pixelv(new_pos)
							if new_pixel.a == 0:
								new_image.set_pixelv(new_pos, outline_color)

						new_pos = pos + (Vector2.RIGHT + Vector2.DOWN) * i  # Bottom right
						if (
							new_pos.x < Global.current_project.size.x
							&& new_pos.y < Global.current_project.size.y
						):
							var new_pixel = image.get_pixelv(new_pos)
							if new_pixel.a == 0:
								new_image.set_pixelv(new_pos, outline_color)

	image.unlock()
	new_image.unlock()
	image.copy_from(new_image)
