extends Node2D

## A Dictionary of bone names as keys and their "Gizmo" as values.
var selected_bone: BoneLayer
var chaining_mode := false
var transformation_active := false


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

	var width: float = (
		bone_cel.WIDTH if (bone == selected_bone) else BoneLayer.DESELECT_WIDTH
	) / camera_zoom.x
	var bone_color := Color.WHITE if (bone == selected_bone) else Color.GRAY
	var current_layer = project.layers[project.current_layer]
	var mouse_point: Vector2 = Global.canvas.current_pixel
	var hover_mode = max(bone.modify_mode, bone.hover_mode(mouse_point, camera_zoom))
	if hover_mode == BoneLayer.EXTEND:
		hover_mode = BoneLayer.ROTATE
	if bone.hover_mode(mouse_point, camera_zoom) == BoneLayer.NONE:
		hover_mode = BoneLayer.NONE

	var bone_start := Vector2.ZERO
	var bone_end := Vector2(bone_cel.gizmo_length, 0).rotated(bone_cel.gizmo_rotate_origin)
	var skip_rotation_gizmo := false
	var parent = BoneLayer.get_parent_bone(bone)
	if chaining_mode:
		if parent in canon_bones:
			skip_rotation_gizmo = true
	if not edit_mode:
		bone_start = bone_cel.start_point
		bone_end = bone_cel.end_point
		draw_set_transform(bone_cel.gizmo_origin)
		width += width / 2 if (hover_mode == BoneLayer.DISPLACE) else 0
		draw_circle(
			bone_start,
			bone_cel.START_RADIUS / camera_zoom.x,
			bone_color,
			false,
			width if (hover_mode == BoneLayer.DISPLACE) else BoneLayer.DESELECT_WIDTH / camera_zoom.x
		)
		width -= width / 2 if (hover_mode == BoneLayer.DISPLACE) else 0
		draw_set_transform(Vector2.ZERO)
	bone.ignore_rotation_hover = skip_rotation_gizmo
	if !skip_rotation_gizmo:
		width += width / 2 if (hover_mode == BoneLayer.ROTATE) else 0
		draw_set_transform(bone_cel.gizmo_origin)
		draw_line(
			bone_start,
			bone_start + bone_end,
			bone_color,
			width if (hover_mode == BoneLayer.ROTATE) else BoneLayer.DESELECT_WIDTH / camera_zoom.x
		)
		if edit_mode:
			draw_line(
				bone_end,
				bone_end + (bone_end).normalized().rotated(PI * 3.0/4),
				bone_color,
				width if (hover_mode == BoneLayer.ROTATE) else BoneLayer.DESELECT_WIDTH / camera_zoom.x
			)
			draw_line(
				bone_end,
				bone_end + (bone_end).normalized().rotated(PI * 1.25),
				bone_color,
				width if (hover_mode == BoneLayer.ROTATE) else BoneLayer.DESELECT_WIDTH / camera_zoom.x
			)
		else:
			draw_circle(
				bone_start + bone_end,
				BoneCel.END_RADIUS / camera_zoom.x,
				bone_color,
				false,
				width if (hover_mode == BoneLayer.ROTATE) else BoneLayer.DESELECT_WIDTH / camera_zoom.x
			)
		width -= width / 2 if (hover_mode == BoneLayer.ROTATE) else 0
		draw_set_transform(Vector2.ZERO)
	## Show connection to parent
	if parent:
		draw_set_transform(bone_cel.gizmo_origin)
		var parent_cel =  parent.get_current_bone_cel()
		var parent_start = bone.rel_to_origin(
			parent.rel_to_global(Vector2.ZERO)
		) + parent_cel.end_point
		var parent_end := Vector2(parent_cel.gizmo_length, 0).rotated(parent_cel.gizmo_rotate_origin)
		if not edit_mode:
			parent_start = bone.rel_to_origin(
				parent.rel_to_global(parent_cel.start_point)
			) + parent_cel.end_point
		draw_dashed_line(
			bone_start,
			parent_start,
			bone_color,
			BoneLayer.DESELECT_WIDTH / camera_zoom.x
		)
		if not parent in canon_bones:
			draw_circle(
				parent_start,
				bone_cel.START_RADIUS / camera_zoom.x,
				Color.GRAY,
				true
			)
		draw_set_transform(Vector2.ZERO)
	var font = Themes.get_font()
	var line_size = bone_cel.gizmo_length
	var fade_ratio = (line_size/font.get_string_size(bone.name).x) * camera_zoom.x
	var alpha = clampf(fade_ratio, 0.6, 1)
	if fade_ratio < 0.3:
		alpha = 0
	draw_set_transform(bone_cel.gizmo_origin + bone_start, rotation, Vector2.ONE / camera_zoom.x)
	draw_string(
		font, Vector2(3, -3), bone.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, bone_color
	)


## This manages the hovering mechanism of gizmo
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		## Bone Selection
		get_selected_bone()


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
