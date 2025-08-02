extends Node2D

## A Dictionary of bone names as keys and their "Gizmo" as values.
var selected_bone: BoneLayer
var chaining_mode := false
var transformation_active := false

@warning_ignore("unused_signal")
signal sync_ui(from_idx: int, data: Dictionary)


func _ready() -> void:
	Global.camera.zoom_changed.connect(queue_redraw)
	Global.cel_switched.connect(queue_redraw)


func _draw() -> void:
	var project = Global.current_project
	var layer = project.layers[project.current_layer]
	var font = Themes.get_font()
	draw_set_transform(Vector2.UP, rotation, Vector2.ONE / Global.camera.zoom.x)
	var text_offset := Vector2(0, -10)
	var edit_mode := false
	if not layer is BoneLayer:
		if BoneLayer.get_parent_bone(layer) != null:
			draw_string(
				font, text_offset, tr("(Bone) Edit mode"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE
			)
		edit_mode = true
		layer = BoneLayer.get_parent_bone(layer)
	else:
		draw_string(
			font, text_offset, tr("(Bone) Pose mode"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE
		)
	draw_set_transform(Vector2.ZERO)
	if layer == null:
		return
	if Global.animation_timeline.is_animation_running:
		return
	var canon_bones = layer.get_children(true)
	canon_bones.push_front(layer)
	for bone in canon_bones:
		if bone is BoneLayer:
			_draw_gizmo(bone, Global.camera.zoom, canon_bones, edit_mode)


## Generates a gizmo (for preview) based on the given data
func _draw_gizmo(
	bone: BoneLayer, camera_zoom: Vector2, canon_bones := [], edit_mode := false
) -> void:
	var project = Global.current_project
	var frame_cels = project.frames[project.current_frame].cels
	var bone_cel: BoneCel = frame_cels[bone.index]
	var mouse_point: Vector2 = Global.canvas.current_pixel

	var width: float = (
		bone_cel.WIDTH if (bone == selected_bone) else BoneLayer.DESELECT_WIDTH
	) / camera_zoom.x
	var net_width = width
	var bone_color := Color.WHITE if (bone == selected_bone) else Color.GRAY
	var hover_mode := maxi(bone.modify_mode, bone.hover_mode(mouse_point, camera_zoom))
	if hover_mode == BoneLayer.EXTEND:
		hover_mode = BoneLayer.ROTATE
	if bone.hover_mode(mouse_point, camera_zoom) == BoneLayer.NONE:
		hover_mode = BoneLayer.NONE

	# Start with values assumed for Edit Mode
	var bone_start := Vector2.ZERO
	var bone_end := Vector2(bone_cel.gizmo_length, 0).rotated(bone_cel.gizmo_rotate_origin)
	if not edit_mode:
		bone_start = bone_cel.start_point
		bone_end = bone_cel.end_point
	# Draw the position circle
	if not edit_mode or chaining_mode:
		draw_set_transform(bone_cel.gizmo_origin)
		net_width = width + (width / 2 if (hover_mode == BoneLayer.DISPLACE) else 0)
		draw_circle(
			bone_start,
			bone_cel.START_RADIUS / camera_zoom.x,
			bone_color,
			false,
			net_width if (hover_mode == BoneLayer.DISPLACE) else BoneLayer.DESELECT_WIDTH / camera_zoom.x
		)
		draw_set_transform(Vector2.ZERO)
	bone.ignore_rotation_hover = chaining_mode
	if bone.get_child_bones(false).is_empty():
		bone.ignore_rotation_hover = false
	if !bone.ignore_rotation_hover:
		net_width = width + (width / 2 if (hover_mode == BoneLayer.ROTATE) else 0)
		draw_set_transform(bone_cel.gizmo_origin)
		# Draw the line joining the position and rotation circles
		draw_line(
			bone_start,
			bone_start + bone_end,
			bone_color,
			net_width if (hover_mode == BoneLayer.ROTATE) else BoneLayer.DESELECT_WIDTH / camera_zoom.x
		)
		# Draw rotation circle (pose mode) or arrow (edit mode)
		if edit_mode:
			draw_line(
				bone_end,
				bone_end + (bone_end).normalized().rotated(PI * 3.0/4),
				bone_color,
				net_width if (hover_mode == BoneLayer.ROTATE) else BoneLayer.DESELECT_WIDTH / camera_zoom.x
			)
			draw_line(
				bone_end,
				bone_end + (bone_end).normalized().rotated(PI * 1.25),
				bone_color,
				net_width if (hover_mode == BoneLayer.ROTATE) else BoneLayer.DESELECT_WIDTH / camera_zoom.x
			)
		else:
			draw_circle(
				bone_start + bone_end,
				BoneCel.END_RADIUS / camera_zoom.x,
				bone_color,
				false,
				net_width if (hover_mode == BoneLayer.ROTATE) else BoneLayer.DESELECT_WIDTH / camera_zoom.x
			)
	draw_set_transform(Vector2.ZERO)
	## Show connection to parent
	var parent = BoneLayer.get_parent_bone(bone)
	if parent:
		var parent_cel :=  parent.get_current_bone_cel()
		var p_start := Vector2.ZERO if edit_mode else parent_cel.start_point
		var p_rot := parent_cel.bone_rotation if edit_mode else 0.0
		var p_end := Vector2.ZERO if (not parent in canon_bones or chaining_mode) else parent_cel.end_point
		var parent_start = bone.rel_to_origin(
			parent.rel_to_global(p_start)
		) + (p_end).rotated(-p_rot)
		draw_set_transform(bone_cel.gizmo_origin)
		if not parent in canon_bones:
			draw_circle(
				parent_start,
				bone_cel.START_RADIUS / camera_zoom.x,
				Color.GRAY,
				true
			)
		draw_dashed_line(
			bone_start,  # Connected to tail of bone
			parent_start,  # Connected to head of parent (or tail in chained mode)
			bone_color,
			BoneLayer.DESELECT_WIDTH / camera_zoom.x
		)
		draw_set_transform(Vector2.ZERO)
	var font = Themes.get_font()
	var line_size = bone_cel.gizmo_length
	var fade_ratio = (line_size / font.get_string_size(bone.name).x) * (camera_zoom.x) / (line_size / font.get_string_size(bone.name).x)
	if chaining_mode:
		fade_ratio = max(2, fade_ratio)
	if fade_ratio >= 2:  # Hide names if we have zoomed far
		draw_set_transform(bone_cel.gizmo_origin + bone_start, rotation, Vector2.ONE / camera_zoom.x)
		draw_string(
			font, Vector2(3, -3), bone.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, bone_color
		)


## This manages the hovering mechanism of gizmo
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		## Bone Selection
		get_selected_bone()
	elif event is InputEventMouseButton:
		if event.is_released() and !selected_bone:
			var project: Project = Global.current_project
			var bone_layer = project.layers[project.current_layer]
			if not bone_layer is BoneLayer:
				return
			var parent := BoneLayer.get_parent_bone(bone_layer)
			if parent:  # We wish to switch to parent
				var p_cel = parent.get_current_bone_cel()
				var pos: Vector2i = Global.canvas.current_pixel.floor()
				if Geometry2D.is_point_in_circle(
					pos,
					parent.rel_to_global(p_cel.start_point),
					p_cel.START_RADIUS / Global.camera.zoom.x
				):
					project.selected_cels.clear()
					project.change_cel(-1, parent.index)


## This manages the hovering mechanism of gizmo
func get_selected_bone() -> void:
	var pos: Vector2i = Global.canvas.current_pixel.floor()
	var project: Project = Global.current_project
	var bone_layer = project.layers[project.current_layer]
	if not bone_layer is BoneLayer:
		return
	if selected_bone:  # Check if we are still hovering over the same gizmo
		if (
			selected_bone.hover_mode(pos, Global.camera.zoom) == BoneLayer.NONE
			and selected_bone.modify_mode == BoneLayer.NONE
		):
			selected_bone = null
	if !selected_bone:  # If in the prevoius check we deselected the gizmo then search for a new one.
		var canon_bones = bone_layer.get_children(true)
		canon_bones.push_front(bone_layer)
		for bone in canon_bones:
			if not bone is BoneLayer:
				continue
			if (
				bone.hover_mode(pos, Global.camera.zoom) != BoneLayer.NONE
				or bone.modify_mode != BoneLayer.NONE
			):
				var skip_gizmo := false
				if (
					chaining_mode
					and (
						bone.modify_mode == BoneLayer.ROTATE
						or bone.hover_mode(pos, Global.camera.zoom) == BoneLayer.ROTATE
						)
				):
					# Check if bone is a parent of anything (if it has, skip it)
					if BoneLayer.get_parent_bone(bone) in canon_bones:
						skip_gizmo = true
						break
				if skip_gizmo:
					continue
				selected_bone = bone
				break
	queue_redraw()
