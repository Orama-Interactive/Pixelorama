extends Node2D

@warning_ignore("unused_signal")
signal sync_ui(from_idx: int, data: Dictionary)

var active_tool: Control
## A Dictionary of bone names as keys and their "Gizmo" as values.
var hover_bone: BoneLayer:
	set(value):
		if hover_bone != value:
			hover_bone = value
			if !value and !selected_bone:
				Global.canvas.skeleton.queue_redraw()
var selected_bone: BoneLayer:
	set(value):
		if selected_bone != value:
			selected_bone = value
			if !value:
				Global.canvas.skeleton.queue_redraw()
var chaining_mode := true
var transformation_active := false
var cursor_reset_delay := 10  # Number of _input cals confirming the cursor should reset
var canon_layers: Array[BaseLayer]

func _ready() -> void:
	Global.camera.zoom_changed.connect(queue_redraw)


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
				font,
				text_offset,
				tr("(Bone) Edit mode"),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				16,
				Color.WHITE
			)
		edit_mode = true
		layer = BoneLayer.get_parent_bone(layer)
	else:
		draw_string(
			font,
			text_offset,
			tr("(Bone) Pose mode"),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color.WHITE
		)
	draw_set_transform(Vector2.ZERO)
	if layer == null:
		return
	if Global.animation_timeline.is_animation_running:
		return
	canon_layers = layer.get_children(true)
	canon_layers.push_front(layer)
	for l in canon_layers:
		if l is BoneLayer:
			l.draw_bone(Global.camera.zoom, Global.canvas.current_pixel, !edit_mode)


func _input(event: InputEvent) -> void:
	if cursor_reset_delay == 0:  # Done to avoid cursor flickering
		var cursor = Input.CURSOR_ARROW
		if Global.cross_cursor:
			cursor = Input.CURSOR_CROSS
		if DisplayServer.cursor_get_shape() != cursor:
			Input.set_default_cursor_shape(cursor)
	else:
		cursor_reset_delay = clampi(cursor_reset_delay - 1, 0, cursor_reset_delay)
	var project = Global.current_project

	## This manages the hovering mechanism of gizmo
	if event is InputEventMouseMotion:
		var bone_layer = project.layers[project.current_layer]
		if not bone_layer is BoneLayer:
			return
		var pos = Global.canvas.current_pixel
		var exclude_bones := []
		if hover_bone:  # Check if we are still hovering over the same gizmo
			# Clear the hover_bone if it's not being hovered or interacted with
			if (
				hover_bone.hover_mode(pos, Global.camera.zoom) == BoneLayer.NONE
				and hover_bone.modify_mode == BoneLayer.NONE
			):
				exclude_bones.append(hover_bone)
				hover_bone = null
		if !hover_bone:
			# If in the prevoius check we deselected the gizmo then search for a new one.
			if selected_bone:
				if active_tool:
					# If a tool is actively using a bone then we don't need to calculate hovering
					hover_bone = selected_bone
					return
				# We are just checking it as higher priorty, we don't have to clear it
				if selected_bone.hover_mode(pos, Global.camera.zoom) != BoneLayer.NONE:
					hover_bone = selected_bone
					return
			for bone: BaseLayer in canon_layers:
				if not bone is BoneLayer:
					continue
				if exclude_bones.has(bone):
					continue
				if bone.modify_mode != BoneLayer.NONE and not bone == selected_bone:
					# Failsafe: Bones should only have an active modify_mode if it is selected.
					bone.modify_mode = BoneLayer.NONE
				# Select the bone if it's being hovered or modified
				var hover_mode = bone.hover_mode(pos, Global.camera.zoom)
				if hover_mode != BoneLayer.NONE:
					var skip_gizmo := false
					if (
						chaining_mode
						and hover_mode == BoneLayer.ROTATE
						and bone.get_child_bones(false).is_empty()
					):
						# In chaining mode, we only allow rotation (through gizmo) if it is
						# the last bone in the chain. Ignore bone if it is a parent of another bone
						skip_gizmo = true
					if skip_gizmo:
						continue
					hover_bone = bone
					break

	elif event is InputEventMouseButton:
		if event.is_released() and !selected_bone:
			var bone_layer = project.layers[project.current_layer]
			if not bone_layer is BoneLayer:
					return
			var parent_bone := BoneLayer.get_parent_bone(bone_layer)
			if parent_bone:  # We wish to switch to parent
					var pos: Vector2i = Global.canvas.current_pixel
					if Geometry2D.is_point_in_circle(
							pos,
							parent_bone.rel_to_canvas(parent_bone.get_net_displacement() + parent_bone.get_end()),
							parent_bone.START_RADIUS / Global.camera.zoom.x
					):
							project.selected_cels.clear()
							project.change_cel(-1, parent_bone.index)
	if (
		event.is_action_pressed(&"activate_left_tool")
		or event.is_action_pressed(&"activate_right_tool")
	):
		selected_bone = hover_bone


## This manages the hovering mechanism of gizmo
func get_selected_bone() -> void:
	var pos: Vector2i = Global.canvas.current_pixel
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
	if !selected_bone:  # If in the previous check we deselected the gizmo then search for a new one.
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
