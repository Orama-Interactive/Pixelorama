extends Polygon2D

var img : Image
var tex : ImageTexture
var is_dragging := false
var move_pixels := false
var diff_x := 0.0
var diff_y := 0.0
var orig_x := 0.0
var orig_y := 0.0
var orig_colors := []

func _ready() -> void:
	img = Image.new()
	#img.create(Global.canvas.size.x, Global.canvas.size.y, false, Image.FORMAT_RGBA8)
	img.create(1, 1, false, Image.FORMAT_RGBA8)
	img.lock()
	tex = ImageTexture.new()
	tex.create_from_image(img, 0)

# warning-ignore:unused_argument
func _process(delta) -> void:
	var mouse_pos := get_local_mouse_position() - Global.canvas.location
	var mouse_pos_floored := mouse_pos.floor()
	var start_pos := polygon[0]
	var end_pos := polygon[2]
	var layer : Image = Global.canvas.layers[Global.canvas.current_layer_index][0]
	
	if point_in_rectangle(mouse_pos, polygon[0], polygon[2]) && Global.selected_pixels.size() > 0 && (Global.current_left_tool == "RectSelect" || Global.current_right_tool == "RectSelect"):
		get_parent().get_parent().mouse_default_cursor_shape = Input.CURSOR_MOVE
		if (Global.current_left_tool == "RectSelect" && Input.is_action_just_pressed("left_mouse")) || (Global.current_right_tool == "RectSelect" && Input.is_action_just_pressed("right_mouse")):
			#Begin dragging
			is_dragging = true
			if Input.is_key_pressed(KEY_SHIFT):
				move_pixels = true
			else:
				move_pixels = false
				img.fill(Color(0, 0, 0, 0))
			diff_x = end_pos.x - mouse_pos_floored.x
			diff_y = end_pos.y - mouse_pos_floored.y
			orig_x = start_pos.x - mouse_pos_floored.x
			orig_y = start_pos.y - mouse_pos_floored.y
			if move_pixels:
				img.resize(polygon[2].x - polygon[0].x, polygon[2].y - polygon[0].y, 0)
				img.lock()
				for i in range(Global.selected_pixels.size()):
					orig_colors.append(layer.get_pixelv(Global.selected_pixels[i]))
					var px = Global.selected_pixels[i] - Global.selected_pixels[0]
					img.set_pixelv(px, orig_colors[i])
					layer.set_pixelv(Global.selected_pixels[i], Color(0, 0, 0, 0))
					#print(layer.get_pixelv(Global.selected_pixels[i]))
				Global.canvas.update_texture(Global.canvas.current_layer_index)
			tex.create_from_image(img, 0)
			update()
	else:
		get_parent().get_parent().mouse_default_cursor_shape = Input.CURSOR_CROSS
		
	if is_dragging:
		if (Global.current_left_tool == "RectSelect" && Input.is_action_pressed("left_mouse")) || (Global.current_right_tool == "RectSelect" && Input.is_action_pressed("right_mouse")):
			#Drag
			if orig_x + mouse_pos_floored.x >= Global.canvas.location.x && diff_x + mouse_pos_floored.x <= Global.canvas.size.x:
				start_pos.x = orig_x + mouse_pos_floored.x
				end_pos.x = diff_x + mouse_pos_floored.x
			
			if orig_y + mouse_pos_floored.y >= Global.canvas.location.y && diff_y + mouse_pos_floored.y <= Global.canvas.size.y:
				start_pos.y = orig_y + mouse_pos_floored.y
				end_pos.y = diff_y + mouse_pos_floored.y
			polygon[0] = start_pos
			polygon[1] = Vector2(end_pos.x, start_pos.y)
			polygon[2] = end_pos
			polygon[3] = Vector2(start_pos.x, end_pos.y)
		
		if (Global.current_left_tool == "RectSelect" && Input.is_action_just_released("left_mouse")) || (Global.current_right_tool == "RectSelect" && Input.is_action_just_released("right_mouse")):
			#Release Drag
			is_dragging = false
			if move_pixels:
				for i in range(Global.selected_pixels.size()):
					if orig_colors[i].a > 0:
						var px = polygon[0] + Global.selected_pixels[i] - Global.selected_pixels[0]
						layer.set_pixelv(px, orig_colors[i])
				Global.canvas.update_texture(Global.canvas.current_layer_index)
			
			orig_colors.clear()
			Global.selected_pixels.clear()
			for xx in range(start_pos.x, end_pos.x):
				for yy in range(start_pos.y, end_pos.y):
					Global.selected_pixels.append(Vector2(xx, yy))	
	
	#Handle copy
	if Input.is_action_just_pressed("copy") && Global.selected_pixels.size() > 0:
		Global.image_clipboard = layer.get_rect(Rect2(polygon[0], polygon[2]))
		print(Rect2(polygon[0], polygon[2]), Global.image_clipboard.get_size())
		print(Global.image_clipboard.get_data()[0])
	
	#Handle paste
	if Input.is_action_just_pressed("paste") && Global.selected_pixels.size() > 0 && !is_dragging:
		layer.blend_rect(Global.image_clipboard, Rect2(Vector2.ZERO, polygon[2]-polygon[0]), polygon[0])
		layer.lock()
		Global.canvas.update_texture(Global.canvas.current_layer_index)

func _draw() -> void:
	if img.get_size() == polygon[2] - polygon[0]:
		draw_texture(tex, polygon[0], Color(1, 1, 1, 0.5))

func point_in_rectangle(p : Vector2, coord1 : Vector2, coord2 : Vector2) -> bool:
	return p.x > coord1.x && p.y > coord1.y && p.x < coord2.x && p.y < coord2.y
	