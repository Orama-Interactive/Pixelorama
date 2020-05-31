class_name Canvas
extends Node2D


var layers := []
var current_layer_index := 0
var location := Vector2.ZERO
var size := Vector2(64, 64)
var fill_color := Color(0, 0, 0, 0)
var frame := 0
var current_pixel := Vector2.ZERO # pretty much same as mouse_pos, but can be accessed externally
var previous_mouse_pos := Vector2.ZERO
var previous_mouse_pos_for_lines := Vector2.ZERO
var can_undo := true
var cursor_inside_canvas := false
var previous_action := -1
var west_limit := location.x
var east_limit := location.x + size.x
var north_limit := location.y
var south_limit := location.y + size.y
var mouse_inside_canvas := false # used for undo
var sprite_changed_this_frame := false # for optimization purposes
var is_making_line := false
var made_line := false
var is_making_selection := "None"
var line_2d : Line2D
var pen_pressure := 1.0 # For tablet pressure sensitivity


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var fill_layers := layers.empty()
	var layer_i := 0
	for l in Global.layers:
		if fill_layers:
			# The sprite itself
			var sprite := Image.new()
			if Global.is_default_image:
				if Global.config_cache.has_section_key("preferences", "default_width"):
					size.x = Global.config_cache.get_value("preferences", "default_width")
				if Global.config_cache.has_section_key("preferences", "default_height"):
					size.y = Global.config_cache.get_value("preferences", "default_height")
				if Global.config_cache.has_section_key("preferences", "default_fill_color"):
					fill_color = Global.config_cache.get_value("preferences", "default_fill_color")
				Global.is_default_image = !Global.is_default_image

			sprite.create(size.x, size.y, false, Image.FORMAT_RGBA8)
			sprite.fill(fill_color)
			sprite.lock()

			var tex := ImageTexture.new()
			tex.create_from_image(sprite, 0)

			# Store [Image, ImageTexture, Opacity]
			layers.append([sprite, tex, 1])

		if self in l[5]:
			# If the linked button is pressed, set as the Image & ImageTexture
			# to be the same as the first linked cel
			layers[layer_i][0] = l[5][0].layers[layer_i][0]
			layers[layer_i][1] = l[5][0].layers[layer_i][1]

		layer_i += 1

	# Only handle camera zoom settings & offset on the first frame
	if Global.canvases[0] == self:
		camera_zoom()

	line_2d = Line2D.new()
	line_2d.width = 0.5
	line_2d.default_color = Color.darkgray
	line_2d.add_point(previous_mouse_pos_for_lines)
	line_2d.add_point(previous_mouse_pos_for_lines)
	add_child(line_2d)


func _draw() -> void:
	# Onion Skinning
	if Global.onion_skinning:
		# Past
		if Global.onion_skinning_past_rate > 0:
			var color : Color
			if Global.onion_skinning_blue_red:
				color = Color.blue
			else:
				color = Color.white
			for i in range(1, Global.onion_skinning_past_rate + 1):
				if Global.current_frame >= i:
					var layer_i := 0
					for layer in Global.canvases[Global.current_frame - i].layers:
						if Global.layers[layer_i][1]: # If it's visible
							color.a = 0.6 / i
							draw_texture(layer[1], location, color)
						layer_i += 1

		# Future
		if Global.onion_skinning_future_rate > 0:
			var color : Color
			if Global.onion_skinning_blue_red:
				color = Color.red
			else:
				color = Color.white
			for i in range(1, Global.onion_skinning_future_rate + 1):
				if Global.current_frame < Global.canvases.size() - i:
					var layer_i := 0
					for layer in Global.canvases[Global.current_frame + i].layers:
						if Global.layers[layer_i][1]: # If it's visible
							color.a = 0.6 / i
							draw_texture(layer[1], location, color)
						layer_i += 1

	# Draw current frame layers
	for i in range(layers.size()):
		var modulate_color := Color(1, 1, 1, layers[i][2])
		if Global.layers[i][1]: # if it's visible
			draw_texture(layers[i][1], location, modulate_color)

			if Global.tile_mode:
				draw_texture(layers[i][1], Vector2(location.x, location.y + size.y), modulate_color) # Down
				draw_texture(layers[i][1], Vector2(location.x - size.x, location.y + size.y), modulate_color) # Down Left
				draw_texture(layers[i][1], Vector2(location.x - size.x, location.y), modulate_color) # Left
				draw_texture(layers[i][1], location - size, modulate_color) # Up left
				draw_texture(layers[i][1], Vector2(location.x, location.y - size.y), modulate_color) # Up
				draw_texture(layers[i][1], Vector2(location.x + size.x, location.y - size.y), modulate_color) # Up right
				draw_texture(layers[i][1], Vector2(location.x + size.x, location.y), modulate_color) # Right
				draw_texture(layers[i][1], location + size, modulate_color) # Down right

	# Idea taken from flurick (on GitHub)
	if Global.draw_grid:
		if Global.grid_type == Global.Grid_Types.CARTESIAN || Global.grid_type == Global.Grid_Types.ALL:
			for x in range(Global.grid_width, size.x, Global.grid_width):
				draw_line(Vector2(x, location.y), Vector2(x, size.y), Global.grid_color, true)

			for y in range(Global.grid_height, size.y, Global.grid_height):
				draw_line(Vector2(location.x, y), Vector2(size.x, y), Global.grid_color, true)

		if Global.grid_type == Global.Grid_Types.ISOMETRIC || Global.grid_type == Global.Grid_Types.ALL:
			var prev_x := 0
			var prev_y := 0
			for y in range(0, size.y + 1, Global.grid_width):
				var yy1 = y + size.y * tan(deg2rad(26.565)) # 30 degrees
				if yy1 <= (size.y + 0.01):
					draw_line(Vector2(location.x, y), Vector2(size.x, yy1),Global.grid_color)
				else:
					var xx1 = (size.x - y) * tan(deg2rad(90 - 26.565)) # 60 degrees
					draw_line(Vector2(location.x, y), Vector2(xx1, size.y), Global.grid_color)
			for y in range(0, size.y + 1, Global.grid_height):
				var xx2 = y * tan(deg2rad(90 - 26.565)) # 60 degrees
				if xx2 <= (size.x + 0.01):
					draw_line(Vector2(location.x, y), Vector2(xx2, location.y), Global.grid_color)
					prev_y = location.y
				else:
					var distance = (xx2 - prev_x) / 2
					#var yy2 = (size.y - y) * tan(deg2rad(26.565)) # 30 degrees
					var yy2 = prev_y + distance
					draw_line(Vector2(location.x, y), Vector2(size.x, yy2), Global.grid_color)
					prev_y = yy2

				prev_x = xx2

			for x in range(0, size.x, Global.grid_width * 2):
				if x == 0:
					continue
				var yy1 = (size.x - x) * tan(deg2rad(26.565)) # 30 degrees
				draw_line(Vector2(x, location.y), Vector2(size.x, yy1), Global.grid_color)
			for x in range(0, size.x, Global.grid_height * 2):
				var yy2 = (size.x - x) * tan(deg2rad(26.565)) # 30 degrees
				draw_line(Vector2(x, size.y), Vector2(size.x, size.y - yy2), Global.grid_color)

	# Draw rectangle to indicate the pixel currently being hovered on
	var mouse_pos := current_pixel
	mouse_pos = mouse_pos.floor()
	if Global.left_square_indicator_visible && Global.can_draw:
		if Global.current_brush_type[0] == Global.Brush_Types.PIXEL || Global.current_left_tool == Global.Tools.LIGHTENDARKEN:
			if Global.current_left_tool == Global.Tools.PENCIL || Global.current_left_tool == Global.Tools.ERASER || Global.current_left_tool == Global.Tools.LIGHTENDARKEN:
				var start_pos_x = mouse_pos.x - (Global.left_brush_size >> 1)
				var start_pos_y = mouse_pos.y - (Global.left_brush_size >> 1)
				draw_rect(Rect2(start_pos_x, start_pos_y, Global.left_brush_size, Global.left_brush_size), Color.blue, false)
		elif Global.current_brush_type[0] == Global.Brush_Types.CIRCLE || Global.current_brush_type[0] == Global.Brush_Types.FILLED_CIRCLE:
			if Global.current_left_tool == Global.Tools.PENCIL || Global.current_left_tool == Global.Tools.ERASER:
				draw_set_transform(mouse_pos, rotation, scale)
				for rect in Global.left_circle_points:
					draw_rect(Rect2(rect, Vector2.ONE), Color.blue, false)
				draw_set_transform(position, rotation, scale)
		else:
			if Global.current_left_tool == Global.Tools.PENCIL || Global.current_left_tool == Global.Tools.ERASER:
				var custom_brush_size = Global.custom_left_brush_image.get_size()  - Vector2.ONE
				var dst := rectangle_center(mouse_pos, custom_brush_size)
				draw_texture(Global.custom_left_brush_texture, dst)

	if Global.right_square_indicator_visible && Global.can_draw:
		if Global.current_brush_type[1] == Global.Brush_Types.PIXEL || Global.current_right_tool == Global.Tools.LIGHTENDARKEN:
			if Global.current_right_tool == Global.Tools.PENCIL || Global.current_right_tool == Global.Tools.ERASER || Global.current_right_tool == Global.Tools.LIGHTENDARKEN:
				var start_pos_x = mouse_pos.x - (Global.right_brush_size >> 1)
				var start_pos_y = mouse_pos.y - (Global.right_brush_size >> 1)
				draw_rect(Rect2(start_pos_x, start_pos_y, Global.right_brush_size, Global.right_brush_size), Color.red, false)
		elif Global.current_brush_type[1] == Global.Brush_Types.CIRCLE || Global.current_brush_type[1] == Global.Brush_Types.FILLED_CIRCLE:
			if Global.current_right_tool == Global.Tools.PENCIL || Global.current_right_tool == Global.Tools.ERASER:
				draw_set_transform(mouse_pos, rotation, scale)
				for rect in Global.right_circle_points:
					draw_rect(Rect2(rect, Vector2.ONE), Color.red, false)
				draw_set_transform(position, rotation, scale)
		else:
			if Global.current_right_tool == Global.Tools.PENCIL || Global.current_right_tool == Global.Tools.ERASER:
				var custom_brush_size = Global.custom_right_brush_image.get_size()  - Vector2.ONE
				var dst := rectangle_center(mouse_pos, custom_brush_size)
				draw_texture(Global.custom_right_brush_texture, dst)


func _input(event : InputEvent) -> void:
	# Don't process anything below if the input isn't a mouse event, or Shift/Ctrl.
	# This decreases CPU/GPU usage slightly.
	if not event is InputEventMouse:
		if event is InputEventKey:
			if event.scancode != KEY_SHIFT && event.scancode != KEY_CONTROL:
				return
		else:
			return

	if (Input.is_action_just_released("left_mouse") && !Input.is_action_pressed("right_mouse")) || (Input.is_action_just_released("right_mouse") && !Input.is_action_pressed("left_mouse")):
		made_line = false
		DrawingAlgos.mouse_press_pixels.clear()
		DrawingAlgos.mouse_press_pressure_values.clear()
		DrawingAlgos.pixel_perfect_drawer.reset()
		DrawingAlgos.pixel_perfect_drawer_h_mirror.reset()
		DrawingAlgos.pixel_perfect_drawer_v_mirror.reset()
		DrawingAlgos.pixel_perfect_drawer_hv_mirror.reset()
		can_undo = true

	current_pixel = get_local_mouse_position() + location
	if Global.current_frame != frame || Global.layers[Global.current_layer][2]:
		previous_mouse_pos = current_pixel
		previous_mouse_pos.x = clamp(previous_mouse_pos.x, location.x, location.x + size.x)
		previous_mouse_pos.y = clamp(previous_mouse_pos.y, location.y, location.y + size.y)
		return

	if Global.has_focus:
		update()

	# Godot 3.2 and above only code
	if Engine.get_version_info().major == 3 && Engine.get_version_info().minor >= 2:
		if event is InputEventMouseMotion:
			pen_pressure = event.pressure

			# To be removed once Godot 3.2.2 is out of beta
			if event.pressure == 0.0: # Drawing with mouse
				pen_pressure = 1 # This causes problems with tablets though

	sprite_changed_this_frame = false
	var sprite : Image = layers[Global.current_layer][0]
	var mouse_pos := current_pixel
	var mouse_pos_floored := mouse_pos.floor()
	var mouse_pos_ceiled := mouse_pos.ceil()
	var current_mouse_button := "None"
	var current_action := -1
	var current_color : Color
	var fill_area := 0 # For the bucket tool
	# For the LightenDarken tool
	var ld := 0
	var ld_amount := 0.1
	var color_picker_for := 0
	var zoom_mode := 0

	west_limit = location.x
	east_limit = location.x + size.x
	north_limit = location.y
	south_limit = location.y + size.y
	if Global.selected_pixels.size() != 0:
		west_limit = max(west_limit, Global.selection_rectangle.polygon[0].x)
		east_limit = min(east_limit, Global.selection_rectangle.polygon[2].x)
		north_limit = max(north_limit, Global.selection_rectangle.polygon[0].y)
		south_limit = min(south_limit, Global.selection_rectangle.polygon[2].y)

	if Input.is_mouse_button_pressed(BUTTON_LEFT):
		current_mouse_button = "left_mouse"
		current_action = Global.current_left_tool
		current_color = Global.color_pickers[0].color
		fill_area = Global.left_fill_area
		ld = Global.left_ld
		ld_amount = Global.left_ld_amount
		color_picker_for = Global.left_color_picker_for
		zoom_mode = Global.left_zoom_mode

	elif Input.is_mouse_button_pressed(BUTTON_RIGHT):
		current_mouse_button = "right_mouse"
		current_action = Global.current_right_tool
		current_color = Global.color_pickers[1].color
		fill_area = Global.right_fill_area
		ld = Global.right_ld
		ld_amount = Global.right_ld_amount
		color_picker_for = Global.right_color_picker_for
		zoom_mode = Global.right_zoom_mode

	if Global.has_focus:
		Global.cursor_position_label.text = "[%s×%s]    %s, %s" % [size.x, size.y, mouse_pos_floored.x, mouse_pos_floored.y]
		if !cursor_inside_canvas:
			cursor_inside_canvas = true
			if Global.cursor_image.get_data().get_size() != Vector2.ZERO:
				Input.set_custom_mouse_cursor(Global.cursor_image, 0, Vector2(15, 15))
			if Global.show_left_tool_icon:
				Global.left_cursor.visible = true
			if Global.show_right_tool_icon:
				Global.right_cursor.visible = true
	else:
		if !Input.is_mouse_button_pressed(BUTTON_LEFT) && !Input.is_mouse_button_pressed(BUTTON_RIGHT):
			if mouse_inside_canvas:
				mouse_inside_canvas = false
		Global.cursor_position_label.text = "[%s×%s]" % [size.x, size.y]
		if cursor_inside_canvas:
			cursor_inside_canvas = false
			Global.left_cursor.visible = false
			Global.right_cursor.visible = false
			Input.set_custom_mouse_cursor(null)

	# Handle Undo/Redo
	var can_handle : bool = Global.can_draw && Global.has_focus && !made_line
	var mouse_pressed : bool = (Input.is_action_just_pressed("left_mouse") && !Input.is_action_pressed("right_mouse")) || (Input.is_action_just_pressed("right_mouse") && !Input.is_action_pressed("left_mouse"))

	if mouse_pressed:
		if can_handle || is_making_line:
			if current_action != -1 && current_action != Global.Tools.COLORPICKER && current_action != Global.Tools.ZOOM:
				if current_action == Global.Tools.RECTSELECT:
					handle_undo("Rectangle Select")
				else:
					handle_undo("Draw")
	elif (Input.is_action_just_released("left_mouse") && !Input.is_action_pressed("right_mouse")) || (Input.is_action_just_released("right_mouse") && !Input.is_action_pressed("left_mouse")):
		if can_handle || Global.undos == Global.undo_redo.get_version():
			if previous_action != -1 && previous_action != Global.Tools.RECTSELECT && current_action != Global.Tools.COLORPICKER && current_action != Global.Tools.ZOOM:
				handle_redo("Draw")

	match current_action: # Handle current tool
		Global.Tools.PENCIL:
			pencil_and_eraser(sprite, mouse_pos, current_color, current_mouse_button, current_action)
		Global.Tools.ERASER:
			pencil_and_eraser(sprite, mouse_pos, Color(0, 0, 0, 0), current_mouse_button, current_action)
		Global.Tools.BUCKET:
			if can_handle:
				var fill_with := 0
				var pattern_image : Image
				var pattern_offset : Vector2
				if current_mouse_button == "left_mouse":
					fill_with = Global.left_fill_with
					pattern_image = Global.pattern_left_image
					pattern_offset = Global.left_fill_pattern_offset
				elif current_mouse_button == "right_mouse":
					fill_with = Global.right_fill_with
					pattern_image = Global.pattern_right_image
					pattern_offset = Global.right_fill_pattern_offset

				if fill_area == 0: # Paint the specific area of the same color
					var horizontal_mirror := false
					var vertical_mirror := false
					var mirror_x := east_limit + west_limit - mouse_pos_floored.x - 1
					var mirror_y := south_limit + north_limit - mouse_pos_floored.y - 1
					if current_mouse_button == "left_mouse":
						horizontal_mirror = Global.left_horizontal_mirror
						vertical_mirror = Global.left_vertical_mirror
					elif current_mouse_button == "right_mouse":
						horizontal_mirror = Global.right_horizontal_mirror
						vertical_mirror = Global.right_vertical_mirror

					if fill_with == 1 && pattern_image: # Pattern fill
						DrawingAlgos.pattern_fill(sprite, mouse_pos, pattern_image, sprite.get_pixelv(mouse_pos), pattern_offset)
						if horizontal_mirror:
							var pos := Vector2(mirror_x, mouse_pos.y)
							DrawingAlgos.pattern_fill(sprite, pos, pattern_image, sprite.get_pixelv(mouse_pos), pattern_offset)
						if vertical_mirror:
							var pos := Vector2(mouse_pos.x, mirror_y)
							DrawingAlgos.pattern_fill(sprite, pos, pattern_image, sprite.get_pixelv(mouse_pos), pattern_offset)
						if horizontal_mirror && vertical_mirror:
							var pos := Vector2(mirror_x, mirror_y)
							DrawingAlgos.pattern_fill(sprite, pos, pattern_image, sprite.get_pixelv(mouse_pos), pattern_offset)
					else: # Flood fill
						DrawingAlgos.flood_fill(sprite, mouse_pos, sprite.get_pixelv(mouse_pos), current_color)
						if horizontal_mirror:
							var pos := Vector2(mirror_x, mouse_pos.y)
							DrawingAlgos.flood_fill(sprite, pos, sprite.get_pixelv(pos), current_color)
						if vertical_mirror:
							var pos := Vector2(mouse_pos.x, mirror_y)
							DrawingAlgos.flood_fill(sprite, pos, sprite.get_pixelv(pos), current_color)
						if horizontal_mirror && vertical_mirror:
							var pos := Vector2(mirror_x, mirror_y)
							DrawingAlgos.flood_fill(sprite, pos, sprite.get_pixelv(pos), current_color)

				else: # Paint all pixels of the same color
					var pixel_color : Color = sprite.get_pixelv(mouse_pos)
					for xx in range(west_limit, east_limit):
						for yy in range(north_limit, south_limit):
							var c : Color = sprite.get_pixel(xx, yy)
							if c == pixel_color:
								if fill_with == 1 && pattern_image: # Pattern fill
									pattern_image.lock()
									var pattern_size := pattern_image.get_size()
									var xxx : int = int(xx + pattern_offset.x) % int(pattern_size.x)
									var yyy : int = int(yy + pattern_offset.y) % int(pattern_size.y)
									var pattern_color : Color = pattern_image.get_pixel(xxx, yyy)
									sprite.set_pixel(xx, yy, pattern_color)
									pattern_image.unlock()
								else:
									sprite.set_pixel(xx, yy, current_color)
					sprite_changed_this_frame = true
		Global.Tools.LIGHTENDARKEN:
			if can_handle:
				var pixel_color : Color = sprite.get_pixelv(mouse_pos)
				var color_changed : Color
				if ld == 0: # Lighten
					color_changed = pixel_color.lightened(ld_amount)
				else: # Darken
					color_changed = pixel_color.darkened(ld_amount)
				pencil_and_eraser(sprite, mouse_pos, color_changed, current_mouse_button, current_action)
		Global.Tools.RECTSELECT:
			# Check SelectionRectangle.gd for more code on Rectangle Selection
			if Global.can_draw && Global.has_focus:
				# If we're creating a new selection
				if Global.selected_pixels.size() == 0 || !point_in_rectangle(mouse_pos_floored, Global.selection_rectangle.polygon[0] - Vector2.ONE, Global.selection_rectangle.polygon[2]):
					if Input.is_action_just_pressed(current_mouse_button):
						Global.selection_rectangle.polygon[0] = mouse_pos_floored
						Global.selection_rectangle.polygon[1] = mouse_pos_floored
						Global.selection_rectangle.polygon[2] = mouse_pos_floored
						Global.selection_rectangle.polygon[3] = mouse_pos_floored
						is_making_selection = current_mouse_button
						Global.selected_pixels.clear()
					else:
						if is_making_selection != "None": # If we're making a new selection...
							var start_pos = Global.selection_rectangle.polygon[0]
							if start_pos != mouse_pos_floored:
								var end_pos := Vector2(mouse_pos_ceiled.x, mouse_pos_ceiled.y)
								if mouse_pos.x < start_pos.x:
									end_pos.x = mouse_pos_ceiled.x - 1
								if mouse_pos.y < start_pos.y:
									end_pos.y = mouse_pos_ceiled.y - 1
								Global.selection_rectangle.polygon[1] = Vector2(end_pos.x, start_pos.y)
								Global.selection_rectangle.polygon[2] = end_pos
								Global.selection_rectangle.polygon[3] = Vector2(start_pos.x, end_pos.y)
		Global.Tools.COLORPICKER:
			var canvas_rect := Rect2(location, size)
			if can_handle && canvas_rect.has_point(mouse_pos):
				var image_data := Image.new()
				image_data.copy_from(sprite)
				image_data.lock()
				var pixel_color : Color = image_data.get_pixelv(mouse_pos)
				if color_picker_for == 0: # Pick for the left color
					Global.color_pickers[0].color = pixel_color
					Global.update_left_custom_brush()
				elif color_picker_for == 1: # Pick for the left color
					Global.color_pickers[1].color = pixel_color
					Global.update_right_custom_brush()
		Global.Tools.ZOOM:
			if can_handle:
				if zoom_mode == 0:
					Global.camera.zoom_camera(-1)
				else:
					Global.camera.zoom_camera(1)

	if Global.can_draw && Global.has_focus && Input.is_action_just_pressed("shift") && ([Global.Tools.PENCIL, Global.Tools.ERASER, Global.Tools.LIGHTENDARKEN].has(Global.current_left_tool) || [Global.Tools.PENCIL, Global.Tools.ERASER, Global.Tools.LIGHTENDARKEN].has(Global.current_right_tool)):
		is_making_line = true
		line_2d.set_point_position(0, previous_mouse_pos_for_lines)
	elif Input.is_action_just_released("shift"):
		is_making_line = false
		line_2d.set_point_position(1, line_2d.points[0])

	if is_making_line:
		var point0 : Vector2 = line_2d.points[0]
		var angle := stepify(rad2deg(mouse_pos.angle_to_point(point0)), 0.01)
		if Input.is_action_pressed("ctrl"):
			angle = round(angle / 15) * 15
			var distance : float = point0.distance_to(mouse_pos)
			line_2d.set_point_position(1, point0 + Vector2.RIGHT.rotated(deg2rad(angle)) * distance)
		else:
			line_2d.set_point_position(1, mouse_pos)

		if angle < 0:
			angle = 360 + angle
		Global.cursor_position_label.text += "    %s°" % str(angle)

	if is_making_selection != "None": # If we're making a selection
		if Input.is_action_just_released(is_making_selection): # Finish selection when button is released
			var start_pos = Global.selection_rectangle.polygon[0]
			var end_pos = Global.selection_rectangle.polygon[2]
			if start_pos.x > end_pos.x:
				var temp = end_pos.x
				end_pos.x = start_pos.x
				start_pos.x = temp

			if start_pos.y > end_pos.y:
				var temp = end_pos.y
				end_pos.y = start_pos.y
				start_pos.y = temp

			Global.selection_rectangle.polygon[0] = start_pos
			Global.selection_rectangle.polygon[1] = Vector2(end_pos.x, start_pos.y)
			Global.selection_rectangle.polygon[2] = end_pos
			Global.selection_rectangle.polygon[3] = Vector2(start_pos.x, end_pos.y)

			for xx in range(start_pos.x, end_pos.x):
				for yy in range(start_pos.y, end_pos.y):
					Global.selected_pixels.append(Vector2(xx, yy))
			is_making_selection = "None"
			handle_redo("Rectangle Select")

	previous_action = current_action
	previous_mouse_pos = current_pixel
	if sprite_changed_this_frame:
		update_texture(Global.current_layer)


func camera_zoom() -> void:
	# Set camera zoom based on the sprite size
	var bigger_canvas_axis = max(size.x, size.y)
	var zoom_max := Vector2(bigger_canvas_axis, bigger_canvas_axis) * 0.01
	if zoom_max > Vector2.ONE:
		Global.camera.zoom_max = zoom_max
		Global.camera2.zoom_max = zoom_max
		Global.camera_preview.zoom_max = zoom_max
	else:
		Global.camera.zoom_max = Vector2.ONE
		Global.camera2.zoom_max = Vector2.ONE
		Global.camera_preview.zoom_max = Vector2.ONE

	Global.camera.fit_to_frame(size)
	Global.camera2.fit_to_frame(size)
	Global.camera_preview.fit_to_frame(size)

	Global.transparent_checker._ready() # To update the rect size


func handle_undo(action : String) -> void:
	if !can_undo:
		return
	var canvases := []
	var layer_index := -1
	if Global.animation_timer.is_stopped(): # if we're not animating, store only the current canvas
		canvases = [self]
		layer_index = Global.current_layer
	else: # If we're animating, store all canvases
		canvases = Global.canvases
	Global.undos += 1
	Global.undo_redo.create_action(action)
	for c in canvases:
		# I'm not sure why I have to unlock it, but...
		# ...if I don't, it doesn't work properly
		c.layers[Global.current_layer][0].unlock()
		var data = c.layers[Global.current_layer][0].data
		c.layers[Global.current_layer][0].lock()
		Global.undo_redo.add_undo_property(c.layers[Global.current_layer][0], "data", data)
	if action == "Rectangle Select":
		var selected_pixels = Global.selected_pixels.duplicate()
		Global.undo_redo.add_undo_property(Global.selection_rectangle, "polygon", Global.selection_rectangle.polygon)
		Global.undo_redo.add_undo_property(Global, "selected_pixels", selected_pixels)
	Global.undo_redo.add_undo_method(Global, "undo", canvases, layer_index)

	can_undo = false


func handle_redo(action : String) -> void:
	can_undo = true

	if Global.undos < Global.undo_redo.get_version():
		return
	var canvases := []
	var layer_index := -1
	if Global.animation_timer.is_stopped():
		canvases = [self]
		layer_index = Global.current_layer
	else:
		canvases = Global.canvases
	for c in canvases:
		Global.undo_redo.add_do_property(c.layers[Global.current_layer][0], "data", c.layers[Global.current_layer][0].data)
	if action == "Rectangle Select":
		Global.undo_redo.add_do_property(Global.selection_rectangle, "polygon", Global.selection_rectangle.polygon)
		Global.undo_redo.add_do_property(Global, "selected_pixels", Global.selected_pixels)
	Global.undo_redo.add_do_method(Global, "redo", canvases, layer_index)
	Global.undo_redo.commit_action()


func update_texture(layer_index : int) -> void:
	layers[layer_index][1].create_from_image(layers[layer_index][0], 0)

	var frame_texture_rect : TextureRect
	frame_texture_rect = Global.find_node_by_name(Global.layers[layer_index][3].get_child(frame), "CelTexture")
	frame_texture_rect.texture = layers[layer_index][1]


func pencil_and_eraser(sprite : Image, mouse_pos : Vector2, color : Color, current_mouse_button : String, current_action := -1) -> void:
	if made_line:
		return
	if is_making_line:
		DrawingAlgos.fill_gaps(sprite, line_2d.points[1], previous_mouse_pos_for_lines, color, current_mouse_button, pen_pressure, current_action)
		DrawingAlgos.draw_brush(sprite, line_2d.points[1], color, current_mouse_button, pen_pressure, current_action)
		made_line = true
	else:
		# Draw
		DrawingAlgos.draw_brush(sprite, mouse_pos, color, current_mouse_button, pen_pressure, current_action)
		DrawingAlgos.fill_gaps(sprite, mouse_pos, previous_mouse_pos, color, current_mouse_button, pen_pressure, current_action) # Fill the gaps


# Checks if a point is inside a rectangle
func point_in_rectangle(p : Vector2, coord1 : Vector2, coord2 : Vector2) -> bool:
	return p.x > coord1.x && p.y > coord1.y && p.x < coord2.x && p.y < coord2.y


# Returns the position in the middle of a rectangle
func rectangle_center(rect_position : Vector2, rect_size : Vector2) -> Vector2:
	return (rect_position - rect_size / 2).floor()
