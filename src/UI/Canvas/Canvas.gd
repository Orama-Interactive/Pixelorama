class_name Canvas
extends Node2D


var fill_color := Color(0, 0, 0, 0)
var current_pixel := Vector2.ZERO
var can_undo := true
var cursor_image_has_changed := false
var sprite_changed_this_frame := false # for optimization purposes
var move_preview_location := Vector2.ZERO

onready var currently_visible_frame : Viewport = $CurrentlyVisibleFrame
onready var current_frame_drawer = $CurrentlyVisibleFrame/CurrentFrameDrawer
onready var tile_mode = $TileMode
onready var pixel_grid = $PixelGrid
onready var grid = $Grid
onready var selection = $Selection
onready var indicators = $Indicators
onready var previews = $Previews


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var frame : Frame = new_empty_frame(true)
	Global.current_project.frames.append(frame)
	yield(get_tree().create_timer(0.2), "timeout")
	camera_zoom()


func _draw() -> void:
	Global.second_viewport.get_child(0).get_node("CanvasPreview").update()
	Global.small_preview_viewport.get_child(0).get_node("CanvasPreview").update()

	var current_cels : Array = Global.current_project.frames[Global.current_project.current_frame].cels
	var current_layer : int = Global.current_project.current_layer
	var _position := position
	var _scale := scale
	if Global.mirror_view:
		_position.x = _position.x + Global.current_project.size.x
		_scale.x = -1
	draw_set_transform(_position, rotation, _scale)
	# Draw current frame layers
	for i in range(Global.current_project.layers.size()):
		var modulate_color := Color(1, 1, 1, current_cels[i].opacity)
		if Global.current_project.layers[i].visible: # if it's visible
			if i == current_layer:
				draw_texture(current_cels[i].image_texture, move_preview_location, modulate_color)
			else:
				draw_texture(current_cels[i].image_texture, Vector2.ZERO, modulate_color)

	if Global.onion_skinning:
		onion_skinning()
	currently_visible_frame.size = Global.current_project.size
	current_frame_drawer.update()
	tile_mode.update()
	draw_set_transform(position, rotation, scale)


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

	# Do not use self.get_local_mouse_position() because it return unexpected
	# value when shrink parameter is not equal to one. At godot version 3.2.3
	var tmp_transform = get_canvas_transform().affine_inverse()
	var tmp_position = Global.main_viewport.get_local_mouse_position()
	current_pixel = tmp_transform.basis_xform(tmp_position) + tmp_transform.origin

	if Global.has_focus:
		update()

	sprite_changed_this_frame = false

	var current_project : Project = Global.current_project

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

		if camera == Global.camera_preview:
			Global.preview_zoom_slider.max_value = -camera.zoom_min.x
			Global.preview_zoom_slider.min_value = -camera.zoom_max.x

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


func handle_undo(action : String, project : Project = Global.current_project, layer_index := -2, frame_index := -2) -> void:
	if !can_undo:
		return

	if layer_index <= -2:
		layer_index = project.current_layer
	if frame_index <= -2:
		frame_index = project.current_frame

	var cels := []
	var frames := []
	var layers := []
	if frame_index == -1:
		frames = project.frames
	else:
		frames.append(project.frames[frame_index])

	if layer_index == -1:
		layers = project.layers
	else:
		layers.append(project.layers[layer_index])

	for f in frames:
		for l in layers:
			var index = project.layers.find(l)
			cels.append(f.cels[index])

	project.undos += 1
	project.undo_redo.create_action(action)
	for cel in cels:
		# If we don't unlock the image, it doesn't work properly
		cel.image.unlock()
		var data = cel.image.data
		cel.image.lock()
		project.undo_redo.add_undo_property(cel.image, "data", data)
	project.undo_redo.add_undo_method(Global, "undo", frame_index, layer_index, project)

	can_undo = false


func handle_redo(_action : String, project : Project = Global.current_project, layer_index := -2, frame_index := -2) -> void:
	can_undo = true
	if project.undos < project.undo_redo.get_version():
		return

	if layer_index <= -2:
		layer_index = project.current_layer
	if frame_index <= -2:
		frame_index = project.current_frame

	var cels := []
	var frames := []
	var layers := []
	if frame_index == -1:
		frames = project.frames
	else:
		frames.append(project.frames[frame_index])

	if layer_index == -1:
		layers = project.layers
	else:
		layers.append(project.layers[layer_index])

	for f in frames:
		for l in layers:
			var index = project.layers.find(l)
			cels.append(f.cels[index])

	for cel in cels:
		project.undo_redo.add_do_property(cel.image, "data", cel.image.data)
	project.undo_redo.add_do_method(Global, "redo", frame_index, layer_index, project)
	project.undo_redo.commit_action()


func update_texture(layer_index : int, frame_index := -1, project : Project = Global.current_project) -> void:
	if frame_index == -1:
		frame_index = project.current_frame

	if frame_index < project.frames.size() and layer_index < project.layers.size():
		var current_cel : Cel = project.frames[frame_index].cels[layer_index]
		current_cel.image_texture.create_from_image(current_cel.image, 0)

		if project == Global.current_project:
			var frame_texture_rect : TextureRect
			frame_texture_rect = Global.find_node_by_name(project.layers[layer_index].frame_container.get_child(frame_index), "CelTexture")
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
						draw_texture(layer.image_texture, Vector2.ZERO, color)
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
						draw_texture(layer.image_texture, Vector2.ZERO, color)
					layer_i += 1
