class_name KeyframeTimeline
extends Control

static var frame_ui_size := 50
## Array of keyframe IDs.
static var selected_keyframes: Array[int]
var current_layer: BaseLayer:
	set(value):
		if is_instance_valid(current_layer):
			if current_layer.effects_added_removed.is_connected(_recreate_timeline):
				current_layer.effects_added_removed.disconnect(_recreate_timeline)
		current_layer = value
		_recreate_timeline()
		current_layer.effects_added_removed.connect(_recreate_timeline)
var layer_element_tree_vscrollbar: VScrollBar

@onready var frames_scroll_container: ScrollContainer = %FramesScrollContainer
@onready var track_scroll_container: ScrollContainer = %TrackScrollContainer
@onready var layer_element_tree: Tree = %LayerElementTree
@onready var track_container: VBoxContainer = %TrackContainer
@onready var frames_container: HBoxContainer = %FramesContainer
@onready var properties_container: VBoxContainer = %PropertiesContainer
@onready var no_key_selected_label: Label = %NoKeySelectedLabel


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
	var project := Global.current_project
	current_layer = project.layers[project.current_layer]
	await get_tree().process_frame
	_on_track_scroll_container_resized()


func _on_cel_switched() -> void:
	var project := Global.current_project
	var layer := project.layers[project.current_layer]
	if layer == current_layer:
		return
	current_layer = layer
	unselect_keyframe()


func _on_project_about_to_switch() -> void:
	var project := Global.current_project
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


func _recreate_timeline() -> void:
	layer_element_tree.clear()
	layer_element_tree.create_item()
	for child in track_container.get_children():
		child.queue_free()
	# Await is needed so that the params get added to the layer effect.
	await get_tree().process_frame
	for effect in current_layer.effects:
		var tree_item := layer_element_tree.create_item()
		tree_item.set_text(0, effect.name)
		var track := KeyframeAnimationTrack.new()
		track.custom_minimum_size.x = frames_container.get_combined_minimum_size().x
		track.custom_minimum_size.y = layer_element_tree.get_item_area_rect(tree_item).size.y
		track_container.add_child(track)
		for param_name in effect.params:
			if param_name in ["PXO_time", "PXO_frame_index", "PXO_layer_index"]:
				continue
			var param_tree_item := tree_item.create_child()
			param_tree_item.set_text(0, Keychain.humanize_snake_case(param_name))
			var param_track := KeyframeAnimationTrack.new()
			param_track.timeline = self
			param_track.effect = effect
			param_track.param_name = param_name
			param_track.is_property = true
			var tree_item_area_rect := layer_element_tree.get_item_area_rect(param_tree_item)
			param_track.custom_minimum_size.x = frames_container.get_combined_minimum_size().x
			param_track.custom_minimum_size.y = tree_item_area_rect.size.y
			track_container.add_child(param_track)
			if effect.animated_params.has(param_name):
				for frame_index: int in effect.animated_params[param_name]:
					var key_button := _create_keyframe_button(
						frame_index, param_track, effect.animated_params, param_name
					)
					param_track.add_child(key_button)
	select_keyframes()


func _create_keyframe_button(
	frame_index: int, param_track: KeyframeAnimationTrack, dict: Dictionary, param_name: String
) -> KeyframeButton:
	var key_button := KeyframeButton.new()
	key_button.keyframe_id = dict[param_name][frame_index].get("id", 0)
	key_button.dict = dict
	key_button.param_name = param_name
	key_button.frame_index = frame_index
	key_button.position.x = frame_index * frame_ui_size
	key_button.position.y = param_track.custom_minimum_size.y / 2 - key_button.size.y / 2
	key_button.pressed.connect(_on_keyframe_pressed.bind(key_button))
	key_button.updated_position.connect(update_keyframe_positions)
	return key_button


func _add_ui_frames() -> void:
	for child in frames_container.get_children():
		child.queue_free()
	var project := Global.current_project
	for i in project.frames.size():
		var v_separator := VSeparator.new()
		frames_container.add_child(v_separator)
		var frame_label := Label.new()
		frame_label.text = str(i + 1)
		frame_label.custom_minimum_size.x = frame_ui_size - v_separator.size.x
		frames_container.add_child(frame_label)
	await get_tree().process_frame
	for child in track_container.get_children():
		child.custom_minimum_size.x = frames_container.get_combined_minimum_size().x


func _on_keyframe_pressed(key_button: KeyframeButton) -> void:
	for child in properties_container.get_children():
		if child != no_key_selected_label:
			child.queue_free()
	for selected_keyframe in get_selected_keyframe_buttons():
		selected_keyframe.button_pressed = false
	selected_keyframes = [key_button.keyframe_id]
	select_keyframes()


func select_keyframes() -> void:
	_clear_keyframe_properties_container()
	if selected_keyframes.size() == 0:
		return
	var key_button: KeyframeButton
	for selected_keyframe in get_selected_keyframe_buttons():
		selected_keyframe.button_pressed = true
		# Set the last selected keyframe as the key button.
		key_button = selected_keyframe
	var dict := key_button.dict
	var param_name := key_button.param_name
	var frame_index := key_button.frame_index
	if not dict[param_name].has(frame_index):
		return
	no_key_selected_label.visible = false
	var property_grid := GridContainer.new()
	property_grid.columns = 2
	var value_label := Label.new()
	value_label.text = "Value:"
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	property_grid.add_child(value_label)
	var property = dict[param_name][frame_index]["value"]
	var trans_type = dict[param_name][frame_index]["trans"]
	var ease_type = dict[param_name][frame_index]["ease"]
	if typeof(property) in [TYPE_INT, TYPE_FLOAT]:
		var slider := ValueSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.allow_lesser = true
		slider.allow_greater = true
		slider.value = property
		slider.value_changed.connect(_on_keyframe_property_changed.bind("value"))
		property_grid.add_child(slider)
	elif typeof(property) in [TYPE_VECTOR2, TYPE_VECTOR2I]:
		var slider := ShaderLoader.VALUE_SLIDER_V2_TSCN.instantiate() as ValueSliderV2
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.allow_lesser = true
		slider.allow_greater = true
		slider.value = property
		slider.value_changed.connect(_on_keyframe_property_changed.bind("value"))
		property_grid.add_child(slider)

	var trans_label := Label.new()
	trans_label.text = "Transition:"
	trans_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	property_grid.add_child(trans_label)
	var trans_type_options := OptionButton.new()
	trans_type_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trans_type_options.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	trans_type_options.add_item("Linear", Tween.TRANS_LINEAR)
	trans_type_options.add_item("Quadratic", Tween.TRANS_QUAD)
	trans_type_options.add_item("Cubic", Tween.TRANS_CUBIC)
	trans_type_options.add_item("Quartic", Tween.TRANS_QUART)
	trans_type_options.add_item("Quintic", Tween.TRANS_QUINT)
	trans_type_options.add_item("Exponential", Tween.TRANS_EXPO)
	trans_type_options.add_item("Square root", Tween.TRANS_CIRC)
	trans_type_options.add_item("Sine", Tween.TRANS_SINE)
	trans_type_options.add_item("Elastic", Tween.TRANS_ELASTIC)
	trans_type_options.add_item("Bounce", Tween.TRANS_BOUNCE)
	trans_type_options.add_item("Back", Tween.TRANS_BACK)
	trans_type_options.add_item("Spring", Tween.TRANS_SPRING)
	trans_type_options.add_item("Constant", Tween.TRANS_SPRING + 1)
	trans_type_options.select(trans_type)
	trans_type_options.item_selected.connect(_on_keyframe_property_changed.bind("trans"))
	property_grid.add_child(trans_type_options)

	var easing_label := Label.new()
	easing_label.text = "Easing:"
	easing_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	property_grid.add_child(easing_label)
	var ease_type_options := OptionButton.new()
	ease_type_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ease_type_options.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ease_type_options.add_item("Ease in", Tween.EASE_IN)
	ease_type_options.add_item("Ease out", Tween.EASE_OUT)
	ease_type_options.add_item("Ease in out", Tween.EASE_IN_OUT)
	ease_type_options.add_item("Ease out in", Tween.EASE_OUT_IN)
	ease_type_options.select(ease_type)
	ease_type_options.item_selected.connect(_on_keyframe_property_changed.bind("ease"))
	property_grid.add_child(ease_type_options)
	properties_container.add_child(property_grid)

	var delete_keyframe_button := Button.new()
	delete_keyframe_button.text = "Delete keyframe"
	delete_keyframe_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_keyframe_button.pressed.connect(_on_keyframe_deleted)
	properties_container.add_child(delete_keyframe_button)
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
		_clear_keyframe_properties_container()
		no_key_selected_label.visible = true
		await get_tree().process_frame
		_on_track_scroll_container_resized()


func _clear_keyframe_properties_container() -> void:
	for child in properties_container.get_children():
		if child != no_key_selected_label:
			child.queue_free()


func append_keyframes_to_selection(rect: Rect2) -> void:
	for track in track_container.get_children():
		for keyframe_button in track.get_children():
			if keyframe_button is not KeyframeButton:
				continue
			if rect.has_point(keyframe_button.position + track.position):
				selected_keyframes.append(keyframe_button.keyframe_id)
				keyframe_button.button_pressed = true
	select_keyframes()


func _on_keyframe_property_changed(new_value, property_name: String) -> void:
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


func add_effect_keyframe(effect: LayerEffect, frame_index: int, param_name: String) -> void:
	var next_keyframe_id := effect.layer.next_keyframe_id
	var undo_redo := Global.current_project.undo_redo
	undo_redo.create_action("Add keyframe")
	undo_redo.add_do_method(effect.set_keyframe.bind(param_name, frame_index))
	undo_redo.add_undo_method(func(): effect.animated_params[param_name].erase(frame_index))
	undo_redo.add_undo_method(unselect_keyframe.bind(next_keyframe_id))
	undo_redo.add_do_method(_recreate_timeline)
	undo_redo.add_undo_method(_recreate_timeline)
	undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	undo_redo.commit_action()


func _on_keyframe_deleted() -> void:
	var undo_redo := Global.current_project.undo_redo
	undo_redo.create_action("Delete keyframe")
	for key_button in get_selected_keyframe_buttons():
		var dict := key_button.dict
		var param_name := key_button.param_name
		var frame_index := key_button.frame_index
		var old_dict = dict[param_name][frame_index].duplicate()
		undo_redo.add_do_method(func(): dict[param_name].erase(frame_index))
		undo_redo.add_undo_method(func(): dict[param_name][frame_index] = old_dict)
		undo_redo.add_do_method(unselect_keyframe.bind(key_button.keyframe_id))
	undo_redo.add_do_method(_recreate_timeline)
	undo_redo.add_undo_method(_recreate_timeline)
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

	undo_redo.add_do_method(_recreate_timeline)
	undo_redo.add_undo_method(_recreate_timeline)
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
	var margin_container := frames_container.get_parent().get_parent() as MarginContainer
	margin_container.add_theme_constant_override(
		&"margin_left", layer_element_tree.size.x + split_separation
	)
	margin_container.add_theme_constant_override(
		&"margin_right", properties_container.size.x + split_separation
	)


func _on_frames_scroll_container_sort_children() -> void:
	track_scroll_container.scroll_horizontal = frames_scroll_container.scroll_horizontal


func _on_track_scroll_container_sort_children() -> void:
	frames_scroll_container.scroll_horizontal = track_scroll_container.scroll_horizontal
	if is_instance_valid(layer_element_tree_vscrollbar):
		layer_element_tree_vscrollbar.value = track_scroll_container.scroll_vertical


func _on_layer_element_tree_vertical_scrolling() -> void:
	track_scroll_container.scroll_vertical = layer_element_tree.get_scroll().y


func _on_layer_element_tree_gui_input(_event: InputEvent) -> void:
	track_scroll_container.scroll_vertical = layer_element_tree.get_scroll().y
