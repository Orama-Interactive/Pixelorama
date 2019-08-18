extends Node2D
class_name Canvas

var layers := []
var current_layer_index := 0
var trans_background : ImageTexture
var current_sprite : Image
var location := Vector2.ZERO
var size := Vector2(64, 64)

var previous_mouse_pos := Vector2.ZERO
var mouse_inside_canvas := false #used for undo
var sprite_changed_this_frame := false #for optimization purposes
var is_making_line := false
var line_2d : Line2D
var draw_grid := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.can_draw = false
	#Background
	trans_background = ImageTexture.new()
	trans_background.create_from_image(load("res://Transparent Background.png"), 0)
	
	#The sprite itself
	if !current_sprite:
		current_sprite = Image.new()
		current_sprite.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	
	current_sprite.lock()
	var tex := ImageTexture.new()
	tex.create_from_image(current_sprite, 0)
	
	#Store [Image, ImageTexture, Layer Name, Visibity boolean]
	layers.append([current_sprite, tex, "Layer 0", true])
	
	generate_layer_panels()
	#Set camera offset to the center of canvas
	$"../Camera2D".offset = size / 2
	#Set camera zoom based on the sprite size
	var bigger = max(size.x, size.y)
	$"../Camera2D".zoom_max = Vector2(bigger, bigger) * 0.01
	$"../Camera2D".zoom = Vector2(bigger, bigger) * 0.002

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
	
	
	if !point_in_rectangle(mouse_pos, location, location + size):
		if !Input.is_mouse_button_pressed(BUTTON_LEFT) && !Input.is_mouse_button_pressed(BUTTON_RIGHT):
			if mouse_inside_canvas:
				mouse_inside_canvas = false
	match current_action:
		"Pencil":
			var current_color : Color
			if current_mouse_button == "L":
				current_color = Global.left_color_picker.color
			elif current_mouse_button == "R":
				current_color = Global.right_color_picker.color
			pencil_and_eraser(mouse_pos, current_color)
		"Eraser":
			pencil_and_eraser(mouse_pos, Color(0, 0, 0, 0))
		"Fill":
			if point_in_rectangle(mouse_pos, location, location + size) && Global.can_draw && Global.has_focus:
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
	
func update_texture(layer_index : int):
	layers[layer_index][1].create_from_image(layers[layer_index][0], 0)
	get_layer_container(layer_index).get_child(0).get_child(1).texture = layers[layer_index][1]

func get_layer_container(layer_index : int) -> PanelContainer:
	for container in Global.vbox_layer_container.get_children():
		if container is PanelContainer && container.i == layer_index:
			return container
	return null

func _draw() -> void:
	draw_texture_rect(trans_background, Rect2(location, size), true)
	#for texture in layer_textures:
	for texture in layers:
		if texture[3]: #if it's visible
			draw_texture(texture[1], location)
	
	#Draw grid (causes lag - unused. If you wanna test it just set draw_grid = true)
	if draw_grid:
		for x in size.x:
			for y in size.y:
				draw_rect(Rect2(location.x + x, location.y + y, 1, 1), Color.black, false)
	
	#Draw rectangle to indicate the pixel currently being hovered on
	var mouse_pos := get_local_mouse_position() - location
	if point_in_rectangle(mouse_pos, location, location + size):
		mouse_pos = mouse_pos.floor()
		draw_rect(Rect2(mouse_pos.x, mouse_pos.y, 1, 1), Color.red, false)

func generate_layer_panels() -> void:
	for child in Global.vbox_layer_container.get_children():
		if child is PanelContainer:
			child.queue_free()
	
	current_layer_index = layers.size() - 1
	if layers.size() == 1:
		Global.remove_layer_button.disabled = true
	else:
		Global.remove_layer_button.disabled = false
	
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

func pencil_and_eraser(mouse_pos : Vector2, color : Color) -> void:
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
		if is_making_line:
			fill_gaps(mouse_pos, color)
			is_making_line = false
			line_2d.queue_free()
		else:
			if point_in_rectangle(mouse_pos, location, location + size):
				mouse_inside_canvas = true
				#Draw
				draw_pixel(mouse_pos, color)
				fill_gaps(mouse_pos, color) #Fill the gaps
			#If mouse is not inside bounds but it used to be, fill the gaps
			elif point_in_rectangle(previous_mouse_pos, location, location + size):
				fill_gaps(mouse_pos, color)

func draw_pixel(pos : Vector2, color : Color) -> void:
	if layers[current_layer_index][0].get_pixelv(pos) != color: #don't draw the same pixel over and over
		if Global.can_draw && Global.has_focus:
			#sprite.lock()
			layers[current_layer_index][0].set_pixelv(pos, color)
			#sprite.unlock()
			sprite_changed_this_frame = true

func point_in_rectangle(p : Vector2, coord1 : Vector2, coord2 : Vector2) -> bool:
	return p.x > coord1.x && p.y > coord1.y && p.x < coord2.x && p.y < coord2.y

#Bresenham's Algorithm
#Thanks to https://godotengine.org/qa/35276/tile-based-line-drawing-algorithm-efficiency
func fill_gaps(mouse_pos : Vector2, color : Color) -> void:
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
		draw_pixel(Vector2(x, y), color)
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
				draw_pixel(p, replace_color)
				var north := p + Vector2.UP
				var south := p + Vector2.DOWN
				if north.y >= location.y && layers[current_layer_index][0].get_pixelv(north) == target_color:
					q.append(north)
				if south.y < location.y + size.y && layers[current_layer_index][0].get_pixelv(south) == target_color:
					q.append(south)

func _on_Timer_timeout() -> void:
	Global.can_draw = true