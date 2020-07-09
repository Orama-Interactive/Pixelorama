class_name Canvas
extends Node2D


var location := Vector2.ZERO
var fill_color := Color(0, 0, 0, 0)
var current_pixel := Vector2.ZERO # pretty much same as mouse_pos, but can be accessed externally
var can_undo := true
var cursor_image_has_changed := false
var sprite_changed_this_frame := false # for optimization purposes


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var frame : Frame = new_empty_frame(true)
	Global.current_project.frames.append(frame)
	camera_zoom()


func _draw() -> void:
	Global.second_viewport.get_child(0).get_node("CanvasPreview").update()
	Global.small_preview_viewport.get_child(0).get_node("CanvasPreview").update()
	var current_cels : Array = Global.current_project.frames[Global.current_project.current_frame].cels
	var size : Vector2 = Global.current_project.size
	if Global.onion_skinning:
		onion_skinning()

	# Draw current frame layers
	for i in range(Global.current_project.layers.size()):
		var modulate_color := Color(1, 1, 1, current_cels[i].opacity)
		if Global.current_project.layers[i].visible: # if it's visible
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
	if Global.has_focus and Global.can_draw:
		Tools.draw_indicator()


func _input(event : InputEvent) -> void:
	# Don't process anything below if the input isn't a mouse event, or Shift/Ctrl.
	# This decreases CPU/GPU usage slightly.
	if not event is InputEventMouse:
		if not event is InputEventKey:
			return
		elif not event.scancode in [KEY_SHIFT, KEY_CONTROL]:
			return
#	elif not get_viewport_rect().has_point(event.position):
#		return

	current_pixel = get_local_mouse_position() + location

	if Global.has_focus:
		update()

	sprite_changed_this_frame = false

	var current_project : Project = Global.current_project
	current_project.x_min = location.x
	current_project.x_max = location.x + current_project.size.x
	current_project.y_min = location.y
	current_project.y_max = location.y + current_project.size.y
	if not current_project.selected_rect.has_no_area():
		current_project.x_min = max(current_project.x_min, current_project.selected_rect.position.x)
		current_project.x_max = min(current_project.x_max, current_project.selected_rect.end.x)
		current_project.y_min = max(current_project.y_min, current_project.selected_rect.position.y)
		current_project.y_max = min(current_project.y_max, current_project.selected_rect.end.y)

	if Global.has_focus:
		if !cursor_image_has_changed:
			cursor_image_has_changed = true
			if Global.show_left_tool_icon:
				Global.left_cursor.visible = true
			if Global.show_right_tool_icon:
				Global.right_cursor.visible = true
	else:
		if cursor_image_has_changed:
			cursor_image_has_changed = false
			Global.left_cursor.visible = false
			Global.right_cursor.visible = false

	Tools.handle_draw(current_pixel.floor(), event)

	if sprite_changed_this_frame:
		update_texture(current_project.current_layer)


func camera_zoom() -> void:
	# Set camera zoom based on the sprite size
	var bigger_canvas_axis = max(Global.current_project.size.x, Global.current_project.size.y)
	var zoom_max := Vector2(bigger_canvas_axis, bigger_canvas_axis) * 0.01
	var cameras = [Global.camera, Global.camera2, Global.camera_preview]
	for camera in cameras:
		if zoom_max > Vector2.ONE:
			camera.zoom_max = zoom_max
		else:
			camera.zoom_max = Vector2.ONE

		camera.fit_to_frame(Global.current_project.size)
		camera.save_values_to_project()

	Global.transparent_checker._ready() # To update the rect size


func new_empty_frame(first_time := false, single_layer := false, size := Global.current_project.size) -> Frame:
	var frame := Frame.new()
	for l in Global.current_project.layers: # Create as many cels as there are layers
		# The sprite itself
		var sprite := Image.new()
		if first_time:
			if Global.config_cache.has_section_key("preferences", "default_image_width"):
				Global.current_project.size.x = Global.config_cache.get_value("preferences", "default_image_width")
			if Global.config_cache.has_section_key("preferences", "default_image_height"):
				Global.current_project.size.y = Global.config_cache.get_value("preferences", "default_image_height")
			if Global.config_cache.has_section_key("preferences", "default_fill_color"):
				fill_color = Global.config_cache.get_value("preferences", "default_fill_color")
		sprite.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		sprite.fill(fill_color)
		sprite.lock()
		frame.cels.append(Cel.new(sprite, 1))

		if single_layer:
			break

	return frame


func handle_undo(action : String) -> void:
	if !can_undo:
		return
	var frames := []
	var frame_index := -1
	var layer_index := -1
	if Global.animation_timer.is_stopped(): # if we're not animating, store only the current canvas
		frames.append(Global.current_project.frames[Global.current_project.current_frame])
		frame_index = Global.current_project.current_frame
		layer_index = Global.current_project.current_layer
	else: # If we're animating, store all frames
		frames = Global.current_project.frames
	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action(action)
	for f in frames:
		# I'm not sure why I have to unlock it, but...
		# ...if I don't, it doesn't work properly
		f.cels[Global.current_project.current_layer].image.unlock()
		var data = f.cels[Global.current_project.current_layer].image.data
		f.cels[Global.current_project.current_layer].image.lock()
		Global.current_project.undo_redo.add_undo_property(f.cels[Global.current_project.current_layer].image, "data", data)
	Global.current_project.undo_redo.add_undo_method(Global, "undo", frame_index, layer_index)

	can_undo = false


func handle_redo(_action : String) -> void:
	can_undo = true

	if Global.current_project.undos < Global.current_project.undo_redo.get_version():
		return
	var frames := []
	var frame_index := -1
	var layer_index := -1
	if Global.animation_timer.is_stopped():
		frames.append(Global.current_project.frames[Global.current_project.current_frame])
		frame_index = Global.current_project.current_frame
		layer_index = Global.current_project.current_layer
	else:
		frames = Global.current_project.frames
	for f in frames:
		Global.current_project.undo_redo.add_do_property(f.cels[Global.current_project.current_layer].image, "data", f.cels[Global.current_project.current_layer].image.data)
	Global.current_project.undo_redo.add_do_method(Global, "redo", frame_index, layer_index)
	Global.current_project.undo_redo.commit_action()


func update_texture(layer_index : int, frame_index := -1) -> void:
	if frame_index == -1:
		frame_index = Global.current_project.current_frame
	var current_cel : Cel = Global.current_project.frames[frame_index].cels[layer_index]
	current_cel.image_texture.create_from_image(current_cel.image, 0)

	var frame_texture_rect : TextureRect
	frame_texture_rect = Global.find_node_by_name(Global.current_project.layers[layer_index].frame_container.get_child(frame_index), "CelTexture")
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
			if Global.current_project.current_frame >= i:
				var layer_i := 0
				for layer in Global.current_project.frames[Global.current_project.current_frame - i].cels:
					if Global.current_project.layers[layer_i].visible:
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
			if Global.current_project.current_frame < Global.current_project.frames.size() - i:
				var layer_i := 0
				for layer in Global.current_project.frames[Global.current_project.current_frame + i].cels:
					if Global.current_project.layers[layer_i].visible:
						color.a = 0.6 / i
						draw_texture(layer.image_texture, location, color)
					layer_i += 1


func draw_grid(grid_type : int) -> void:
	var size : Vector2 = Global.current_project.size
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
