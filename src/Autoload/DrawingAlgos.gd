extends Node


enum GradientDirection {TOP, BOTTOM, LEFT, RIGHT}


func scale3X(sprite : Image, tol : float = 50) -> Image:
	var scaled = Image.new()
	scaled.create(sprite.get_width()*3, sprite.get_height()*3, false, Image.FORMAT_RGBA8)
	scaled.lock()
	sprite.lock()
	var a : Color
	var b : Color
	var c : Color
	var d : Color
	var e : Color
	var f : Color
	var g : Color
	var h : Color
	var i : Color

	for x in range(1,sprite.get_width()-1):
		for y in range(1,sprite.get_height()-1):
			var xs : float = 3*x
			var ys : float = 3*y

			a = sprite.get_pixel(x-1,y-1)
			b = sprite.get_pixel(x,y-1)
			c = sprite.get_pixel(x+1,y-1)
			d = sprite.get_pixel(x-1,y)
			e = sprite.get_pixel(x,y)
			f = sprite.get_pixel(x+1,y)
			g = sprite.get_pixel(x-1,y+1)
			h = sprite.get_pixel(x,y+1)
			i = sprite.get_pixel(x+1,y+1)

			var db : bool = similarColors(d, b, tol)
			var dh : bool = similarColors(d, h, tol)
			var bf : bool = similarColors(f, b, tol)
			var ec : bool = similarColors(e, c, tol)
			var ea : bool = similarColors(e, a, tol)
			var fh : bool = similarColors(f, h, tol)
			var eg : bool = similarColors(e, g, tol)
			var ei : bool = similarColors(e, i, tol)

			scaled.set_pixel(xs-1, ys-1, d if (db and !dh and !bf) else e )
			scaled.set_pixel(xs, ys-1, b if (db and !dh and !bf and !ec) or
			(bf and !db and !fh and !ea) else e)
			scaled.set_pixel(xs+1, ys-1, f if (bf and !db and !fh) else e)
			scaled.set_pixel(xs-1, ys, d if (dh and !fh and !db and !ea) or
			 (db and !dh and !bf and !eg) else e)
			scaled.set_pixel(xs, ys, e);
			scaled.set_pixel(xs+1, ys, f if (bf and !db and !fh and !ei) or
			(fh and !bf and !dh and !ec) else e)
			scaled.set_pixel(xs-1, ys+1, d if (dh and !fh and !db) else e)
			scaled.set_pixel(xs, ys+1, h if (fh and !bf and !dh and !eg) or
			(dh and !fh and !db and !ei) else e)
			scaled.set_pixel(xs+1, ys+1, f if (fh and !bf and !dh) else e)

	scaled.unlock()
	sprite.unlock()
	return scaled


func rotxel(sprite : Image, angle : float, pixels : Array) -> void:
	# If angle is simple, then nn rotation is the best
	if angle == 0 || angle == PI/2 || angle == PI || angle == 2*PI:
		nn_rotate(sprite, angle, pixels)
		return

	var aux : Image = Image.new()
	aux.copy_from(sprite)
	var selection_rectangle := Rect2(pixels[0].x, pixels[0].y, pixels[-1].x - pixels[0].x + 1, pixels[-1].y - pixels[0].y + 1)
	var center : Vector2 = selection_rectangle.position + ((selection_rectangle.end - selection_rectangle.position) / 2)
	var ox : int
	var oy : int
	var p : Color
	aux.lock()
	sprite.lock()
	for pix in pixels:
		var x = pix.x
		var y = pix.y
		var dx = 3*(x - center.x)
		var dy = 3*(y - center.y)
		var found_pixel : bool = false
		for k in range(9):
			var i = -1 + k % 3
# warning-ignore:integer_division
			var j = -1 + int(k / 3)
			var dir = atan2(dy + j, dx + i)
			var mag = sqrt(pow(dx + i, 2) + pow(dy + j, 2))
			dir -= angle
			ox = round(center.x*3 + 1 + mag*cos(dir))
			oy = round(center.y*3 + 1 + mag*sin(dir))

			if (sprite.get_width() % 2 != 0):
				ox += 1
				oy += 1

			if (ox >= 0 && ox < sprite.get_width()*3
				&& oy >= 0 && oy < sprite.get_height()*3):
					found_pixel = true
					break

		if !found_pixel:
			sprite.set_pixel(x, y, Color(0,0,0,0))
			continue

		var fil : int = oy % 3
		var col : int = ox % 3
		var index : int = col + 3*fil

		ox = round((ox - 1)/3.0);
		oy = round((oy - 1)/3.0);
		var a : Color
		var b : Color
		var c : Color
		var d : Color
		var e : Color
		var f : Color
		var g : Color
		var h : Color
		var i : Color
		if (ox == 0 || ox == sprite.get_width() - 1 ||
			oy == 0 || oy == sprite.get_height() - 1):
				p = aux.get_pixel(ox, oy)
		else:
			a = aux.get_pixel(ox-1,oy-1);
			b = aux.get_pixel(ox,oy-1);
			c = aux.get_pixel(ox+1,oy-1);
			d = aux.get_pixel(ox-1,oy);
			e = aux.get_pixel(ox,oy);
			f = aux.get_pixel(ox+1,oy);
			g = aux.get_pixel(ox-1,oy+1);
			h = aux.get_pixel(ox,oy+1);
			i = aux.get_pixel(ox+1,oy+1);

			match(index):
				0:
					p = d if (similarColors(d,b) && !similarColors(d,h)
					 && !similarColors(b,f)) else e;
				1:
					p = b if ((similarColors(d,b) && !similarColors(d,h) &&
					 !similarColors(b,f) && !similarColors(e,c)) ||
					 (similarColors(b,f) && !similarColors(d,b) &&
					 !similarColors(f,h) && !similarColors(e,a))) else e;
				2:
					p = f if (similarColors(b,f) && !similarColors(d,b) &&
					 !similarColors(f,h)) else e;
				3:
					p = d if ((similarColors(d,h) && !similarColors(f,h) &&
					 !similarColors(d,b) && !similarColors(e,a)) ||
					 (similarColors(d,b) && !similarColors(d,h) &&
					!similarColors(b,f) && !similarColors(e,g))) else e;
				4:
					p = e
				5:
					p =  f if((similarColors(b,f) && !similarColors(d,b) &&
					 !similarColors(f,h) && !similarColors(e,i))
					 || (similarColors(f,h) && !similarColors(b,f) &&
					 !similarColors(d,h) && !similarColors(e,c))) else e;
				6:
					p = d if (similarColors(d,h) && !similarColors(f,h) &&
					 !similarColors(d,b)) else e;
				7:
					p = h if ((similarColors(f,h) && !similarColors(f,b) &&
					 !similarColors(d,h) && !similarColors(e,g))
					 || (similarColors(d,h) && !similarColors(f,h) &&
					 !similarColors(d,b) && !similarColors(e,i))) else e;
				8:
					p = f if (similarColors(f,h) && !similarColors(f,b) &&
					 !similarColors(d,h)) else e;
		sprite.set_pixel(x, y, p)
	sprite.unlock()
	aux.unlock()


func fake_rotsprite(sprite : Image, angle : float, pixels : Array) -> void:
	var selection_rectangle := Rect2(pixels[0].x, pixels[0].y, pixels[-1].x - pixels[0].x + 1, pixels[-1].y - pixels[0].y + 1)
	var selected_sprite := Image.new()
	selected_sprite = sprite.get_rect(selection_rectangle)
	selected_sprite.copy_from(scale3X(selected_sprite))
	nn_rotate(selected_sprite, angle, [])
# warning-ignore:integer_division
# warning-ignore:integer_division
	selected_sprite.resize(selected_sprite.get_width() / 3, selected_sprite.get_height() / 3, 0)
	sprite.blit_rect(selected_sprite, Rect2(Vector2.ZERO, selected_sprite.get_size()), selection_rectangle.position)


func nn_rotate(sprite : Image, angle : float, pixels : Array) -> void:
	var aux : Image = Image.new()
	aux.copy_from(sprite)
	sprite.lock()
	aux.lock()
	var ox: int
	var oy: int
	var center : Vector2
	if pixels:
		var selection_rectangle := Rect2(pixels[0].x, pixels[0].y, pixels[-1].x - pixels[0].x + 1, pixels[-1].y - pixels[0].y + 1)
		center = selection_rectangle.position + ((selection_rectangle.end - selection_rectangle.position) / 2)
		for pix in pixels:
			var x = pix.x
			var y = pix.y
			ox = (x - center.x)*cos(angle) + (y - center.y)*sin(angle) + center.x
			oy = -(x - center.x)*sin(angle) + (y - center.y)*cos(angle) + center.y
			if ox >= 0 && ox < sprite.get_width() && oy >= 0 && oy < sprite.get_height():
				sprite.set_pixel(x, y, aux.get_pixel(ox, oy))
			else:
				sprite.set_pixel(x, y, Color(0,0,0,0))
	else:
# warning-ignore:integer_division
# warning-ignore:integer_division
		center = Vector2(sprite.get_width() / 2, sprite.get_height() / 2)
		for x in range(sprite.get_width()):
			for y in range(sprite.get_height()):
				ox = (x - center.x)*cos(angle) + (y - center.y)*sin(angle) + center.x
				oy = -(x - center.x)*sin(angle) + (y - center.y)*cos(angle) + center.y
				if ox >= 0 && ox < sprite.get_width() && oy >= 0 && oy < sprite.get_height():
					sprite.set_pixel(x, y, aux.get_pixel(ox, oy))
				else:
					sprite.set_pixel(x, y, Color(0,0,0,0))
	sprite.unlock()
	aux.unlock()


func similarColors(c1 : Color, c2 : Color, tol : float = 100) -> bool:
	var dist = colorDistance(c1, c2)
	return dist <= tol


func colorDistance(c1 : Color, c2 : Color) -> float:
		return sqrt(pow((c1.r - c2.r)*255, 2) + pow((c1.g - c2.g)*255, 2)
		+ pow((c1.b - c2.b)*255, 2) + pow((c1.a - c2.a)*255, 2))

# Image effects

func scale_image(width : int, height : int, interpolation : int) -> void:
	general_do_scale(width, height)

	for f in Global.current_project.frames:
		for i in range(f.cels.size() - 1, -1, -1):
			var sprite := Image.new()
			sprite.copy_from(f.cels[i].image)
			# Different method for scale3x
			if interpolation == 5:
				var times : Vector2 = Vector2(ceil(width/(3.0*sprite.get_width())),ceil(height/(3.0*sprite.get_height())))
				for _j in range(max(times.x,times.y)):
					sprite.copy_from(scale3X(sprite))
				sprite.resize(width, height, 0)
			else:
				sprite.resize(width, height, interpolation)
			Global.current_project.undo_redo.add_do_property(f.cels[i].image, "data", sprite.data)
			Global.current_project.undo_redo.add_undo_property(f.cels[i].image, "data", f.cels[i].image.data)

	general_undo_scale()


func crop_image(image : Image) -> void:
	# Use first cel as a starting rectangle
	var used_rect : Rect2 = image.get_used_rect()

	for f in Global.current_project.frames:
		# However, if first cel is empty, loop through all cels until we find one that isn't
		for cel in f.cels:
			if used_rect != Rect2(0, 0, 0, 0):
				break
			else:
				if cel.image.get_used_rect() != Rect2(0, 0, 0, 0):
					used_rect = cel.image.get_used_rect()

		# Merge all layers with content
		for cel in f.cels:
				if cel.image.get_used_rect() != Rect2(0, 0, 0, 0):
					used_rect = used_rect.merge(cel.image.get_used_rect())

	# If no layer has any content, just return
	if used_rect == Rect2(0, 0, 0, 0):
		return

	var width := used_rect.size.x
	var height := used_rect.size.y
	general_do_scale(width, height)
	for f in Global.current_project.frames:
		# Loop through all the layers to crop them
		for j in range(Global.current_project.layers.size() - 1, -1, -1):
			var sprite : Image = f.cels[j].image.get_rect(used_rect)
			Global.current_project.undo_redo.add_do_property(f.cels[j].image, "data", sprite.data)
			Global.current_project.undo_redo.add_undo_property(f.cels[j].image, "data", f.cels[j].image.data)

	general_undo_scale()


func resize_canvas(width : int, height : int, offset_x : int, offset_y : int) -> void:
	general_do_scale(width, height)
	for f in Global.current_project.frames:
		for c in f.cels:
			var sprite := Image.new()
			sprite.create(width, height, false, Image.FORMAT_RGBA8)
			sprite.blend_rect(c.image, Rect2(Vector2.ZERO, Global.current_project.size), Vector2(offset_x, offset_y))
			Global.current_project.undo_redo.add_do_property(c.image, "data", sprite.data)
			Global.current_project.undo_redo.add_undo_property(c.image, "data", c.image.data)

	general_undo_scale()


func general_do_scale(width : int, height : int) -> void:
	var x_ratio = Global.current_project.size.x / width
	var y_ratio = Global.current_project.size.y / height
	var new_x_symmetry_point = Global.current_project.x_symmetry_point / x_ratio
	var new_y_symmetry_point = Global.current_project.y_symmetry_point / y_ratio
	var new_x_symmetry_axis_points = Global.current_project.x_symmetry_axis.points
	var new_y_symmetry_axis_points = Global.current_project.y_symmetry_axis.points
	new_x_symmetry_axis_points[0].y /= y_ratio
	new_x_symmetry_axis_points[1].y /= y_ratio
	new_y_symmetry_axis_points[0].x /= x_ratio
	new_y_symmetry_axis_points[1].x /= x_ratio

	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Scale")
	Global.current_project.undo_redo.add_do_property(Global.current_project, "size", Vector2(width, height).floor())
	Global.current_project.undo_redo.add_do_property(Global.current_project, "x_symmetry_point", new_x_symmetry_point)
	Global.current_project.undo_redo.add_do_property(Global.current_project, "y_symmetry_point", new_y_symmetry_point)
	Global.current_project.undo_redo.add_do_property(Global.current_project.x_symmetry_axis, "points", new_x_symmetry_axis_points)
	Global.current_project.undo_redo.add_do_property(Global.current_project.y_symmetry_axis, "points", new_y_symmetry_axis_points)


func general_undo_scale() -> void:
	Global.current_project.undo_redo.add_undo_property(Global.current_project, "size", Global.current_project.size)
	Global.current_project.undo_redo.add_undo_property(Global.current_project, "x_symmetry_point", Global.current_project.x_symmetry_point)
	Global.current_project.undo_redo.add_undo_property(Global.current_project, "y_symmetry_point", Global.current_project.y_symmetry_point)
	Global.current_project.undo_redo.add_undo_property(Global.current_project.x_symmetry_axis, "points", Global.current_project.x_symmetry_axis.points)
	Global.current_project.undo_redo.add_undo_property(Global.current_project.y_symmetry_axis, "points", Global.current_project.y_symmetry_axis.points)
	Global.current_project.undo_redo.add_undo_method(Global, "undo")
	Global.current_project.undo_redo.add_do_method(Global, "redo")
	Global.current_project.undo_redo.commit_action()


func invert_image_colors(image : Image, pixels : Array, red := true, green := true, blue := true, alpha := false) -> void:
	image.lock()
	for i in pixels:
		var px_color := image.get_pixelv(i)
		# Manually invert each color channel
		if red:
			px_color.r = 1.0 - px_color.r
		if green:
			px_color.g = 1.0 - px_color.g
		if blue:
			px_color.b = 1.0 - px_color.b
		if alpha:
			px_color.a = 1.0 - px_color.a
		image.set_pixelv(i, px_color)


func desaturate_image(image : Image, pixels : Array, red := true, green := true, blue := true, alpha := false) -> void:
	image.lock()
	for i in pixels:
		var px_color := image.get_pixelv(i)
		var gray = px_color.v
		if red:
			px_color.r = gray
		if green:
			px_color.g = gray
		if blue:
			px_color.b = gray
		if alpha:
			px_color.a = gray

		image.set_pixelv(i, px_color)


func generate_outline(image : Image, pixels : Array, outline_color : Color, thickness : int, diagonal : bool, inside_image : bool) -> void:
	if image.is_invisible():
		return
	var new_image := Image.new()
	new_image.copy_from(image)
	new_image.lock()
	image.lock()

	for pos in pixels:
		var current_pixel := image.get_pixelv(pos)
		if current_pixel.a == 0:
			continue

		for i in range(1, thickness + 1):
			if inside_image:
				var outline_pos : Vector2 = pos + Vector2.LEFT # Left
				if outline_pos.x < 0 || image.get_pixelv(outline_pos).a == 0:
					var new_pos : Vector2 = pos + Vector2.RIGHT * (i - 1)
					if new_pos.x < Global.current_project.size.x:
						var new_pixel = image.get_pixelv(new_pos)
						if new_pixel.a > 0:
							new_image.set_pixelv(new_pos, outline_color)

				outline_pos = pos + Vector2.RIGHT # Right
				if outline_pos.x >= Global.current_project.size.x || image.get_pixelv(outline_pos).a == 0:
					var new_pos : Vector2 = pos + Vector2.LEFT * (i - 1)
					if new_pos.x >= 0:
						var new_pixel = image.get_pixelv(new_pos)
						if new_pixel.a > 0:
							new_image.set_pixelv(new_pos, outline_color)

				outline_pos = pos + Vector2.UP # Up
				if outline_pos.y < 0 || image.get_pixelv(outline_pos).a == 0:
					var new_pos : Vector2 = pos + Vector2.DOWN * (i - 1)
					if new_pos.y < Global.current_project.size.y:
						var new_pixel = image.get_pixelv(new_pos)
						if new_pixel.a > 0:
							new_image.set_pixelv(new_pos, outline_color)

				outline_pos = pos + Vector2.DOWN # Down
				if outline_pos.y >= Global.current_project.size.y || image.get_pixelv(outline_pos).a == 0:
					var new_pos : Vector2 = pos + Vector2.UP * (i - 1)
					if new_pos.y >= 0:
						var new_pixel = image.get_pixelv(new_pos)
						if new_pixel.a > 0:
							new_image.set_pixelv(new_pos, outline_color)

				if diagonal:
					outline_pos = pos + (Vector2.LEFT + Vector2.UP) # Top left
					if (outline_pos.x < 0 && outline_pos.y < 0) || image.get_pixelv(outline_pos).a == 0:
						var new_pos : Vector2 = pos + (Vector2.RIGHT + Vector2.DOWN) * (i - 1)
						if new_pos.x < Global.current_project.size.x && new_pos.y < Global.current_project.size.y:
							var new_pixel = image.get_pixelv(new_pos)
							if new_pixel.a > 0:
								new_image.set_pixelv(new_pos, outline_color)

					outline_pos = pos + (Vector2.LEFT + Vector2.DOWN) # Bottom left
					if (outline_pos.x < 0 && outline_pos.y >= Global.current_project.size.y) || image.get_pixelv(outline_pos).a == 0:
						var new_pos : Vector2 = pos + (Vector2.RIGHT + Vector2.UP) * (i - 1)
						if new_pos.x < Global.current_project.size.x && new_pos.y >= 0:
							var new_pixel = image.get_pixelv(new_pos)
							if new_pixel.a > 0:
								new_image.set_pixelv(new_pos, outline_color)

					outline_pos = pos + (Vector2.RIGHT + Vector2.UP) # Top right
					if (outline_pos.x >= Global.current_project.size.x && outline_pos.y < 0) || image.get_pixelv(outline_pos).a == 0:
						var new_pos : Vector2 = pos + (Vector2.LEFT + Vector2.DOWN) * (i - 1)
						if new_pos.x >= 0 && new_pos.y < Global.current_project.size.y:
							var new_pixel = image.get_pixelv(new_pos)
							if new_pixel.a > 0:
								new_image.set_pixelv(new_pos, outline_color)

					outline_pos = pos + (Vector2.RIGHT + Vector2.DOWN) # Bottom right
					if (outline_pos.x >= Global.current_project.size.x && outline_pos.y >= Global.current_project.size.y) || image.get_pixelv(outline_pos).a == 0:
						var new_pos : Vector2 = pos + (Vector2.LEFT + Vector2.UP) * (i - 1)
						if new_pos.x >= 0 && new_pos.y >= 0:
							var new_pixel = image.get_pixelv(new_pos)
							if new_pixel.a > 0:
								new_image.set_pixelv(new_pos, outline_color)

			else:
				var new_pos : Vector2 = pos + Vector2.LEFT * i # Left
				if new_pos.x >= 0:
					var new_pixel = image.get_pixelv(new_pos)
					if new_pixel.a == 0:
						new_image.set_pixelv(new_pos, outline_color)

				new_pos = pos + Vector2.RIGHT * i # Right
				if new_pos.x < Global.current_project.size.x:
					var new_pixel = image.get_pixelv(new_pos)
					if new_pixel.a == 0:
						new_image.set_pixelv(new_pos, outline_color)

				new_pos = pos + Vector2.UP * i # Up
				if new_pos.y >= 0:
					var new_pixel = image.get_pixelv(new_pos)
					if new_pixel.a == 0:
						new_image.set_pixelv(new_pos, outline_color)

				new_pos = pos + Vector2.DOWN * i # Down
				if new_pos.y < Global.current_project.size.y:
					var new_pixel = image.get_pixelv(new_pos)
					if new_pixel.a == 0:
						new_image.set_pixelv(new_pos, outline_color)

				if diagonal:
					new_pos = pos + (Vector2.LEFT + Vector2.UP) * i # Top left
					if new_pos.x >= 0 && new_pos.y >= 0:
						var new_pixel = image.get_pixelv(new_pos)
						if new_pixel.a == 0:
							new_image.set_pixelv(new_pos, outline_color)

					new_pos = pos + (Vector2.LEFT + Vector2.DOWN) * i # Bottom left
					if new_pos.x >= 0 && new_pos.y < Global.current_project.size.y:
						var new_pixel = image.get_pixelv(new_pos)
						if new_pixel.a == 0:
							new_image.set_pixelv(new_pos, outline_color)

					new_pos = pos + (Vector2.RIGHT + Vector2.UP) * i # Top right
					if new_pos.x < Global.current_project.size.x && new_pos.y >= 0:
						var new_pixel = image.get_pixelv(new_pos)
						if new_pixel.a == 0:
							new_image.set_pixelv(new_pos, outline_color)

					new_pos = pos + (Vector2.RIGHT + Vector2.DOWN) * i # Bottom right
					if new_pos.x < Global.current_project.size.x && new_pos.y < Global.current_project.size.y:
						var new_pixel = image.get_pixelv(new_pos)
						if new_pixel.a == 0:
							new_image.set_pixelv(new_pos, outline_color)

	image.unlock()
	new_image.unlock()
	image.copy_from(new_image)


func adjust_hsv(img: Image, delta_h : float, delta_s : float, delta_v : float, pixels : Array) -> void:
	img.lock()
	for i in pixels:
		var c : Color = img.get_pixelv(i)
		# Hue
		var hue = range_lerp(c.h,0,1,-180,180)
		hue = hue + delta_h

		while(hue >= 180):
			hue -= 360
		while(hue < -180):
			hue += 360

		# Saturation
		var sat = c.s
		if delta_s > 0:
			sat = range_lerp(delta_s,0,100,c.s,1)
		elif delta_s < 0:
			sat = range_lerp(delta_s,-100,0,0,c.s)

		# Value
		var val = c.v
		if delta_v > 0:
			val = range_lerp(delta_v,0,100,c.v,1)
		elif delta_v < 0:
			val = range_lerp(delta_v,-100,0,0,c.v)

		c.h = range_lerp(hue,-180,180,0,1)
		c.s = sat
		c.v = val
		img.set_pixelv(i,c)

	img.unlock()


func generate_gradient(image : Image, colors : Array, steps := 2, direction : int = GradientDirection.TOP, pixels = Global.current_project.selected_pixels) -> void:
	if colors.size() < 2:
		return

	var t = 1.0 / (steps - 1)
	for i in range(1, steps - 1):
		var color : Color
		color = colors[-1].linear_interpolate(colors[0], t * i)
		colors.insert(1, color)

	image.unlock()
	if direction == GradientDirection.BOTTOM or direction == GradientDirection.RIGHT:
		colors.invert()

	var selection_rectangle := Rect2(pixels[0].x, pixels[0].y, pixels[-1].x - pixels[0].x + 1, pixels[-1].y - pixels[0].y + 1)
	var size := selection_rectangle.size
	image.lock()
	var gradient_size

	if direction == GradientDirection.TOP or direction == GradientDirection.BOTTOM:
		gradient_size = size.y / steps
		for i in steps:
			for xx in size.x:
				var start = i * gradient_size
				var end = (i + 1) * gradient_size
				for yy in range(start, end):
					var pos : Vector2 = Vector2(xx, yy) + pixels[0]
					image.set_pixelv(pos, colors[i])

	else:
		gradient_size = size.x / steps
		for i in steps:
			for yy in size.y:
				var start = i * gradient_size
				var end = (i + 1) * gradient_size
				for xx in range(start, end):
					var pos : Vector2 = Vector2(xx, yy) + pixels[0]
					image.set_pixelv(pos, colors[i])
