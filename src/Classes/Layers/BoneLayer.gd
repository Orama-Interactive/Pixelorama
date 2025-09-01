class_name BoneLayer
extends GroupLayer

enum { NONE, DISPLACE, ROTATE, EXTEND }
const InteractionDistance = 20
const DESELECT_WIDTH: float = 1

var enabled := true

var ignore_rotation_hover := false
var modify_mode := NONE
var generation_cache: Dictionary
var rotation_renderer := ShaderImageEffect.new()
var algorithm := DrawingAlgos.nn_shader


func serialize() -> Dictionary:
	var data := super.serialize()
	data["enabled"] = enabled
	return data


func deserialize(dict: Dictionary) -> void:
	super.deserialize(dict)
	enabled = dict.get("enabled", enabled)


## Returns a new empty [BaseCel]
func new_empty_cel() -> BaseCel:
	return BoneCel.new()


static func get_parent_bone(layer) -> BoneLayer:
	var bone_parent = layer.parent
	while bone_parent != null:
		if bone_parent is BoneLayer:
			break
		bone_parent = bone_parent.parent
	return bone_parent


func get_best_origin(frame: Frame) -> Vector2i:
	var project = Global.current_project
	var used_rect := Rect2i()
	for child_layer in project.layers[index].get_children(false):
		if !child_layer is GroupLayer:
			var cel_rect := frame.cels[child_layer.index].get_image().get_used_rect()
			if cel_rect.has_area():
				used_rect = used_rect.merge(cel_rect) if used_rect.has_area() else cel_rect
	return used_rect.position + (used_rect.size / 2)


func get_current_bone_cel(frame_idx := Global.current_project.current_frame) -> BoneCel:
	return Global.current_project.frames[Global.current_project.current_frame].cels[index]


## Calculates hover mode of current BoneLayer
func hover_mode(mouse_position: Vector2, camera_zoom) -> int:
	var bone_cel := get_current_bone_cel()
	var local_mouse_pos = bone_cel.rel_to_origin(mouse_position)
	if (bone_cel.start_point).distance_to(local_mouse_pos) <= InteractionDistance / camera_zoom.x:
		return DISPLACE
	elif (
		(bone_cel.start_point + bone_cel.end_point).distance_to(local_mouse_pos)
		<= InteractionDistance / camera_zoom.x
	):
		if !ignore_rotation_hover:
			return EXTEND
	elif _is_close_to_segment(
		bone_cel.rel_to_start_point(mouse_position),
		InteractionDistance / camera_zoom.x,
		Vector2.ZERO,
		bone_cel.end_point
	):
		if !ignore_rotation_hover:
			return ROTATE
	return NONE


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


func get_child_bones(recursive: bool) -> Array[BoneLayer]:
	var children: Array[BoneLayer] = []
	if recursive:
		for i in index:
			if is_ancestor_of(project.layers[i]) and project.layers[i] is BoneLayer:
				children.append(project.layers[i])
	else:
		for i in index:
			if project.layers[i].parent == self:
				if project.layers[i] is BoneLayer:
					children.append(project.layers[i])
				elif project.layers[i] is GroupLayer:
					var groups_to_scan = [project.layers[i]]
					while groups_to_scan.size() != 0:
						for child in groups_to_scan.pop_front().get_children(false):
							if child is BoneLayer:
								children.append(child)
							elif child is GroupLayer:
								groups_to_scan.append(child)
					pass
	return children


func apply_bone(cel_image: Image, at_frame: Frame) -> Image:
	if is_edit_mode() or DrawingAlgos.force_bone_mode == DrawingAlgos.BoneRenderMode.EDIT:
		if DrawingAlgos.force_bone_mode != DrawingAlgos.BoneRenderMode.POSE:
			return cel_image

	var bone_cel: BoneCel = at_frame.cels[index]
	var start_point: Vector2i = bone_cel.start_point
	var angle: float = bone_cel.bone_rotation
	if angle == 0 and start_point == Vector2i.ZERO:
		return cel_image
	var used_region := cel_image.get_used_rect()
	if used_region.size == Vector2i.ZERO:
		return cel_image
	# Imprint on a square for rotation
	# (We are doing this so that the image doesn't get clipped as a result of rotation.)
	var diagonal_length := floori(used_region.size.length())
	if diagonal_length % 2 == 0:
		diagonal_length += 1
	var s_offset: Vector2i = (
		(0.5 * (Vector2i(diagonal_length, diagonal_length) - used_region.size)).floor()
	)
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
		var cache_key := {"angle": angle, "un_transformed": square_image.get_data()}
		var bone_cache: Dictionary = generation_cache.get_or_add(bone_cel, {})
		if cache_key in bone_cache.keys():
			square_image = bone_cache[cache_key]
		else:
			rotation_renderer.generate_image(
				square_image, algorithm, rotate_params, square_image.get_size(), true, false
			)
			bone_cache.clear()
			bone_cache[cache_key] = square_image
	var gizmo_origin: Vector2i = bone_cel.gizmo_origin.floor()
	var pivot: Vector2i = gizmo_origin
	var bone_start_global: Vector2i = gizmo_origin + start_point
	var square_image_start: Vector2i = used_region.position - s_offset
	var global_square_centre: Vector2 = square_image_start + (square_image.get_size() / 2)
	var global_rotated_new_centre = (
		(global_square_centre - Vector2(pivot)).rotated(angle) + Vector2(bone_start_global)
	)
	var new_start: Vector2i = (
		square_image_start + Vector2i((global_rotated_new_centre - global_square_centre).floor())
	)
	cel_image.fill(Color(0, 0, 0, 0))
	cel_image.blit_rect(
		square_image, Rect2i(Vector2.ZERO, square_image.get_size()), Vector2i(new_start)
	)
	return cel_image


func get_layer_type() -> int:
	return Global.LayerTypes.BONE


func set_name_to_default(number: int) -> void:
	name = tr("Bone") + " %s" % number


func is_edit_mode() -> bool:
	# Edit mode is when, if current layer isn't a BoneLayer, or a part of BoneLayer or is
	# BoneLayer but not enabled
	var edit_mode := (
		not enabled
		or (
			not project.layers[project.current_layer] is BoneLayer
			and not BoneLayer.get_parent_bone(project.layers[project.current_layer]) == null
		)
	)
	return edit_mode


func is_blender() -> bool:
	if blend_mode != BlendModes.PASS_THROUGH:
		return true
	else:
		if DrawingAlgos.force_bone_mode == DrawingAlgos.BoneRenderMode.EDIT:
			return false
		elif DrawingAlgos.force_bone_mode == DrawingAlgos.BoneRenderMode.POSE:
			return true
	return false
