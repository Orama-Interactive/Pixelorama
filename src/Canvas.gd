class_name Canvas
extends Node2D


var location := Vector2.ZERO
var size := Vector2(64, 64)
var fill_color := Color(0, 0, 0, 0)
var current_pixel := Vector2.ZERO # pretty much same as mouse_pos, but can be accessed externally
var previous_mouse_pos := Vector2.ZERO
var previous_mouse_pos_for_lines := Vector2.ZERO
var can_undo := true
var cursor_image_has_changed := false
var previous_action := -1
var west_limit := location.x
var east_limit := location.x + size.x
var north_limit := location.y
var south_limit := location.y + size.y
var sprite_changed_this_frame := false # for optimization purposes
var is_making_line := false
var made_line := false
var is_making_selection := -1
var line_2d : Line2D
var pen_pressure := 1.0 # For tablet pressure sensitivity


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var frame : Frame = new_empty_frame(true)
	Global.frames.append(frame)
	camera_zoom()

	line_2d = Line2D.new()
	line_2d.width = 0.5
	line_2d.default_color = Color.darkgray
	line_2d.add_point(previous_mouse_pos_for_lines)
	line_2d.add_point(previous_mouse_pos_for_lines)
	add_child(line_2d)


func _draw() -> void:
	var current_cels : Array = Global.frames[Global.current_frame].cels
	if Global.onion_skinning:
		onion_skinning()

	# Draw current frame layers
	for i in range(Global.layers.size()):
		var modulate_color := Color(1, 1, 1, current_cels[i].opacity)
		if Global.layers[i].visible: # if it's visible
			draw_texture(current_cels[i].image_texture, location, modulate_color)

			if Global.tile_mode:
				draw_texture(current_cels[i].image_texture, Vector2(location.x, location.y + size.y), modulate_color) # Down
				draw_texture(current_cels[i].image_texture, Vector2(location.x - size.x, location.y + size.y), modulate_color) # Down Left
				draw_texture(current_cels[i].image_texture, Vector2(location.x - size.x, location.y), modulate_color) # Left
				draw_texture(current_cels[i].image_texture, location - size, modulate_color) # Up left
				draw_texture(current_cels[i].image_texture, Vector2(location.x, location.y - size.y), modulate_color) # Up
				draw_texture(current_cels[i].image_texture, Vector2(location.x + size.x, location.y - size.y), modulate_color) # Up right
				draw_texture(current_cels[i].image_texture, Vector2(location.x + size.x, location.y), modulate_color) # Right
				draw_texture(current_cels[i].image_texture, location + size, modulate_color) # Down right

	if Global.draw_grid:
		draw_grid(Global.grid_type)

	# Draw rectangle to indicate the pixel currently being hovered on
	if Global.can_draw:
		var mouse_pos := current_pixel
		mouse_pos = mouse_pos.floor()
		var visible_indicators := [Global.left_square_indicator_visible, Global.right_square_indicator_visible]

		for i in range(0, 1):
			if visible_indicators[i]:
				if Global.current_brush_types[i] == Global.Brush_Types.PIXEL || Global.current_tools[i] == Global.Tools.LIGHTENDARKEN:
					if Global.current_tools[i] == Global.Tools.PENCIL || Global.current_tools[i] == Global.Tools.ERASER || Global.current_tools[i] == Global.Tools.LIGHTENDARKEN:
						var start_pos_x = mouse_pos.x - (Global.brush_sizes[i] >> 1)
						var start_pos_y = mouse_pos.y - (Global.brush_sizes[i] >> 1)
						draw_rect(Rect2(start_pos_x, start_pos_y, Global.brush_sizes[i], Global.brush_sizes[i]), Color.blue, false)
				elif Global.current_brush_types[i] == Global.Brush_Types.CIRCLE || Global.current_brush_types[i] == Global.Brush_Types.FILLED_CIRCLE:
					if Global.current_tools[i] == Global.Tools.PENCIL || Global.current_tools[i] == Global.Tools.ERASER:
						draw_set_transform(mouse_pos, rotation, scale)
						for rect in Global.left_circle_points:
							draw_rect(Rect2(rect, Vector2.ONE), Color.blue, false)
						draw_set_transform(position, rotation, scale)
				else:
					if Global.current_tools[i] == Global.Tools.PENCIL || Global.current_tools[i] == Global.Tools.ERASER:
						var custom_brush_size = Global.custom_brush_images[i].get_size()  - Vector2.ONE
						var dst : Vector2 = DrawingAlgos.rectangle_center(mouse_pos, custom_brush_size)
						draw_texture(Global.custom_brush_textures[i], dst)


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
		DrawingAlgos.reset()
		can_undo = true

	current_pixel = get_local_mouse_position() + location

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
	var mouse_pos := current_pixel
	var mouse_pos_floored := mouse_pos.floor()
	var current_mouse_button := -1

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
		current_mouse_button = Global.Mouse_Button.LEFT

	elif Input.is_mouse_button_pressed(BUTTON_RIGHT):
		current_mouse_button = Global.Mouse_Button.RIGHT

	var current_action : int = Global.current_tools[current_mouse_button] if current_mouse_button != -1 else -1

	if Global.has_focus:
		Global.cursor_position_label.text = "[%s×%s]    %s, %s" % [size.x, size.y, mouse_pos_floored.x, mouse_pos_floored.y]
		if !cursor_image_has_changed:
			cursor_image_has_changed = true
			if Global.cursor_image.get_data().get_size() != Vector2.ZERO:
				Input.set_custom_mouse_cursor(Global.cursor_image, 0, Vector2(15, 15))
			if Global.show_left_tool_icon:
				Global.left_cursor.visible = true
			if Global.show_right_tool_icon:
				Global.right_cursor.visible = true
	else:
		Global.cursor_position_label.text = "[%s×%s]" % [size.x, size.y]
		if cursor_image_has_changed:
			cursor_image_has_changed = false
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

	handle_tools(current_mouse_button, current_action, mouse_pos, can_handle)

	if Global.can_draw && Global.has_focus && Input.is_action_just_pressed("shift") && ([Global.Tools.PENCIL, Global.Tools.ERASER, Global.Tools.LIGHTENDARKEN].has(Global.current_tools[0]) || [Global.Tools.PENCIL, Global.Tools.ERASER, Global.Tools.LIGHTENDARKEN].has(Global.current_tools[1])):
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

	if is_making_selection != -1: # If we're making a selection
		var mouse_button_string := "left_mouse" if is_making_selection == Global.Mouse_Button.LEFT else "right_mouse"

		if Input.is_action_just_released(mouse_button_string): # Finish selection when button is released
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
			is_making_selection = -1
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


func new_empty_frame(first_time := false) -> Frame:
	var frame := Frame.new()
	for l in Global.layers:
		# The sprite itself
		var sprite := Image.new()
		if first_time:
			if Global.config_cache.has_section_key("preferences", "default_width"):
				size.x = Global.config_cache.get_value("preferences", "default_width")
			if Global.config_cache.has_section_key("preferences", "default_height"):
				size.y = Global.config_cache.get_value("preferences", "default_height")
			if Global.config_cache.has_section_key("preferences", "default_fill_color"):
				fill_color = Global.config_cache.get_value("preferences", "default_fill_color")

		sprite.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		sprite.fill(fill_color)
		sprite.lock()
		frame.cels.append(Cel.new(sprite, 1))

	return frame


func handle_tools(current_mouse_button : int, current_action : int, mouse_pos : Vector2, can_handle : bool) -> void:
	var current_cel : Cel = Global.frames[Global.current_frame].cels[Global.current_layer]
	var sprite : Image = current_cel.image
	var mouse_pos_floored := mouse_pos.floor()
	var mouse_pos_ceiled := mouse_pos.ceil()

	var current_color : Color = Global.color_pickers[current_mouse_button].color
	var fill_area : int = Global.fill_areas[current_mouse_button]
	var ld : int = Global.ld_modes[current_mouse_button]
	var ld_amount : float = Global.ld_amounts[current_mouse_button]
	var color_picker_for : int = Global.color_picker_for[current_mouse_button]
	var zoom_mode : int = Global.zoom_modes[current_mouse_button]

	match current_action: # Handle current tool
		Global.Tools.PENCIL:
			pencil_and_eraser(sprite, mouse_pos, current_color, current_mouse_button, current_action)
		Global.Tools.ERASER:
			pencil_and_eraser(sprite, mouse_pos, Color(0, 0, 0, 0), current_mouse_button, current_action)
		Global.Tools.BUCKET:
			if can_handle:
				var fill_with : int = Global.fill_with[current_mouse_button]
				var pattern_image : Image = Global.pattern_images[current_mouse_button]
				var pattern_offset : Vector2 = Global.fill_pattern_offsets[current_mouse_button]

				if fill_area == Global.Fill_Area.SAME_COLOR_AREA: # Paint the specific area of the same color
					var mirror_x := east_limit + west_limit - mouse_pos_floored.x - 1
					var mirror_y := south_limit + north_limit - mouse_pos_floored.y - 1
					var horizontal_mirror : bool = Global.horizontal_mirror[current_mouse_button]
					var vertical_mirror : bool = Global.vertical_mirror[current_mouse_button]

					if fill_with == Global.Fill_With.PATTERN && pattern_image: # Pattern fill
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
								if fill_with == Global.Fill_With.PATTERN && pattern_image: # Pattern fill
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
				if ld == Global.Lighten_Darken_Mode.LIGHTEN:
					color_changed = pixel_color.lightened(ld_amount)
				else: # Darken
					color_changed = pixel_color.darkened(ld_amount)
				pencil_and_eraser(sprite, mouse_pos, color_changed, current_mouse_button, current_action)
		Global.Tools.RECTSELECT:
			# Check SelectionRectangle.gd for more code on Rectangle Selection
			if Global.can_draw && Global.has_focus:
				# If we're creating a new selection
				if Global.selected_pixels.size() == 0 || !point_in_rectangle(mouse_pos_floored, Global.selection_rectangle.polygon[0] - Vector2.ONE, Global.selection_rectangle.polygon[2]):
					var mouse_button_string := "left_mouse" if current_mouse_button == Global.Mouse_Button.LEFT else "right_mouse"

					if Input.is_action_just_pressed(mouse_button_string):
						Global.selection_rectangle.polygon[0] = mouse_pos_floored
						Global.selection_rectangle.polygon[1] = mouse_pos_floored
						Global.selection_rectangle.polygon[2] = mouse_pos_floored
						Global.selection_rectangle.polygon[3] = mouse_pos_floored
						is_making_selection = current_mouse_button
						Global.selected_pixels.clear()
					else:
						if is_making_selection != -1: # If we're making a new selection...
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
				Global.color_pickers[color_picker_for].color = pixel_color
				Global.update_custom_brush(color_picker_for)
		Global.Tools.ZOOM:
			if can_handle:
				if zoom_mode == Global.Zoom_Mode.ZOOM_IN:
					Global.camera.zoom_camera(-1)
				else:
					Global.camera.zoom_camera(1)


func pencil_and_eraser(sprite : Image, mouse_pos : Vector2, color : Color, current_mouse_button : int, current_action := -1) -> void:
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


func handle_undo(action : String) -> void:
	if !can_undo:
		return
	var frames := []
	var frame_index := -1
	var layer_index := -1
	if Global.animation_timer.is_stopped(): # if we're not animating, store only the current canvas
		frames.append(Global.frames[Global.current_frame])
		frame_index = Global.current_frame
		layer_index = Global.current_layer
	else: # If we're animating, store all frames
		frames = Global.frames
	Global.undos += 1
	Global.undo_redo.create_action(action)
	for f in frames:
		# I'm not sure why I have to unlock it, but...
		# ...if I don't, it doesn't work properly
		f.cels[Global.current_layer].image.unlock()
		var data = f.cels[Global.current_layer].image.data
		f.cels[Global.current_layer].image.lock()
		Global.undo_redo.add_undo_property(f.cels[Global.current_layer].image, "data", data)
	if action == "Rectangle Select":
		var selected_pixels = Global.selected_pixels.duplicate()
		Global.undo_redo.add_undo_property(Global.selection_rectangle, "polygon", Global.selection_rectangle.polygon)
		Global.undo_redo.add_undo_property(Global, "selected_pixels", selected_pixels)
	Global.undo_redo.add_undo_method(Global, "undo", frame_index, layer_index)

	can_undo = false


func handle_redo(action : String) -> void:
	can_undo = true

	if Global.undos < Global.undo_redo.get_version():
		return
	var frames := []
	var frame_index := -1
	var layer_index := -1
	if Global.animation_timer.is_stopped():
		frames.append(Global.frames[Global.current_frame])
		frame_index = Global.current_frame
		layer_index = Global.current_layer
	else:
		frames = Global.frames
	for f in frames:
		Global.undo_redo.add_do_property(f.cels[Global.current_layer].image, "data", f.cels[Global.current_layer].image.data)
	if action == "Rectangle Select":
		Global.undo_redo.add_do_property(Global.selection_rectangle, "polygon", Global.selection_rectangle.polygon)
		Global.undo_redo.add_do_property(Global, "selected_pixels", Global.selected_pixels)
	Global.undo_redo.add_do_method(Global, "redo", frame_index, layer_index)
	Global.undo_redo.commit_action()


func update_texture(layer_index : int, frame_index := -1) -> void:
	if frame_index == -1:
		frame_index = Global.current_frame
	var current_cel : Cel = Global.frames[frame_index].cels[layer_index]
	current_cel.image_texture.create_from_image(current_cel.image, 0)

	var frame_texture_rect : TextureRect
	frame_texture_rect = Global.find_node_by_name(Global.layers[layer_index].frame_container.get_child(frame_index), "CelTexture")
	frame_texture_rect.texture = current_cel.image_texture


func onion_skinning() -> void:
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
				for layer in Global.frames[Global.current_frame - i].cels:
					if Global.layers[layer_i].visible:
						color.a = 0.6 / i
						draw_texture(layer.image_texture, location, color)
					layer_i += 1

	# Future
	if Global.onion_skinning_future_rate > 0:
		var color : Color
		if Global.onion_skinning_blue_red:
			color = Color.red
		else:
			color = Color.white
		for i in range(1, Global.onion_skinning_future_rate + 1):
			if Global.current_frame < Global.frames.size() - i:
				var layer_i := 0
				for layer in Global.frames[Global.current_frame + i].cels:
					if Global.layers[layer_i].visible:
						color.a = 0.6 / i
						draw_texture(layer.image_texture, location, color)
					layer_i += 1


func draw_grid(grid_type : int) -> void:
	if grid_type == Global.Grid_Types.CARTESIAN || grid_type == Global.Grid_Types.ALL:
		for x in range(Global.grid_width, size.x, Global.grid_width):
			draw_line(Vector2(x, location.y), Vector2(x, size.y), Global.grid_color, true)

		for y in range(Global.grid_height, size.y, Global.grid_height):
			draw_line(Vector2(location.x, y), Vector2(size.x, y), Global.grid_color, true)

	# Doesn't work properly yet
	if grid_type == Global.Grid_Types.ISOMETRIC || grid_type == Global.Grid_Types.ALL:
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


# Checks if a point is inside a rectangle
func point_in_rectangle(p : Vector2, coord1 : Vector2, coord2 : Vector2) -> bool:
	return p.x > coord1.x && p.y > coord1.y && p.x < coord2.x && p.y < coord2.y
