extends Node


var mouse_press_pixels := [] # Cleared after mouse release
var mouse_press_pressure_values := [] # Cleared after mouse release


# Algorithm based on http://members.chello.at/easyfilter/bresenham.html
func plot_circle(sprite : Image, xm : int, ym : int, r : int, color : Color, fill := false) -> void:
	var radius := r # Used later for filling
	var x := -r
	var y := 0
	var err := 2 - r * 2 # II. Quadrant
	while x < 0:
		var quadrant_1 := Vector2(xm - x, ym + y)
		var quadrant_2 := Vector2(xm - y, ym - x)
		var quadrant_3 := Vector2(xm + x, ym - y)
		var quadrant_4 := Vector2(xm + y, ym + x)
		draw_pixel_blended(sprite, quadrant_1, color)
		draw_pixel_blended(sprite, quadrant_2, color)
		draw_pixel_blended(sprite, quadrant_3, color)
		draw_pixel_blended(sprite, quadrant_4, color)

		r = err
		if r <= y:
			y += 1
			err += y * 2 + 1
		if r > x || err > y:
			x += 1
			err += x * 2 + 1

	if fill:
		for j in range (-radius, radius + 1):
			for i in range (-radius, radius + 1):
				if i * i + j * j <= radius * radius:
					var draw_pos := Vector2(i + xm, j + ym)
					draw_pixel_blended(sprite, draw_pos, color)


func draw_pixel_blended(sprite : Image, pos : Vector2, color : Color) -> void:
	var saved_pixel_index := mouse_press_pixels.find(pos)
	var west_limit = Global.canvas.west_limit
	var east_limit = Global.canvas.east_limit
	var north_limit = Global.canvas.north_limit
	var south_limit = Global.canvas.south_limit
	var pen_pressure = Global.canvas.pen_pressure

	if point_in_rectangle(pos, Vector2(west_limit - 1, north_limit - 1), Vector2(east_limit, south_limit)) && (saved_pixel_index == -1 || pen_pressure > mouse_press_pressure_values[saved_pixel_index]):
		if color.a > 0 && color.a < 1:
			color = blend_colors(color, sprite.get_pixelv(pos))

		if saved_pixel_index == -1:
			mouse_press_pixels.append(pos)
			mouse_press_pressure_values.append(pen_pressure)
		else:
			mouse_press_pressure_values[saved_pixel_index] = pen_pressure
		sprite.set_pixelv(pos, color)


# Thanks to https://en.wikipedia.org/wiki/Flood_fill
func flood_fill(sprite : Image, pos : Vector2, target_color : Color, replace_color : Color) -> void:
	var west_limit = Global.canvas.west_limit
	var east_limit = Global.canvas.east_limit
	var north_limit = Global.canvas.north_limit
	var south_limit = Global.canvas.south_limit
	pos = pos.floor()
	var pixel = sprite.get_pixelv(pos)
	if target_color == replace_color:
		return
	elif pixel != target_color:
		return
	else:

		if !point_in_rectangle(pos, Vector2(west_limit - 1, north_limit - 1), Vector2(east_limit, south_limit)):
			return

		var q = [pos]
		for n in q:
			# If the difference in colors is very small, break the loop (thanks @azagaya on GitHub!)
			if target_color == replace_color:
				break
			var west : Vector2 = n
			var east : Vector2 = n
			while west.x >= west_limit && sprite.get_pixelv(west) == target_color:
				west += Vector2.LEFT
			while east.x < east_limit && sprite.get_pixelv(east) == target_color:
				east += Vector2.RIGHT
			for px in range(west.x + 1, east.x):
				var p := Vector2(px, n.y)
				# Draw
				sprite.set_pixelv(p, replace_color)
				replace_color = sprite.get_pixelv(p)
				var north := p + Vector2.UP
				var south := p + Vector2.DOWN
				if north.y >= north_limit && sprite.get_pixelv(north) == target_color:
					q.append(north)
				if south.y < south_limit && sprite.get_pixelv(south) == target_color:
					q.append(south)

		Global.canvas.sprite_changed_this_frame = true


func pattern_fill(sprite : Image, pos : Vector2, pattern : Image, target_color : Color, var offset : Vector2) -> void:
	var west_limit = Global.canvas.west_limit
	var east_limit = Global.canvas.east_limit
	var north_limit = Global.canvas.north_limit
	var south_limit = Global.canvas.south_limit
	pos = pos.floor()
	if !point_in_rectangle(pos, Vector2(west_limit - 1, north_limit - 1), Vector2(east_limit, south_limit)):
		return

	pattern.lock()
	var pattern_size := pattern.get_size()
	var q = [pos]

	for n in q:
		var west : Vector2 = n
		var east : Vector2 = n
		while west.x >= west_limit && sprite.get_pixelv(west) == target_color:
			west += Vector2.LEFT
		while east.x < east_limit && sprite.get_pixelv(east) == target_color:
			east += Vector2.RIGHT

		for px in range(west.x + 1, east.x):
			var p := Vector2(px, n.y)
			var xx : int = int(px + offset.x) % int(pattern_size.x)
			var yy : int = int(n.y + offset.y) % int(pattern_size.y)
			var pattern_color : Color = pattern.get_pixel(xx, yy)
			if pattern_color == target_color:
				continue
			sprite.set_pixelv(p, pattern_color)

			var north := p + Vector2.UP
			var south := p + Vector2.DOWN
			if north.y >= north_limit && sprite.get_pixelv(north) == target_color:
				q.append(north)
			if south.y < south_limit && sprite.get_pixelv(south) == target_color:
				q.append(south)

	pattern.unlock()
	Global.canvas.sprite_changed_this_frame = true


func blend_colors(color_1 : Color, color_2 : Color) -> Color:
	var color := Color()
	color.a = color_1.a + color_2.a * (1 - color_1.a) # Blend alpha
	if color.a != 0:
		# Blend colors
		color.r = (color_1.r * color_1.a + color_2.r * color_2.a * (1-color_1.a)) / color.a
		color.g = (color_1.g * color_1.a + color_2.g * color_2.a * (1-color_1.a)) / color.a
		color.b = (color_1.b * color_1.a + color_2.b * color_2.a * (1-color_1.a)) / color.a
	return color


# Custom blend rect function, needed because Godot's issue #31124
func blend_rect(bg : Image, brush : Image, src_rect : Rect2, dst : Vector2) -> void:
	var brush_size := brush.get_size()
	var clipped_src_rect := Rect2(Vector2.ZERO, brush_size).clip(src_rect)
	if clipped_src_rect.size.x <= 0 || clipped_src_rect.size.y <= 0:
		return
	var src_underscan := Vector2(min(0, src_rect.position.x), min(0, src_rect.position.y))
	var dest_rect := Rect2(0, 0, bg.get_width(), bg.get_height()).clip(Rect2(dst - src_underscan, clipped_src_rect.size))

	for x in range(0, dest_rect.size.x):
		for y in range(0, dest_rect.size.y):
			var src_x := clipped_src_rect.position.x + x;
			var src_y := clipped_src_rect.position.y + y;

			var dst_x := dest_rect.position.x + x;
			var dst_y := dest_rect.position.y + y;

			brush.lock()
			var brush_color := brush.get_pixel(src_x, src_y)
			var bg_color := bg.get_pixel(dst_x, dst_y)
			var out_color := blend_colors(brush_color, bg_color)
			if out_color.a != 0:
				bg.set_pixel(dst_x, dst_y, out_color)
			brush.unlock()


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


func rotxel(sprite : Image, angle : float) -> void:

	# If angle is simple, then nn rotation is the best

	if angle == 0 || angle == PI/2 || angle == PI || angle == 2*PI:
		nn_rotate(sprite, angle)
		return

	var aux : Image = Image.new()
	aux.copy_from(sprite)
	var center : Vector2 = Vector2(sprite.get_width()/2, sprite.get_height()/2)
	var ox : int
	var oy : int
	var p : Color
	aux.lock()
	sprite.lock()
	for x in range(sprite.get_width()):
		for y in range(sprite.get_height()):
			var dx = 3*(x - center.x)
			var dy = 3*(y - center.y)
			var found_pixel : bool = false
			for k in range(9):
				var i = -1 + k % 3
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


func fake_rotsprite(sprite : Image, angle : float) -> void:
	sprite.copy_from(scale3X(sprite))
	nn_rotate(sprite,angle)
	sprite.resize(sprite.get_width()/3,sprite.get_height()/3,0)


func nn_rotate(sprite : Image, angle : float) -> void:
	var aux : Image = Image.new()
	aux.copy_from(sprite)
	sprite.lock()
	aux.lock()
	var ox: int
	var oy: int
	var center : Vector2 = Vector2(sprite.get_width()/2, sprite.get_height()/2)
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


func adjust_hsv(img: Image, id : int, delta : float) -> void:
	var west_limit = Global.canvas.west_limit
	var east_limit = Global.canvas.east_limit
	var north_limit = Global.canvas.north_limit
	var south_limit = Global.canvas.south_limit
	img.lock()

	match id:
		0: # Hue
			for i in range(west_limit, east_limit):
				for j in range(north_limit, south_limit):
					var c : Color = img.get_pixel(i,j)
					var hue = range_lerp(c.h,0,1,-180,180)
					hue = hue + delta

					while(hue >= 180):
						hue -= 360
					while(hue < -180):
						hue += 360
					c.h = range_lerp(hue,-180,180,0,1)
					img.set_pixel(i,j,c)

		1: # Saturation
			for i in range(west_limit, east_limit):
				for j in range(north_limit, south_limit):
					var c : Color = img.get_pixel(i,j)
					var sat = c.s
					if delta > 0:
						sat = range_lerp(delta,0,100,c.s,1)
					elif delta < 0:
						sat = range_lerp(delta,-100,0,0,c.s)
					c.s = sat
					img.set_pixel(i,j,c)

		2: # Value
			for i in range(west_limit, east_limit):
				for j in range(north_limit, south_limit):
					var c : Color = img.get_pixel(i,j)
					var val = c.v
					if delta > 0:
						val = range_lerp(delta,0,100,c.v,1)
					elif delta < 0:
						val = range_lerp(delta,-100,0,0,c.v)

					c.v = val
					img.set_pixel(i,j,c)

	img.unlock()


# Checks if a point is inside a rectangle
func point_in_rectangle(p : Vector2, coord1 : Vector2, coord2 : Vector2) -> bool:
	return p.x > coord1.x && p.y > coord1.y && p.x < coord2.x && p.y < coord2.y
