extends BaseTool

enum IKAlgorithms { FABRIK, CCDIK }
var is_transforming := false
var generation_threshold: float = 20
var live_thread := Thread.new()

var _live_update := false
var _allow_chaining := false
var _use_ik := true
var _ik_protocol: int = IKAlgorithms.FABRIK
var _chain_length: int = 2
var _max_ik_itterations: int = 20
var _ik_error_margin: float = 0.1
var _include_children := true
var _displace_offset := Vector2.ZERO
var _prev_mouse_position := Vector2.INF
var _hover_layer_in_chain = null
var _undo_target_frames := PackedInt32Array()
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
	super()


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
	config["use_ik"] = _use_ik
	config["ik_protocol"] = _ik_protocol
	config["chain_length"] = _chain_length
	config["max_ik_itterations"] = _max_ik_itterations
	config["ik_error_margin"] = _ik_error_margin
	config["include_children"] = _include_children
	return config


func set_config(config: Dictionary) -> void:
	super.set_config(config)
	_live_update = config.get("live_update", _live_update)
	_allow_chaining = config.get("allow_chaining", _allow_chaining)
	_use_ik = config.get("use_ik", _use_ik)
	_ik_protocol = config.get("ik_protocol", _ik_protocol)
	_chain_length = config.get("chain_length", _chain_length)
	_max_ik_itterations = config.get("max_ik_itterations", _max_ik_itterations)
	_ik_error_margin = config.get("ik_error_margin", _ik_error_margin)
	_include_children = config.get("include_children", _include_children)


func update_config() -> void:
	super.update_config()
	%LiveUpdateCheckbox.set_pressed_no_signal(_live_update)
	%AllowChaining.set_pressed_no_signal(_allow_chaining)
	%InverseKinematics.set_pressed_no_signal(_use_ik)
	%AlgorithmOption.select(_ik_protocol)
	%ChainSize.set_value_no_signal_update_display(_chain_length)
	%IKIterations.set_value_no_signal_update_display(_max_ik_itterations)
	%IKErrorMargin.set_value_no_signal_update_display(_ik_error_margin)
	%IncludeChildrenCheckbox.set_pressed_no_signal(_include_children)
	%ChainingOptions.visible = _allow_chaining
	%IKOptions.visible = _use_ik
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


func _on_inverse_kinematics_toggled(toggled_on: bool) -> void:
	_use_ik = toggled_on
	update_config()
	save_config()


func _on_algorithm_selected(index: int) -> void:
	_ik_protocol = index
	update_config()
	save_config()


func _on_chain_size_value_changed(value: float) -> void:
	_chain_length = value
	update_config()
	save_config()


func _on_ik_iterations_value_changed(value: float) -> void:
	_max_ik_itterations = value
	update_config()
	save_config()


func _on_ik_error_margin_value_changed(value: float) -> void:
	_ik_error_margin = value
	update_config()
	save_config()


func _on_rotation_changed(value: float):
	if current_selected_bone:
		var bone_cel = current_selected_bone.get_current_bone_cel()
		var old_update_children = bone_cel.should_update_children
		bone_cel.should_update_children = _include_children
		bone_cel.bone_rotation = deg_to_rad(value)
		Global.canvas.skeleton.queue_redraw()
		Global.canvas.queue_redraw()
		bone_cel.should_update_children = old_update_children


func _on_position_changed(value: Vector2):
	if current_selected_bone:
		var bone_cel = current_selected_bone.get_current_bone_cel()
		var old_update_children = bone_cel.should_update_children
		bone_cel.should_update_children = _include_children
		bone_cel.start_point = bone_cel.rel_to_origin(value).ceil()
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
			popup_submenu.index_pressed.connect(copy_bone_data.bind(frame_idx, popup_submenu))


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
			popup_submenu.index_pressed.connect(tween_skeleton_data.bind(frame_idx, popup_submenu))


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
	var looper := bones.duplicate()
	var project := Global.current_project
	var frame := project.frames[project.current_frame]
	for bone: BoneLayer in looper:
		if (_include_children or bone_index == 0) and bone in bones:
			var child_bones = bone.get_child_bones(true)
			child_bones.reverse()
			looper.append_array(child_bones)
		var bone_cel := bone.get_current_bone_cel()
		var old_data := bone_cel.serialize()
		var best_origin := Vector2(bone.get_best_origin(frame))
		project.undo_redo.add_do_method(bone_cel.reset.bind({"gizmo_origin": best_origin}))
		project.undo_redo.add_undo_method(bone_cel.deserialize.bind(old_data))
	commit_undo(true)


func copy_bone_data(bone_index: int, from_frame: int, popup: PopupMenu):
	Global.current_project.undo_redo.create_action("Copy pose")
	var bones := get_selected_bones(popup, bone_index)
	var looper := bones.duplicate()
	var project := Global.current_project
	for bone: BoneLayer in looper:
		if (_include_children or bone_index == 0) and bone in bones:
			var child_bones = bone.get_child_bones(true)
			child_bones.reverse()
			looper.append_array(child_bones)
		var bone_cel := bone.get_current_bone_cel()
		var from_cel: BoneCel = project.frames[from_frame].cels[bone.index]
		project.undo_redo.add_undo_method(bone_cel.deserialize.bind(bone_cel.serialize()))
		project.undo_redo.add_do_method(bone_cel.deserialize.bind(from_cel.serialize()))
	copy_pose_from.get_popup().hide()
	copy_pose_from.get_popup().clear(true)  # To save Memory
	commit_undo(true)


func tween_skeleton_data(bone_index: int, from_frame: int, popup: PopupMenu):
	Global.current_project.undo_redo.create_action("Tween Skeleton")
	var bones := get_selected_bones(popup, bone_index)
	var looper := bones.duplicate()
	var project := Global.current_project
	var props := bones[0].get_current_bone_cel().serialize().keys()
	for frame_idx in range(from_frame + 1, project.current_frame):
		for bone: BoneLayer in looper:
			if (_include_children or bone_index == 0) and bone in bones:
				var child_bones = bone.get_child_bones(true)
				child_bones.reverse()
				looper.append_array(child_bones)
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
					project.undo_redo.add_do_method(
						bone_cel.set.bind(
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
	Global.current_project.undo_redo.create_action("Reset Rotation")
	var bones := get_selected_bones(rotation_reset_menu.get_popup(), bone_index)
	var looper := bones.duplicate()
	var project := Global.current_project
	for bone: BoneLayer in looper:
		if (_include_children or bone_index == 0) and bone in bones:
			var child_bones = bone.get_child_bones(true)
			child_bones.reverse()
			looper.append_array(child_bones)
		var bone_cel: BoneCel = project.frames[project.current_frame].cels[bone.index]
		project.undo_redo.add_undo_property(bone_cel, "bone_rotation", bone_cel.bone_rotation)
		project.undo_redo.add_do_property(bone_cel, "bone_rotation", 0)
	commit_undo(true)


func reset_bone_position(bone_index: int):
	Global.current_project.undo_redo.create_action("Reset Position")
	var bones := get_selected_bones(position_reset_menu.get_popup(), bone_index)
	var looper := bones.duplicate()
	var project := Global.current_project
	for bone: BoneLayer in looper:
		if (_include_children or bone_index == 0) and bone in bones:
			var child_bones = bone.get_child_bones(true)
			child_bones.reverse()
			looper.append_array(child_bones)
		var bone_cel: BoneCel = project.frames[project.current_frame].cels[bone.index]
		project.undo_redo.add_undo_property(bone_cel, "start_point", bone_cel.start_point)
		project.undo_redo.add_do_property(bone_cel, "start_point", Vector2.ZERO)
	commit_undo(true)


# Tool draw actions
func draw_start(_pos: Vector2i) -> void:
	_undo_target_frames.clear()
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
		_displace_offset = bone_cel.rel_to_start_point(mouse_point)
		_prev_mouse_position = mouse_point

	display_props()


func add_undo_draw_data():
	if !Global.current_project.current_frame in _undo_target_frames and current_selected_bone:
		var current_cel = current_selected_bone.get_current_bone_cel()
		_undo_target_frames.append(Global.current_project.current_frame)
		Global.current_project.undo_redo.add_undo_method(
			current_cel.deserialize.bind(current_cel.serialize(), true)
		)
		# Check if bone is a parent of anything (skip if it is)
		if _allow_chaining and BoneLayer.get_parent_bone(current_selected_bone):
			if _use_ik:
				for cel in get_ik_cels(current_selected_bone):
					Global.current_project.undo_redo.add_undo_method(
						cel.deserialize.bind(cel.serialize(), false)
					)
			var parent_bone = BoneLayer.get_parent_bone(current_selected_bone)
			var parent_b_cel = (
				Global
				. current_project
				. frames[Global.current_project.current_frame]
				. cels[parent_bone.index]
			)
			Global.current_project.undo_redo.add_undo_method(
				parent_b_cel.deserialize.bind(parent_b_cel.serialize(), false)
			)


func draw_move(_pos: Vector2i) -> void:
	add_undo_draw_data()  # This is done so we can animate while playing
	# Another tool is already active
	if not is_transforming:
		return
	# We need mouse_point to be a Vector2 in order for rotation to work properly.
	var mouse_point: Vector2 = Global.canvas.current_pixel
	var offset := mouse_point - _prev_mouse_position
	if !current_selected_bone or !current_selected_bone is BoneLayer:
		return
	# This is thae cel that is the main focus of rotation
	var bone_cel_in_focus = current_selected_bone.get_current_bone_cel()
	if (
		_allow_chaining
		and BoneLayer.get_parent_bone(current_selected_bone)
		and not Input.is_action_pressed(&"transform_move_selection_only", true)
	):
		# This section manages chaining. It changes the Global.canvas.skeleton.selected_bone
		# to point the parent instead if chained
		match current_selected_bone.modify_mode:
			BoneLayer.DISPLACE:
				if _use_ik:
					var update_canvas := true
					match _ik_protocol:
						IKAlgorithms.FABRIK:
							update_canvas = FABRIK.calculate(
								get_ik_cels(current_selected_bone),
								mouse_point,
								_max_ik_itterations,
								_ik_error_margin
							)
						IKAlgorithms.CCDIK:
							update_canvas = CCDIK.calculate(
								get_ik_cels(current_selected_bone),
								mouse_point,
								_max_ik_itterations,
								_ik_error_margin
							)
					if _live_update and update_canvas:
						Global.canvas.queue_redraw()
					else:
						Global.canvas.skeleton.queue_redraw()
					_prev_mouse_position = mouse_point
					display_props()
					return  # We don't need to do anything further
				else:
					_hover_layer_in_chain = current_selected_bone
					current_selected_bone = BoneLayer.get_parent_bone(current_selected_bone)
					bone_cel_in_focus = current_selected_bone.get_current_bone_cel()
					current_selected_bone.modify_mode = BoneLayer.ROTATE
					Global.canvas.skeleton.selected_bone = current_selected_bone
					_hover_layer_in_chain.modify_mode = BoneLayer.NONE
	if current_selected_bone.modify_mode == BoneLayer.DISPLACE:
		var old_update_children = bone_cel_in_focus.should_update_children
		if Input.is_action_pressed(&"transform_move_selection_only", true):
			bone_cel_in_focus.gizmo_origin += offset.rotated(-bone_cel_in_focus.bone_rotation)
			bone_cel_in_focus.should_update_children = false
		bone_cel_in_focus.start_point = Vector2i(
			bone_cel_in_focus.rel_to_origin(mouse_point) - _displace_offset
		)
		bone_cel_in_focus.should_update_children = old_update_children
	elif (
		current_selected_bone.modify_mode == BoneLayer.ROTATE
		or current_selected_bone.modify_mode == BoneLayer.EXTEND
	):
		var localized_mouse_norm: Vector2 = (
			bone_cel_in_focus.rel_to_start_point(mouse_point).normalized()
		)
		var localized_prev_mouse_norm: Vector2 = (
			bone_cel_in_focus.rel_to_start_point(_prev_mouse_position).normalized()
		)
		var diff := localized_mouse_norm.angle_to(localized_prev_mouse_norm)
		if Input.is_action_pressed(&"transform_move_selection_only", true):
			bone_cel_in_focus.gizmo_rotate_origin -= diff
			if current_selected_bone.modify_mode == BoneLayer.EXTEND:
				bone_cel_in_focus.gizmo_length = (
					bone_cel_in_focus.rel_to_start_point(mouse_point).length()
				)
		else:
			bone_cel_in_focus.bone_rotation -= diff
			if _allow_chaining and _hover_layer_in_chain:
				_hover_layer_in_chain.get_current_bone_cel().bone_rotation += diff
	if _live_update:
		Global.canvas.queue_redraw()
	else:
		Global.canvas.skeleton.queue_redraw()
	_prev_mouse_position = mouse_point
	display_props()


func draw_end(_pos: Vector2i) -> void:
	_prev_mouse_position = Vector2.INF
	_displace_offset = Vector2.ZERO
	_hover_layer_in_chain = null
	if Global.canvas.skeleton:
		# Another tool is already active
		if not is_transforming:
			commit_undo()
			return
		is_transforming = false
		Global.canvas.skeleton.transformation_active = false
		if current_selected_bone:
			var project := Global.current_project
			for frame_idx in _undo_target_frames:
				var bone_cel = current_selected_bone.get_current_bone_cel(frame_idx)
				if not bone_cel is BoneCel:
					continue
				Global.current_project.undo_redo.add_do_method(
					bone_cel.deserialize.bind(bone_cel.serialize(), true)
				)
				if current_selected_bone.modify_mode != BoneLayer.NONE:
					Global.canvas.queue_redraw()
					current_selected_bone.modify_mode = BoneLayer.NONE
				if _allow_chaining:
					if _use_ik:
						for cel in get_ik_cels(current_selected_bone, frame_idx):
							Global.current_project.undo_redo.add_do_method(
								cel.deserialize.bind(cel.serialize(), true)
							)
					else:
						for child in current_selected_bone.get_child_bones(false):
							var child_cel = child.get_current_bone_cel(frame_idx)
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
	if bone_index == 0:  # All bones (we only need root layers for this)
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
	if not _pos_slider.max_value.is_equal_approx(Global.current_project.size):
		# temporarily set it to null to avoid unnecessary update
		current_selected_bone = null
		_pos_slider.max_value = Global.current_project.size
	current_selected_bone = Global.canvas.skeleton.selected_bone
	if current_selected_bone is BoneLayer:
		var frame_cels = Global.current_project.frames[Global.current_project.current_frame].cels
		%BoneProps.visible = true
		%BoneLabel.text = tr("Name:") + " " + current_selected_bone.name
		_rot_slider.set_value_no_signal_update_display(
			rad_to_deg(frame_cels[current_selected_bone.index].bone_rotation)
		)
		_pos_slider.set_value_no_signal(
			frame_cels[current_selected_bone.index].rel_to_canvas(
				frame_cels[current_selected_bone.index].start_point
			)
		)
		return
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


class FABRIK:
	# Initial Implementation by:
	# https://github.com/nezvers/Godot_Public_Examples/blob/master/Nature_code/Kinematics/FABRIK.gd
	# see https://www.youtube.com/watch?v=Ihp6tOCYHug for an intuitive explanation.
	static func calculate(
		bone_cels: Array[BoneCel], target_pos: Vector2, max_itterations: int, errorMargin: float
	) -> bool:
		var posList := PackedVector2Array()
		var lenghts := PackedFloat32Array()
		var totalLength := 0
		for i in bone_cels.size() - 1:
			var p_1 := _get_global_start(bone_cels[i])
			var p_2 := _get_global_start(bone_cels[i + 1])
			posList.append(p_1)
			if i == bone_cels.size() - 2:
				posList.append(p_2)
			var l = p_2.distance_to(p_1)
			lenghts.append(l)
			totalLength += l
		var old_points = posList.duplicate()
		var start_global = posList[0]
		var end_global = posList[posList.size() - 1]
		var distance: float = (target_pos - start_global).length()
		# out of reach, no point of IK
		if distance >= totalLength or posList.size() <= 2:
			for i in bone_cels.size():
				var cel := bone_cels[i]
				if i < bone_cels.size() - 1:
					# find how much to rotate to bring next start point to mach the one in poslist
					var cel_start = _get_global_start(cel)
					var look_old = _get_global_start(bone_cels[i + 1])
					var look_new = target_pos  # what we should look at
					# Rotate to look at the next point
					var angle_diff = (
						cel_start.angle_to_point(look_new) - cel_start.angle_to_point(look_old)
					)
					if !is_equal_approx(angle_diff, 0.0):
						cel.bone_rotation += angle_diff
			return true
		else:
			var errorDist: float = (target_pos - end_global).length()
			var itterations := 0
			# limit the itteration count
			while errorDist > errorMargin && itterations < max_itterations:
				_backward_reach(posList, target_pos, lenghts)  # start at endPos
				_forward_reach(posList, start_global, lenghts)  # start at pinPos
				errorDist = (target_pos - posList[posList.size() - 1]).length()
				itterations += 1
			if old_points == posList:
				return false
			for i in bone_cels.size():
				var cel := bone_cels[i]
				if i < bone_cels.size() - 1:
					# find how much to rotate to bring next start point to mach the one in poslist
					var cel_start = _get_global_start(cel)
					var next_start_old = _get_global_start(bone_cels[i + 1])  # current situation
					var next_start_new = posList[i + 1]  # what should have been
					# Rotate to look at the next point
					var angle_diff = (
						cel_start.angle_to_point(next_start_new)
						- cel_start.angle_to_point(next_start_old)
					)
					if !is_equal_approx(angle_diff, 0.0):
						cel.bone_rotation += angle_diff
			return true

	static func _backward_reach(posList: PackedVector2Array, ending: Vector2, lenghts) -> void:
		var last := posList.size() - 1
		posList[last] = ending  # Place the tail of last vector at ending
		for i in last:
			var head_of_last: Vector2 = posList[last - i]
			var tail_of_next: Vector2 = posList[last - i - 1]
			var dir: Vector2 = (tail_of_next - head_of_last).normalized()
			tail_of_next = head_of_last + (dir * lenghts[i - 1])
			posList[last - 1 - i] = tail_of_next

	static func _forward_reach(posList: PackedVector2Array, starting: Vector2, lenghts) -> void:
		posList[0] = starting  # Place the tail of first vector at starting
		for i in posList.size() - 1:
			var head_of_last: Vector2 = posList[i]
			var tail_of_next: Vector2 = posList[i + 1]
			var dir: Vector2 = (tail_of_next - head_of_last).normalized()
			tail_of_next = head_of_last + (dir * lenghts[i])
			posList[i + 1] = tail_of_next

	static func _get_global_start(cel: BaseCel) -> Vector2:
		return cel.rel_to_canvas(cel.start_point)


class CCDIK:
	# Inspired from:
	# https://github.com/chFleschutz/inverse-kinematics-algorithms/blob/main/src/CCD.h
	static func calculate(
		bone_cels: Array[BoneCel], target_pos: Vector2, max_iterations: int, errorMargin: float
	) -> bool:
		var lenghts := PackedFloat32Array()
		var totalLength := 0
		for i in bone_cels.size() - 1:
			var p_1 := _get_global_start(bone_cels[i])
			var p_2 := _get_global_start(bone_cels[i + 1])
			var l = p_2.distance_to(p_1)
			lenghts.append(l)
			totalLength += l
		var distance: float = (target_pos - _get_global_start(bone_cels[0])).length()
		# Check if the target is reachable
		if totalLength < distance:
			# Stretch
			for i in bone_cels.size():
				var cel := bone_cels[i]
				if i < bone_cels.size() - 1:
					# find how much to rotate to bring next start point to mach the one in poslist
					var cel_start = _get_global_start(cel)
					var look_old = _get_global_start(bone_cels[i + 1])
					var look_new = target_pos  # what we should look at
					# Rotate to look at the next point
					var angle_diff = (
						cel_start.angle_to_point(look_new) - cel_start.angle_to_point(look_old)
					)
					if !is_equal_approx(angle_diff, 0.0):
						cel.bone_rotation += angle_diff
			return true
		for _i in range(max_iterations):
			# Adjust rotation of each bone in the skeleton
			for i in range(bone_cels.size() - 2, -1, -1):
				var pivot_pos = _get_global_start(bone_cels[-1])
				var current_base_pos = _get_global_start(bone_cels[i])
				var base_pivot_vec = pivot_pos - current_base_pos
				var base_target_vec = target_pos - current_base_pos

				# Normalize vectors
				base_pivot_vec = base_pivot_vec.normalized()
				base_target_vec = base_target_vec.normalized()

				var dot = base_pivot_vec.dot(base_target_vec)
				var det = (
					base_pivot_vec.x * base_target_vec.y - base_pivot_vec.y * base_target_vec.x
				)
				var angle_delta = atan2(det, dot)
				if !is_equal_approx(angle_delta, 0.0):
					bone_cels[i].bone_rotation += angle_delta

			# Check for convergence
			var last_cel = bone_cels[bone_cels.size() - 1]
			if (target_pos - last_cel.rel_to_canvas(last_cel.start_point)).length() < errorMargin:
				return true
		return true

	static func _get_global_start(cel: BaseCel) -> Vector2:
		return cel.rel_to_canvas(cel.start_point)


## Returns the cels in the IK chain in order, with the last bone at the end
func get_ik_cels(
	start_layer: BoneLayer, frame_idx := Global.current_project.current_frame
) -> Array[BoneCel]:
	var bone_cels: Array[BoneCel] = []
	var i = 0
	var p = start_layer
	while p:
		bone_cels.push_front(p.get_current_bone_cel())
		p = BoneLayer.get_parent_bone(p)
		i += 1
		if i > _chain_length:
			break
	return bone_cels
