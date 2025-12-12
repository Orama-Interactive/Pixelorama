class_name KeyframeTimeline
extends Control

const KEYFRAME_ICON := preload("uid://yhha3l44svgs")
const KEYFRAME_SELECTED_ICON = preload("uid://dtx6hygsgoifb")

static var frame_ui_size := 50
var current_layer: BaseLayer:
	set(value):
		if is_instance_valid(current_layer):
			if current_layer.effects_added_removed.is_connected(_on_effects_added_removed):
				current_layer.effects_added_removed.disconnect(_on_effects_added_removed)
			for effect in current_layer.effects:
				for connection in effect.keyframe_set.get_connections():
					effect.keyframe_set.disconnect(connection["callable"])
		current_layer = value
		_recreate_timeline()
		current_layer.effects_added_removed.connect(_on_effects_added_removed)
		for effect in current_layer.effects:
			effect.keyframe_set.connect(_recreate_timeline)
var keyframe_button_group := ButtonGroup.new()
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
	_on_keyframe_unselect()


func _on_project_about_to_switch() -> void:
	var project := Global.current_project
	project.frames_updated.disconnect(_add_ui_frames)


func _on_project_switched() -> void:
	var project := Global.current_project
	_add_ui_frames()
	if not project.frames_updated.is_connected(_add_ui_frames):
		project.frames_updated.connect(_add_ui_frames)


func _on_effects_added_removed() -> void:
	# Disconnect keyframe_set signals and connect them again,
	# to handle both effect removal and addition.
	# TODO: This is a very lazy way to handle this,
	# the correct approach would be to have separate added and removed signals for effects.
	for effect in current_layer.effects:
		for connection in effect.keyframe_set.get_connections():
			effect.keyframe_set.disconnect(connection["callable"])
	for effect in current_layer.effects:
		effect.keyframe_set.connect(_recreate_timeline)
	_recreate_timeline()


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
		for param in effect.params:
			if param in ["PXO_time", "PXO_frame_index", "PXO_layer_index"]:
				continue
			var param_tree_item := tree_item.create_child()
			param_tree_item.set_text(0, Keychain.humanize_snake_case(param))
			var param_track := KeyframeAnimationTrack.new()
			param_track.effect = effect
			param_track.param_name = param
			param_track.is_property = true
			var tree_item_area_rect := layer_element_tree.get_item_area_rect(param_tree_item)
			param_track.custom_minimum_size.x = frames_container.get_combined_minimum_size().x
			param_track.custom_minimum_size.y = tree_item_area_rect.size.y
			track_container.add_child(param_track)
			if effect.animated_params.has(param):
				for frame_index: int in effect.animated_params[param]:
					var keyframe := TextureButton.new()
					keyframe.texture_normal = KEYFRAME_ICON
					keyframe.texture_pressed = KEYFRAME_SELECTED_ICON
					keyframe.toggle_mode = true
					keyframe.button_group = keyframe_button_group
					keyframe.position.x = frame_index * frame_ui_size
					keyframe.position.y = (
						param_track.custom_minimum_size.y / 2 - keyframe.size.y / 2
					)
					keyframe.pressed.connect(_on_keyframe_pressed.bind(effect, param, frame_index))
					param_track.add_child(keyframe)


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


func _on_keyframe_pressed(effect: LayerEffect, param_name: String, frame_index: int) -> void:
	for child in properties_container.get_children():
		if child != no_key_selected_label:
			child.queue_free()
	no_key_selected_label.visible = false
	var property_grid := GridContainer.new()
	property_grid.columns = 2
	var value_label := Label.new()
	value_label.text = "Value:"
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	property_grid.add_child(value_label)
	var property = effect.animated_params[param_name][frame_index]["value"]
	var trans_type = effect.animated_params[param_name][frame_index]["trans"]
	var ease_type = effect.animated_params[param_name][frame_index]["ease"]
	if typeof(property) in [TYPE_INT, TYPE_FLOAT]:
		var slider := ValueSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.allow_lesser = true
		slider.allow_greater = true
		slider.value = property
		slider.value_changed.connect(
			_on_keyframe_value_changed.bind(effect.animated_params, frame_index, param_name)
		)
		property_grid.add_child(slider)
	elif typeof(property) in [TYPE_VECTOR2, TYPE_VECTOR2I]:
		var slider := ShaderLoader.VALUE_SLIDER_V2_TSCN.instantiate() as ValueSliderV2
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.allow_lesser = true
		slider.allow_greater = true
		slider.value = property
		slider.value_changed.connect(
			_on_keyframe_value_changed.bind(effect.animated_params, frame_index, param_name)
		)
		property_grid.add_child(slider)

	var trans_label := Label.new()
	trans_label.text = "Transition"
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
	trans_type_options.item_selected.connect(
		_on_keyframe_trans_changed.bind(effect.animated_params, frame_index, param_name)
	)
	property_grid.add_child(trans_type_options)

	var easing_label := Label.new()
	easing_label.text = "Easing"
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
	ease_type_options.item_selected.connect(
		_on_keyframe_ease_changed.bind(effect.animated_params, frame_index, param_name)
	)
	property_grid.add_child(ease_type_options)
	properties_container.add_child(property_grid)

	var delete_keyframe_button := Button.new()
	delete_keyframe_button.text = "Delete keyframe"
	delete_keyframe_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_keyframe_button.pressed.connect(
		_on_keyframe_deleted.bind(effect.animated_params, frame_index, param_name)
	)
	properties_container.add_child(delete_keyframe_button)
	await get_tree().process_frame
	_on_track_scroll_container_resized()


func _on_keyframe_unselect() -> void:
	for child in properties_container.get_children():
		if child != no_key_selected_label:
			child.queue_free()
	no_key_selected_label.visible = true
	await get_tree().process_frame
	_on_track_scroll_container_resized()


func _on_keyframe_value_changed(
	new_value, dict: Dictionary, frame_index: int, param_name: String
) -> void:
	dict[param_name][frame_index]["value"] = new_value
	Global.canvas.queue_redraw()


func _on_keyframe_trans_changed(
	index: int, dict: Dictionary, frame_index: int, param_name: String
) -> void:
	dict[param_name][frame_index]["trans"] = index
	Global.canvas.queue_redraw()


func _on_keyframe_ease_changed(
	index: int, dict: Dictionary, frame_index: int, param_name: String
) -> void:
	dict[param_name][frame_index]["ease"] = index
	Global.canvas.queue_redraw()


func _on_keyframe_deleted(dict: Dictionary, frame_index: int, param_name: String) -> void:
	dict[param_name].erase(frame_index)
	_recreate_timeline()
	_on_keyframe_unselect()
	Global.canvas.queue_redraw()


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
