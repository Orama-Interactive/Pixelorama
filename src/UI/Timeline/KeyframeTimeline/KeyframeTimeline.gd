class_name KeyframeTimeline
extends Control

static var frame_ui_size := 50:
	set(value):
		frame_ui_size = clampi(value, 10, 128)
## Array of keyframe IDs.
static var selected_keyframes: Array[int]
var current_layer: BaseLayer:
	set(value):
		if is_instance_valid(current_layer):
			if current_layer.effect_added.is_connected(_on_effects_added_removed):
				current_layer.effect_added.disconnect(_on_effects_added_removed)
			if current_layer.effect_removed.is_connected(_on_effects_added_removed):
				current_layer.effect_removed.disconnect(_on_effects_added_removed)
		current_layer = value
		recreate_timeline()
		current_layer.effect_added.connect(_on_effects_added_removed)
		current_layer.effect_removed.connect(_on_effects_added_removed)
		await get_tree().process_frame
		await get_tree().process_frame
		keyframe_timeline_cursor.update_position()
		var v_scroll := track_scroll_container.scroll_vertical
		track_scroll_container.ensure_control_visible(keyframe_timeline_cursor)
		track_scroll_container.scroll_vertical = v_scroll
var layer_element_tree_vscrollbar: VScrollBar
## Keeps track of all categories if they are collapsed. It doesn't matter if they exist or not
var collapsed_track_names: PackedStringArray

@onready
var keyframe_timeline_frame_display: KeyframeTimelineFrameDisplay = %KeyframeTimelineFrameDisplay
@onready var track_scroll_container: ScrollContainer = %TrackScrollContainer
@onready var layer_element_tree: Tree = %LayerElementTree
@onready var track_container: VBoxContainer = %TrackContainer
@onready var keyframe_timeline_cursor: Control = %KeyframeTimelineCursor


func _ready() -> void:
	Global.project_about_to_switch.connect(_on_project_about_to_switch)
	Global.project_switched.connect(_on_project_switched)
	Global.cel_switched.connect(_on_cel_switched)
	for child in layer_element_tree.get_children(true):
		if child is VScrollBar:
			layer_element_tree_vscrollbar = child
			child.scrolling.connect(_on_layer_element_tree_vertical_scrolling)
			break
	await get_tree().process_frame
	if not is_instance_valid(current_layer):
		var project := Global.current_project
		current_layer = project.layers[project.current_layer]
		await get_tree().process_frame
	_on_track_scroll_container_resized()


func _input(event: InputEvent) -> void:
	var mouse_pos := get_global_mouse_position()
	var timeline_rect := Rect2(global_position, size)
	if not timeline_rect.has_point(mouse_pos) or not visible:
		return
	if Input.is_key_pressed(KEY_CTRL):
		var zoom := 2 * int(event.is_action("zoom_in")) - 2 * int(event.is_action("zoom_out"))
		if is_zero_approx(zoom):
			return
		frame_ui_size += zoom
		get_viewport().set_input_as_handled()
		keyframe_timeline_frame_display.queue_redraw()
		for track in track_container.get_children():
			if track is not KeyframeAnimationTrack:
				continue
			track.custom_minimum_size.x = frame_ui_size * Global.current_project.frames.size()
			for key_button in track.get_children():
				if key_button is not KeyframeButton:
					continue
				key_button.position.x = key_button.frame_index * frame_ui_size
		keyframe_timeline_cursor.update_position()
	if event.is_action_pressed(&"delete"):
		_on_keyframe_deleted()
		get_viewport().set_input_as_handled()


func _on_cel_switched() -> void:
	var v_scroll := track_scroll_container.scroll_vertical
	track_scroll_container.ensure_control_visible(keyframe_timeline_cursor)
	track_scroll_container.scroll_vertical = v_scroll
	var project := Global.current_project
	var layer := project.layers[project.current_layer]
	if layer == current_layer:
		return
	current_layer = layer
	unselect_keyframe()


func _on_effects_added_removed(_effect: LayerEffect) -> void:
	# Await is needed so that the params get added to the layer effect.
	await get_tree().process_frame
	recreate_timeline()


func _on_project_about_to_switch() -> void:
	var project := Global.current_project
	if project.frames_updated.is_connected(_add_ui_frames):
		project.frames_updated.disconnect(_add_ui_frames)


func _on_project_switched() -> void:
	var project := Global.current_project
	_add_ui_frames()
	if not project.frames_updated.is_connected(_add_ui_frames):
		project.frames_updated.connect(_add_ui_frames)


static func get_selected_keyframe_buttons() -> Array[KeyframeButton]:
	var keyframe_buttons: Array[KeyframeButton]
	for kfb: KeyframeButton in Global.get_tree().get_nodes_in_group(&"KeyframeButtons"):
		if kfb.keyframe_id in selected_keyframes:
			keyframe_buttons.append(kfb)
	return keyframe_buttons


func recreate_timeline() -> void:
	var h_scroll := track_scroll_container.scroll_horizontal
	var v_scroll := track_scroll_container.scroll_vertical
	layer_element_tree.clear()
	for child in track_container.get_children():
		child.queue_free()
	for connection in get_incoming_connections():
		if connection.callable == _keyframe_changed:
			connection.signal.disconnect(_keyframe_changed)
	var root := layer_element_tree.create_item()
	var layer_item := add_section(
		current_layer.name, KeyframeAnimationTrack.TrackTypes.LAYER_EFFECT, root
	)
	current_layer.keyframe_set.connect(_keyframe_changed)
	current_layer.keyframe_unset.connect(_keyframe_changed)
	#region Add tracks for layer's animatable properties.
	for param_name in current_layer.animated_params:
		add_property(
			param_name, KeyframeAnimationTrack.TrackTypes.LAYER_EFFECT, layer_item, current_layer
		)
	#endregion
	#region Add tracks for animatable objects.
	for effect in current_layer.effects:
		effect.keyframe_set.connect(_keyframe_changed)
		effect.keyframe_unset.connect(_keyframe_changed)
		var effect_item := add_section(
			effect.name, KeyframeAnimationTrack.TrackTypes.LAYER_EFFECT, layer_item
		)
		for param_name in effect.params:
			if not effect.is_param_valid(param_name):
				continue
			if param_name in ShaderLoader.UNIFORMS_TO_IGNORE:
				continue
			var value = effect.params[param_name]
			if not AnimatableObject.is_animatable_type(value):
				continue
			add_property(
				param_name, KeyframeAnimationTrack.TrackTypes.LAYER_EFFECT, effect_item, effect
			)
	#endregion
	select_keyframes()
	track_scroll_container.scroll_horizontal = h_scroll
	track_scroll_container.scroll_vertical = v_scroll
	# Hide UI which is un-usable.
	_hide_extra_ui()


func add_section(
	section_name: StringName, track_type: KeyframeAnimationTrack.TrackTypes, parent_item: TreeItem
) -> TreeItem:
	var tree_item := parent_item.create_child()
	tree_item.set_text(0, section_name)
	if section_name in collapsed_track_names:
		tree_item.collapsed = true
	if parent_item.collapsed:
		return
	var track := KeyframeAnimationTrack.new()
	track.type = track_type
	track.custom_minimum_size.x = frame_ui_size * Global.current_project.frames.size()
	track.custom_minimum_size.y = layer_element_tree.get_item_area_rect(tree_item).size.y
	track_container.add_child(track)
	return tree_item


# NOTE: The property to be animated must have a animated_params variable.
func add_property(
	property: StringName,
	param_type: KeyframeAnimationTrack.TrackTypes,
	parent_item: TreeItem,
	animatable_object: AnimatableObject,
	animation_dictionary_name := &"animated_params"
):
	if not is_instance_valid(parent_item):
		return
	var param_tree_item := parent_item.create_child()
	param_tree_item.set_text(0, Keychain.humanize_snake_case(property))
	if parent_item.collapsed:
		return

	var tree_item_area_rect := layer_element_tree.get_item_area_rect(param_tree_item)
	var param_track := KeyframeAnimationTrack.new()
	param_track.type = param_type
	param_track.timeline = self
	param_track.param_name = property
	param_track.is_property = true
	param_track.custom_minimum_size.x = frame_ui_size * Global.current_project.frames.size()
	param_track.custom_minimum_size.y = tree_item_area_rect.size.y
	track_container.add_child(param_track)
	match param_track.type:
		KeyframeAnimationTrack.TrackTypes.LAYER_EFFECT:
			param_track.animatable_object = animatable_object

	var animation_dictionary: Dictionary[String, Dictionary] = animatable_object.get(
		animation_dictionary_name
	)
	if not animation_dictionary:
		return
	if animation_dictionary.has(property):
		for frame_index: int in animation_dictionary[property]:
			var key_button := _create_keyframe_button(
				frame_index, param_track, animation_dictionary, property
			)
			param_track.add_child(key_button)


func _keyframe_changed(_param_name: String) -> void:
	recreate_timeline()


func _hide_extra_ui() -> void:
	var was_visible_before = layer_element_tree.get_parent().visible
	var tree_root := layer_element_tree.get_root()
	layer_element_tree.get_parent().visible = tree_root.get_first_child() != null
	if layer_element_tree.get_parent().visible != was_visible_before:
		await get_tree().process_frame
		_on_track_scroll_container_resized()


func _create_keyframe_button(
	frame_index: int, param_track: KeyframeAnimationTrack, dict: Dictionary, param_name: String
) -> KeyframeButton:
	var key_button := KeyframeButton.new()
	key_button.keyframe_timeline = self
	key_button.keyframe_id = dict[param_name][frame_index].get("id", 0)
	key_button.dict = dict
	key_button.param_name = param_name
	key_button.frame_index = frame_index
	key_button.position.x = frame_index * frame_ui_size
	key_button.position.y = param_track.custom_minimum_size.y / 2 - key_button.size.y / 2
	key_button.pressed.connect(_on_keyframe_pressed.bind(key_button))
	key_button.updated_position.connect(update_keyframe_positions)
	key_button.deleted.connect(_on_keyframe_deleted)
	return key_button


func _add_ui_frames() -> void:
	var project := Global.current_project
	for child in track_container.get_children():
		child.custom_minimum_size.x = frame_ui_size * project.frames.size()


func _on_keyframe_pressed(key_button: KeyframeButton) -> void:
	for selected_keyframe in get_selected_keyframe_buttons():
		selected_keyframe.button_pressed = false
	selected_keyframes = [key_button.keyframe_id]
	select_keyframes()


func select_keyframes() -> void:
	if selected_keyframes.size() == 0:
		return
	var key_button: KeyframeButton
	for selected_keyframe in get_selected_keyframe_buttons():
		selected_keyframe.button_pressed = true
		# Set the last selected keyframe in the array as the key button.
		key_button = selected_keyframe
	if not key_button:
		unselect_keyframe()
		return
	await get_tree().process_frame
	_on_track_scroll_container_resized()


func unselect_keyframe(key_id := -1) -> void:
	if key_id == -1:
		for selected_keyframe_button in get_selected_keyframe_buttons():
			selected_keyframe_button.button_pressed = false
		selected_keyframes.clear()
	else:
		if key_id in selected_keyframes:
			selected_keyframes.erase(key_id)
		for kfb: KeyframeButton in Global.get_tree().get_nodes_in_group(&"KeyframeButtons"):
			if kfb.keyframe_id == key_id:
				kfb.button_pressed = false
	if selected_keyframes.size() == 0:
		await get_tree().process_frame
		_on_track_scroll_container_resized()


func append_keyframes_to_selection(rect: Rect2) -> void:
	for track in track_container.get_children():
		for keyframe_button in track.get_children():
			if keyframe_button is not KeyframeButton:
				continue
			var key_rect := Rect2(keyframe_button.position + track.position, keyframe_button.size)
			if rect.intersects(key_rect):
				selected_keyframes.append(keyframe_button.keyframe_id)
				keyframe_button.button_pressed = true
	select_keyframes()


func on_keyframe_property_changed(new_value, property_name: String) -> void:
	var undo_redo := Global.current_project.undo_redo
	undo_redo.create_action("Change keyframe %s" % property_name, UndoRedo.MERGE_ENDS)
	for key_button in get_selected_keyframe_buttons():
		var dict := key_button.dict
		var param_name := key_button.param_name
		var frame_index := key_button.frame_index
		var old_value = dict[param_name][frame_index][property_name]
		undo_redo.add_do_method(func(): dict[param_name][frame_index][property_name] = new_value)
		undo_redo.add_undo_method(func(): dict[param_name][frame_index][property_name] = old_value)
	undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	undo_redo.commit_action()


func add_effect_keyframe(anim_obj: AnimatableObject, frame_index: int, param_name: String) -> void:
	var project := Global.current_project
	var next_keyframe_id := project.next_keyframe_id
	selected_keyframes = [next_keyframe_id]
	anim_obj.add_keyframe_undo_redo(param_name, frame_index, project)


func _on_keyframe_deleted(keyframe_id := -1) -> void:
	var keyframe_buttons: Array[KeyframeButton]
	if keyframe_id == -1 or keyframe_id in selected_keyframes:
		keyframe_buttons = get_selected_keyframe_buttons()
	else:
		# If the keyframe we are deleting is not selected, find it.
		for kfb: KeyframeButton in Global.get_tree().get_nodes_in_group(&"KeyframeButtons"):
			if kfb.keyframe_id == keyframe_id:
				keyframe_buttons = [kfb]
				break
	if keyframe_buttons.is_empty():
		return
	var undo_redo := Global.current_project.undo_redo
	undo_redo.create_action("Delete keyframe")
	for key_button in keyframe_buttons:
		var track := key_button.get_parent() as KeyframeAnimationTrack
		var dict := key_button.dict
		var param_name := key_button.param_name
		var frame_index := key_button.frame_index
		var old_dict = dict[param_name][frame_index].duplicate()
		var anim_obj := track.animatable_object
		undo_redo.add_do_method(anim_obj.delete_keyframe.bind(param_name, frame_index))
		undo_redo.add_undo_method(
			anim_obj.set_keyframe_data.bind(param_name, frame_index, old_dict)
		)
	undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	undo_redo.commit_action()


func update_keyframe_positions() -> void:
	var undo_redo := Global.current_project.undo_redo
	undo_redo.create_action("Move keyframe(s)")

	# param_dict → [{from, to, data}]
	var moves: Dictionary[Dictionary, Array] = {}

	for kf in get_selected_keyframe_buttons():
		var frame_from := kf.frame_index
		var frame_to := floori(kf.position.x / frame_ui_size)
		if frame_from == frame_to:
			continue
		var param_dict: Dictionary = kf.dict[kf.param_name]
		if not moves.has(param_dict):
			moves[param_dict] = []

		moves[param_dict].append({"from": frame_from, "to": frame_to})
	for param_dict in moves.keys():
		var move_list := moves[param_dict]
		undo_redo.add_do_method(_apply_frame_moves.bind(param_dict, move_list))
		undo_redo.add_undo_method(_apply_frame_moves.bind(param_dict, _invert_moves(move_list)))

	undo_redo.add_do_method(recreate_timeline)
	undo_redo.add_undo_method(recreate_timeline)
	undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	undo_redo.commit_action()


func _apply_frame_moves(param_dict: Dictionary, moves: Array) -> void:
	var temp := {}
	# extract
	for m in moves:
		if param_dict.has(m.from):
			temp[m.to] = param_dict[m.from].duplicate(true)
			param_dict.erase(m.from)
	# insert
	for frame in temp.keys():
		param_dict[frame] = temp[frame]


func _invert_moves(moves: Array) -> Array:
	var inverted := []
	for m in moves:
		inverted.append({"from": m.to, "to": m.from})
	return inverted


func _on_track_scroll_container_resized() -> void:
	var split_separation := get_theme_constant(&"separation", &"SplitContainer")
	var margin_container := keyframe_timeline_frame_display.get_parent() as MarginContainer
	var l_marg := layer_element_tree.size.x if layer_element_tree.is_visible_in_tree() else 0.0
	margin_container.add_theme_constant_override(&"margin_left", l_marg + split_separation)
	margin_container.add_theme_constant_override(&"margin_right", split_separation)
	await get_tree().process_frame
	keyframe_timeline_cursor.update_position()


func _on_track_scroll_container_sort_children() -> void:
	_on_track_scroll_container_resized()
	keyframe_timeline_frame_display.x_offset = track_scroll_container.scroll_horizontal
	keyframe_timeline_frame_display.queue_redraw()
	if is_instance_valid(layer_element_tree_vscrollbar):
		layer_element_tree_vscrollbar.value = track_scroll_container.scroll_vertical


func _on_layer_element_tree_vertical_scrolling() -> void:
	track_scroll_container.scroll_vertical = layer_element_tree.get_scroll().y


func _on_layer_element_tree_gui_input(_event: InputEvent) -> void:
	track_scroll_container.scroll_vertical = layer_element_tree.get_scroll().y


func _on_layer_element_tree_item_collapsed(item: TreeItem) -> void:
	var section_name := item.get_text(0)
	var collapse_state_changed := false
	if item.collapsed and not section_name in collapsed_track_names:
		collapsed_track_names.append(item.get_text(0))
		collapse_state_changed = true
	elif not item.collapsed and section_name in collapsed_track_names:
		collapsed_track_names.erase(item.get_text(0))
		collapse_state_changed = true
	if collapse_state_changed:
		unselect_keyframe()
		await get_tree().process_frame
		recreate_timeline()
