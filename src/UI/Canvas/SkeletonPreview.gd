extends Node2D

## A Dictionary of bone names as keys and their "Gizmo" as values.
var selected_bone: BoneLayer
var chaining_mode := false
var active_skeleton_tools := Array()
var transformation_active := false
var ignore_render_once := false  ## used to check if we need a new render or not (used in _input())


func _ready() -> void:
	Global.camera.zoom_changed.connect(queue_redraw)
	Global.cel_switched.connect(queue_redraw)


func _draw() -> void:
	var project = Global.current_project
	var layer = project.layers[project.current_layer]
	while layer != null:
		if layer is BoneLayer:
			break
		layer = layer.parent
	if layer == null:
		return
	var canon_bones = layer.get_children(true)
	canon_bones.push_front(layer)
	for bone in canon_bones:
		if bone is BoneLayer:
			_draw_gizmo(bone, Global.camera.zoom, canon_bones)


## Generates a gizmo (for preview) based on the given data
func _draw_gizmo(
	bone: BoneLayer, camera_zoom: Vector2, canon_bones := []
) -> void:
	var project = Global.current_project
	var frame_cels = project.frames[project.current_frame].cels
	var bone_cel: BoneCel = frame_cels[bone.index]

	var width: float = (
		bone_cel.WIDTH if (bone == selected_bone) else BoneLayer.DESELECT_WIDTH
	) / camera_zoom.x
	var main_color := Color.WHITE if (bone == selected_bone) else Color.GRAY
	var dim_color := Color(main_color.r, main_color.g, main_color.b, 0.8)
	var mouse_point: Vector2 = Global.canvas.current_pixel
	var hover_mode = max(bone.modify_mode, bone.hover_mode(mouse_point, camera_zoom))
	draw_set_transform(bone_cel.gizmo_origin)
	draw_circle(
		bone_cel.start_point,
		bone_cel.START_RADIUS / camera_zoom.x,
		main_color if (hover_mode == BoneLayer.DISPLACE) else dim_color, false,
		width
	)
	var skip_rotation_gizmo := false
	# TODO: figure out later
	var parent = bone.get_parent_bone()
	if chaining_mode:
		if parent in canon_bones:
			skip_rotation_gizmo = true
	bone.ignore_rotation_hover = skip_rotation_gizmo
	if !skip_rotation_gizmo:
		draw_line(
			bone_cel.start_point,
			bone_cel.start_point + bone_cel.end_point,
			main_color if (hover_mode == BoneLayer.ROTATE) else dim_color,
			width if (hover_mode == BoneLayer.ROTATE) else BoneLayer.DESELECT_WIDTH / camera_zoom.x
		)
		draw_circle(
			bone_cel.start_point + bone_cel.end_point,
			BoneCel.END_RADIUS / camera_zoom.x,
			main_color if (hover_mode == BoneLayer.SCALE) else dim_color,
			false,
			width
		)
	## Show connection to parent
	if parent:
		draw_dashed_line(
			bone_cel.start_point,
			bone.rel_to_origin(parent.rel_to_global(frame_cels[parent.index].start_point)),
			main_color,
			width,
		)
	if Themes:
		var font = Themes.get_font()
		draw_set_transform(bone_cel.gizmo_origin + bone_cel.start_point, rotation, Vector2.ONE / camera_zoom.x)
		var line_size = bone_cel.gizmo_length
		var fade_ratio = (line_size/font.get_string_size(bone.name).x) * camera_zoom.x
		var alpha = clampf(fade_ratio, 0.6, 1)
		if fade_ratio < 0.3:
			alpha = 0
		draw_string(
			font, Vector2.ZERO, bone.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, alpha)
		)

func announce_tool_removal(tool_node):
	active_skeleton_tools.erase(tool_node)


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
					if bone.get_parent_bone() in canon_bones:
						skip_gizmo = true
						break
				if skip_gizmo:
					continue
				selected_bone = bone
				break
		queue_redraw()
