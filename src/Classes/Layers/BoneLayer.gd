class_name BoneLayer
extends GroupLayer

enum { NONE, DISPLACE, ROTATE, EXTEND }
const INTERACTION_DISTANCE: float = 20
const DESELECT_WIDTH: float = 1
const MIN_LENGTH: float = 5
const START_RADIUS: float = 6
const END_RADIUS: float = 4
const WIDTH: float = 2

## Starting point of the gizmo (with zero displacement).
## True gizmo origin is this plus displacement. It's value is ofsetted negatively from the
## the image it's meant to move.
var gizmo_offset := Vector2.ZERO
## Gizmo rotation (when local_rotation is zero).
## True gizmo rotation is this plus local_rotation. It's value is relative to the origin of
## the image it's meant to rotate.
var gizmo_rotate_origin: float = 0  ## Unit is Radians

## The distance between the starting point of gizmo and it's ending point.
var gizmo_length: int = MIN_LENGTH + 5:
	set(value):
		if not is_equal_approx(value, gizmo_length) and value > int(MIN_LENGTH):
			if value < int(MIN_LENGTH):
				value = int(MIN_LENGTH)
			gizmo_length = value

var enabled := true

var ignore_rotation_hover := false
var modify_mode := NONE
var generation_cache: Dictionary
var rotation_renderer := ShaderImageEffect.new()
var algorithm := DrawingAlgos.nn_shader
var animator := BoneAnimator.new(default_bone_params())

# Performance variables
var _old_hover := NONE


class BoneAnimator:
	extends AnimatableObject

	func _init(_params: Dictionary[String, Variant] = {}) -> void:
		params = _params


static func get_parent_chain(layer) -> Array[BoneLayer]:
	var chain: Array[BoneLayer] = []
	var bone_parent = layer.parent
	while bone_parent != null:
		if bone_parent is BoneLayer:
			chain.push_front(bone_parent)
		bone_parent = bone_parent.parent
	return chain


static func get_parent_bone(layer) -> BoneLayer:
	var bone_parent = layer.parent
	while bone_parent != null:
		if bone_parent is BoneLayer:
			break
		bone_parent = bone_parent.parent
	return bone_parent


static func default_bone_params() -> Dictionary[String, Variant]:
	var data: Dictionary[String, Variant] = {}
	data["local_displacement"] = Vector2.ZERO
	data["local_rotation"] = 0
	return data


## Returns the coordinates of starting (position circle) point in global coordinates
func get_start() -> Vector2:
	return get_net_displacement() + gizmo_offset.rotated(get_net_rotation())


func get_end(frame: int = project.current_frame) -> Vector2:
	return Vector2(gizmo_length, 0).rotated(gizmo_rotate_origin + get_net_rotation(frame))


func get_parent_contributions(frame: int = project.current_frame):
	var rotation: float = 0
	var displacement := Vector2.ZERO
	var parent_chain := get_parent_chain(self)
	for parent_bone in parent_chain:
		var params := parent_bone.animator.get_params(frame)
		displacement += params.get("local_displacement", Vector2.ZERO).rotated(rotation)
		rotation += params.get("local_rotation", 0.0)
	return {
		"rotation": rotation,
		"displacement": displacement,
	}


func get_local_displacement(frame: int = project.current_frame) -> Vector2:
	return animator.get_param("local_displacement", frame, Vector2.ZERO)


func set_local_displacement(value: Vector2, frame: int = project.current_frame) -> void:
	animator.set_keyframe("local_displacement", frame, value)


func get_local_rotation(frame: int = project.current_frame) -> float:
	return animator.get_param("local_rotation", frame, 0.0)


func set_local_rotation(value: float, frame: int = project.current_frame) -> void:
	animator.set_keyframe("local_rotation", frame, value)


func get_net_displacement(frame: int = project.current_frame) -> Vector2:
	var p_contributions = get_parent_contributions(frame)
	return p_contributions["displacement"] + (
		animator.get_param(
			"local_displacement", frame, Vector2.ZERO
		).rotated(p_contributions["rotation"])
	)


func get_net_rotation(frame: int = project.current_frame) -> float:
	return get_local_rotation(frame) + get_parent_contributions(frame)["rotation"]


## Converts coordinates that are relative to canvas get converted to position relative to
## gizmo_offset.
func rel_to_origin(pos: Vector2) -> Vector2:
	return pos - gizmo_offset.rotated(get_net_rotation())


## Converts coordinates that are relative to canvas get converted to position relative to
## start point (the bigger circle).
func rel_to_start_point(pos: Vector2, frame: int = project.current_frame) -> Vector2:
	return pos - gizmo_offset.rotated(get_net_rotation()) - get_net_displacement(frame)


## Converts coordinates that are relative to gizmo_offset get converted to position relative to
## canvas.
func rel_to_canvas(pos: Vector2) -> Vector2:
	return pos + gizmo_offset.rotated(get_net_rotation())


func _init(_project: Project, _name := "") -> void:
	super(_project, _name)


# Currently used in serialize()
func get_bone_data(vectors_as_string: bool) -> Dictionary:
	var data := {}
	if vectors_as_string:
		data["gizmo_offset"] = var_to_str(gizmo_offset)
		data["gizmo_rotate_origin"] = var_to_str(gizmo_rotate_origin)
	else:
		data["gizmo_offset"] = gizmo_offset
		data["gizmo_rotate_origin"] = gizmo_rotate_origin
	data["gizmo_length"] = gizmo_length
	return data.merged(animator.serialize())


func serialize() -> Dictionary:
	var data := super()
	data["enabled"] = enabled
	data.merge(get_bone_data(true))
	return data


func deserialize(dict: Dictionary) -> void:
	super(dict)
	if dict.has("enabled"):
		enabled = dict.get("enabled", enabled)
	animator.deserialize(dict)


## Returns a new empty [BaseCel]
func new_empty_cel() -> BaseCel:
	return BoneCel.new()


func get_best_origin(frame: Frame) -> Vector2i:
	var used_rect := Rect2i()
	for child_layer in project.layers[index].get_children(false):
		if !child_layer is GroupLayer:
			var cel_rect := frame.cels[child_layer.index].get_image().get_used_rect()
			if cel_rect.has_area():
				used_rect = used_rect.merge(cel_rect) if used_rect.has_area() else cel_rect
	@warning_ignore("integer_division")
	return used_rect.position + (used_rect.size / 2)


func get_interaction_distance(zoom_level: float) -> float:
	return clampf(INTERACTION_DISTANCE / zoom_level, 0, gizmo_length * 0.2)


## Calculates hover mode of current BoneLayer
func hover_mode(mouse_position: Vector2, camera_zoom) -> int:
	var gizmo_pos_circle := get_net_displacement() + gizmo_offset.rotated(get_net_rotation())
	var end_point := get_end()
	var hover_type := NONE
	var interaction_distance := get_interaction_distance(camera_zoom.x)
	# Mouse close to position circle
	if gizmo_pos_circle.distance_to(mouse_position) <= interaction_distance:
		hover_type = DISPLACE
	elif (
		(gizmo_pos_circle + end_point).distance_to(mouse_position)
		<= interaction_distance
	):
		# Mouse close to end circle
		if !ignore_rotation_hover:
			hover_type = EXTEND
	elif BoneLayer.is_close_to_segment(
		mouse_position,
		interaction_distance,
		gizmo_pos_circle, gizmo_pos_circle + end_point
	):
		# Mouse close joining line
		if !ignore_rotation_hover:
			hover_type = ROTATE
	if gizmo_length * camera_zoom.x < 10 and hover_type != NONE:  # we zoomed out too much
		hover_type = DISPLACE
	if _old_hover != hover_type:
		Global.canvas.skeleton.queue_redraw()
	return hover_type


static func is_close_to_segment(
	pos: Vector2, detect_distance: float, s1: Vector2, s2: Vector2
) -> bool:
	var test_line := (s2 - s1).rotated(deg_to_rad(90)).normalized() * detect_distance
	var from_a := pos - test_line
	var from_b := pos + test_line
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
	return children


func apply_bone(cel_image: Image, at_frame: int) -> Image:
	if is_edit_mode() or DrawingAlgos.force_bone_mode == DrawingAlgos.BoneRenderMode.EDIT:
		if DrawingAlgos.force_bone_mode != DrawingAlgos.BoneRenderMode.POSE:
			return cel_image
	var frame_angle: float = get_net_rotation(at_frame)
	var frame_start_point: Vector2i = get_net_displacement(at_frame)
	if frame_angle == 0 and frame_start_point == Vector2i.ZERO:
		return cel_image
	var used_region := cel_image.get_used_rect()
	if used_region.size == Vector2i.ZERO:
		return cel_image
	# Imprint on a square for rotation
	# (We are doing this so that the image doesn't get clipped as a result of rotation.)
	var diagonal_length := floori(used_region.size.length())
	if diagonal_length % 2 == 0:
		diagonal_length += 1
	# Vector pointing from the top left corners of the square rect and the used rect of the
	# contentent that is centered on it.
	var s_offset: Vector2i = (
		(0.5 * (Vector2i(diagonal_length, diagonal_length) - used_region.size)).floor()
	)
	var square_image_start: Vector2i = used_region.position - s_offset
	var square_image = cel_image.get_region(
		Rect2i(square_image_start, Vector2i(diagonal_length, diagonal_length))
	)
	# Apply Rotation To this Image
	if frame_angle != 0:
		var transformation_matrix := Transform2D(frame_angle, Vector2.ZERO)
		var rotate_params := {
			"transformation_matrix": transformation_matrix.affine_inverse(),
			"pivot": Vector2(0.5, 0.5),
			"ending_angle": frame_angle,
			"tolerance": 0,
			"preview": false
		}
		# Detects if the rotation is changed for this generation or not
		# (useful if bone is moved around while having some rotation)
		# NOTE: I tried caching entire poses (that remain same) as well. It was faster than this
		# approach but only by a few milliseconds. I don't think straining the memory for only
		# a boost of a few millisec was worth it so i declare this the most optimal approach.
		var cache_key := {"angle": frame_angle, "un_transformed": square_image.get_data()}
		var bone_cel: BoneCel = project.frames[at_frame].cels[index]
		var bone_cache: Dictionary = generation_cache.get_or_add(bone_cel, {})
		if cache_key in bone_cache.keys():
			square_image = bone_cache[cache_key]
		else:
			rotation_renderer.generate_image(
				square_image, algorithm, rotate_params, square_image.get_size(), true, false
			)
			bone_cache.clear()
			bone_cache[cache_key] = square_image
	var gizmo_offset_rotated_floored: Vector2i = gizmo_offset.rotated(frame_angle).floor()
	var pivot: Vector2i = gizmo_offset_rotated_floored
	var bone_start_global: Vector2i = gizmo_offset_rotated_floored + frame_start_point
	var global_square_centre: Vector2 = square_image_start + (square_image.get_size() / 2)
	var global_rotated_new_centre = (
		(global_square_centre).rotated(frame_angle) - Vector2(pivot) + Vector2(bone_start_global)
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


## Generates a gizmo (for preview). Called by _draw() of manager
func draw_bone(
	camera_zoom: Vector2, mouse_point: Vector2, with_transform := true
) -> void:
	var preview := Global.canvas.skeleton
	var highlight = (self == preview.hover_bone or self == preview.selected_bone)
	var primary_color := Color.WHITE
	var secondary_color := Color(1, 1, 1, 0.8)
	var highlight_color := primary_color if (highlight) else secondary_color

	# Get the appropriate hover mode
	var true_hover_mode = BoneLayer.NONE
	if highlight:
		var hover := hover_mode(mouse_point, camera_zoom)
		true_hover_mode = max(modify_mode, hover)
		if true_hover_mode == BoneLayer.EXTEND:
			true_hover_mode = BoneLayer.ROTATE
		if hover == BoneLayer.NONE:
			true_hover_mode = BoneLayer.NONE

		preview.cursor_reset_delay = 10
		match true_hover_mode:
			BoneLayer.DISPLACE:
				if DisplayServer.cursor_get_shape() != Input.CURSOR_MOVE:
					Input.set_default_cursor_shape(Input.CURSOR_MOVE)
			BoneLayer.ROTATE:
				if DisplayServer.cursor_get_shape() != Input.CURSOR_POINTING_HAND:
					Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

	var bone_displacement := get_net_displacement()
	var net_rotation := get_net_rotation()
	var bone_end := get_end()
	if not with_transform:  # Exclude effects of rotation
		bone_displacement = Vector2.ZERO
		bone_end = bone_end.rotated(-net_rotation)

	# Lambdha func to get width
	var get_width := func(for_hover_mode):
		var initial_width: float = (WIDTH if (highlight) else DESELECT_WIDTH) / camera_zoom.x
		var hover_width_diff: float = (
			initial_width / 2 if (true_hover_mode != BoneLayer.NONE) else 0.0
		)
		var net_width := (
			initial_width + hover_width_diff
			if true_hover_mode == for_hover_mode or self == preview.selected_bone
			else BoneLayer.DESELECT_WIDTH / camera_zoom.x
		)
		return net_width

	# Draw the position circle
	preview.draw_set_transform(gizmo_offset.rotated(net_rotation))
	# Joint circle at start
	preview.draw_circle(
		bone_displacement,
		START_RADIUS / camera_zoom.x,
		highlight_color,
		false,
		get_width.call(BoneLayer.DISPLACE)
	)

	preview.draw_set_transform(Vector2.ZERO)
	ignore_rotation_hover = preview.chaining_mode
	var skip_rotation_bone := false
	if preview.chaining_mode and not get_child_bones(false).is_empty():
		skip_rotation_bone = true
	ignore_rotation_hover = skip_rotation_bone
	if !skip_rotation_bone:
		preview.draw_set_transform(gizmo_offset.rotated(net_rotation))
		if with_transform:
			# Increase width slightly in order to indicate highlight
			# Draw the line joining the start and end points
			var split := 0.1 * bone_end
			var perp := bone_end.normalized().rotated(-(PI / 2))
			var w1 := START_RADIUS / camera_zoom.x   # start thickness
			var w2 := END_RADIUS / camera_zoom.x   # end thickness
			var start := bone_displacement + (bone_end.normalized() * w1)
			var end := bone_displacement + bone_end - (bone_end.normalized() * w2)
			var p1 := start + split + perp * get_interaction_distance(camera_zoom.x)
			var p2 := end + (perp / 2) * w2
			var p3 := end - (perp / 2) * w2
			var p4 := start + split - perp * get_interaction_distance(camera_zoom.x)
			preview.draw_polyline(
				PackedVector2Array([start, p1, p2, p3, p4, start, end]),
				highlight_color,
				get_width.call(BoneLayer.ROTATE)
			)
		else:
			# Draw the line joining the position and rotation circles
			preview.draw_line(
				bone_displacement,
				bone_displacement + bone_end,
				highlight_color,
				get_width.call(BoneLayer.ROTATE)
			)
		# Draw rotation circle (pose mode)
		preview.draw_circle(
			bone_displacement + bone_end,
			BoneLayer.END_RADIUS / camera_zoom.x,
			highlight_color,
			false,
			get_width.call(BoneLayer.ROTATE)
		)
	preview.draw_set_transform(Vector2.ZERO)
	if with_transform:
		## Show connection to parent and write bone name
		var parent_bone: BoneLayer = BoneLayer.get_parent_bone(self)
		if parent_bone:
			var p_start := parent_bone.get_start()
			var p_end := Vector2.ZERO if preview.chaining_mode else parent_bone.get_end()
			if not parent_bone in preview.canon_layers:
				preview.draw_circle(p_start + p_end, START_RADIUS / camera_zoom.x, Color.GRAY, true)
			preview.draw_dashed_line(
				bone_displacement + gizmo_offset.rotated(net_rotation),
				p_start + p_end,
				highlight_color,
				BoneLayer.DESELECT_WIDTH / camera_zoom.x
			)

		var font = Themes.get_font()
		var line_size = gizmo_length
		var fade_ratio = (line_size * camera_zoom.x) / (font.get_string_size(name).x)
		if preview.chaining_mode:
			fade_ratio = max(0.3, fade_ratio)
		if fade_ratio >= 0.4 and !preview.active_tool:  # Hide names if we have zoomed far
			preview.draw_set_transform(
				gizmo_offset + bone_displacement, preview.rotation, Vector2.ONE / camera_zoom.x
			)
			preview.draw_string(
				font, Vector2(3, -3), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, highlight_color
			)
