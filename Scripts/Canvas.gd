extends Node2D
class_name Canvas

var layers := []
var current_layer_index := 0
var trans_background : ImageTexture
var location := Vector2.ZERO
var size := Vector2(64, 64)
var frame := 0
var frame_button : VBoxContainer
var frame_texture_rect : TextureRect

var previous_mouse_pos := Vector2.ZERO
var mouse_inside_canvas := false #used for undo
var sprite_changed_this_frame := false #for optimization purposes

var is_making_line := false
var line_2d : Line2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.can_draw = false
	#Background
	trans_background = ImageTexture.new()
	trans_background.create_from_image(load("res://Transparent Background.png"), 0)
	
	#The sprite itself
	if layers.empty():
		var sprite := Image.new()
		sprite.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	
		sprite.lock()
		var tex := ImageTexture.new()
		tex.create_from_image(sprite, 0)
		
		#Store [Image, ImageTexture, Layer Name, Visibity boolean]
		layers.append([sprite, tex, "Layer 0", true])
	
	generate_layer_panels()
	
	frame_button = load("res://FrameButton.tscn").instance()
	frame_button.name = "Frame_%s" % frame
	frame_button.get_node("FrameButton").frame = frame
	frame_button.get_node("FrameID").text = str(frame + 1)
	Global.frame_container.add_child(frame_button)
	
	frame_texture_rect = Global.find_node_by_name(frame_button, "FrameTexture")
	frame_texture_rect.texture = layers[0][1] #ImageTexture current_layer_index
	
	camera_zoom()

# warning-ignore:unused_argument
func _process(delta) -> void:
	sprite_changed_this_frame = false
	update()
	var mouse_pos := get_local_mouse_position() - location
	var current_mouse_button := "None"
	var current_action := "None"
	if Input.is_mouse_button_pressed(BUTTON_LEFT):
		current_mouse_button = "L"
		current_action = Global.current_left_tool
	elif Input.is_mouse_button_pressed(BUTTON_RIGHT):
		current_mouse_button = "R"
		current_action = Global.current_right_tool
	
	if visible:
		if !point_in_rectangle(mouse_pos, location, location + size):
			if !Input.is_mouse_button_pressed(BUTTON_LEFT) && !Input.is_mouse_button_pressed(BUTTON_RIGHT):
				if mouse_inside_canvas:
					mouse_inside_canvas = false
			Global.cursor_position_label.text = "[%sx%s]" % [size.x, size.y]
		else:
			var mouse_pos_floored := mouse_pos.floor()
			Global.cursor_position_label.text = "[%sx%s] %s, %s" % [size.x, size.y, mouse_pos_floored.x, mouse_pos_floored.y]
	
	match current_action:
		"Pencil":
			var current_color : Color
			if current_mouse_button == "L":
				current_color = Global.left_color_picker.color
			elif current_mouse_button == "R":
				current_color = Global.right_color_picker.color
			pencil_and_eraser(mouse_pos, current_color, current_mouse_button)
		"Eraser":
			pencil_and_eraser(mouse_pos, Color(0, 0, 0, 0), current_mouse_button)
		"Fill":
			if point_in_rectangle(mouse_pos, location, location + size) && Global.can_draw && Global.has_focus && Global.current_frame == frame:
				var current_color : Color
				if current_mouse_button == "L":
					current_color = Global.left_color_picker.color
				elif current_mouse_button == "R":
					current_color = Global.right_color_picker.color
				flood_fill(mouse_pos, layers[current_layer_index][0].get_pixelv(mouse_pos), current_color)
	
	if !is_making_line:
		previous_mouse_pos = mouse_pos
		previous_mouse_pos.x = clamp(previous_mouse_pos.x, location.x, location.x + size.x)
		previous_mouse_pos.y = clamp(previous_mouse_pos.y, location.y, location.y + size.y)
	else:
		line_2d.set_point_position(1, mouse_pos)
	
	if sprite_changed_this_frame:
		update_texture(current_layer_index)
	
func update_texture(layer_index : int) -> void:
	layers[layer_index][1].create_from_image(layers[layer_index][0], 0)
	get_layer_container(layer_index).get_child(0).get_child(1).texture = layers[layer_index][1]
	
	#This code is used to update the texture in the animation timeline frame button
	#but blend_rect causes major performance issues on large images
	var whole_image := Image.new()
	whole_image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for layer in layers:
		whole_image.blend_rect(layer[0], Rect2(position, size), Vector2.ZERO)
		layer[0].lock()
	var whole_image_texture := ImageTexture.new()
	whole_image_texture.create_from_image(whole_image, 0)
	frame_texture_rect.texture = whole_image_texture

func get_layer_container(layer_index : int) -> PanelContainer:
	for container in Global.vbox_layer_container.get_children():
		if container is PanelContainer && container.i == layer_index:
			return container
	return null

func _draw() -> void:
	draw_texture_rect(trans_background, Rect2(location, size), true) #Draw transparent background
	
	#Onion Skinning
	#Past
	if Global.onion_skinning_past_rate > 0:
		var color : Color
		if Global.onion_skinning_blue_red:
			color = Color.blue
		else:
			color = Color.white
		for i in range(1, Global.onion_skinning_past_rate + 1):
			if Global.current_frame >= i:
				for texture in Global.canvases[Global.current_frame - i].layers:
					color.a = 0.6/i
					draw_texture(texture[1], location, color)
	
	#Future
	if Global.onion_skinning_future_rate > 0:
		var color : Color
		if Global.onion_skinning_blue_red:
			color = Color.red
		else:
			color = Color.white
		for i in range(1, Global.onion_skinning_future_rate + 1):
			#print(i)
			if Global.current_frame < Global.canvases.size() - i:
				for texture in Global.canvases[Global.current_frame + i].layers:
					color.a = 0.6/i
					draw_texture(texture[1], location, color)
	
	#Draw current frame layers
	for texture in layers:
		if texture[3]: #if it's visible
			draw_texture(texture[1], location)
	
	#Idea taken from flurick (on GitHub)
	if Global.draw_grid:
		for x in size.x:
			draw_line(Vector2(x, location.y), Vector2(x, size.y), Color.black, true)
		for y in size.y:
			draw_line(Vector2(location.x, y), Vector2(size.x, y), Color.black, true)
	
	#Draw rectangle to indicate the pixel currently being hovered on
	var mouse_pos := get_local_mouse_position() - location
	if point_in_rectangle(mouse_pos, location, location + size):
		mouse_pos = mouse_pos.floor()
		if Global.left_square_indicator_visible:
			var start_pos_x = mouse_pos.x - (Global.left_brush_size >> 1)
			var start_pos_y = mouse_pos.y - (Global.left_brush_size >> 1)
			draw_rect(Rect2(start_pos_x, start_pos_y, Global.left_brush_size, Global.left_brush_size), Color.blue, false)
		if Global.right_square_indicator_visible:
			var start_pos_x = mouse_pos.x - (Global.right_brush_size >> 1)
			var start_pos_y = mouse_pos.y - (Global.right_brush_size >> 1)
			draw_rect(Rect2(start_pos_x, start_pos_y, Global.right_brush_size, Global.right_brush_size), Color.red, false)

func generate_layer_panels() -> void:
	for child in Global.vbox_layer_container.get_children():
		if child is PanelContainer:
			child.queue_free()
	
	current_layer_index = layers.size() - 1
	if layers.size() == 1:
		Global.remove_layer_button.disabled = true
		Global.remove_layer_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	else:
		Global.remove_layer_button.disabled = false
		Global.remove_layer_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	for i in range(layers.size() -1, -1, -1):
		var layer_container = load("res://LayerContainer.tscn").instance()
		#layer_names.insert(i, "Layer %s" % i)
		layers[i][2] = "Layer %s" % i
		layer_container.i = i
		#layer_container.get_child(0).get_child(2).text = layer_names[i]
		layer_container.get_child(0).get_child(2).text = layers[i][2]
		layers[i][3] = true #set visible
		layer_container.get_child(0).get_child(1).texture = layers[i][1]
		Global.vbox_layer_container.add_child(layer_container)

func camera_zoom() -> void:
	#Set camera offset to the center of canvas
	Global.camera.offset = size / 2
	#Set camera zoom based on the sprite size
	var bigger = max(size.x, size.y)
	var zoom_max := Vector2(bigger, bigger) * 0.01
	if zoom_max > Vector2.ONE:
		Global.camera.zoom_max = zoom_max
	else:
		Global.camera.zoom_max = Vector2.ONE
	Global.camera.zoom = Vector2(bigger, bigger) * 0.002
	Global.zoom_level_label.text = "Zoom: x%s" % [stepify(1 / $"../Camera2D".zoom.x, 0.01)]

func pencil_and_eraser(mouse_pos : Vector2, color : Color, current_mouse_button : String) -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		if !is_making_line:
			line_2d = Line2D.new()
			line_2d.width = 0.5
			line_2d.default_color = Color.darkgray
			line_2d.add_point(previous_mouse_pos)
			line_2d.add_point(mouse_pos)
			add_child(line_2d)
			is_making_line = true
	else:
		var brush_size := 1
		if current_mouse_button == "L":
			brush_size = Global.left_brush_size
		elif current_mouse_button == "R":
			brush_size = Global.right_brush_size
			
		if is_making_line:
			fill_gaps(mouse_pos, color, brush_size)
			is_making_line = false
			line_2d.queue_free()
		else:
			if point_in_rectangle(mouse_pos, location, location + size):
				mouse_inside_canvas = true
				#Draw
				draw_pixel(mouse_pos, color, brush_size)
				fill_gaps(mouse_pos, color, brush_size) #Fill the gaps
			#If mouse is not inside bounds but it used to be, fill the gaps
			elif point_in_rectangle(previous_mouse_pos, location, location + size):
				fill_gaps(mouse_pos, color, brush_size)

func draw_pixel(pos : Vector2, color : Color, brush_size : int) -> void:
	if Global.can_draw && Global.has_focus && Global.current_frame == frame:
		var start_pos_x = pos.x - (brush_size >> 1)
		var start_pos_y = pos.y - (brush_size >> 1)
		for cur_pos_x in range(start_pos_x, start_pos_x + brush_size):
			#layers[current_layer_index][0].set_pixel(cur_pos_x, pos.y, color)
			for cur_pos_y in range(start_pos_y, start_pos_y + brush_size):
				if layers[current_layer_index][0].get_pixel(cur_pos_x, cur_pos_y) != color: #don't draw the same pixel over and over
					layers[current_layer_index][0].set_pixel(cur_pos_x, cur_pos_y, color)
		#layers[current_layer_index][0].set_pixelv(pos, color)
					sprite_changed_this_frame = true

func point_in_rectangle(p : Vector2, coord1 : Vector2, coord2 : Vector2) -> bool:
	return p.x > coord1.x && p.y > coord1.y && p.x < coord2.x && p.y < coord2.y

#Bresenham's Algorithm
#Thanks to https://godotengine.org/qa/35276/tile-based-line-drawing-algorithm-efficiency
func fill_gaps(mouse_pos : Vector2, color : Color, brush_size : int) -> void:
	var previous_mouse_pos_floored = previous_mouse_pos.floor()
	var mouse_pos_floored = mouse_pos.floor()
	mouse_pos_floored.x = clamp(mouse_pos_floored.x, location.x - 1, location.x + size.x)
	mouse_pos_floored.y = clamp(mouse_pos_floored.y, location.y - 1, location.y + size.y)
	var dx := int(abs(mouse_pos_floored.x - previous_mouse_pos_floored.x))
	var dy := int(-abs(mouse_pos_floored.y - previous_mouse_pos_floored.y))
	var err := dx + dy
	var e2 := err << 1 #err * 2
	var sx = 1 if previous_mouse_pos_floored.x < mouse_pos_floored.x else -1
	var sy = 1 if previous_mouse_pos_floored.y < mouse_pos_floored.y else -1
	var x = previous_mouse_pos_floored.x
	var y = previous_mouse_pos_floored.y
	while !(x == mouse_pos_floored.x && y == mouse_pos_floored.y):
		draw_pixel(Vector2(x, y), color, brush_size)
		e2 = err << 1
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy

#Thanks to https://en.wikipedia.org/wiki/Flood_fill
func flood_fill(pos : Vector2, target_color : Color, replace_color : Color) -> void:
	pos = pos.floor()
	var pixel = layers[current_layer_index][0].get_pixelv(pos)
	if target_color == replace_color:
		return
	elif pixel != target_color:
		return
	else:
		var q = [pos]
		for n in q:
			var west : Vector2 = n
			var east : Vector2 = n
			while west.x >= location.x && layers[current_layer_index][0].get_pixelv(west) == target_color:
				west += Vector2.LEFT
			while east.x < location.x + size.x && layers[current_layer_index][0].get_pixelv(east) == target_color:
				east += Vector2.RIGHT
			for px in range(west.x + 1, east.x):
				var p := Vector2(px, n.y)
				#print(point_in_rectangle(p, location, size))
				draw_pixel(p, replace_color, 1)
				var north := p + Vector2.UP
				var south := p + Vector2.DOWN
				if north.y >= location.y && layers[current_layer_index][0].get_pixelv(north) == target_color:
					q.append(north)
				if south.y < location.y + size.y && layers[current_layer_index][0].get_pixelv(south) == target_color:
					q.append(south)

func _on_Timer_timeout() -> void:
	Global.can_draw = true