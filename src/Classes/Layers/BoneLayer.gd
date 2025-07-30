class_name BoneLayer
extends GroupLayer

enum {NONE, DISPLACE, ROTATE, SCALE}  ## I planned to add scaling too but decided to give up
const InteractionDistance = 20
const DESELECT_WIDTH: float = 1

var enabled := true
var ignore_rotation_hover := false
var modify_mode := NONE
var generation_cache: Dictionary
var render_array: Array[ImageExtended]


func _init(_project: Project, _name := "") -> void:
	project = _project
	name = _name
	blend_mode = BlendModes.NORMAL


## Returns a new empty [BaseCel]
func new_empty_cel() -> BaseCel:
	return BoneCel.new()


func get_parent_bone():
	var bone_parent = parent
	while bone_parent != null:
		if bone_parent is BoneLayer:
			break
		bone_parent = bone_parent.parent
	return bone_parent


#func get_best_origin(layer_idx: int) -> Vector2i:
	#var project = Global.current_project
	#if current_frame >= 0 and current_frame < project.frames.size():
		#if layer_idx >= 0 and layer_idx < project.layers.size():
			#if project.layers[layer_idx].get_layer_type() == 1:
				#var used_rect := Rect2i()
				#for child_layer in project.layers[layer_idx].get_children(false):
					#if project.frames[current_frame].cels[child_layer.index].get_class_name() == "PixelCel":
						#var cel_rect = (
								#project.frames[current_frame].cels[child_layer.index].get_image()
							#).get_used_rect()
						#if cel_rect.has_area():
							#used_rect = used_rect.merge(cel_rect) if used_rect.has_area() else cel_rect
				#return used_rect.position + (used_rect.size / 2)
	#return Vector2i.ZERO\

func get_current_bone_cel() -> BoneCel:
	return Global.current_project.frames[Global.current_project.current_frame].cels[index]


## Calculates hover mode of current BoneLayer
func hover_mode(mouse_position: Vector2, camera_zoom) -> int:
	var bone_cel := get_current_bone_cel()
	var local_mouse_pos = rel_to_origin(mouse_position)
	if (bone_cel.start_point).distance_to(local_mouse_pos) <= InteractionDistance / camera_zoom.x:
		return DISPLACE
	elif (
		(bone_cel.start_point + bone_cel.end_point).distance_to(local_mouse_pos)
		<= InteractionDistance / camera_zoom.x
	):
		if !ignore_rotation_hover:
			return SCALE
	elif _is_close_to_segment(
		rel_to_start_point(mouse_position),
		InteractionDistance / camera_zoom.x,
		Vector2.ZERO, bone_cel.end_point
	):
		if !ignore_rotation_hover:
			return ROTATE
	return NONE


## Converts to position relative to it's gizmo origin in current frame
func rel_to_origin(pos: Vector2) -> Vector2:
	var bone_cel := get_current_bone_cel()
	return pos - bone_cel.gizmo_origin

## Converts to position relative to it's start point in current frame
func rel_to_start_point(pos: Vector2) -> Vector2:
	var bone_cel := get_current_bone_cel()
	return pos - bone_cel.gizmo_origin - bone_cel.start_point

## Converts to position relative to canvas
func rel_to_global(pos: Vector2) -> Vector2:
	var bone_cel := get_current_bone_cel()
	return pos + bone_cel.gizmo_origin

#func reset_bone(overrides := {}) -> Dictionary:
	#var reset_data = generate_empty_data(bone_name, parent_bone_name)
	#var connection_array := update_property.get_connections()
	#for connection: Dictionary in connection_array:
		#update_property.disconnect(connection["callable"])
	#for key in reset_data.keys():
		#if key in overrides.keys():
			#set(key, overrides[key])
			#reset_data[key] = overrides[key]
		#else:
			#set(key, reset_data[key])
	#for connection: Dictionary in connection_array:
		#update_property.connect(connection["callable"])
	#return reset_data


static func _is_close_to_segment(
	pos: Vector2, detect_distance: float, s1: Vector2, s2: Vector2
) -> bool:
	var test_line := (s2 - s1).rotated(deg_to_rad(90)).normalized()
	var from_a := pos - test_line * detect_distance
	var from_b := pos + test_line * detect_distance
	if Geometry2D.segment_intersects_segment(from_a, from_b, s1, s2):
		return true
	return false

## Overrides

func blend_children(frame: Frame, origin := Vector2i.ZERO, apply_effects := true) -> Image:
	if project.current_layer == index:
		Global.canvas.skeleton.queue_redraw()
	var image: ImageExtended = generate_pose(frame)
	return image


func generate_pose(frame: Frame) -> ImageExtended:
	# Do we even need to generate a pose?
	var project := Global.current_project
	var image = ImageExtended.create_custom(
		project.size.x, project.size.y, false, project.get_image_format(), project.is_indexed()
	)
	if not get_parent_bone() == null:  # We don't want to render to a child
		return image
	if not visible:  # Pose Layer is invisible (So generating is a waste of time)
		return image

	# Start generating
	# (Group visibility is completely ignored while the visibility of other layer types is respected)
	var previous_ordered_layers: Array[int] = project.ordered_layers
	var for_frame = project.frames.find(frame)
	project.order_layers(for_frame)
	var textures: Array[Image] = []
	# Nx4 texture, where N is the number of layers and the first row are the blend modes,
	# the second are the opacities, the third are the origins and the fourth are the
	# clipping mask booleans.
	var metadata_image := Image.create_empty(project.layers.size(), 4, false, Image.FORMAT_R8)
	for i in project.layers.size():
		var ordered_index := project.ordered_layers[i]
		var layer := project.layers[ordered_index]
		var include := true if layer.is_visible_in_hierarchy() else false
		var bone_layer = layer.parent
		# Ignore visibility for group layers
		if bone_layer:
			if bone_layer != self and not self.is_ancestor_of(bone_layer):
				continue
		var cel = frame.cels[ordered_index]
		var cel_image := ImageExtended.create_custom(
			project.size.x, project.size.y, false, project.get_image_format(), project.is_indexed()
		)
		if layer == self or not is_instance_valid(bone_layer):
			_set_layer_metadata_image(layer, cel, metadata_image, ordered_index, false)
			continue

		if layer.is_blender():
			cel_image = layer.blend_children(frame)
		else:
			if include:
				cel_image = layer.display_effects(cel)

		if bone_layer is BoneLayer and is_instance_valid(bone_layer):
			bone_layer.apply_bone(cel_image, frame)


		textures.append(cel_image)
		if (
			layer.is_blended_by_ancestor()
		):
			include = false
		_set_layer_metadata_image(layer, cel, metadata_image, ordered_index, include)

	var texture_array := Texture2DArray.new()
	if textures.is_empty():
		return image
	texture_array.create_from_images(textures)
	var params := {
		"layers": texture_array,
		"metadata": ImageTexture.create_from_image(metadata_image),
	}
	var blended := Image.create_empty(project.size.x, project.size.y, false, image.get_format())
	var gen := ShaderImageEffect.new()
	gen.generate_image(blended, DrawingAlgos.blend_layers_shader, params, project.size)
	image.blend_rect(blended, Rect2i(Vector2.ZERO, project.size), Vector2.ZERO)
	# Re-order the layers again to ensure correct canvas drawing
	project.ordered_layers = previous_ordered_layers
	return image


## modified version of `set_layer_metadata_image` in DrawingAlgos
func _set_layer_metadata_image(
	layer, cel, image, index, include := true
) -> void:
	# Store the blend mode
	image.set_pixel(index, 0, Color(layer.blend_mode / 255.0, 0.0, 0.0, 0.0))
	# Store the opacity
	if layer.is_visible_in_hierarchy():
		var opacity = cel.get_final_opacity(layer)
		image.set_pixel(index, 1, Color(opacity, 0.0, 0.0, 0.0))
	else:
		image.set_pixel(index, 1, Color())
	# Store the clipping mask boolean
	if layer.clipping_mask:
		image.set_pixel(index, 3, Color.RED)
	else:
		image.set_pixel(index, 3, Color.BLACK)
	if not include:
		# Store a small red value as a way to indicate that this layer should be skipped
		# Used for layers such as child layers of a group, so that the group layer itself can
		# successfully be used as a clipping mask with the layer below it.
		image.set_pixel(index, 3, Color(0.2, 0.0, 0.0, 0.0))


func apply_bone(cel_image: ImageExtended, at_frame: Frame) -> Image:
	if not enabled:
		return cel_image
	var bone_cel: BoneCel = at_frame.cels[index]
	var used_region := cel_image.get_used_rect()
	var start_point: Vector2i = bone_cel.start_point
	var gizmo_origin: Vector2i = bone_cel.gizmo_origin.floor()
	var angle: float = bone_cel.bone_rotation
	if angle == 0 and start_point == Vector2i.ZERO:
		return cel_image
	if used_region.size == Vector2i.ZERO:
		return cel_image
	# Imprint on a square for rotation
	# (We are doing this so that the image doesn't get clipped as a result of rotation.)
	var diagonal_length := floori(used_region.size.length())
	if diagonal_length % 2 == 0:
		diagonal_length += 1
	var s_offset: Vector2i = (
		0.5 * (Vector2i(diagonal_length, diagonal_length)
		- used_region.size)
	).floor()
	var square_image = cel_image.get_region(
		Rect2i(used_region.position - s_offset, Vector2i(diagonal_length, diagonal_length))
	)
	# Apply Rotation To this Image
	if angle != 0:
		var transformation_matrix := Transform2D(angle, Vector2.ZERO)
		var rotate_params := {
			"transformation_matrix": transformation_matrix.affine_inverse(),
			"pivot": Vector2(0.5, 0.5),
			"ending_angle": angle,
			"tolerance": 0,
			"preview": false
		}
		# Detects if the rotation is changed for this generation or not
		# (useful if bone is moved arround while having some rotation)
		# NOTE: I tried cacheing entire poses (that remain same) as well. It was faster than this
		# approach but only by a few milliseconds. I don't think straining the memory for only
		# a boost of a few millisec was worth it so i declare this the most optimal approach.
		var cache_key := {"angle": angle, "cel_content": cel_image.get_data()}
		var bone_cache: Dictionary = generation_cache.get_or_add(bone_cel, {})
		if cache_key in bone_cache.keys():
			square_image = bone_cache[cache_key]
		else:
			var gen = ShaderImageEffect.new()
			gen.generate_image(
				square_image,
				DrawingAlgos.nn_shader,
				rotate_params, square_image.get_size()
			)
			bone_cache.clear()
			bone_cache[cache_key] = square_image
	var pivot: Vector2i = gizmo_origin
	var bone_start_global: Vector2i = gizmo_origin + start_point
	var square_image_start: Vector2i = used_region.position - s_offset
	var global_square_centre: Vector2 = square_image_start + (square_image.get_size() / 2)
	var global_rotated_new_centre = (
		(global_square_centre - Vector2(pivot)).rotated(angle)
		+ Vector2(bone_start_global)
	)
	var new_start: Vector2i = (
		square_image_start
		+ Vector2i((global_rotated_new_centre - global_square_centre).floor())
	)
	cel_image.fill(Color(0, 0, 0, 0))
	cel_image.blit_rect(
		square_image,
		Rect2i(Vector2.ZERO, square_image.get_size()),
		Vector2i(new_start)
	)
	return cel_image


func get_layer_type() -> int:
	return Global.LayerTypes.BONE
