class_name Canvas
extends Node2D

const MOVE_ACTIONS := ["move_mouse_left", "move_mouse_right", "move_mouse_up", "move_mouse_down"]
const CURSOR_SPEED_RATE := 6.0

var current_pixel := Vector2.ZERO
var sprite_changed_this_frame := false  # For optimization purposes
var move_preview_location := Vector2.ZERO

onready var currently_visible_frame: Viewport = $CurrentlyVisibleFrame
onready var current_frame_drawer = $CurrentlyVisibleFrame/CurrentFrameDrawer
onready var tile_mode = $TileMode
onready var pixel_grid = $PixelGrid
onready var grid = $Grid
onready var selection = $Selection
onready var crop_rect: CropRect = $CropRect
onready var indicators = $Indicators
onready var previews = $Previews
onready var mouse_guide_container = $MouseGuideContainer


func _ready() -> void:
	$OnionPast.type = $OnionPast.PAST
	$OnionPast.blue_red_color = Color.blue
	$OnionFuture.type = $OnionFuture.FUTURE
	$OnionFuture.blue_red_color = Color.red
	yield(get_tree(), "idle_frame")
	camera_zoom()


func _draw() -> void:
	Global.second_viewport.get_child(0).get_node("CanvasPreview").update()
	Global.small_preview_viewport.get_child(0).get_node("CanvasPreview").update()

	var current_cels: Array = Global.current_project.frames[Global.current_project.current_frame].cels
	var position_tmp := position
	var scale_tmp := scale
	if Global.mirror_view:
		position_tmp.x = position_tmp.x + Global.current_project.size.x
		scale_tmp.x = -1
	draw_set_transform(position_tmp, rotation, scale_tmp)
	# Draw current frame layers
	for i in range(Global.current_project.layers.size()):
		if current_cels[i] is GroupCel:
			continue
		var modulate_color := Color(1, 1, 1, current_cels[i].opacity)
		if Global.current_project.layers[i].is_visible_in_hierarchy():
			var selected_layers = []
			if move_preview_location != Vector2.ZERO:
				for cel_pos in Global.current_project.selected_cels:
					if cel_pos[0] == Global.current_project.current_frame:
						if Global.current_project.layers[cel_pos[1]].can_layer_get_drawn():
							selected_layers.append(cel_pos[1])
			if i in selected_layers:
				draw_texture(current_cels[i].image_texture, move_preview_location, modulate_color)
			else:
				draw_texture(current_cels[i].image_texture, Vector2.ZERO, modulate_color)

	if Global.onion_skinning:
		refresh_onion()
	currently_visible_frame.size = Global.current_project.size
	current_frame_drawer.update()
	if Global.current_project.tiles.mode != Tiles.MODE.NONE:
		tile_mode.update()
	draw_set_transform(position, rotation, scale)


func _input(event: InputEvent) -> void:
	# Don't process anything below if the input isn't a mouse event, or Shift/Ctrl.
	# This decreases CPU/GPU usage slightly.
	var get_velocity := false
	if not event is InputEventMouseMotion:
		for action in MOVE_ACTIONS:
			if event.is_action(action):
				get_velocity = true
		if (
			!get_velocity
			and !(event.is_action("activate_left_tool") or event.is_action("activate_right_tool"))
		):
			return

	var tmp_position: Vector2 = Global.main_viewport.get_local_mouse_position()
	if get_velocity:
		var velocity := Input.get_vector(
			"move_mouse_left", "move_mouse_right", "move_mouse_up", "move_mouse_down"
		)
		if velocity != Vector2.ZERO:
			tmp_position += velocity * CURSOR_SPEED_RATE
			Global.main_viewport.warp_mouse(tmp_position)
	# Do not use self.get_local_mouse_position() because it return unexpected
	# value when shrink parameter is not equal to one. At godot version 3.2.3
	var tmp_transform = get_canvas_transform().affine_inverse()
	current_pixel = tmp_transform.basis_xform(tmp_position) + tmp_transform.origin

	if Global.has_focus:
		update()

	sprite_changed_this_frame = false

	Tools.handle_draw(current_pixel.floor(), event)

	if sprite_changed_this_frame:
		update_selected_cels_textures()


func camera_zoom() -> void:
	# Set camera zoom based on the sprite size
	var bigger_canvas_axis = max(Global.current_project.size.x, Global.current_project.size.y)
	var zoom_max := Vector2(bigger_canvas_axis, bigger_canvas_axis) * 0.01

	for camera in Global.cameras:
		if zoom_max > Vector2.ONE:
			camera.zoom_max = zoom_max
		else:
			camera.zoom_max = Vector2.ONE

		if camera == Global.camera_preview:
			Global.preview_zoom_slider.max_value = -camera.zoom_min.x
			Global.preview_zoom_slider.min_value = -camera.zoom_max.x

		camera.fit_to_frame(Global.current_project.size)
		camera.save_values_to_project()

	Global.transparent_checker.update_rect()


func update_texture(layer_i: int, frame_i := -1, project: Project = Global.current_project) -> void:
	if frame_i == -1:
		frame_i = project.current_frame

	if frame_i < project.frames.size() and layer_i < project.layers.size():
		var current_cel: BaseCel = project.frames[frame_i].cels[layer_i]
		current_cel.update_texture()


func update_selected_cels_textures(project: Project = Global.current_project) -> void:
	for cel_index in project.selected_cels:
		var frame_index: int = cel_index[0]
		var layer_index: int = cel_index[1]
		if frame_index < project.frames.size() and layer_index < project.layers.size():
			var current_cel: BaseCel = project.frames[frame_index].cels[layer_index]
			current_cel.update_texture()


func refresh_onion() -> void:
	$OnionPast.update()
	$OnionFuture.update()
