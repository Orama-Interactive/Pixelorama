extends Node2D

## A Dictionary of bone names as keys and their "Gizmo" as values.
var selected_bone: BoneCel
var active_skeleton_tools := Array()
var transformation_active := false


func _ready() -> void:
	Global.camera.zoom_changed.connect(queue_redraw)
	Global.cel_switched.connect(queue_redraw)


func _draw() -> void:
	var project = Global.current_project
	var layer = project.layers[project.current_layer]
	if not layer is BoneLayer:
		return
	_draw_gizmo(layer, Global.camera.zoom)


## Generates a gizmo (for preview) based on the given data
func _draw_gizmo(layer: BoneLayer, camera_zoom: Vector2, chained := false, parent = null) -> void:
	var project = Global.current_project
	if not project.layers[project.current_layer] is BoneLayer:
		return
	var bone: BoneCel = project.frames[project.current_frame].cels[layer.index]
	var width: float = (
		bone.WIDTH if (bone == selected_bone) else bone.DESELECT_WIDTH
	) / camera_zoom.x
	var main_color := Color.WHITE if (bone == selected_bone) else Color.GRAY
	var dim_color := Color(main_color.r, main_color.g, main_color.b, 0.8)
	var mouse_point: Vector2 = Global.canvas.current_pixel
	var hover_mode = max(bone.modify_mode, bone.hover_mode(mouse_point, camera_zoom))
	draw_set_transform(bone.gizmo_origin)
	draw_circle(
		bone.start_point,
		bone.START_RADIUS / camera_zoom.x,
		main_color if (hover_mode == bone.DISPLACE) else dim_color, false,
		width
	)
	var skip_rotation_gizmo := false
	# TODO: figure out later
	if chained:  # Check if it's a parent of another bone.
		for potential_child in bone.get_children():
			if potential_child == BoneLayer:
				skip_rotation_gizmo = true
				_draw_gizmo(potential_child, camera_zoom, chained, bone)
	bone.ignore_rotation_hover = skip_rotation_gizmo
	if !skip_rotation_gizmo:
		draw_line(
			bone.start_point,
			bone.start_point + bone.end_point,
			main_color if (hover_mode == bone.ROTATE) else dim_color,
			width if (hover_mode == bone.ROTATE) else bone.DESELECT_WIDTH / camera_zoom.x
		)
		draw_circle(
			bone.start_point + bone.end_point,
			bone.END_RADIUS / camera_zoom.x,
			main_color if (hover_mode == bone.SCALE) else dim_color,
			false,
			width
		)
	## Show connection to parent
	if parent:
		draw_dashed_line(
			bone.start_point,
			bone.rel_to_origin(parent.rel_to_global(parent.start_point)),
			main_color,
			width,
		)
	if Themes:
		var font = Themes.get_font()
		draw_set_transform(bone.gizmo_origin + bone.start_point, rotation, Vector2.ONE / camera_zoom.x)
		var line_size = bone.gizmo_length
		var fade_ratio = (line_size/font.get_string_size(bone.bone_name).x) * camera_zoom.x
		var alpha = clampf(fade_ratio, 0.6, 1)
		if fade_ratio < 0.3:
			alpha = 0
		draw_string(
			font, Vector2.ZERO, bone.bone_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, alpha)
		)

func announce_tool_removal(tool_node):
	active_skeleton_tools.erase(tool_node)


## This manages the hovering mechanism of gizmo
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var project: Project = Global.current_project
		var bone_layer = project.layers[project.current_layer]
		if bone_layer is BoneLayer:
			return
		var pos = event.position
		if selected_bone:  # Check if we are still hovering over the same gizmo
			if (
				selected_bone.hover_mode(pos, Global.camera.zoom) == selected_bone.NONE
				and selected_bone.modify_mode == selected_bone.NONE
			):
				selected_bone = null
		if !selected_bone:  # If in the prevoius check we deselected the gizmo then search for a new one.
			var frame = project.frames[project.current_frame]
			for bone_child_layer in bone_layer.get_children(false):
				if not bone_child_layer is BoneLayer:
					continue
				var bone_cel = frame.cels[bone_child_layer.index]
				if (
					bone_cel.hover_mode(pos, Global.camera.zoom) != bone_cel.NONE
					or bone_cel.modify_mode != bone_cel.NONE
				):
					var skip_gizmo := false
					if (
						bone_layer.allow_chaining
						and (
							bone_cel.modify_mode == bone_cel.ROTATE
							or bone_cel.hover_mode(pos, Global.camera.zoom) == bone_cel.ROTATE
							)
					):
						# Check if bone is a parent of anything (if it has, skip it)
						for other_gizmo in bone_child_layer.get_children(false):
							if other_gizmo.bone_name == bone.parent_bone_name:
								skip_gizmo = true
								break
					if skip_gizmo:
						continue
					selected_bone = bone
					skeleton_manager.update_frame_data()
					break
			skeleton_manager.queue_redraw()


func get_selected(initial_layer: BoneLayer, pos: Vector2, project: Project):
	if selected_bone:  # Check if we are still hovering over the same gizmo
		if (
			selected_bone.hover_mode(pos, Global.camera.zoom) == selected_bone.NONE
			and selected_bone.modify_mode == selected_bone.NONE
		):
			selected_bone = null
	if !selected_bone:  # If in the upper check we deselected the gizmo then search for a new one.
		var frame = project.frames[project.current_frame]
		for bone_child_layer in initial_layer.get_children(true):
			if not bone_child_layer is BoneLayer:
				continue
			var bone_cel = frame.cels[bone_child_layer.index]
			if (
				bone_cel.hover_mode(pos, Global.camera.zoom) != bone_cel.NONE
				or bone_cel.modify_mode != bone_cel.NONE
			):
				var skip_gizmo := false
				if (
					initial_layer.allow_chaining
					and (
						bone_cel.modify_mode == bone_cel.ROTATE
						or bone_cel.hover_mode(pos, Global.camera.zoom) == bone_cel.ROTATE
						)
				):
					# Check if bone is a child of anything (if it is, skip it)
					for child_bone_layer in bone_child_layer.get_children(false):
						if child_bone_layer is BoneLayer:
							get_selected(child_bone_layer, pos, project)
							break
						if other_gizmo.bone_name == bone.parent_bone_name:
							skip_gizmo = true
							break
				if skip_gizmo:
					continue
				selected_bone = bone
				skeleton_manager.update_frame_data()
				break
		queue_redraw()
