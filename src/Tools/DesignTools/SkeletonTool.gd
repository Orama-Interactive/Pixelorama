extends BaseTool

var is_transforming := false
var generation_threshold: float = 20
var live_thread := Thread.new()

var _live_update := false
var _allow_chaining := false
var _include_children := true
var _displace_offset := Vector2.ZERO
var _prev_mouse_position := Vector2.INF
var _distance_to_parent: float = 0
var _chained_gizmo = null
var current_selected_bone: BoneLayer  # needed for chain mode to work

@onready var _pos_slider: ValueSliderV2 = $BoneProps/BonePositionSlider
@onready var _rot_slider: ValueSlider = $BoneProps/BoneRotationSlider
@onready var quick_set_bones_menu: MenuButton = $QuickSetBones
@onready var rotation_reset_menu: MenuButton = $RotationReset
@onready var position_reset_menu: MenuButton = $PositionReset
@onready var copy_pose_from: MenuButton = $CopyPoseFrom
@onready var tween_skeleton_menu: MenuButton = $TweenSkeleton


func _ready() -> void:
	Global.canvas.skeleton.sync_ui.connect(_sync_ui)
	Global.cel_switched.connect(_queue_display_props)
	Global.project_switched.connect(_queue_display_props)
	Global.project_data_changed.connect(_on_project_data_changed)

	quick_set_bones_menu.get_popup().index_pressed.connect(quick_set_bones)
	rotation_reset_menu.get_popup().index_pressed.connect(reset_bone_angle)
	position_reset_menu.get_popup().index_pressed.connect(reset_bone_position)
	super._ready()


func _on_warn_pressed() -> void:
	var warn_text = """
To avoid any quirky behavior, it is recomended to not tween between
large rotations, and have "Include bone children" enabled.
"""
	Global.popup_error(warn_text)


func get_config() -> Dictionary:
	var config := super.get_config()
	config["live_update"] = _live_update
	config["allow_chaining"] = _allow_chaining
	config["include_children"] = _include_children
	return config


func set_config(config: Dictionary) -> void:
	super.set_config(config)
	_live_update = config.get("live_update", _live_update)
	_allow_chaining = config.get("allow_chaining", _allow_chaining)
	_include_children = config.get("include_children", _include_children)


func update_config() -> void:
	super.update_config()
	%LiveUpdateCheckbox.set_pressed_no_signal(_live_update)
	%AllowChaining.set_pressed_no_signal(_allow_chaining)
	%IncludeChildrenCheckbox.set_pressed_no_signal(_include_children)
	Global.canvas.skeleton.chaining_mode = _allow_chaining
	Global.canvas.skeleton.sync_ui.emit(tool_slot.button, get_config())
	Global.canvas.skeleton.queue_redraw()


func _exit_tree() -> void:
	Global.cel_switched.disconnect(_queue_display_props)
	Global.project_switched.disconnect(_queue_display_props)
	Global.project_data_changed.disconnect(_on_project_data_changed)


# UI "option" Signals
func _on_live_update_toggled(toggled_on: bool) -> void:
	_live_update = toggled_on
	update_config()
	save_config()


func _on_allow_chaining_toggled(toggled_on: bool) -> void:
	_allow_chaining = toggled_on
	update_config()
	save_config()


func _on_include_children_checkbox_toggled(toggled_on: bool) -> void:
	_include_children = toggled_on
	update_config()
	save_config()


func _on_rotation_changed(value: float):
	# TODO: add undo/redo later
	if current_selected_bone:
		var bone_cel = current_selected_bone.get_current_bone_cel()
		var old_update_children = bone_cel.should_update_children
		bone_cel.should_update_children = _include_children
		bone_cel.bone_rotation = deg_to_rad(value)
		Global.canvas.skeleton.queue_redraw()
		Global.canvas.queue_redraw()
		bone_cel.should_update_children = old_update_children


func _on_position_changed(value: Vector2):
	# TODO: add undo/redo later
	if current_selected_bone:
		var bone_cel = current_selected_bone.get_current_bone_cel()
		var old_update_children = bone_cel.should_update_children
		bone_cel.should_update_children = _include_children
		bone_cel.start_point = current_selected_bone.rel_to_origin(value).ceil()
		Global.canvas.skeleton.queue_redraw()
		Global.canvas.queue_redraw()
		bone_cel.should_update_children = old_update_children


func _on_rotation_reset_menu_about_to_popup() -> void:
	populate_popup(rotation_reset_menu.get_popup(), {"bone_rotation": 0})


func _on_position_reset_menu_about_to_popup() -> void:
	populate_popup(position_reset_menu.get_popup(), {"start_point": Vector2.ZERO})


func _on_quick_set_bones_menu_about_to_popup() -> void:
	populate_popup(quick_set_bones_menu.get_popup())


func _on_copy_pose_from_about_to_popup() -> void:
	var popup := copy_pose_from.get_popup()
	popup.clear(true)
	var project = Global.current_project
	var bone_layers = PackedInt32Array()
	for layer in project.layers:
		if layer is BoneLayer:
			bone_layers.push_back(layer.index)
	var reference_props := merge_bone_data(project.current_frame, bone_layers)
	bone_layers.reverse()  ## makes the parent bones come first
	for frame_idx in project.frames.size():
		if project.current_frame == frame_idx:
			# It won't make a difference if we skip it or not (as the system will autoatically)
			# skip it anyway (but it's bet to skip it ourselves to avoid unnecessary calculations)
			continue
		var frame_data = merge_bone_data(frame_idx, bone_layers)
		if reference_props != frame_data:  # Checks if this pose is already added to list
			var popup_submenu = PopupMenu.new()
			popup_submenu.about_to_popup.connect(
				populate_popup.bind(popup_submenu, reference_props, frame_idx)
			)
			popup.add_submenu_node_item(str("Frame ", frame_idx + 1), popup_submenu)
			popup_submenu.index_pressed.connect(
				copy_bone_data.bind(frame_idx, popup_submenu)
			)


func _on_tween_skeleton_about_to_popup() -> void:
	var popup := tween_skeleton_menu.get_popup()
	var project = Global.current_project
	popup.clear(true)
	var bone_layers = PackedInt32Array()
	for layer in project.layers:
		if layer is BoneLayer:
			bone_layers.push_back(layer.index)
	var reference_props := merge_bone_data(project.current_frame, bone_layers)
	bone_layers.reverse()  ## makes the parent bones come first
	popup.add_separator("Start From")
	for frame_idx in project.frames.size():
		if frame_idx >= project.current_frame:
			# It won't make a difference if we skip it or not (as the system will autoatically)
			# skip it anyway (but it's bet to skip it ourselves to avoid unnecessary calculations)
			break
		var frame_data = merge_bone_data(frame_idx, bone_layers)
		if reference_props != frame_data:  # Checks if this pose is already added to list
			var popup_submenu = PopupMenu.new()
			popup_submenu.about_to_popup.connect(
				populate_popup.bind(popup_submenu, reference_props, frame_idx)
			)
			popup.add_submenu_node_item(str("Frame ", frame_idx + 1), popup_submenu)
			popup_submenu.index_pressed.connect(
				tween_skeleton_data.bind(frame_idx, popup_submenu)
			)


# UI "updating" signals
func _sync_ui(from_idx: int, data: Dictionary):
	if tool_slot.button != from_idx:
		Global.canvas.skeleton.sync_ui.disconnect(_sync_ui)
		set_config(data)
		update_config()
		save_config()
		Global.canvas.skeleton.sync_ui.connect(_sync_ui)


func _queue_display_props() -> void:
	if is_inside_tree():
		await get_tree().process_frame
	display_props()


func _on_project_data_changed(_project):
	display_props()


# Bone "apply" signals
func quick_set_bones(bone_index: int):
	Global.current_project.undo_redo.create_action("Quick set bones")
	var bones = get_selected_bones(quick_set_bones_menu.get_popup(), bone_index)
	var project := Global.current_project
	var frame := project.frames[project.current_frame]
	for bone: BoneLayer in bones:
		if _include_children or bone_index == 0:
			for child_bone in bone.get_child_bones(true):
				bones.append(child_bone)
		var bone_cel := bone.get_current_bone_cel()
		var old_data := bone_cel.serialize()
		var best_origin := Vector2(bone.get_best_origin(frame))
		project.undo_redo.add_do_method(
			bone_cel.reset.bind({"gizmo_origin": best_origin})
		)
		project.undo_redo.add_undo_method(
			bone_cel.deserialize.bind(old_data)
		)
	commit_undo(true)


func copy_bone_data(bone_index: int, from_frame: int, popup: PopupMenu):
	Global.current_project.undo_redo.create_action("Copy pose")
	var bones := get_selected_bones(popup, bone_index)
	var project := Global.current_project
	for bone: BoneLayer in bones:
		if _include_children or bone_index == 0:
			for child_bone in bone.get_child_bones(true):
				bones.append(child_bone)
		var bone_cel := bone.get_current_bone_cel()
		var from_cel: BoneCel = project.frames[from_frame].cels[bone.index]
		project.undo_redo.add_undo_method(
			bone_cel.deserialize.bind(bone_cel.serialize())
		)
		project.undo_redo.add_do_method(
			bone_cel.deserialize.bind(from_cel.serialize())
		)
	copy_pose_from.get_popup().hide()
	copy_pose_from.get_popup().clear(true)  # To save Memory
	commit_undo(true)


func tween_skeleton_data(bone_index: int, from_frame: int, popup: PopupMenu):
	Global.current_project.undo_redo.create_action("Tween Skeleton")
	var bones := get_selected_bones(popup, bone_index)
	var project := Global.current_project
	var props := bones[0].get_current_bone_cel().serialize().keys()
	for frame_idx in range(from_frame + 1, project.current_frame):
		for bone: BoneLayer in bones:
			if _include_children or bone_index == 0:
				for child_bone in bone.get_child_bones(true):
					bones.append(child_bone)
			var to_cel: BoneCel = project.frames[project.current_frame].cels[bone.index]
			var bone_cel: BoneCel = project.frames[frame_idx].cels[bone.index]
			var from_cel: BoneCel = project.frames[from_frame].cels[bone.index]
			var old_update = bone_cel.should_update_children
			project.undo_redo.add_do_property(bone_cel, "should_update_children", false)
			project.undo_redo.add_undo_property(bone_cel, "should_update_children", false)
			for property: String in props:
				if typeof(bone_cel.get(property)) != TYPE_STRING:
					project.undo_redo.add_undo_method(
						bone_cel.set.bind(property, bone_cel.get(property))
					)
					project.undo_redo.add_do_method(bone_cel.set.bind(
						property,
						Tween.interpolate_value(
							from_cel.get(property),
							to_cel.get(property) - from_cel.get(property),
							frame_idx - from_frame,
							project.current_frame - from_frame,
							Tween.TRANS_LINEAR,
							Tween.EASE_IN
						)
					)
				)
			project.undo_redo.add_undo_property(bone_cel, "should_update_children", old_update)
			project.undo_redo.add_do_property(bone_cel, "should_update_children", old_update)
	copy_pose_from.get_popup().hide()
	copy_pose_from.get_popup().clear(true)  # To save Memory
	commit_undo(true)


func reset_bone_angle(bone_index: int):
	var bones := get_selected_bones(rotation_reset_menu.get_popup(), bone_index)
	var project := Global.current_project
	for bone: BoneLayer in bones:
		if _include_children or bone_index == 0:
			for child_bone in bone.get_child_bones(true):
				bones.append(child_bone)
		var bone_cel: BoneCel = project.frames[project.current_frame].cels[bone.index]
		var old_update = bone_cel.should_update_children
		bone_cel.should_update_children = false
		bone_cel.bone_rotation = 0
		bone_cel.should_update_children = true
	Global.canvas.skeleton.queue_redraw()
	Global.canvas.queue_redraw()


func reset_bone_position(bone_index: int):
	var bones := get_selected_bones(position_reset_menu.get_popup(), bone_index)
	var project := Global.current_project
	for bone: BoneLayer in bones:
		if _include_children or bone_index == 0:
			for child_bone in bone.get_child_bones(true):
				bones.append(child_bone)
		var bone_cel: BoneCel = project.frames[project.current_frame].cels[bone.index]
		var old_update = bone_cel.should_update_children
		bone_cel.should_update_children = false
		bone_cel.start_point = Vector2.ZERO
		bone_cel.should_update_children = true
	Global.canvas.skeleton.queue_redraw()
	Global.canvas.queue_redraw()


# Tool draw actions
func draw_start(_pos: Vector2i) -> void:
	Global.current_project.undo_redo.create_action("Move bone")
	# If this tool is on both sides then only allow one at a time
	if Global.canvas.skeleton.transformation_active:
		return
	Global.canvas.skeleton.transformation_active = true
	is_transforming = true
	current_selected_bone = Global.canvas.skeleton.selected_bone
	var mouse_point: Vector2 = Global.canvas.current_pixel
	if !current_selected_bone:
		return
	var bone_cel = current_selected_bone.get_current_bone_cel()
	if current_selected_bone.modify_mode == BoneLayer.NONE:
		# When moving mouse we may stop hovering but we are still modifying that bone.
		# this is why we need a sepatate modify_mode variable
		current_selected_bone.modify_mode = current_selected_bone.hover_mode(
			Vector2(mouse_point), Global.camera.zoom
		)
	if _prev_mouse_position == Vector2.INF:
		_displace_offset = current_selected_bone.rel_to_start_point(mouse_point)
		_prev_mouse_position = mouse_point

	## Check if bone is a parent of anything (skip if it is)
	Global.current_project.undo_redo.add_undo_method(
		bone_cel.deserialize.bind(bone_cel.serialize(), true)
	)
	if _allow_chaining and BoneLayer.get_parent_bone(current_selected_bone):
		var parent_bone = BoneLayer.get_parent_bone(current_selected_bone)
		var parent_b_cel = Global.current_project.frames[Global.current_project.current_frame].cels[
			parent_bone.index
		]
		var bone_start: Vector2i = current_selected_bone.rel_to_global(bone_cel.start_point)
		var parent_start: Vector2i = parent_bone.rel_to_global(parent_b_cel.start_point)
		_distance_to_parent = bone_start.distance_to(parent_start)
		Global.current_project.undo_redo.add_undo_method(
			parent_b_cel.deserialize.bind(parent_b_cel.serialize(), false)
		)

	display_props()


func draw_move(_pos: Vector2i) -> void:
	# Another tool is already active
	if not is_transforming:
		return
	# We need mouse_point to be a Vector2 in order for rotation to work properly.
	var mouse_point: Vector2 = Global.canvas.current_pixel.floor()
	var offset := mouse_point - _prev_mouse_position
	if !current_selected_bone:
		return
	var bone_cel = current_selected_bone.get_current_bone_cel()
	if _allow_chaining and BoneLayer.get_parent_bone(current_selected_bone):
		# This section manages chaining. It changes the Global.canvas.skeleton.selected_bone
		# to point the parent instead if chained
		match current_selected_bone.modify_mode:
			BoneLayer.DISPLACE:
				_chained_gizmo = current_selected_bone
				current_selected_bone = BoneLayer.get_parent_bone(current_selected_bone)
				current_selected_bone.modify_mode = BoneLayer.ROTATE
				Global.canvas.skeleton.selected_bone = current_selected_bone
				_chained_gizmo.modify_mode = BoneLayer.NONE
	if current_selected_bone.modify_mode == BoneLayer.DISPLACE:
		var old_update_children = bone_cel.should_update_children
		if Input.is_action_pressed(&"transform_move_selection_only", true):
			bone_cel.gizmo_origin += offset.rotated(-bone_cel.bone_rotation)
			bone_cel.should_update_children = false
		bone_cel.start_point = Vector2i(
			(current_selected_bone.rel_to_origin(mouse_point) - _displace_offset)
		)
		bone_cel.should_update_children = old_update_children
	elif (
		current_selected_bone.modify_mode == BoneLayer.ROTATE
		or current_selected_bone.modify_mode == BoneLayer.EXTEND
	):
		var localized_mouse_norm: Vector2 = current_selected_bone.rel_to_start_point(mouse_point).normalized()
		var localized_prev_mouse_norm: Vector2 = current_selected_bone.rel_to_start_point(
			_prev_mouse_position
		).normalized()
		var diff := localized_mouse_norm.angle_to(localized_prev_mouse_norm)
		if Input.is_action_pressed(&"transform_move_selection_only", true):
			bone_cel.gizmo_rotate_origin -= diff
			if current_selected_bone.modify_mode == BoneLayer.EXTEND:
				bone_cel.gizmo_length = current_selected_bone.rel_to_start_point(mouse_point).length()
		else:
			bone_cel.bone_rotation -= diff
			if _allow_chaining and _chained_gizmo:
				_chained_gizmo.get_current_bone_cel().bone_rotation += diff
	if _live_update:
		if ProjectSettings.get_setting("rendering/driver/threads/thread_model") != 2:
			Global.canvas.queue_redraw()
		else:  # Multi-threaded mode (Currently pixelorama is single threaded)
			if not live_thread.is_alive():
				var error := live_thread.start(Global.canvas.queue_redraw)
				if error != OK:  # Thread failed, so do this the hard way.
					Global.canvas.queue_redraw()
	else:
		Global.canvas.skeleton.queue_redraw()
	_prev_mouse_position = mouse_point
	display_props()


func draw_end(_pos: Vector2i) -> void:
	_prev_mouse_position = Vector2.INF
	_displace_offset = Vector2.ZERO
	_chained_gizmo = null
	if Global.canvas.skeleton:
		# Another tool is already active
		if not is_transforming:
			commit_undo()
			return
		is_transforming = false
		Global.canvas.skeleton.transformation_active = false
		if current_selected_bone:
			var bone_cel = current_selected_bone.get_current_bone_cel()
			Global.current_project.undo_redo.add_do_method(
				bone_cel.deserialize.bind(bone_cel.serialize(), true)
			)
			if current_selected_bone.modify_mode != BoneLayer.NONE:
				Global.canvas.queue_redraw()
				current_selected_bone.modify_mode = BoneLayer.NONE
			if _allow_chaining:
				for child in current_selected_bone.get_child_bones(false):
					var child_cel = child.get_current_bone_cel()
					Global.current_project.undo_redo.add_do_method(
						child_cel.deserialize.bind(child_cel.serialize(), true)
					)
	commit_undo()
	Global.current_project.has_changed = true
	display_props()


## Helper functions
func commit_undo(execute := false):
	var undo_redo = Global.current_project.undo_redo
	undo_redo.add_do_method(Global.canvas.queue_redraw)
	undo_redo.add_undo_method(Global.canvas.queue_redraw)
	undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	undo_redo.commit_action(execute)


func populate_popup(
	popup: PopupMenu, reference_properties := {}, frame_idx := Global.current_project.current_frame
):
	popup.clear()
	popup.add_item("All Bones")
	var items_added_after_prev_separator := true
	var project := Global.current_project
	for bone_idx in range(project.layers.size() - 1, -1, -1):
		var bone: BaseLayer = project.layers[bone_idx]
		if !bone is BoneLayer:
			continue
		var bone_reset_reference = reference_properties
		if not BoneLayer.get_parent_bone(bone) and items_added_after_prev_separator:  ## Root nodes
			popup.add_separator(str("Root:", bone.name))
			items_added_after_prev_separator = false
		# NOTE: root node may or may not get added to list but we still need a separator
		if bone_reset_reference.is_empty():
			popup.add_item(bone.name, bone_idx)
			items_added_after_prev_separator = true
		else:
			if bone.index in reference_properties.keys():
				bone_reset_reference = reference_properties[bone.index]
			var bone_cel: BoneCel = project.frames[frame_idx].cels[bone.index]
			for property: String in bone_reset_reference.keys():
				if typeof(bone_reset_reference[property]) == TYPE_STRING:
					bone_reset_reference[property] = str_to_var(bone_reset_reference[property])
				if bone_cel.get(property) != bone_reset_reference[property]:
					popup.add_item(bone.name, bone_idx)
					items_added_after_prev_separator = true
					break
	if popup.is_item_separator(popup.item_count - 1):
		popup.remove_item(popup.item_count - 1)


func get_selected_bones(popup: PopupMenu, bone_index: int) -> Array[BoneLayer]:
	var bone_names: Array[BoneLayer] = []
	var project := Global.current_project
	if bone_index == 0: # All bones (we only need root layers for this)
		for layer in project.layers:
			if layer is BaseLayer and BoneLayer.get_parent_bone(layer) == null:
				bone_names.append(layer)
	else:
		var bone_idx: int = popup.get_item_id(bone_index)
		if bone_idx < project.layers.size() and bone_idx >= 0:
			if project.layers[bone_idx] is BoneLayer:
				bone_names.append(project.layers[bone_idx])
	return bone_names


func display_props():
	current_selected_bone = Global.canvas.skeleton.selected_bone
	if current_selected_bone is BoneLayer:
		var frame_cels = Global.current_project.frames[Global.current_project.current_frame].cels
		%BoneProps.visible = true
		%BoneLabel.text = tr("Name:") + " " + current_selected_bone.name
		_rot_slider.set_value_no_signal_update_display(rad_to_deg(frame_cels[current_selected_bone.index].bone_rotation))
		_pos_slider.set_value_no_signal(
			current_selected_bone.rel_to_global(
				frame_cels[current_selected_bone.index].start_point
			)
		)
		_pos_slider.max_value = Global.current_project.size
	else:
		%BoneProps.visible = false


func merge_bone_data(frame_idx: int, bones: PackedInt32Array) -> Dictionary:
	var data = {}
	var project = Global.current_project
	for i in bones.size():
		var test_cel = project.frames[frame_idx].cels[bones[i]]
		if test_cel is BoneCel:
			var cel_data = test_cel.serialize()
			data[bones[i]] = cel_data
	return data
