extends Node2D

## A Dictionary of bone names as keys and their "Gizmo" as values.
var selected_bone: BoneLayer
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
	_draw_gizmo(layer, Global.camera.zoom)


## Generates a gizmo (for preview) based on the given data
func _draw_gizmo(
	bone: BoneLayer, camera_zoom: Vector2, chained := false, parent: BoneLayer = null
) -> void:
	var project = Global.current_project
	var frame_cels = project.frames[project.current_frame].cels
	var bone_cel: BoneCel = frame_cels[bone.index]

	var width: float = (
		bone_cel.WIDTH if (bone == selected_bone) else bone_cel.DESELECT_WIDTH
	) / camera_zoom.x
	var main_color := Color.WHITE if (bone == selected_bone) else Color.GRAY
	var dim_color := Color(main_color.r, main_color.g, main_color.b, 0.8)
	var mouse_point: Vector2 = Global.canvas.current_pixel
	var hover_mode = max(bone_cel.modify_mode, bone_cel.hover_mode(mouse_point, camera_zoom))
	draw_set_transform(bone_cel.gizmo_origin)
	draw_circle(
		bone_cel.start_point,
		bone_cel.START_RADIUS / camera_zoom.x,
		main_color if (hover_mode == bone_cel.DISPLACE) else dim_color, false,
		width
	)
	var skip_rotation_gizmo := false
	# TODO: figure out later
	for potential_child in bone.get_children(false):
		if potential_child is BoneLayer:
			if chained:  # Check if it's a parent of another bone.
				skip_rotation_gizmo = true
			_draw_gizmo(potential_child, camera_zoom, chained, bone)
	bone_cel.ignore_rotation_hover = skip_rotation_gizmo
	if !skip_rotation_gizmo:
		draw_line(
			bone_cel.start_point,
			bone_cel.start_point + bone_cel.end_point,
			main_color if (hover_mode == bone_cel.ROTATE) else dim_color,
			width if (hover_mode == bone_cel.ROTATE) else bone_cel.DESELECT_WIDTH / camera_zoom.x
		)
		draw_circle(
			bone_cel.start_point + bone_cel.end_point,
			bone_cel.END_RADIUS / camera_zoom.x,
			main_color if (hover_mode == bone_cel.SCALE) else dim_color,
			false,
			width
		)
	## Show connection to parent
	if parent:
		draw_dashed_line(
			bone_cel.start_point,
			bone_cel.rel_to_origin(
				frame_cels[parent.index].rel_to_global(frame_cels[parent.index].start_point)
			),
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
		var project: Project = Global.current_project
		var bone_layer = project.layers[project.current_layer]
		if not bone_layer is BoneLayer:
			return
		var pos = Global.canvas.current_pixel
		if selected_bone:  # Check if we are still hovering over the same gizmo
			var frame_cels = project.frames[project.current_frame].cels
			if (
				frame_cels[selected_bone.index].hover_mode(pos, Global.camera.zoom) == BoneCel.NONE
				and frame_cels[selected_bone.index].modify_mode == BoneCel.NONE
			):
				selected_bone = null
		if !selected_bone:  # If in the prevoius check we deselected the gizmo then search for a new one.
			get_selected(bone_layer, pos, project)
		queue_redraw()


func get_selected(initial_layer: BoneLayer, pos: Vector2, project: Project):
	var frame = project.frames[project.current_frame]
	var bone_cel = frame.cels[initial_layer.index]
	if (
		bone_cel.hover_mode(pos, Global.camera.zoom) != bone_cel.NONE
		or bone_cel.modify_mode != bone_cel.NONE
	):
		if (
			initial_layer.allow_chaining
			and (
				bone_cel.modify_mode == bone_cel.ROTATE
				or bone_cel.hover_mode(pos, Global.camera.zoom) == bone_cel.ROTATE
				)
		):
			# Check if bone_child_layer is a child of anything (if it is, skip it)
			for child_bone_layer in initial_layer.get_children(false):
				if child_bone_layer is BoneLayer:
					get_selected(child_bone_layer, pos, project)
				if selected_bone:
					break
		selected_bone = initial_layer
