extends BaseTool

var _skeleton_preview: Node2D
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
var current_selected_bone: BoneLayer  # Just to keep reference easy nothing more

@onready var _pos_slider: ValueSliderV2 = $BoneProps/BonePositionSlider
@onready var _rot_slider: ValueSlider = $BoneProps/BoneRotationSlider
@onready var quick_set_bones_menu: MenuButton = $QuickSetBones
@onready var rotation_reset_menu: MenuButton = $RotationReset
@onready var position_reset_menu: MenuButton = $PositionReset
@onready var copy_pose_from: MenuButton = $CopyPoseFrom
@onready var force_refresh_pose: MenuButton = $ForceRefreshPose
@onready var tween_skeleton_menu: MenuButton = $TweenSkeleton


func _ready() -> void:
	_skeleton_preview = Global.canvas.skeleton
	if _skeleton_preview:
		_skeleton_preview.active_skeleton_tools.append(self)
		_skeleton_preview.queue_redraw()
	if tool_slot.name == "Left tool":
		$ColorRect.color = Global.left_tool_color
	else:
		$ColorRect.color = Global.right_tool_color
	$Label.text = "Skeleton Options"

	Global.cel_switched.connect(queue_display_props)
	Global.project_switched.connect(queue_display_props)
	Global.project_data_changed.connect(_on_project_data_changed)

	quick_set_bones_menu.get_popup().index_pressed.connect(quick_set_bones)
	rotation_reset_menu.get_popup().index_pressed.connect(reset_bone_angle)
	position_reset_menu.get_popup().index_pressed.connect(reset_bone_position)
	force_refresh_pose.get_popup().index_pressed.connect(refresh_pose)
	kname = name.replace(" ", "_").to_lower()
	load_config()


func _on_warn_pressed() -> void:
	var warn_text = """
To avoid any quirky behavior, it is recomended to not tween between
large rotations, and have "Include bone children" enabled.
"""
	Global.popup_error(warn_text)


func load_config() -> void:
	var value = Global.config_cache.get_value(tool_slot.kname, kname, {})
	set_config(value)
	update_config()


func get_config() -> Dictionary:
	var config :Dictionary
	config["live_update"] = _live_update
	config["allow_chaining"] = _allow_chaining
	config["include_children"] = _include_children
	return config


func set_config(config: Dictionary) -> void:
	_live_update = config.get("live_update", _live_update)
	_allow_chaining = config.get("allow_chaining", _allow_chaining)
	_include_children = config.get("include_children", _include_children)


func update_config() -> void:
	%LiveUpdateCheckbox.button_pressed = _live_update
	%AllowChaining.button_pressed = _allow_chaining
	%IncludeChildrenCheckbox.button_pressed = _include_children
	if _skeleton_preview:
		_skeleton_preview.chaining_mode = _allow_chaining
		_skeleton_preview.queue_redraw()


func save_config() -> void:
	var config := get_config()
	Global.config_cache.set_value(tool_slot.kname, kname, config)


func queue_display_props() -> void:
	if is_inside_tree():
		await get_tree().process_frame
	display_props()


func _exit_tree() -> void:
	if _skeleton_preview:
		_skeleton_preview.announce_tool_removal(self)
		_skeleton_preview.queue_redraw()
	Global.cel_switched.disconnect(queue_display_props)
	Global.project_switched.disconnect(queue_display_props)
	Global.project_data_changed.disconnect(_on_project_data_changed)


func draw_start(_pos: Vector2i) -> void:
	if !_skeleton_preview:
		return
	# If this tool is on both sides then only allow one at a time
	if _skeleton_preview.transformation_active:
		return
	_skeleton_preview.transformation_active = true
	is_transforming = true
	current_selected_bone = _skeleton_preview.selected_bone
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

	## TODO Fix later
	## Check if bone is a parent of anything (skip if it is)
	if _allow_chaining and BoneLayer.get_parent_bone(current_selected_bone):
		var parent_bone = BoneLayer.get_parent_bone(current_selected_bone)
		var parent_b_cel = Global.current_project.frames[Global.current_project.current_frame].cels[
			parent_bone.index
		]
		var bone_start: Vector2i = current_selected_bone.rel_to_global(bone_cel.start_point)
		var parent_start: Vector2i = parent_bone.rel_to_global(parent_b_cel.start_point)
		_distance_to_parent = bone_start.distance_to(parent_start)
	display_props()


func draw_move(_pos: Vector2i) -> void:
	# Another tool is already active
	if not is_transforming:
		return
	if !_skeleton_preview:
		return
	# We need mouse_point to be a Vector2 in order for rotation to work properly.
	var mouse_point: Vector2 = Global.canvas.current_pixel
	var offset := mouse_point - _prev_mouse_position
	if !current_selected_bone:
		return
	var bone_cel = current_selected_bone.get_current_bone_cel()
	if _allow_chaining and BoneLayer.get_parent_bone(current_selected_bone):
		match current_selected_bone.modify_mode:  # This manages chaining
			BoneLayer.DISPLACE:
				_chained_gizmo = current_selected_bone
				current_selected_bone = BoneLayer.get_parent_bone(current_selected_bone)
				current_selected_bone.modify_mode = BoneLayer.ROTATE
				_skeleton_preview.selected_bone = current_selected_bone
				_chained_gizmo.modify_mode = BoneLayer.NONE
	if current_selected_bone.modify_mode == BoneLayer.DISPLACE:
		if Input.is_key_pressed(KEY_CTRL):
			_skeleton_preview.ignore_render_once = true
			bone_cel.gizmo_origin += offset.rotated(-bone_cel.bone_rotation)
		bone_cel.start_point = Vector2i(current_selected_bone.rel_to_origin(mouse_point) - _displace_offset)
	elif (
		current_selected_bone.modify_mode == BoneLayer.ROTATE
		or current_selected_bone.modify_mode == BoneLayer.SCALE
	):
		var localized_mouse_norm: Vector2 = current_selected_bone.rel_to_start_point(mouse_point).normalized()
		var localized_prev_mouse_norm: Vector2 = current_selected_bone.rel_to_start_point(
			_prev_mouse_position
		).normalized()
		var diff := localized_mouse_norm.angle_to(localized_prev_mouse_norm)
		if Input.is_key_pressed(KEY_CTRL):
			_skeleton_preview.ignore_render_once = true
			bone_cel.gizmo_rotate_origin -= diff
			if current_selected_bone.modify_mode == BoneLayer.SCALE:
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
	_prev_mouse_position = mouse_point
	display_props()


func draw_end(_pos: Vector2i) -> void:
	_prev_mouse_position = Vector2.INF
	_displace_offset = Vector2.ZERO
	_chained_gizmo = null
	if _skeleton_preview:
		# Another tool is already active
		if not is_transforming:
			return
		is_transforming = false
		_skeleton_preview.transformation_active = false
		if current_selected_bone:
			var bone_cel = current_selected_bone.get_current_bone_cel()
			if current_selected_bone.modify_mode != BoneLayer.NONE:
				Global.canvas.queue_redraw()
				current_selected_bone.modify_mode = BoneLayer.NONE
			if _allow_chaining and BoneLayer.get_parent_bone(current_selected_bone):
				if current_selected_bone.modify_mode == BoneLayer.DISPLACE:
					BoneLayer.get_parent_bone(current_selected_bone).modify_mode = BoneLayer.NONE
	Global.current_project.has_changed = true
	display_props()


func quick_set_bones(bone_id: int):
	pass
	#if _skeleton_preview:
		#var bone_names = get_selected_bone_names(quick_set_bones_menu.get_popup(), bone_id)
		#var new_data = _skeleton_preview.current_frame_data.duplicate(true)
		#for layer_idx: int in Global.current_project.layers.size():
			#var bone_name: StringName = Global.current_project.layers[layer_idx].name
			#if bone_name in bone_names:
				#new_data[bone_name] = _skeleton_preview.current_frame_bones[bone_name].reset_bone(
					#{"gizmo_origin": Vector2(_skeleton_preview.get_best_origin(layer_idx))}
				#)
		#_skeleton_preview.current_frame_data = new_data
		#_skeleton_preview.save_frame_info(Global.current_project)
		#_skeleton_preview.queue_redraw()
		#Global.canvas.queue_redraw()


func copy_bone_data(bone_id: int, from_frame: int, popup: PopupMenu, old_current_frame: int):
	pass
	#if _skeleton_preview:
		#if old_current_frame != _skeleton_preview.current_frame:
			#return
		#var bone_names := get_selected_bone_names(popup, bone_id)
		#var new_data = _skeleton_preview.current_frame_data.duplicate(true)
		#var copy_data: Dictionary = _skeleton_preview.load_frame_info(
			#Global.current_project, from_frame
		#)
		#for bone_name in bone_names:
			#if bone_name in _skeleton_preview.current_frame_bones.keys():
				#new_data[bone_name] = _skeleton_preview.current_frame_bones[bone_name].reset_bone(
					#copy_data.get(bone_name, {})
				#)
		#_skeleton_preview.current_frame_data = new_data
		#_skeleton_preview.save_frame_info(Global.current_project)
		#_skeleton_preview.queue_redraw()
		#Global.canvas.queue_redraw()
		#copy_pose_from.get_popup().hide()
		#copy_pose_from.get_popup().clear(true)  # To save Memory


func refresh_pose(refresh_mode: int):
	pass
	#if _skeleton_preview:
		#var frames := [_skeleton_preview.current_frame]
		#if refresh_mode == 0:  # All frames
			#frames = range(0, Global.current_project.frames.size())
		#for frame_idx in frames:
			#_skeleton_preview.generate_pose(frame_idx)


func tween_skeleton_data(bone_id: int, from_frame: int, popup: PopupMenu, current_frame: int):
	if _skeleton_preview:
		if current_frame != _skeleton_preview.current_frame:
			return
		var bone_names := get_selected_bone_names(popup, bone_id)
		var start_data: Dictionary = _skeleton_preview.load_frame_info(
			Global.current_project, from_frame
		)
		var end_data: Dictionary = _skeleton_preview.load_frame_info(
			Global.current_project, current_frame
		)
		for frame_idx in range(from_frame + 1, current_frame):
			var frame_info: Dictionary = _skeleton_preview.load_frame_info(
				Global.current_project, frame_idx
			)
			for bone_name in bone_names:
				if (
					bone_name in frame_info.keys()
					and bone_name in start_data.keys()
					and bone_name in end_data.keys()
				):
					var bone_dict: Dictionary = frame_info[bone_name]
					for data_key: String in bone_dict.keys():
						if typeof(bone_dict[data_key]) != TYPE_STRING:
							bone_dict[data_key] = Tween.interpolate_value(
								start_data[bone_name][data_key],
								end_data[bone_name][data_key] - start_data[bone_name][data_key],
								frame_idx - from_frame,
								current_frame - from_frame,
								Tween.TRANS_LINEAR,
								Tween.EASE_IN
							)
			_skeleton_preview.save_frame_info(Global.current_project, frame_info, frame_idx)
			_skeleton_preview.generate_pose(frame_idx)
		copy_pose_from.get_popup().hide()
		copy_pose_from.get_popup().clear(true)  # To save Memory


func reset_bone_angle(bone_id: int):
	pass
	### This rotation will also rotate the child bones as the parent bone's angle is changed.
	#var bone_names := get_selected_bone_names(rotation_reset_menu.get_popup(), bone_id)
	#for bone_name in bone_names:
		#if bone_name in _skeleton_preview.current_frame_bones.keys():
			#_skeleton_preview.current_frame_bones[bone_name].bone_rotation = 0
	#_skeleton_preview.queue_redraw()
	#Global.canvas.queue_redraw()


func reset_bone_position(bone_id: int):
	pass
	#var bone_names := get_selected_bone_names(position_reset_menu.get_popup(), bone_id)
	#for bone_name in bone_names:
		#if bone_name in _skeleton_preview.current_frame_bones.keys():
			#_skeleton_preview.current_frame_bones[bone_name].start_point = Vector2.ZERO
	#_skeleton_preview.queue_redraw()
	#Global.canvas.queue_redraw()


func _on_rotation_changed(value: float):
	pass
	### This rotation will also rotate the child bones as the parent bone's angle is changed.
	#if current_selected_bone:
		#if current_selected_bone in _skeleton_preview.current_frame_bones.values():
			#current_selected_bone.bone_rotation = deg_to_rad(value)
			#_skeleton_preview.queue_redraw()
			#Global.canvas.queue_redraw()


func _on_position_changed(value: Vector2):
	pass
	#if current_selected_bone:
		#if current_selected_bone in _skeleton_preview.current_frame_bones.values():
			#current_selected_bone.start_point = current_selected_bone.rel_to_origin(value).ceil()
			#_skeleton_preview.queue_redraw()
			#Global.canvas.queue_redraw()


func _on_quick_set_bones_menu_about_to_popup() -> void:
	if _skeleton_preview:
		populate_popup(quick_set_bones_menu.get_popup())


func _on_rotation_reset_menu_about_to_popup() -> void:
	if _skeleton_preview:
		populate_popup(rotation_reset_menu.get_popup(), {"bone_rotation": 0})


func _on_position_reset_menu_about_to_popup() -> void:
	if _skeleton_preview:
		populate_popup(position_reset_menu.get_popup(), {"start_point": Vector2.ZERO})


func _on_copy_pose_from_about_to_popup() -> void:
	var popup := copy_pose_from.get_popup()
	popup.clear(true)
	if !_skeleton_preview:
		return
	var project = Global.current_project
	var reference_bone_data: Dictionary = _skeleton_preview.current_frame_data
	for frame_idx in Global.current_project.frames.size():
		if _skeleton_preview.current_frame == frame_idx:
			# It won't make a difference if we skip it or not (as the system will autoatically)
			# skip it anyway (but it's bet to skip it ourselves to avoid unnecessary calculations)
			continue
		var frame_data: Dictionary = _skeleton_preview.load_frame_info(project, frame_idx)
		if (
			frame_data != _skeleton_preview.current_frame_data  # Different pose detected
		):
			if reference_bone_data != frame_data:  # Checks if this pose is already added to list
				reference_bone_data = frame_data  # Mark this pose as seen
				var popup_submenu = PopupMenu.new()
				popup_submenu.about_to_popup.connect(
					populate_popup.bind(popup_submenu, reference_bone_data)
				)
				popup.add_submenu_node_item(str("Frame ", frame_idx + 1), popup_submenu)
				popup_submenu.index_pressed.connect(
					copy_bone_data.bind(frame_idx, popup_submenu, _skeleton_preview.current_frame)
				)

func _on_force_refresh_pose_about_to_popup() -> void:
	var popup := force_refresh_pose.get_popup()
	popup.clear(true)
	popup.add_item("All Frames")
	popup.add_separator()
	popup.add_item(str("Current Frame"))


func _on_tween_skeleton_about_to_popup() -> void:
	var popup := tween_skeleton_menu.get_popup()
	var project = Global.current_project
	popup.clear(true)
	popup.add_separator("Start From")
	var reference_bone_data: Dictionary = _skeleton_preview.current_frame_data
	for frame_idx in Global.current_project.frames.size():
		if frame_idx >= _skeleton_preview.current_frame - 1:
			break
		var frame_data: Dictionary = _skeleton_preview.load_frame_info(project, frame_idx)
		if (
			frame_data != _skeleton_preview.current_frame_data  # Different pose detected
		):
			if reference_bone_data != frame_data:  # Checks if this pose is already added to list
				reference_bone_data = frame_data  # Mark this pose as seen
				var popup_submenu = PopupMenu.new()
				popup_submenu.about_to_popup.connect(
					populate_popup.bind(popup_submenu, reference_bone_data)
				)
				popup.add_submenu_node_item(str("Frame ", frame_idx + 1), popup_submenu)
				popup_submenu.index_pressed.connect(
					tween_skeleton_data.bind(frame_idx, popup_submenu, _skeleton_preview.current_frame)
				)

func _on_include_children_checkbox_toggled(toggled_on: bool) -> void:
	_include_children = toggled_on
	update_config()
	save_config()


func _on_allow_chaining_toggled(toggled_on: bool) -> void:
	_allow_chaining = toggled_on
	update_config()
	save_config()


func _on_live_update_pressed(toggled_on: bool) -> void:
	_live_update = toggled_on
	update_config()
	save_config()


func populate_popup(popup: PopupMenu, reference_properties := {}):
	pass
	#popup.clear()
	#if !_skeleton_preview:
		#return
	#if _skeleton_preview.group_names_ordered.is_empty():
		#return
	#popup.add_item("All Bones")
	#var items_added_after_prev_separator := true
	#for bone_key in _skeleton_preview.group_names_ordered:
		#var bone_reset_reference = reference_properties
		#if bone_key in _skeleton_preview.current_frame_bones.keys():
			#var bone = _skeleton_preview.current_frame_bones[bone_key]
			#if bone.parent_bone_name == "" and items_added_after_prev_separator:  ## Root nodes
				#popup.add_separator(str("Root:", bone.bone_name))
				#items_added_after_prev_separator = false
			## NOTE: root node may or may not get added to list but we still need a separator
			#if bone_reset_reference.is_empty():
				#popup.add_item(bone.bone_name)
				#items_added_after_prev_separator = true
			#else:
				#if bone_key in reference_properties.keys():
					#bone_reset_reference = reference_properties[bone_key]
				#for property: String in bone_reset_reference.keys():
					#if bone.get(property) != bone_reset_reference[property]:
						#popup.add_item(bone.bone_name)
						#items_added_after_prev_separator = true
						#break
	#if popup.is_item_separator(popup.item_count - 1):
		#popup.remove_item(popup.item_count - 1)


func get_selected_bone_names(popup: PopupMenu, bone_index: int) -> PackedStringArray:
	#var frame_bones: Array = _skeleton_preview.group_names_ordered
	var bone_names = PackedStringArray()
	#if bone_index == 0: # All bones
		#bone_names = frame_bones
	#else:
		#var bone_name: String = popup.get_item_text(bone_index)
		#bone_names.append(bone_name)
		#if _include_children:
			#for bone_key: String in frame_bones:
				#if bone_key in _skeleton_preview.current_frame_bones.keys():
					#var bone = _skeleton_preview.current_frame_bones[bone_key]
					#if bone.parent_bone_name in bone_names:
						#bone_names.append(bone.bone_name)
	return bone_names


func display_props():
	current_selected_bone = _skeleton_preview.selected_bone
	if _rot_slider.value_changed.is_connected(_on_rotation_changed):  # works for both signals
		_rot_slider.value_changed.disconnect(_on_rotation_changed)
		_pos_slider.value_changed.disconnect(_on_position_changed)
	if current_selected_bone is BoneLayer:
		var frame_cels = Global.current_project.frames[Global.current_project.current_frame].cels
		%BoneProps.visible = true
		%BoneLabel.text = tr("Name:") + " " + current_selected_bone.name
		_rot_slider.value = rad_to_deg(frame_cels[current_selected_bone.index].bone_rotation)
		_pos_slider.value = current_selected_bone.rel_to_global(
			frame_cels[current_selected_bone.index].start_point
		)
		_rot_slider.value_changed.connect(_on_rotation_changed)
		_pos_slider.value_changed.connect(_on_position_changed)
	else:
		%BoneProps.visible = false


func _on_project_data_changed(_project):
	display_props()
