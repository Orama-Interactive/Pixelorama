extends Node


const Drawer = preload("res://src/Drawers.gd").Drawer
const SimpleDrawer = preload("res://src/Drawers.gd").SimpleDrawer
const PixelPerfectDrawer = preload("res://src/Drawers.gd").PixelPerfectDrawer

var pixel_perfect_drawer := PixelPerfectDrawer.new()
var pixel_perfect_drawer_h_mirror := PixelPerfectDrawer.new()
var pixel_perfect_drawer_v_mirror := PixelPerfectDrawer.new()
var pixel_perfect_drawer_hv_mirror := PixelPerfectDrawer.new()
var simple_drawer := SimpleDrawer.new()

var mouse_press_pixels := [] # Cleared after mouse release
var mouse_press_pressure_values := [] # Cleared after mouse release


func draw_pixel_blended(sprite : Image, pos : Vector2, color : Color, pen_pressure : float, current_mouse_button := -1, current_action := -1, drawer : Drawer = simple_drawer) -> void:
	var west_limit = Global.canvas.west_limit
	var east_limit = Global.canvas.east_limit
	var north_limit = Global.canvas.north_limit
	var south_limit = Global.canvas.south_limit
	if !point_in_rectangle(pos, Vector2(west_limit - 1, north_limit - 1), Vector2(east_limit, south_limit)):
		return

	var pos_floored := pos.floor()
	var current_pixel_color = sprite.get_pixelv(pos)
	var saved_pixel_index := mouse_press_pixels.find(pos_floored)
	if current_action == Global.Tools.PENCIL && color.a < 1:
		color = blend_colors(color, current_pixel_color)

	if current_pixel_color != color && (saved_pixel_index == -1 || pen_pressure > mouse_press_pressure_values[saved_pixel_index]):
		if current_action == Global.Tools.LIGHTENDARKEN:
			var ld : int = Global.ld_modes[current_mouse_button]
			var ld_amount : float = Global.ld_amounts[current_mouse_button]
			if ld == Global.Lighten_Darken_Mode.LIGHTEN:
				color = current_pixel_color.lightened(ld_amount)
			else:
				color = current_pixel_color.darkened(ld_amount)

		if saved_pixel_index == -1:
			mouse_press_pixels.append(pos_floored)
			mouse_press_pressure_values.append(pen_pressure)
		else:
			mouse_press_pressure_values[saved_pixel_index] = pen_pressure
		drawer.set_pixel(sprite, pos, color)


func draw_brush(sprite : Image, pos : Vector2, color : Color, current_mouse_button : int, pen_pressure : float, current_action := -1) -> void:
	if Global.can_draw && Global.has_focus:
		var west_limit = Global.canvas.west_limit
		var east_limit = Global.canvas.east_limit
		var north_limit = Global.canvas.north_limit
		var south_limit = Global.canvas.south_limit

		if Global.pressure_sensitivity_mode == Global.Pressure_Sensitivity.ALPHA:
			if current_action == Global.Tools.PENCIL:
				color.a *= pen_pressure
			elif current_action == Global.Tools.ERASER: # This is not working
				color.a *= (1.0 - pen_pressure)

		var brush_size : int = Global.brush_sizes[current_mouse_button]
		var brush_type : int = Global.current_brush_types[current_mouse_button]

		var horizontal_mirror : bool = Global.horizontal_mirror[current_mouse_button]
		var vertical_mirror : bool = Global.vertical_mirror[current_mouse_button]

		if brush_type == Global.Brush_Types.PIXEL || current_action == Global.Tools.LIGHTENDARKEN:
			var start_pos_x = pos.x - (brush_size >> 1)
			var start_pos_y = pos.y - (brush_size >> 1)
			var end_pos_x = start_pos_x + brush_size
			var end_pos_y = start_pos_y + brush_size

			for cur_pos_x in range(start_pos_x, end_pos_x):
				for cur_pos_y in range(start_pos_y, end_pos_y):
					var pixel_perfect : bool = Global.pixel_perfect[current_mouse_button]
# warning-ignore:incompatible_ternary
					var drawer : Drawer = pixel_perfect_drawer if pixel_perfect else simple_drawer
					draw_pixel_blended(sprite, Vector2(cur_pos_x, cur_pos_y), color, pen_pressure, current_mouse_button, current_action, drawer)

					# Handle mirroring
					var mirror_x = east_limit + west_limit - cur_pos_x - 1
					var mirror_y = south_limit + north_limit - cur_pos_y - 1
					if horizontal_mirror:
# warning-ignore:incompatible_ternary
						var drawer_h_mirror : Drawer = pixel_perfect_drawer_h_mirror if pixel_perfect else simple_drawer
						draw_pixel_blended(sprite, Vector2(mirror_x, cur_pos_y), color, pen_pressure, current_mouse_button, current_action, drawer_h_mirror)
					if vertical_mirror:
# warning-ignore:incompatible_ternary
						var drawer_v_mirror : Drawer = pixel_perfect_drawer_v_mirror if pixel_perfect else simple_drawer
						draw_pixel_blended(sprite, Vector2(cur_pos_x, mirror_y), color, pen_pressure, current_mouse_button, current_action, drawer_v_mirror)
					if horizontal_mirror && vertical_mirror:
# warning-ignore:incompatible_ternary
						var drawer_hv_mirror : Drawer = pixel_perfect_drawer_hv_mirror if pixel_perfect else simple_drawer
						draw_pixel_blended(sprite, Vector2(mirror_x, mirror_y), color, pen_pressure, current_mouse_button, current_action, drawer_hv_mirror)

					Global.canvas.sprite_changed_this_frame = true

		elif brush_type == Global.Brush_Types.CIRCLE || brush_type == Global.Brush_Types.FILLED_CIRCLE:
			plot_circle(sprite, pos.x, pos.y, brush_size, color, brush_type == Global.Brush_Types.FILLED_CIRCLE)

			# Handle mirroring
			var mirror_x = east_limit + west_limit - pos.x
			var mirror_y = south_limit + north_limit - pos.y
			if horizontal_mirror:
				plot_circle(sprite, mirror_x, pos.y, brush_size, color, brush_type == Global.Brush_Types.FILLED_CIRCLE)
			if vertical_mirror:
				plot_circle(sprite, pos.x, mirror_y, brush_size, color, brush_type == Global.Brush_Types.FILLED_CIRCLE)
			if horizontal_mirror && vertical_mirror:
				plot_circle(sprite, mirror_x, mirror_y, brush_size, color, brush_type == Global.Brush_Types.FILLED_CIRCLE)

			Global.canvas.sprite_changed_this_frame = true

		else:
			var brush_index : int = Global.custom_brush_indexes[current_mouse_button]
			var custom_brush_image : Image
			if brush_type != Global.Brush_Types.RANDOM_FILE:
				custom_brush_image = Global.custom_brush_images[current_mouse_button]
			else: # Handle random brush
				var brush_button = Global.file_brush_container.get_child(brush_index + 3)
				var random_index = randi() % brush_button.random_brushes.size()
				custom_brush_image = Image.new()
				custom_brush_image.copy_from(brush_button.random_brushes[random_index])
				var custom_brush_size = custom_brush_image.get_size()
				custom_brush_image.resize(custom_brush_size.x * brush_size, custom_brush_size.y * brush_size, Image.INTERPOLATE_NEAREST)
				custom_brush_image = Global.blend_image_with_color(custom_brush_image, color, Global.interpolate_spinboxes[current_mouse_button].value / 100)
				custom_brush_image.lock()

			var custom_brush_size := custom_brush_image.get_size() - Vector2.ONE
			pos = pos.floor()
			var dst := rectangle_center(pos, custom_brush_size)
			var src_rect := Rect2(Vector2.ZERO, custom_brush_size + Vector2.ONE)
			# Rectangle with the same size as the brush, but at cursor's position
			var pos_rect := Rect2(dst, custom_brush_size + Vector2.ONE)

			# The selection rectangle
			# If there's no rectangle, the whole canvas is considered a selection
			var selection_rect := Rect2()
			selection_rect.position = Vector2(west_limit, north_limit)
			selection_rect.end = Vector2(east_limit, south_limit)
			# Intersection of the position rectangle and selection
			var pos_rect_clipped := pos_rect.clip(selection_rect)
			# If the size is 0, that means that the brush wasn't positioned inside the selection
			if pos_rect_clipped.size == Vector2.ZERO:
				return

			# Re-position src_rect and dst based on the clipped position
			var pos_difference := (pos_rect.position - pos_rect_clipped.position).abs()
			# Obviously, if pos_rect and pos_rect_clipped are the same, pos_difference is Vector2.ZERO
			src_rect.position = pos_difference
			dst += pos_difference
			src_rect.end -= pos_rect.end - pos_rect_clipped.end
			# If the selection rectangle is smaller than the brush, ...
			# ... make sure pixels aren't being drawn outside the selection by adjusting src_rect's size
			src_rect.size.x = min(src_rect.size.x, selection_rect.size.x)
			src_rect.size.y = min(src_rect.size.y, selection_rect.size.y)

			# Handle mirroring
			var mirror_x = east_limit + west_limit - pos.x - (pos.x - dst.x)
			var mirror_y = south_limit + north_limit - pos.y - (pos.y - dst.y)
			if int(pos_rect_clipped.size.x) % 2 != 0:
				mirror_x -= 1
			if int(pos_rect_clipped.size.y) % 2 != 0:
				mirror_y -= 1
			# Use custom blend function cause of godot's issue  #31124
			if color.a > 0: # If it's the pencil
				blend_rect(sprite, custom_brush_image, src_rect, dst)
				if horizontal_mirror:
					blend_rect(sprite, custom_brush_image, src_rect, Vector2(mirror_x, dst.y))
				if vertical_mirror:
					blend_rect(sprite, custom_brush_image, src_rect, Vector2(dst.x, mirror_y))
				if horizontal_mirror && vertical_mirror:
					blend_rect(sprite, custom_brush_image, src_rect, Vector2(mirror_x, mirror_y))

			else: # if it's transparent - if it's the eraser
				var custom_brush := Image.new()
				custom_brush.copy_from(Global.custom_brushes[brush_index])
				custom_brush_size = custom_brush.get_size()
				custom_brush.resize(custom_brush_size.x * brush_size, custom_brush_size.y * brush_size, Image.INTERPOLATE_NEAREST)
				var custom_brush_blended = Global.blend_image_with_color(custom_brush, color, 1)

				sprite.blit_rect_mask(custom_brush_blended, custom_brush, src_rect, dst)
				if horizontal_mirror:
					sprite.blit_rect_mask(custom_brush_blended, custom_brush, src_rect, Vector2(mirror_x, dst.y))
				if vertical_mirror:
					sprite.blit_rect_mask(custom_brush_blended, custom_brush, src_rect, Vector2(dst.x, mirror_y))
				if horizontal_mirror && vertical_mirror:
					sprite.blit_rect_mask(custom_brush_blended, custom_brush, src_rect, Vector2(mirror_x, mirror_y))

			sprite.lock()
			Global.canvas.sprite_changed_this_frame = true

		Global.canvas.previous_mouse_pos_for_lines = pos.floor() + Vector2(0.5, 0.5)
		Global.canvas.previous_mouse_pos_for_lines.x = clamp(Global.canvas.previous_mouse_pos_for_lines.x, Global.canvas.location.x, Global.canvas.location.x + Global.canvas.size.x)
		Global.canvas.previous_mouse_pos_for_lines.y = clamp(Global.canvas.previous_mouse_pos_for_lines.y, Global.canvas.location.y, Global.canvas.location.y + Global.canvas.size.y)
		if Global.canvas.is_making_line:
			Global.canvas.line_2d.set_point_position(0, Global.canvas.previous_mouse_pos_for_lines)


# Bresenham's Algorithm
# Thanks to https://godotengine.org/qa/35276/tile-based-line-drawing-algorithm-efficiency
func fill_gaps(sprite : Image, end_pos : Vector2, start_pos : Vector2, color : Color, current_mouse_button : int, pen_pressure : float, current_action := -1) -> void:
	var previous_mouse_pos_floored = start_pos.floor()
	var mouse_pos_floored = end_pos.floor()
	var dx := int(abs(mouse_pos_floored.x - previous_mouse_pos_floored.x))
	var dy := int(-abs(mouse_pos_floored.y - previous_mouse_pos_floored.y))
	var err := dx + dy
	var e2 := err << 1 # err * 2
	var sx = 1 if previous_mouse_pos_floored.x < mouse_pos_floored.x else -1
	var sy = 1 if previous_mouse_pos_floored.y < mouse_pos_floored.y else -1
	var x = previous_mouse_pos_floored.x
	var y = previous_mouse_pos_floored.y
	while !(x == mouse_pos_floored.x && y == mouse_pos_floored.y):
		draw_brush(sprite, Vector2(x, y), color, current_mouse_button, pen_pressure, current_action)
		e2 = err << 1
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


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
		draw_pixel_blended(sprite, quadrant_1, color, Global.canvas.pen_pressure)
		draw_pixel_blended(sprite, quadrant_2, color, Global.canvas.pen_pressure)
		draw_pixel_blended(sprite, quadrant_3, color, Global.canvas.pen_pressure)
		draw_pixel_blended(sprite, quadrant_4, color, Global.canvas.pen_pressure)

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
					draw_pixel_blended(sprite, draw_pos, color, Global.canvas.pen_pressure)


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
# warning-ignore:integer_division
# warning-ignore:integer_division
	var center : Vector2 = Vector2(sprite.get_width() / 2, sprite.get_height() / 2)
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


func fake_rotsprite(sprite : Image, angle : float) -> void:
	sprite.copy_from(scale3X(sprite))
	nn_rotate(sprite,angle)
# warning-ignore:integer_division
# warning-ignore:integer_division
	sprite.resize(sprite.get_width() / 3, sprite.get_height() / 3, 0)


func nn_rotate(sprite : Image, angle : float) -> void:
	var aux : Image = Image.new()
	aux.copy_from(sprite)
	sprite.lock()
	aux.lock()
	var ox: int
	var oy: int
# warning-ignore:integer_division
# warning-ignore:integer_division
	var center : Vector2 = Vector2(sprite.get_width() / 2, sprite.get_height() / 2)
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


# Returns the position in the middle of a rectangle
func rectangle_center(rect_position : Vector2, rect_size : Vector2) -> Vector2:
	return (rect_position - rect_size / 2).floor()
