class_name Canvas
extends Node2D

const CURSOR_SPEED_RATE := 6.0

var current_pixel := Vector2.ZERO
var sprite_changed_this_frame := false  ## For optimization purposes
var update_all_layers := false
var project_changed := false
var move_preview_location := Vector2i.ZERO
var layer_texture_array := Texture2DArray.new()
var layer_metadata_image := Image.new()
var layer_metadata_texture := ImageTexture.new()

@onready var currently_visible_frame := $CurrentlyVisibleFrame as SubViewport
@onready var current_frame_drawer := $CurrentlyVisibleFrame/CurrentFrameDrawer as Node2D
@onready var tile_mode := $TileMode as Node2D
@onready var color_index := $ColorIndex as Node2D
@onready var pixel_grid := $PixelGrid as Node2D
@onready var grid := $Grid as Node2D
@onready var selection := $Selection as SelectionNode
@onready var onion_past := $OnionPast as Node2D
@onready var onion_future := $OnionFuture as Node2D
@onready var crop_rect := $CropRect as CropRect
@onready var indicators := $Indicators as Node2D
@onready var previews := $Previews as Node2D
@onready var previews_sprite := $PreviewsSprite as Sprite2D
@onready var mouse_guide_container := $MouseGuideContainer as Node2D
@onready var gizmos_3d := $Gizmos3D as Node2D
@onready var measurements := $Measurements as Node2D
@onready var reference_image_container := $ReferenceImages as Node2D


func _ready() -> void:
	material.set_shader_parameter("layers", layer_texture_array)
	material.set_shader_parameter("metadata", layer_metadata_texture)
	Global.project_switched.connect(
		func():
			project_changed = true
			queue_redraw()
	)
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
	draw_layers(project_changed)
	project_changed = false
	if Global.onion_skinning:
		refresh_onion()
	currently_visible_frame.size = Global.current_project.size
	current_frame_drawer.queue_redraw()
	tile_mode.queue_redraw()
	draw_set_transform(position, rotation, scale)
	color_index.queue_redraw()


func _input(event: InputEvent) -> void:
	# Move the cursor with the keyboard (numpad keys by default)
	var mouse_movement := Input.get_vector(
		&"move_mouse_left", &"move_mouse_right", &"move_mouse_up", &"move_mouse_down"
	)
	# Don't process anything below if the input isn't a mouse event, a tool activation shortcut,
	# or the numpad keys that move the cursor.
	# This decreases CPU/GPU usage slightly.
	if not event is InputEventMouseMotion:
		if (
			mouse_movement == Vector2.ZERO
			and not (
				event.is_action(&"activate_left_tool") or event.is_action(&"activate_right_tool")
			)
		):
			return
	# Get the viewport's mouse position instead of the local mouse position to use warp_mouse
	var tmp_position := get_viewport().get_mouse_position()
	if mouse_movement != Vector2.ZERO:
		tmp_position += mouse_movement * CURSOR_SPEED_RATE
		get_viewport().warp_mouse(tmp_position)
	var tmp_transform := get_canvas_transform().affine_inverse()
	current_pixel = tmp_transform.basis_xform(tmp_position) + tmp_transform.origin

	sprite_changed_this_frame = false
	Tools.handle_draw(Vector2i(current_pixel.floor()), event)

	if sprite_changed_this_frame:
		queue_redraw()
		update_selected_cels_textures()


func camera_zoom() -> void:
	for camera: CanvasCamera in get_tree().get_nodes_in_group("CanvasCameras"):
		camera.fit_to_frame(Global.current_project.size)

	Global.transparent_checker.update_rect()


func update_texture(
	layer_i: int, frame_i := -1, project := Global.current_project, undo := false
) -> void:
	if frame_i == -1:
		frame_i = project.current_frame

	if frame_i < project.frames.size() and layer_i < project.layers.size():
		var current_cel := project.frames[frame_i].cels[layer_i]
		current_cel.update_texture(undo)
		# Needed so that changes happening to the non-selected layer(s) are also visible
		# e.g. when undoing/redoing, when applying image effects to the entire frame, etc
		if frame_i != project.current_frame:
			# Don't update if the cel is on a different frame (can happen with undo/redo)
			return
		var layer := project.layers[layer_i].get_blender_ancestor()
		var cel_image: Image
		if layer.is_blender():
			cel_image = layer.blend_children(
				project.frames[project.current_frame], Vector2i.ZERO, Global.display_layer_effects
			)
		else:
			if Global.display_layer_effects:
				cel_image = layer.display_effects(current_cel)
			else:
				cel_image = current_cel.get_image()
		if (
			cel_image.get_size()
			== Vector2i(layer_texture_array.get_width(), layer_texture_array.get_height())
		):
			layer_texture_array.update_layer(cel_image, project.ordered_layers[layer.index])


func update_selected_cels_textures(project := Global.current_project) -> void:
	for cel_index in project.selected_cels:
		var frame_index: int = cel_index[0]
		var layer_index: int = cel_index[1]
		if frame_index < project.frames.size() and layer_index < project.layers.size():
			var current_cel := project.frames[frame_index].cels[layer_index]
			current_cel.update_texture()


func draw_layers(force_recreate := false) -> void:
	var project := Global.current_project
	var recreate_texture_array := (
		layer_texture_array.get_layers() != project.layers.size()
		or layer_texture_array.get_width() != project.size.x
		or layer_texture_array.get_height() != project.size.y
		or force_recreate
	)
	if recreate_texture_array:
		var textures: Array[Image] = []
		textures.resize(project.layers.size())
		# Nx4 texture, where N is the number of layers and the first row are the blend modes,
		# the second are the opacities, the third are the origins and the fourth are the
		# clipping mask booleans.
		layer_metadata_image = Image.create(project.layers.size(), 4, false, Image.FORMAT_RGF)
		# Draw current frame layers
		for i in project.layers.size():
			var layer := project.layers[i]
			var ordered_index := project.ordered_layers[layer.index]
			var cel_image := Image.new()
			_update_texture_array_layer(project, layer, cel_image, false)
			textures[ordered_index] = cel_image
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
				var layer := project.layers[i]
				var ordered_index := project.ordered_layers[layer.index]
				var cel_image := Image.new()
				_update_texture_array_layer(project, layer, cel_image, true)
				var parent_layer := layer.get_blender_ancestor()
				if layer != parent_layer:
					# True when the layer has parents. In that case, update its top-most parent.
					_update_texture_array_layer(project, parent_layer, Image.new(), true)
				# Update the origin
				var origin := Vector2(move_preview_location).abs() / Vector2(cel_image.get_size())
				layer_metadata_image.set_pixel(
					ordered_index, 2, Color(origin.x, origin.y, 0.0, 0.0)
				)
			layer_metadata_texture.update(layer_metadata_image)

	material.set_shader_parameter("origin_x_positive", move_preview_location.x > 0)
	material.set_shader_parameter("origin_y_positive", move_preview_location.y > 0)
	update_all_layers = false


func _update_texture_array_layer(
	project: Project, layer: BaseLayer, cel_image: Image, update_layer: bool
) -> void:
	var ordered_index := project.ordered_layers[layer.index]
	var cel := project.frames[project.current_frame].cels[layer.index]
	var include := true
	if layer.is_blender():
		cel_image.copy_from(
			layer.blend_children(
				project.frames[project.current_frame],
				move_preview_location,
				Global.display_layer_effects
			)
		)
	else:
		if Global.display_layer_effects:
			cel_image.copy_from(layer.display_effects(cel))
		else:
			cel_image.copy_from(cel.get_image())
	if layer.is_blended_by_ancestor():
		include = false
	if update_layer:
		layer_texture_array.update_layer(cel_image, ordered_index)
	DrawingAlgos.set_layer_metadata_image(layer, cel, layer_metadata_image, ordered_index, include)


func refresh_onion() -> void:
	onion_past.queue_redraw()
	onion_future.queue_redraw()
