class_name Canvas
extends Node2D

const MOVE_ACTIONS := ["move_mouse_left", "move_mouse_right", "move_mouse_up", "move_mouse_down"]
const CURSOR_SPEED_RATE := 6.0

var current_pixel := Vector2.ZERO
var sprite_changed_this_frame := false  ## For optimization purposes
var update_all_layers := false
var move_preview_location := Vector2i.ZERO
var layer_texture_array := Texture2DArray.new()
var layer_metadata_image := Image.new()
var layer_metadata_texture := ImageTexture.new()

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
@onready var measurements := $Measurements as Node2D
@onready var reference_image_container := $ReferenceImages as Node2D


func _ready() -> void:
	material.set_shader_parameter("layers", layer_texture_array)
	material.set_shader_parameter("metadata", layer_metadata_texture)
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
		# Needed so that changes happening to the non-selected layer(s) are also visible
		# e.g. when undoing/redoing, when applying image effects to the entire frame, etc
		if frame_i != project.current_frame:
			# Don't update if the cel is on a different frame (can happen with undo/redo)
			return
		var layer := project.layers[layer_i]
		var cel_image: Image
		if Global.display_layer_effects:
			cel_image = layer.display_effects(current_cel)
		else:
			cel_image = current_cel.get_image()
		if (
			cel_image.get_size()
			== Vector2i(layer_texture_array.get_width(), layer_texture_array.get_height())
		):
			layer_texture_array.update_layer(cel_image, project.ordered_layers[layer_i])


func update_selected_cels_textures(project := Global.current_project) -> void:
	for cel_index in project.selected_cels:
		var frame_index: int = cel_index[0]
		var layer_index: int = cel_index[1]
		if frame_index < project.frames.size() and layer_index < project.layers.size():
			var current_cel := project.frames[frame_index].cels[layer_index]
			current_cel.update_texture()


func draw_layers() -> void:
	var project := Global.current_project
	var current_cels := project.frames[project.current_frame].cels
	var recreate_texture_array := (
		layer_texture_array.get_layers() != project.layers.size()
		or layer_texture_array.get_width() != project.size.x
		or layer_texture_array.get_height() != project.size.y
	)
	if recreate_texture_array:
		var textures: Array[Image] = []
		textures.resize(project.layers.size())
		# Nx3 texture, where N is the number of layers and the first row are the blend modes,
		# the second are the opacities and the third are the origins
		layer_metadata_image = Image.create(project.layers.size(), 3, false, Image.FORMAT_RG8)
		# Draw current frame layers
		for i in project.layers.size():
			var ordered_index := project.ordered_layers[i]
			var layer := project.layers[i]
			var cel := current_cels[i]
			var cel_image: Image
			if Global.display_layer_effects:
				cel_image = layer.display_effects(cel)
			else:
				cel_image = cel.get_image()
			textures[ordered_index] = cel_image
			# Store the blend mode
			layer_metadata_image.set_pixel(
				ordered_index, 0, Color(layer.blend_mode / 255.0, 0.0, 0.0, 0.0)
			)
			# Store the opacity
			if layer.is_visible_in_hierarchy():
				var opacity := cel.get_final_opacity(layer)
				layer_metadata_image.set_pixel(ordered_index, 1, Color(opacity, 0.0, 0.0, 0.0))
			else:
				layer_metadata_image.set_pixel(ordered_index, 1, Color())
			# Store the origin
			if [project.current_frame, i] in project.selected_cels:
				var origin := Vector2(move_preview_location).abs() / Vector2(cel_image.get_size())
				layer_metadata_image.set_pixel(
					ordered_index, 2, Color(origin.x, origin.y, 0.0, 0.0)
				)
			else:
				layer_metadata_image.set_pixel(ordered_index, 2, Color())

		layer_texture_array.create_from_images(textures)
		layer_metadata_texture.set_image(layer_metadata_image)
	else:  # Update the TextureArray
		if layer_texture_array.get_layers() > 0:
			for i in project.layers.size():
				if not update_all_layers:
					var test_array := [project.current_frame, i]
					if not test_array in project.selected_cels:
						continue
				var ordered_index := project.ordered_layers[i]
				var layer := project.layers[i]
				var cel := current_cels[i]
				var cel_image: Image
				if Global.display_layer_effects:
					cel_image = layer.display_effects(cel)
				else:
					cel_image = cel.get_image()
				layer_texture_array.update_layer(cel_image, ordered_index)
				layer_metadata_image.set_pixel(
					ordered_index, 0, Color(layer.blend_mode / 255.0, 0.0, 0.0, 0.0)
				)
				if layer.is_visible_in_hierarchy():
					var opacity := cel.get_final_opacity(layer)
					layer_metadata_image.set_pixel(ordered_index, 1, Color(opacity, 0.0, 0.0, 0.0))
				else:
					layer_metadata_image.set_pixel(ordered_index, 1, Color())
				var origin := Vector2(move_preview_location).abs() / Vector2(cel_image.get_size())
				layer_metadata_image.set_pixel(
					ordered_index, 2, Color(origin.x, origin.y, 0.0, 0.0)
				)
			layer_metadata_texture.update(layer_metadata_image)

	material.set_shader_parameter("origin_x_positive", move_preview_location.x > 0)
	material.set_shader_parameter("origin_y_positive", move_preview_location.y > 0)
	update_all_layers = false


func refresh_onion() -> void:
	onion_past.queue_redraw()
	onion_future.queue_redraw()
