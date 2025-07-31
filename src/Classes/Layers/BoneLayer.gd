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

## Blends all of the images of children layer of the group layer into a single image.
func blend_children(frame: Frame, origin := Vector2i.ZERO, apply_effects := true) -> Image:
	var image := ImageExtended.create_custom(
		project.size.x, project.size.y, false, project.get_image_format(), project.is_indexed()
	)
	var children := get_children(false)
	if children.size() <= 0:
		return image
	var textures: Array[Image] = []
	_cache_texture_data.clear()
	var metadata_image := Image.create(children.size(), 4, false, Image.FORMAT_RGF)
	# Corresponding to the index of texture in textures. This is not the layer index
	var current_metadata_index := 0
	for i in children.size():
		var layer := children[i]
		if layer is GroupLayer:
			current_metadata_index = _blend_child_group(
				image,
				layer,
				frame,
				textures,
				metadata_image,
				current_metadata_index,
				origin,
				apply_effects
			)
			# NOTE: incrementation of current_metadata_index is done internally in
			# _blend_child_group(), so we don't have to use current_metadata_index += 1 here
		else:
			_include_child_in_blending(
				image,
				layer,
				frame,
				textures,
				metadata_image,
				current_metadata_index,
				origin,
				apply_effects
			)
			current_metadata_index += 1

	if DisplayServer.get_name() != "headless" and textures.size() > 0:
		var texture_array := Texture2DArray.new()
		texture_array.create_from_images(textures)
		var params := {
			"layers": texture_array,
			"metadata": ImageTexture.create_from_image(metadata_image),
			"origin_x_positive": origin.x > 0,
			"origin_y_positive": origin.y > 0,
		}
		var c_key := [_cache_texture_data, metadata_image.get_data(), origin.x > 0, origin.y > 0]
		if _group_cache.has(c_key):
			# Don't waste time re-generating for groups that have remained unchanged
			var cache_image = Image.create_from_data(
				project.size.x,
				project.size.y,
				false,
				project.get_image_format(),
				_group_cache[c_key]
			)
			image.blit_rect(
				cache_image, Rect2i(Vector2i.ZERO, cache_image.get_size()), Vector2i.ZERO
			)
		else:
			_group_cache.clear()
			_blend_generator.generate_image(
				image, DrawingAlgos.blend_layers_shader, params, project.size, true, false
			)
			_group_cache[c_key] = image.get_data()
		if apply_effects:
			image = display_effects(frame.cels[index], image)
	return image


func _include_child_in_blending(
	image: ImageExtended,
	layer: BaseLayer,
	frame: Frame,
	textures: Array[Image],
	metadata_image: Image,
	i: int,
	origin: Vector2i,
	apply_effects: bool
) -> void:
	var cel := frame.cels[layer.index]
	if DisplayServer.get_name() == "headless":
		DrawingAlgos.blend_layers_headless(image, project, layer, cel, origin)
	else:
		var cel_image: Image
		if apply_effects:
			cel_image = layer.display_effects(cel)
		else:
			cel_image = cel.get_image()
		textures.append(cel_image)
		_cache_texture_data.append(cel_image.get_data())
		DrawingAlgos.set_layer_metadata_image(layer, cel, metadata_image, i)
		if origin != Vector2i.ZERO:
			# Only used as a preview for the move tool, when used on a group's children
			var test_array := [project.frames.find(frame), project.layers.find(layer)]
			if test_array in project.selected_cels:
				var origin_fixed := Vector2(origin).abs() / Vector2(cel_image.get_size())
				metadata_image.set_pixel(i, 2, Color(origin_fixed.x, origin_fixed.y, 0.0, 0.0))


## Include a child group in the blending process.
## If the child group is set to pass through mode, loop through its children
## and include them as separate images, instead of blending them all together.
## Gets called recursively if the child group has children groups of its own,
## and they are also set to pass through mode.
func _blend_child_group(
	image: ImageExtended,
	layer: BaseLayer,
	frame: Frame,
	textures: Array[Image],
	metadata_image: Image,
	i: int,
	origin: Vector2i,
	apply_effects: bool
) -> int:
	var new_i := i
	var blend_rect := Rect2i(Vector2i.ZERO, project.size)
	var cel := frame.cels[layer.index]
	if layer.blend_mode == BlendModes.PASS_THROUGH:
		var children := layer.get_children(false)
		for j in children.size():
			var child := children[j]
			if child is GroupLayer:
				new_i = _blend_child_group(
					image, child, frame, textures, metadata_image, new_i, origin, apply_effects
				)
			else:
				metadata_image.crop(metadata_image.get_width() + 1, metadata_image.get_height())
				_include_child_in_blending(
					image, child, frame, textures, metadata_image, new_i, origin, apply_effects
				)
				new_i += 1
	else:
		var blended_children := (layer as GroupLayer).blend_children(frame, origin)
		if DisplayServer.get_name() == "headless":
			image.blend_rect(blended_children, blend_rect, origin)
		else:
			textures.append(blended_children)
			_cache_texture_data.append(blended_children.get_data())
			DrawingAlgos.set_layer_metadata_image(layer, cel, metadata_image, i)
		new_i += 1
	return new_i


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
