class_name Canvas
extends Node2D

const MOVE_ACTIONS := ["move_mouse_left", "move_mouse_right", "move_mouse_up", "move_mouse_down"]
const CURSOR_SPEED_RATE := 6.0

var current_pixel := Vector2.ZERO
var sprite_changed_this_frame := false  ## For optimization purposes
var move_preview_location := Vector2i.ZERO

@onready var currently_visible_frame := $CurrentlyVisibleFrame as SubViewport
@onready var current_frame_drawer := $CurrentlyVisibleFrame/CurrentFrameDrawer as Node2D
@onready var tile_mode := $TileMode as Node2D
@onready var pixel_grid := $PixelGrid as Node2D
@onready var grid := $Grid as Node2D
@onready var selection := $Selection as Node2D
@onready var onion_past := $OnionPast as Node2D
@onready var onion_future := $OnionFuture as Node2D
@onready var crop_rect := $CropRect as CropRect
@onready var indicators := $Indicators as Node2D
@onready var previews := $Previews as Node2D
@onready var mouse_guide_container := $MouseGuideContainer as Node2D
@onready var gizmos_3d := $Gizmos3D as Node2D


func _ready() -> void:
	Global.project_changed.connect(queue_redraw)
	onion_past.type = onion_past.PAST
	onion_past.blue_red_color = Global.onion_skinning_past_color
	onion_future.type = onion_future.FUTURE
	onion_future.blue_red_color = Global.onion_skinning_future_color
	await get_tree().process_frame
	camera_zoom()


func _draw() -> void:
	var position_tmp := position
	var scale_tmp := scale
	if Global.mirror_view:
		position_tmp.x = position_tmp.x + Global.current_project.size.x
		scale_tmp.x = -1
	# If we just use the first cel and it happens to be a GroupCel
	# nothing will get drawn
	var cel_to_draw := Global.current_project.find_first_drawable_cel()
	draw_set_transform(position_tmp, rotation, scale_tmp)
	# Placeholder so we can have a material here
	if is_instance_valid(cel_to_draw):
		draw_texture(cel_to_draw.image_texture, Vector2.ZERO)
	draw_layers()
	if Global.onion_skinning:
		refresh_onion()
	currently_visible_frame.size = Global.current_project.size
	current_frame_drawer.queue_redraw()
	if Global.current_project.tiles.mode != Tiles.MODE.NONE:
		tile_mode.queue_redraw()
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

	var tmp_position := Global.main_viewport.get_local_mouse_position()
	if get_velocity:
		var velocity := Input.get_vector(
			"move_mouse_left", "move_mouse_right", "move_mouse_up", "move_mouse_down"
		)
		if velocity != Vector2.ZERO:
			tmp_position += velocity * CURSOR_SPEED_RATE
			Global.main_viewport.warp_mouse(tmp_position)
	# Do not use self.get_local_mouse_position() because it return unexpected
	# value when shrink parameter is not equal to one. At godot version 3.2.3
	var tmp_transform := get_canvas_transform().affine_inverse()
	current_pixel = tmp_transform.basis_xform(tmp_position) + tmp_transform.origin

	sprite_changed_this_frame = false
	Tools.handle_draw(Vector2i(current_pixel.floor()), event)

	if sprite_changed_this_frame:
		if Global.has_focus:
			queue_redraw()
		update_selected_cels_textures()


func camera_zoom() -> void:
	for camera in Global.cameras:
		camera.fit_to_frame(Global.current_project.size)
		camera.save_values_to_project()

	Global.transparent_checker.update_rect()


func update_texture(layer_i: int, frame_i := -1, project := Global.current_project) -> void:
	if frame_i == -1:
		frame_i = project.current_frame

	if frame_i < project.frames.size() and layer_i < project.layers.size():
		var current_cel := project.frames[frame_i].cels[layer_i]
		current_cel.update_texture()


func update_selected_cels_textures(project := Global.current_project) -> void:
	for cel_index in project.selected_cels:
		var frame_index: int = cel_index[0]
		var layer_index: int = cel_index[1]
		if frame_index < project.frames.size() and layer_index < project.layers.size():
			var current_cel := project.frames[frame_index].cels[layer_index]
			current_cel.update_texture()


func draw_layers() -> void:
	var current_frame := Global.current_project.frames[Global.current_project.current_frame]
	var current_cels := current_frame.cels
	var textures: Array[Image] = []
	var opacities := PackedFloat32Array()
	var blend_modes := PackedInt32Array()
	var origins := PackedVector2Array()
	# Draw current frame layers
	for i in Global.current_project.layers.size():
		if current_cels[i] is GroupCel:
			continue
		var layer := Global.current_project.layers[i]
		if layer.is_visible_in_hierarchy():
			var cel_image: Image
			if Global.display_layer_effects:
				cel_image = layer.display_effects(current_cels[i])
			else:
				cel_image = current_cels[i].get_image()
			textures.append(cel_image)
			opacities.append(current_cels[i].opacity)
			if [Global.current_project.current_frame, i] in Global.current_project.selected_cels:
				origins.append(Vector2(move_preview_location) / Vector2(cel_image.get_size()))
			else:
				origins.append(Vector2.ZERO)
			blend_modes.append(layer.blend_mode)
	var texture_array := Texture2DArray.new()
	texture_array.create_from_images(textures)
	material.set_shader_parameter("layers", texture_array)
	material.set_shader_parameter("opacities", opacities)
	material.set_shader_parameter("blend_modes", blend_modes)
	material.set_shader_parameter("origins", origins)


func refresh_onion() -> void:
	onion_past.queue_redraw()
	onion_future.queue_redraw()
