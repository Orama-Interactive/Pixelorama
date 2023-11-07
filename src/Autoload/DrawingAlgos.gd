extends Node

enum GradientDirection { TOP, BOTTOM, LEFT, RIGHT }
## Continuation from Image.Interpolation
enum Interpolation { SCALE3X = 5, CLEANEDGE = 6, OMNISCALE = 7 }
var blend_layers_shader := preload("res://src/Shaders/BlendLayers.gdshader")
var clean_edge_shader: Shader
var omniscale_shader := preload("res://src/Shaders/Effects/Rotation/OmniScale.gdshader")


## Blends canvas layers into passed image starting from the origin position
func blend_all_layers(
	image: Image, frame: Frame, origin := Vector2i.ZERO, project := Global.current_project
) -> void:
	var current_cels := frame.cels
	var textures: Array[Image] = []
	var opacities := PackedFloat32Array()
	var blend_modes := PackedInt32Array()

	for i in Global.current_project.layers.size():
		if current_cels[i] is GroupCel:
			continue
		if not Global.current_project.layers[i].is_visible_in_hierarchy():
			continue
		textures.append(current_cels[i].get_image())
		opacities.append(current_cels[i].opacity)
		blend_modes.append(Global.current_project.layers[i].blend_mode)
	var texture_array := Texture2DArray.new()
	texture_array.create_from_images(textures)
	var params := {
		"layers": texture_array,
		"opacities": opacities,
		"blend_modes": blend_modes,
	}
	var blended := Image.create(project.size.x, project.size.y, false, image.get_format())
	var gen := ShaderImageEffect.new()
	gen.generate_image(blended, blend_layers_shader, params, project.size)
	image.blend_rect(blended, Rect2i(Vector2i.ZERO, project.size), origin)


## Blends selected cels of the given frame into passed image starting from the origin position
func blend_selected_cels(
	image: Image, frame: Frame, origin := Vector2i.ZERO, project := Global.current_project
) -> void:
	var textures: Array[Image] = []
	var opacities := PackedFloat32Array()
	var blend_modes := PackedInt32Array()
	for cel_ind in frame.cels.size():
		var test_array := [project.current_frame, cel_ind]
		if not test_array in project.selected_cels:
			continue
		if frame.cels[cel_ind] is GroupCel:
			continue
		if not project.layers[cel_ind].is_visible_in_hierarchy():
			continue
		var cel := frame.cels[cel_ind]
		textures.append(cel.get_image())
		opacities.append(cel.opacity)
		blend_modes.append(Global.current_project.layers[cel_ind].blend_mode)
	var texture_array := Texture2DArray.new()
	texture_array.create_from_images(textures)
	var params := {
		"layers": texture_array,
		"opacities": opacities,
		"blend_modes": blend_modes,
	}
	var blended := Image.create(project.size.x, project.size.y, false, image.get_format())
	var gen := ShaderImageEffect.new()
	gen.generate_image(blended, blend_layers_shader, params, project.size)
	image.blend_rect(blended, Rect2i(Vector2i.ZERO, project.size), origin)


## Algorithm based on http://members.chello.at/easyfilter/bresenham.html
func get_ellipse_points(pos: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var array: Array[Vector2i] = []
	var x0 := pos.x
	var x1 := pos.x + (size.x - 1)
	var y0 := pos.y
	var y1 := pos.y + (size.y - 1)
	var a := absi(x1 - x0)
	var b := absi(y1 - x0)
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

	y0 += (b + 1) / 2
	y1 = y0 - b1
	a *= 8 * a
	b1 = 8 * b * b

	while x0 <= x1:
		var v1 := Vector2i(x1, y0)
		var v2 := Vector2i(x0, y0)
		var v3 := Vector2i(x0, y1)
		var v4 := Vector2i(x1, y1)
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
		var v1 := Vector2i(x0 - 1, y0)
		var v2 := Vector2i(x1 + 1, y0)
		var v3 := Vector2i(x0 - 1, y1)
		var v4 := Vector2i(x1 + 1, y1)
		array.append(v1)
		array.append(v2)
		array.append(v3)
		array.append(v4)
		y0 += 1
		y1 -= 1

	return array


func get_ellipse_points_filled(pos: Vector2i, size: Vector2i, thickness := 1) -> Array[Vector2i]:
	var offsetted_size := size + Vector2i.ONE * (thickness - 1)
	var border := get_ellipse_points(pos, offsetted_size)
	var filling: Array[Vector2i] = []

	for x in range(1, ceili(offsetted_size.x / 2.0)):
		var fill := false
		var prev_is_true := false
		for y in range(0, ceili(offsetted_size.y / 2.0)):
			var top_l_p := Vector2i(x, y)
			var bit := border.has(pos + top_l_p)

			if bit and not fill:
				prev_is_true = true
				continue

			if not bit and (fill or prev_is_true):
				filling.append(pos + top_l_p)
				filling.append(pos + Vector2i(x, offsetted_size.y - y - 1))
				filling.append(pos + Vector2i(offsetted_size.x - x - 1, y))
				filling.append(pos + Vector2i(offsetted_size.x - x - 1, offsetted_size.y - y - 1))

				if prev_is_true:
					fill = true
					prev_is_true = false
			elif bit and fill:
				break

	return border + filling


func scale_3x(sprite: Image, tol := 50.0) -> Image:
	var scaled := Image.create(
		sprite.get_width() * 3, sprite.get_height() * 3, false, Image.FORMAT_RGBA8
	)
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
			var xs := 3 * x
			var ys := 3 * y

			a = sprite.get_pixel(maxi(x - 1, 0), maxi(y - 1, 0))
			b = sprite.get_pixel(mini(x, sprite.get_width() - 1), maxi(y - 1, 0))
			c = sprite.get_pixel(mini(x + 1, sprite.get_width() - 1), maxi(y - 1, 0))
			d = sprite.get_pixel(maxi(x - 1, 0), mini(y, sprite.get_height() - 1))
			e = sprite.get_pixel(mini(x, sprite.get_width() - 1), mini(y, sprite.get_height() - 1))
			f = sprite.get_pixel(
				mini(x + 1, sprite.get_width() - 1), mini(y, sprite.get_height() - 1)
			)
			g = sprite.get_pixel(maxi(x - 1, 0), mini(y + 1, sprite.get_height() - 1))
			h = sprite.get_pixel(
				mini(x, sprite.get_width() - 1), mini(y + 1, sprite.get_height() - 1)
			)
			i = sprite.get_pixel(
				mini(x + 1, sprite.get_width() - 1), mini(y + 1, sprite.get_height() - 1)
			)

			var db: bool = similar_colors(d, b, tol)
			var dh: bool = similar_colors(d, h, tol)
			var bf: bool = similar_colors(f, b, tol)
			var ec: bool = similar_colors(e, c, tol)
			var ea: bool = similar_colors(e, a, tol)
			var fh: bool = similar_colors(f, h, tol)
			var eg: bool = similar_colors(e, g, tol)
			var ei: bool = similar_colors(e, i, tol)

			scaled.set_pixel(maxi(xs - 1, 0), maxi(ys - 1, 0), d if (db and !dh and !bf) else e)
			scaled.set_pixel(
				xs,
				maxi(ys - 1, 0),
				b if (db and !dh and !bf and !ec) or (bf and !db and !fh and !ea) else e
			)
			scaled.set_pixel(xs + 1, maxi(ys - 1, 0), f if (bf and !db and !fh) else e)
			scaled.set_pixel(
				maxi(xs - 1, 0),
				ys,
				d if (dh and !fh and !db and !ea) or (db and !dh and !bf and !eg) else e
			)
			scaled.set_pixel(xs, ys, e)
			scaled.set_pixel(
				xs + 1, ys, f if (bf and !db and !fh and !ei) or (fh and !bf and !dh and !ec) else e
			)
			scaled.set_pixel(maxi(xs - 1, 0), ys + 1, d if (dh and !fh and !db) else e)
			scaled.set_pixel(
				xs, ys + 1, h if (fh and !bf and !dh and !eg) or (dh and !fh and !db and !ei) else e
			)
			scaled.set_pixel(xs + 1, ys + 1, f if (fh and !bf and !dh) else e)

	return scaled


func rotxel(sprite: Image, angle: float, pivot: Vector2) -> void:
	# If angle is simple, then nn rotation is the best
	if angle == 0 || angle == PI / 2 || angle == PI || angle == 2 * PI:
		nn_rotate(sprite, angle, pivot)
		return

	var aux := Image.new()
	aux.copy_from(sprite)
	var ox: int
	var oy: int
	var p: Color
	for x in sprite.get_size().x:
		for y in sprite.get_size().y:
			var dx := 3 * (x - pivot.x)
			var dy := 3 * (y - pivot.y)
			var found_pixel := false
			for k in range(9):
				var modk := -1 + k % 3
				var divk := -1 + int(k / 3)
				var dir := atan2(dy + divk, dx + modk)
				var mag := sqrt(pow(dx + modk, 2) + pow(dy + divk, 2))
				dir -= angle
				ox = roundi(pivot.x * 3 + 1 + mag * cos(dir))
				oy = roundi(pivot.y * 3 + 1 + mag * sin(dir))

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

			ox = roundi((ox - 1) / 3.0)
			oy = roundi((oy - 1) / 3.0)
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


func fake_rotsprite(sprite: Image, angle: float, pivot: Vector2) -> void:
	var selected_sprite := Image.new()
	selected_sprite.copy_from(sprite)
	selected_sprite.copy_from(scale_3x(selected_sprite))
	nn_rotate(selected_sprite, angle, pivot * 3)
	selected_sprite.resize(
		selected_sprite.get_width() / 3, selected_sprite.get_height() / 3, Image.INTERPOLATE_NEAREST
	)
	sprite.blit_rect(selected_sprite, Rect2(Vector2.ZERO, selected_sprite.get_size()), Vector2.ZERO)


func nn_rotate(sprite: Image, angle: float, pivot: Vector2) -> void:
	var aux := Image.new()
	aux.copy_from(sprite)
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


func similar_colors(c1: Color, c2: Color, tol := 100.0) -> bool:
	var dist := color_distance(c1, c2)
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
			if not f.cels[i] is PixelCel:
				continue
			var sprite := Image.new()
			sprite.copy_from(f.cels[i].get_image())
			if interpolation == Interpolation.SCALE3X:
				var times := Vector2i(
					ceili(width / (3.0 * sprite.get_width())),
					ceili(height / (3.0 * sprite.get_height()))
				)
				for _j in range(maxi(times.x, times.y)):
					sprite.copy_from(scale_3x(sprite))
				sprite.resize(width, height, Image.INTERPOLATE_NEAREST)
			elif interpolation == Interpolation.CLEANEDGE:
				var gen := ShaderImageEffect.new()
				gen.generate_image(sprite, clean_edge_shader, {}, Vector2i(width, height))
			elif interpolation == Interpolation.OMNISCALE and omniscale_shader:
				var gen := ShaderImageEffect.new()
				gen.generate_image(sprite, omniscale_shader, {}, Vector2i(width, height))
			else:
				sprite.resize(width, height, interpolation)
			Global.current_project.undo_redo.add_do_property(f.cels[i].image, "data", sprite.data)
			Global.current_project.undo_redo.add_undo_property(
				f.cels[i].image, "data", f.cels[i].image.data
			)

	general_undo_scale()


func center(indices: Array) -> void:
	var project := Global.current_project
	Global.canvas.selection.transform_content_confirm()
	project.undos += 1
	project.undo_redo.create_action("Center Frames")
	for frame in indices:
		# Find used rect of the current frame (across all of the layers)
		var used_rect := Rect2i()
		for cel in project.frames[frame].cels:
			if not cel is PixelCel:
				continue
			var cel_rect := cel.get_image().get_used_rect()
			if cel_rect.has_area():
				used_rect = used_rect.merge(cel_rect) if used_rect.has_area() else cel_rect
		if not used_rect.has_area():
			continue

		# Now apply centering
		var offset: Vector2i = (0.5 * (project.size - used_rect.size)).floor()
		for cel in project.frames[frame].cels:
			if not cel is PixelCel:
				continue
			var sprite := Image.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
			sprite.blend_rect(cel.image, used_rect, offset)
			project.undo_redo.add_do_property(cel.image, "data", sprite.data)
			project.undo_redo.add_undo_property(cel.image, "data", cel.image.data)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.commit_action()


func crop_image() -> void:
	Global.canvas.selection.transform_content_confirm()
	var used_rect := Rect2i()
	for f in Global.current_project.frames:
		for cel in f.cels:
			if not cel is PixelCel:
				continue
			var cel_used_rect := cel.get_image().get_used_rect()
			if cel_used_rect == Rect2i(0, 0, 0, 0):  # If the cel has no content
				continue

			if used_rect == Rect2i(0, 0, 0, 0):  # If we still haven't found the first cel with content
				used_rect = cel_used_rect
			else:
				used_rect = used_rect.merge(cel_used_rect)

	# If no layer has any content, just return
	if used_rect == Rect2i(0, 0, 0, 0):
		return

	var width := used_rect.size.x
	var height := used_rect.size.y
	general_do_scale(width, height)
	# Loop through all the cels to crop them
	for f in Global.current_project.frames:
		for cel in f.cels:
			if not cel is PixelCel:
				continue
			var sprite := cel.get_image().get_region(used_rect)
			Global.current_project.undo_redo.add_do_property(cel.image, "data", sprite.data)
			Global.current_project.undo_redo.add_undo_property(cel.image, "data", cel.image.data)

	general_undo_scale()


func resize_canvas(width: int, height: int, offset_x: int, offset_y: int) -> void:
	general_do_scale(width, height)
	for f in Global.current_project.frames:
		for c in f.cels:
			if not c is PixelCel:
				continue
			var sprite := Image.create(width, height, false, Image.FORMAT_RGBA8)
			sprite.blend_rect(
				c.get_image(),
				Rect2i(Vector2i.ZERO, Global.current_project.size),
				Vector2i(offset_x, offset_y)
			)
			Global.current_project.undo_redo.add_do_property(c.image, "data", sprite.data)
			Global.current_project.undo_redo.add_undo_property(c.image, "data", c.image.data)

	general_undo_scale()


func general_do_scale(width: int, height: int) -> void:
	var project := Global.current_project
	var size := Vector2i(width, height)
	var x_ratio := float(project.size.x) / width
	var y_ratio := float(project.size.y) / height

	var selection_map_copy := SelectionMap.new()
	selection_map_copy.copy_from(project.selection_map)
	selection_map_copy.crop(size.x, size.y)

	var new_x_symmetry_point := project.x_symmetry_point / x_ratio
	var new_y_symmetry_point := project.y_symmetry_point / y_ratio
	var new_x_symmetry_axis_points := project.x_symmetry_axis.points
	var new_y_symmetry_axis_points := project.y_symmetry_axis.points
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
	var project := Global.current_project
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
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.commit_action()
