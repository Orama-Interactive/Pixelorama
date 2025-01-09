extends Panel

## Emitted when the animation starts playing.
signal animation_started(forward: bool)
## Emitted when the animation reaches the final frame and is not looping,
## or if the animation is manually paused.
## Note: This signal is not emitted if the animation is looping.
signal animation_finished
## Emitted when the animation loops, meaning when it reaches the final frame
## and the animation keeps playing.
signal animation_looped

enum LoopType { NO, CYCLE, PINGPONG }

const FRAME_BUTTON_TSCN := preload("res://src/UI/Timeline/FrameButton.tscn")
const LAYER_FX_SCENE_PATH := "res://src/UI/Timeline/LayerEffects/LayerEffectsSettings.tscn"

var is_animation_running := false
var animation_loop := LoopType.CYCLE
var animation_forward := true
var first_frame := 0
var last_frame := 0
var is_mouse_hover := false
var cel_size := 36:
	set = _cel_size_changed
var min_cel_size := 36
var max_cel_size := 144
var past_above_canvas := true
var future_above_canvas := true
var layer_effect_settings: AcceptDialog:
	get:
		if not is_instance_valid(layer_effect_settings):
			layer_effect_settings = load(LAYER_FX_SCENE_PATH).instantiate()
			add_child(layer_effect_settings)
		return layer_effect_settings
var global_layer_visibility := true
var global_layer_lock := false
var global_layer_expand := true

@onready var animation_timer := $AnimationTimer as Timer
@onready var old_scroll := 0  ## The previous scroll state of $ScrollContainer.
@onready var tag_spacer := %TagSpacer as Control
@onready var layer_settings_container := %LayerSettingsContainer as VBoxContainer
@onready var layer_container := %LayerContainer as VBoxContainer
@onready var layer_header_container := %LayerHeaderContainer as HBoxContainer
@onready var add_layer_list := %AddLayerList as MenuButton
@onready var remove_layer := %RemoveLayer as Button
@onready var move_up_layer := %MoveUpLayer as Button
@onready var move_down_layer := %MoveDownLayer as Button
@onready var merge_down_layer := %MergeDownLayer as Button
@onready var layer_fx := %LayerFX as Button
@onready var blend_modes_button := %BlendModes as OptionButton
@onready var opacity_slider := %OpacitySlider as ValueSlider
@onready var frame_scroll_container := %FrameScrollContainer as Control
@onready var frame_scroll_bar := %FrameScrollBar as HScrollBar
@onready var tag_scroll_container := %TagScroll as ScrollContainer
@onready var layer_frame_h_split := %LayerFrameHSplit as HSplitContainer
@onready var layer_frame_header_h_split := %LayerFrameHeaderHSplit as HSplitContainer
@onready var delete_frame := %DeleteFrame as Button
@onready var move_frame_left := %MoveFrameLeft as Button
@onready var move_frame_right := %MoveFrameRight as Button
@onready var play_backwards := %PlayBackwards as Button
@onready var play_forward := %PlayForward as Button
@onready var fps_spinbox := %FPSValue as ValueSlider
@onready var onion_skinning_button := %OnionSkinning as BaseButton
@onready var cel_size_slider := %CelSizeSlider as ValueSlider
@onready var loop_animation_button := %LoopAnim as BaseButton
@onready var timeline_settings := $TimelineSettings as Popup
@onready var new_tile_map_layer_dialog := $NewTileMapLayerDialog as ConfirmationDialog
@onready var drag_highlight := $DragHighlight as ColorRect


func _ready() -> void:
	Global.control.find_child("LayerProperties").layer_property_changed.connect(_update_layer_ui)
	min_cel_size = get_tree().current_scene.theme.default_font_size + 24
	layer_container.custom_minimum_size.x = layer_settings_container.size.x + 12
	layer_header_container.custom_minimum_size.x = layer_container.custom_minimum_size.x
	cel_size = min_cel_size
	cel_size_slider.min_value = min_cel_size
	cel_size_slider.max_value = max_cel_size
	cel_size_slider.value = cel_size
	add_layer_list.get_popup().id_pressed.connect(on_add_layer_list_id_pressed)
	frame_scroll_bar.value_changed.connect(_frame_scroll_changed)
	animation_timer.wait_time = 1 / Global.current_project.fps
	fps_spinbox.value = Global.current_project.fps
	_fill_blend_modes_option_button()
	# Config loading.
	layer_frame_h_split.split_offset = Global.config_cache.get_value("timeline", "layer_size", 0)
	layer_frame_header_h_split.split_offset = layer_frame_h_split.split_offset
	cel_size = Global.config_cache.get_value("timeline", "cel_size", cel_size)  # Call setter
	var past_rate = Global.config_cache.get_value(
		"timeline", "past_rate", Global.onion_skinning_past_rate
	)
	var future_rate = Global.config_cache.get_value(
		"timeline", "future_rate", Global.onion_skinning_future_rate
	)
	var blue_red = Global.config_cache.get_value(
		"timeline", "blue_red", Global.onion_skinning_blue_red
	)
	var past_above = Global.config_cache.get_value(
		"timeline", "past_above_canvas", past_above_canvas
	)
	var future_above = Global.config_cache.get_value(
		"timeline", "future_above_canvas", future_above_canvas
	)
	var onion_skinning_opacity = Global.config_cache.get_value(
		"timeline", "onion_skinning_opacity", 0.6
	)
	%OnionSkinningOpacity.value = onion_skinning_opacity * 100.0
	%PastOnionSkinning.value = past_rate
	%FutureOnionSkinning.value = future_rate
	%BlueRedMode.button_pressed = blue_red
	%PastPlacement.select(0 if past_above else 1)
	%FuturePlacement.select(0 if future_above else 1)
	# Emit signals that were supposed to be emitted.
	%PastPlacement.item_selected.emit(0 if past_above else 1)
	%FuturePlacement.item_selected.emit(0 if future_above else 1)
	Global.cel_switched.connect(_cel_switched)
	# Makes sure that the frame and tag scroll bars are in the right place:
	Global.layer_vbox.emit_signal.call_deferred("resized")


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		drag_highlight.hide()
	elif what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_TRANSLATION_CHANGED:
		await get_tree().process_frame
		if is_instance_valid(layer_settings_container):
			layer_container.custom_minimum_size.x = layer_settings_container.size.x + 12
			layer_header_container.custom_minimum_size.x = layer_container.custom_minimum_size.x


func _input(event: InputEvent) -> void:
	var project := Global.current_project
	if event.is_action_pressed("go_to_previous_layer"):
		project.selected_cels.clear()
		if project.current_layer > 0:
			project.change_cel(-1, project.current_layer - 1)
		else:
			project.change_cel(-1, project.layers.size() - 1)
	elif event.is_action_pressed("go_to_next_layer"):
		project.selected_cels.clear()
		if project.current_layer < project.layers.size() - 1:
			project.change_cel(-1, project.current_layer + 1)
		else:
			project.change_cel(-1, 0)

	var mouse_pos := get_global_mouse_position()
	var timeline_rect := Rect2(global_position, size)
	if timeline_rect.has_point(mouse_pos):
		if Input.is_key_pressed(KEY_CTRL):
			var zoom := 2 * int(event.is_action("zoom_in")) - 2 * int(event.is_action("zoom_out"))
			cel_size += zoom
			if zoom != 0:
				get_viewport().set_input_as_handled()


func reset_settings() -> void:
	cel_size = 36
	%OnionSkinningOpacity.value = 60.0
	%PastOnionSkinning.value = 1
	%FutureOnionSkinning.value = 1
	%BlueRedMode.button_pressed = false
	%PastPlacement.select(0)
	%FuturePlacement.select(0)
	%PastPlacement.item_selected.emit(0)
	%FuturePlacement.item_selected.emit(0)
	for onion_skinning_node: Node2D in get_tree().get_nodes_in_group("canvas_onion_skinning"):
		onion_skinning_node.opacity = 0.6
		onion_skinning_node.queue_redraw()


func _get_minimum_size() -> Vector2:
	# X targets enough to see layers, 1 frame, vertical scrollbar, and padding
	# Y targets enough to see 1 layer
	if not is_instance_valid(Global.layer_vbox):
		return Vector2.ZERO
	return Vector2(Global.layer_vbox.size.x + cel_size + 26, cel_size + 105)


func _frame_scroll_changed(_value: float) -> void:
	# Update the tag scroll as well:
	adjust_scroll_container()


func _on_LayerVBox_resized() -> void:
	frame_scroll_bar.offset_left = frame_scroll_container.position.x
	# It doesn't update properly without awaits (for the first time after Pixelorama starts)
	await get_tree().process_frame
	await get_tree().process_frame
	adjust_scroll_container()


func adjust_scroll_container() -> void:
	tag_spacer.custom_minimum_size.x = (
		frame_scroll_container.global_position.x - tag_scroll_container.global_position.x
	)
	tag_scroll_container.get_child(0).custom_minimum_size.x = Global.frame_hbox.size.x
	Global.tag_container.custom_minimum_size = Global.frame_hbox.size
	tag_scroll_container.scroll_horizontal = frame_scroll_bar.value


func _on_LayerFrameSplitContainer_gui_input(event: InputEvent) -> void:
	Global.config_cache.set_value("timeline", "layer_size", layer_frame_h_split.split_offset)
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		update_minimum_size()  # After you're done resizing the layers, update min size


func _cel_size_changed(value: int) -> void:
	if cel_size == value:
		return
	cel_size = clampi(value, min_cel_size, max_cel_size)
	cel_size_slider.value = cel_size
	update_minimum_size()
	Global.config_cache.set_value("timeline", "cel_size", cel_size)
	for layer_button: Control in Global.layer_vbox.get_children():
		layer_button.custom_minimum_size.y = cel_size
		layer_button.size.y = cel_size
	for cel_hbox: Control in Global.cel_vbox.get_children():
		for cel_button: Control in cel_hbox.get_children():
			cel_button.custom_minimum_size.x = cel_size
			cel_button.custom_minimum_size.y = cel_size
			cel_button.size.x = cel_size
			cel_button.size.y = cel_size

	for frame_id: Control in Global.frame_hbox.get_children():
		frame_id.custom_minimum_size.x = cel_size
		frame_id.size.x = cel_size

	for tag_c: Control in Global.tag_container.get_children():
		tag_c.update_position_and_size()


## Fill the blend modes OptionButton with items
func _fill_blend_modes_option_button() -> void:
	blend_modes_button.clear()
	var selected_layers_are_groups := true
	if Global.current_project.layers.size() == 0:
		selected_layers_are_groups = false
	else:
		for idx_pair in Global.current_project.selected_cels:
			var layer := Global.current_project.layers[idx_pair[1]]
			if not layer is GroupLayer:
				selected_layers_are_groups = false
				break
	if selected_layers_are_groups:
		# Special blend mode that appears only when group layers are selected
		blend_modes_button.add_item("Pass through", BaseLayer.BlendModes.PASS_THROUGH)
	blend_modes_button.add_item("Normal", BaseLayer.BlendModes.NORMAL)
	blend_modes_button.add_item("Erase", BaseLayer.BlendModes.ERASE)
	blend_modes_button.add_separator("Darken")
	blend_modes_button.add_item("Darken", BaseLayer.BlendModes.DARKEN)
	blend_modes_button.add_item("Multiply", BaseLayer.BlendModes.MULTIPLY)
	blend_modes_button.add_item("Color burn", BaseLayer.BlendModes.COLOR_BURN)
	blend_modes_button.add_item("Linear burn", BaseLayer.BlendModes.LINEAR_BURN)
	blend_modes_button.add_separator("Lighten")
	blend_modes_button.add_item("Lighten", BaseLayer.BlendModes.LIGHTEN)
	blend_modes_button.add_item("Screen", BaseLayer.BlendModes.SCREEN)
	blend_modes_button.add_item("Color dodge", BaseLayer.BlendModes.COLOR_DODGE)
	blend_modes_button.add_item("Add", BaseLayer.BlendModes.ADD)
	blend_modes_button.add_separator("Contrast")
	blend_modes_button.add_item("Overlay", BaseLayer.BlendModes.OVERLAY)
	blend_modes_button.add_item("Soft light", BaseLayer.BlendModes.SOFT_LIGHT)
	blend_modes_button.add_item("Hard light", BaseLayer.BlendModes.HARD_LIGHT)
	blend_modes_button.add_separator("Inversion")
	blend_modes_button.add_item("Difference", BaseLayer.BlendModes.DIFFERENCE)
	blend_modes_button.add_item("Exclusion", BaseLayer.BlendModes.EXCLUSION)
	blend_modes_button.add_item("Subtract", BaseLayer.BlendModes.SUBTRACT)
	blend_modes_button.add_item("Divide", BaseLayer.BlendModes.DIVIDE)
	blend_modes_button.add_separator("Component")
	blend_modes_button.add_item("Hue", BaseLayer.BlendModes.HUE)
	blend_modes_button.add_item("Saturation", BaseLayer.BlendModes.SATURATION)
	blend_modes_button.add_item("Color", BaseLayer.BlendModes.COLOR)
	blend_modes_button.add_item("Luminosity", BaseLayer.BlendModes.LUMINOSITY)


func _on_blend_modes_item_selected(index: int) -> void:
	var project := Global.current_project
	var current_mode := blend_modes_button.get_item_id(index)
	project.undo_redo.create_action("Set Blend Mode")
	for idx_pair in project.selected_cels:
		var layer := project.layers[idx_pair[1]]
		var previous_mode := layer.blend_mode
		project.undo_redo.add_do_property(layer, "blend_mode", current_mode)
		project.undo_redo.add_undo_property(layer, "blend_mode", previous_mode)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_do_method(_update_layer_ui)
	project.undo_redo.add_do_method(_update_layers)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_undo_method(_update_layer_ui)
	project.undo_redo.add_undo_method(_update_layers)
	project.undo_redo.commit_action()


func _update_layers() -> void:
	Global.canvas.update_all_layers = true
	Global.canvas.draw_layers()


func add_frame() -> void:
	var project := Global.current_project
	var frame_add_index := project.current_frame + 1
	var frame := project.new_empty_frame()
	project.undos += 1
	project.undo_redo.create_action("Add Frame")
	for l in range(project.layers.size()):
		if project.layers[l].new_cels_linked:  # If the link button is pressed
			var prev_cel := project.frames[project.current_frame].cels[l]
			if prev_cel.link_set == null:
				prev_cel.link_set = {}
				project.undo_redo.add_do_method(
					project.layers[l].link_cel.bind(prev_cel, prev_cel.link_set)
				)
				project.undo_redo.add_undo_method(project.layers[l].link_cel.bind(prev_cel, null))
			frame.cels[l].set_content(prev_cel.get_content(), prev_cel.image_texture)
			frame.cels[l].link_set = prev_cel.link_set

	# Code to PUSH AHEAD tags starting after the frame
	var new_animation_tags := project.animation_tags.duplicate()
	# Loop through the tags to create new classes for them, so that they won't be the same
	# as Global.current_project.animation_tags's classes. Needed for undo/redo to work properly.
	for i in new_animation_tags.size():
		new_animation_tags[i] = AnimationTag.new(
			new_animation_tags[i].name,
			new_animation_tags[i].color,
			new_animation_tags[i].from,
			new_animation_tags[i].to
		)
	# Loop through the tags to see if the frame is in one
	for tag in new_animation_tags:
		if frame_add_index >= tag.from && frame_add_index <= tag.to:
			tag.to += 1
		elif (frame_add_index) < tag.from:
			tag.from += 1
			tag.to += 1

	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_do_method(project.add_frames.bind([frame], [frame_add_index]))
	project.undo_redo.add_undo_method(project.remove_frames.bind([frame_add_index]))
	project.undo_redo.add_do_property(project, "animation_tags", new_animation_tags)
	project.undo_redo.add_undo_property(project, "animation_tags", project.animation_tags)
	project.undo_redo.add_do_method(project.change_cel.bind(project.current_frame + 1))
	project.undo_redo.add_undo_method(project.change_cel.bind(project.current_frame))
	project.undo_redo.commit_action()
	# It doesn't update properly without awaits
	await get_tree().process_frame
	await get_tree().process_frame
	adjust_scroll_container()


func _on_DeleteFrame_pressed() -> void:
	delete_frames()


func delete_frames(indices: PackedInt32Array = []) -> void:
	var project := Global.current_project
	if project.frames.size() == 1:
		return

	if indices.size() == 0:
		for cel in Global.current_project.selected_cels:
			var f: int = cel[0]
			if not f in indices:
				indices.append(f)
		indices.sort()

	if indices.size() == project.frames.size():
		indices.remove_at(indices.size() - 1)  # Ensure the project has at least 1 frame

	var current_frame := mini(project.current_frame, project.frames.size() - indices.size() - 1)
	var frames: Array[Frame] = []
	var frame_correction := 0  # Only needed for tag adjustment

	var new_animation_tags := project.animation_tags.duplicate()
	# Loop through the tags to create new classes for them, so that they won't be the same
	# as Global.current_project.animation_tags's classes. Needed for undo/redo to work properly.
	for i in new_animation_tags.size():
		new_animation_tags[i] = AnimationTag.new(
			new_animation_tags[i].name,
			new_animation_tags[i].color,
			new_animation_tags[i].from,
			new_animation_tags[i].to
		)

	for f in indices:
		frames.append(project.frames[f])

		# Loop through the tags to see if the frame is in one
		f -= frame_correction  # Erasing made frames indexes 1 step ahead their intended tags
		var tag_correction := 0  # needed when tag is erased
		for tag_ind in new_animation_tags.size():
			var tag = new_animation_tags[tag_ind - tag_correction]
			if f + 1 >= tag.from && f + 1 <= tag.to:
				if tag.from == tag.to:  # If we're deleting the only frame in the tag
					new_animation_tags.erase(tag)
					tag_correction += 1
				else:
					tag.to -= 1
			elif f + 1 < tag.from:
				tag.from -= 1
				tag.to -= 1
		frame_correction += 1  # Compensation for the next batch

	project.undos += 1
	project.undo_redo.create_action("Remove Frame")
	project.undo_redo.add_do_method(project.remove_frames.bind(indices))
	project.undo_redo.add_undo_method(project.add_frames.bind(frames, indices))
	project.undo_redo.add_do_property(project, "animation_tags", new_animation_tags)
	project.undo_redo.add_undo_property(project, "animation_tags", project.animation_tags)
	project.undo_redo.add_do_method(project.change_cel.bind(current_frame))
	project.undo_redo.add_undo_method(project.change_cel.bind(project.current_frame))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()
	# It doesn't update properly without awaits
	await get_tree().process_frame
	await get_tree().process_frame
	adjust_scroll_container()


func _on_CopyFrame_pressed() -> void:
	copy_frames([], -1, false)


## Copies frames located at [param indices] and inserts them at [param destination].
## When [param destination] is -1, the new frames will be placed right next to the last frame in
## [param destination]. if [param select_all_cels] is [code]true[/code] then all of the new copied
## cels will be selected, otherwise only the cels corresponding to the original selected cels will
## get selected. if [param tag_name_from] holds an animation tag then a tag of it's name will be
## created over the new frames.
## [br]Note: [param indices] must be in ascending order
func copy_frames(
	indices := [], destination := -1, select_all_cels := true, tag_name_from: AnimationTag = null
) -> void:
	var project := Global.current_project

	if indices.size() == 0:
		for cel in Global.current_project.selected_cels:
			var f: int = cel[0]
			if not f in indices:
				indices.append(f)
		indices.sort()

	var copied_frames: Array[Frame] = []
	var copied_indices := PackedInt32Array()  # the indices of newly copied frames

	if destination != -1:
		copied_indices = range(destination + 1, (destination + 1) + indices.size())
	else:
		copied_indices = range(indices[-1] + 1, indices[-1] + 1 + indices.size())
	var new_animation_tags := project.animation_tags.duplicate()
	# Loop through the tags to create new classes for them, so that they won't be the same
	# as project.animation_tags's classes. Needed for undo/redo to work properly.
	for i in new_animation_tags.size():
		new_animation_tags[i] = AnimationTag.new(
			new_animation_tags[i].name,
			new_animation_tags[i].color,
			new_animation_tags[i].from,
			new_animation_tags[i].to
		)
	project.undos += 1
	project.undo_redo.create_action("Add Frame")
	var last_focus_cels := []
	for f in indices:
		var src_frame := project.frames[f]
		var new_frame := Frame.new()
		copied_frames.append(new_frame)

		new_frame.duration = src_frame.duration
		for l in range(project.layers.size()):
			if [f, l] in project.selected_cels:
				last_focus_cels.append([copied_indices[indices.find(f)], l])
			var src_cel := project.frames[f].cels[l]  # Cel we're copying from, the source
			var new_cel: BaseCel
			var selected_id := -1
			if src_cel is Cel3D:
				new_cel = Cel3D.new(
					src_cel.size, false, src_cel.object_properties, src_cel.scene_properties
				)
				if src_cel.selected != null:
					selected_id = src_cel.selected.id
			elif src_cel is CelTileMap:
				new_cel = CelTileMap.new(src_cel.tileset)
			else:
				new_cel = src_cel.get_script().new()

			if project.layers[l].new_cels_linked:
				if src_cel.link_set == null:
					src_cel.link_set = {}
					project.undo_redo.add_do_method(
						project.layers[l].link_cel.bind(src_cel, src_cel.link_set)
					)
					project.undo_redo.add_undo_method(
						project.layers[l].link_cel.bind(src_cel, null)
					)
				new_cel.set_content(src_cel.get_content(), src_cel.image_texture)
				new_cel.link_set = src_cel.link_set
			else:
				new_cel.set_content(src_cel.copy_content())
			new_cel.opacity = src_cel.opacity

			if new_cel is Cel3D:
				if selected_id in new_cel.object_properties.keys():
					if selected_id != -1:
						new_cel.selected = new_cel.get_object_from_id(selected_id)
			new_frame.cels.append(new_cel)

		# After adding one frame, loop through the tags to see if the frame was in an animation tag
		for tag in new_animation_tags:
			if copied_indices[0] >= tag.from && copied_indices[0] <= tag.to:
				tag.to += 1
			elif copied_indices[0] < tag.from:
				tag.from += 1
				tag.to += 1
	if tag_name_from:
		new_animation_tags.append(
			AnimationTag.new(
				tag_name_from.name,
				tag_name_from.color,
				copied_indices[0] + 1,
				copied_indices[-1] + 1
			)
		)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	# Note: temporarily set the selected cels to an empty array (needed for undo/redo)
	project.undo_redo.add_do_property(Global.current_project, "selected_cels", [])
	project.undo_redo.add_undo_property(Global.current_project, "selected_cels", [])
	project.undo_redo.add_do_method(project.add_frames.bind(copied_frames, copied_indices))
	project.undo_redo.add_undo_method(project.remove_frames.bind(copied_indices))
	if select_all_cels:
		var all_new_cels := []
		# Select all the new frames so that it is easier to move/offset collectively if user wants
		# To ease animation workflow, new current frame is the first copied frame instead of the last
		var range_start := copied_indices[-1]
		var range_end := copied_indices[0]
		var frame_diff_sign := signi(range_end - range_start)
		if frame_diff_sign == 0:
			frame_diff_sign = 1
		for i in range(range_start, range_end + frame_diff_sign, frame_diff_sign):
			for j in range(0, Global.current_project.layers.size()):
				var frame_layer := [i, j]
				if !all_new_cels.has(frame_layer):
					all_new_cels.append(frame_layer)
		project.undo_redo.add_do_property(Global.current_project, "selected_cels", all_new_cels)
		project.undo_redo.add_do_method(project.change_cel.bind(range_end))
	else:
		project.undo_redo.add_do_property(Global.current_project, "selected_cels", last_focus_cels)
		project.undo_redo.add_do_method(project.change_cel.bind(copied_indices[0]))
	project.undo_redo.add_undo_property(
		Global.current_project, "selected_cels", project.selected_cels
	)
	project.undo_redo.add_undo_method(project.change_cel.bind(project.current_frame))
	project.undo_redo.add_do_property(project, "animation_tags", new_animation_tags)
	project.undo_redo.add_undo_property(project, "animation_tags", project.animation_tags)
	project.undo_redo.commit_action()


func _on_MoveLeft_pressed() -> void:
	if Global.current_project.current_frame == 0:
		return
	move_frames(Global.current_project.current_frame, -1)


func _on_MoveRight_pressed() -> void:
	if Global.current_project.current_frame == Global.current_project.frames.size() - 1:
		return
	move_frames(Global.current_project.current_frame, 1)


func move_frames(frame: int, rate: int) -> void:
	var project := Global.current_project
	var frame_indices: PackedInt32Array = []
	var moved_frame_indices: PackedInt32Array = []
	for cel in project.selected_cels:
		var frame_index: int = cel[0]
		if not frame_indices.has(frame_index):
			frame_indices.append(frame_index)
			moved_frame_indices.append(frame_index + rate)
	frame_indices.sort()
	moved_frame_indices.sort()
	if not frame in frame_indices:
		frame_indices = [frame]
		moved_frame_indices = [frame + rate]
	for moved_index in moved_frame_indices:
		# Don't allow frames to be moved if they are out of bounds
		if moved_index < 0 or moved_index >= project.frames.size():
			return
	project.undo_redo.create_action("Change Frame Order")
	project.undo_redo.add_do_method(project.move_frames.bind(frame_indices, moved_frame_indices))
	project.undo_redo.add_undo_method(project.move_frames.bind(moved_frame_indices, frame_indices))

	if project.current_frame in frame_indices:
		project.undo_redo.add_do_method(project.change_cel.bind(frame + rate))
	else:
		project.undo_redo.add_do_method(project.change_cel.bind(project.current_frame))

	project.undo_redo.add_undo_method(project.change_cel.bind(project.current_frame))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.commit_action()


func reverse_frames(indices: PackedInt32Array = []) -> void:
	var project := Global.current_project
	project.undo_redo.create_action("Change Frame Order")
	project.undo_redo.add_do_method(project.reverse_frames.bind(indices))
	project.undo_redo.add_undo_method(project.reverse_frames.bind(indices))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.commit_action()


func _on_OnionSkinning_pressed() -> void:
	Global.onion_skinning = !Global.onion_skinning
	Global.canvas.refresh_onion()
	var texture_button: TextureRect = onion_skinning_button.get_child(0)
	if Global.onion_skinning:
		Global.change_button_texturerect(texture_button, "onion_skinning.png")
	else:
		Global.change_button_texturerect(texture_button, "onion_skinning_off.png")


func _on_timeline_settings_button_pressed() -> void:
	var pos := Vector2i(onion_skinning_button.global_position) - timeline_settings.size
	timeline_settings.popup_on_parent(Rect2i(pos.x - 16, pos.y + 32, 136, 126))


func _on_LoopAnim_pressed() -> void:
	var texture_button: TextureRect = loop_animation_button.get_child(0)
	match animation_loop:
		LoopType.NO:
			animation_loop = LoopType.CYCLE
			Global.change_button_texturerect(texture_button, "loop.png")
			loop_animation_button.tooltip_text = "Cycle loop"
		LoopType.CYCLE:
			animation_loop = LoopType.PINGPONG
			Global.change_button_texturerect(texture_button, "loop_pingpong.png")
			loop_animation_button.tooltip_text = "Ping-pong loop"
		LoopType.PINGPONG:
			animation_loop = LoopType.NO
			Global.change_button_texturerect(texture_button, "loop_none.png")
			loop_animation_button.tooltip_text = "No loop"


func _on_PlayForward_toggled(button_pressed: bool) -> void:
	if button_pressed:
		Global.change_button_texturerect(play_forward.get_child(0), "pause.png")
	else:
		Global.change_button_texturerect(play_forward.get_child(0), "play.png")
	play_animation(button_pressed, true)


func _on_PlayBackwards_toggled(button_pressed: bool) -> void:
	if button_pressed:
		Global.change_button_texturerect(play_backwards.get_child(0), "pause.png")
	else:
		Global.change_button_texturerect(play_backwards.get_child(0), "play_backwards.png")
	play_animation(button_pressed, false)


## Called on each frame of the animation
func _on_AnimationTimer_timeout() -> void:
	if first_frame == last_frame:
		play_forward.button_pressed = false
		play_backwards.button_pressed = false
		animation_timer.stop()
		return

	Global.canvas.selection.transform_content_confirm()
	var project := Global.current_project
	var fps := project.fps
	if animation_forward:
		if project.current_frame < last_frame:
			project.selected_cels.clear()
			project.change_cel(project.current_frame + 1, -1)
			animation_timer.wait_time = project.frames[project.current_frame].duration * (1.0 / fps)
			animation_timer.start()  # Change the frame, change the wait time and start a cycle
		else:
			match animation_loop:
				LoopType.NO:
					play_forward.button_pressed = false
					play_backwards.button_pressed = false
					animation_timer.stop()
					animation_finished.emit()
					is_animation_running = false
				LoopType.CYCLE:
					project.selected_cels.clear()
					project.change_cel(first_frame, -1)
					animation_timer.wait_time = (
						project.frames[project.current_frame].duration * (1 / fps)
					)
					animation_looped.emit()
					animation_timer.start()
				LoopType.PINGPONG:
					animation_forward = false
					animation_looped.emit()
					_on_AnimationTimer_timeout()

	else:
		if project.current_frame > first_frame:
			project.selected_cels.clear()
			project.change_cel(project.current_frame - 1, -1)
			animation_timer.wait_time = project.frames[project.current_frame].duration * (1.0 / fps)
			animation_timer.start()
		else:
			match animation_loop:
				LoopType.NO:
					play_backwards.button_pressed = false
					play_forward.button_pressed = false
					animation_timer.stop()
					animation_finished.emit()
					is_animation_running = false
				LoopType.CYCLE:
					project.selected_cels.clear()
					project.change_cel(last_frame, -1)
					animation_timer.wait_time = (
						project.frames[project.current_frame].duration * (1 / fps)
					)
					animation_looped.emit()
					animation_timer.start()
				LoopType.PINGPONG:
					animation_forward = true
					animation_looped.emit()
					_on_AnimationTimer_timeout()
	frame_scroll_container.ensure_control_visible(
		Global.frame_hbox.get_child(project.current_frame)
	)


func play_animation(play: bool, forward_dir: bool) -> void:
	first_frame = 0
	last_frame = Global.current_project.frames.size() - 1
	if Global.play_only_tags:
		for tag in Global.current_project.animation_tags:
			if (
				Global.current_project.current_frame + 1 >= tag.from
				&& Global.current_project.current_frame + 1 <= tag.to
			):
				first_frame = tag.from - 1
				last_frame = mini(Global.current_project.frames.size() - 1, tag.to - 1)

	if first_frame == last_frame:
		if forward_dir:
			play_forward.button_pressed = false
		else:
			play_backwards.button_pressed = false
		return

	if forward_dir:
		play_backwards.toggled.disconnect(_on_PlayBackwards_toggled)
		play_backwards.button_pressed = false
		Global.change_button_texturerect(play_backwards.get_child(0), "play_backwards.png")
		play_backwards.toggled.connect(_on_PlayBackwards_toggled)
	else:
		play_forward.toggled.disconnect(_on_PlayForward_toggled)
		play_forward.button_pressed = false
		Global.change_button_texturerect(play_forward.get_child(0), "play.png")
		play_forward.toggled.connect(_on_PlayForward_toggled)

	if play:
		animation_timer.set_one_shot(true)  # wait_time can't change correctly if it's playing
		var duration: float = (
			Global.current_project.frames[Global.current_project.current_frame].duration
		)
		animation_timer.wait_time = duration * (1 / Global.current_project.fps)
		animation_timer.start()
		animation_forward = forward_dir
		animation_started.emit(forward_dir)
	else:
		animation_timer.stop()
		animation_finished.emit()

	is_animation_running = play


func _on_NextFrame_pressed() -> void:
	var project := Global.current_project
	project.selected_cels.clear()
	if project.current_frame < project.frames.size() - 1:
		project.change_cel(project.current_frame + 1, -1)
	else:
		project.change_cel(0, -1)


func _on_PreviousFrame_pressed() -> void:
	var project := Global.current_project
	project.selected_cels.clear()
	if project.current_frame > 0:
		project.change_cel(project.current_frame - 1, -1)
	else:
		project.change_cel(project.frames.size() - 1, -1)


func _on_LastFrame_pressed() -> void:
	Global.current_project.selected_cels.clear()
	Global.current_project.change_cel(Global.current_project.frames.size() - 1, -1)


func _on_FirstFrame_pressed() -> void:
	Global.current_project.selected_cels.clear()
	Global.current_project.change_cel(0, -1)


func _on_FPSValue_value_changed(value: float) -> void:
	Global.current_project.fps = value
	animation_timer.wait_time = 1 / Global.current_project.fps


func _on_PastOnionSkinning_value_changed(value: float) -> void:
	Global.onion_skinning_past_rate = int(value)
	Global.config_cache.set_value("timeline", "past_rate", Global.onion_skinning_past_rate)
	Global.canvas.queue_redraw()


func _on_FutureOnionSkinning_value_changed(value: float) -> void:
	Global.onion_skinning_future_rate = int(value)
	Global.config_cache.set_value("timeline", "future_rate", Global.onion_skinning_future_rate)
	Global.canvas.queue_redraw()


func _on_BlueRedMode_toggled(button_pressed: bool) -> void:
	Global.onion_skinning_blue_red = button_pressed
	Global.config_cache.set_value("timeline", "blue_red", Global.onion_skinning_blue_red)
	Global.canvas.queue_redraw()


func _on_play_only_tags_toggled(toggled_on: bool) -> void:
	Global.play_only_tags = toggled_on


func _on_PastPlacement_item_selected(index: int) -> void:
	past_above_canvas = (index == 0)
	Global.config_cache.set_value("timeline", "past_above_canvas", past_above_canvas)
	Global.canvas.get_node("OnionPast").set("show_behind_parent", !past_above_canvas)


func _on_FuturePlacement_item_selected(index: int) -> void:
	future_above_canvas = (index == 0)
	Global.config_cache.set_value("timeline", "future_above_canvas", future_above_canvas)
	Global.canvas.get_node("OnionFuture").set("show_behind_parent", !future_above_canvas)


# Layer buttons
func _on_add_layer_pressed() -> void:
	var project := Global.current_project
	var layer := PixelLayer.new(project)
	add_layer(layer, project)


func on_add_layer_list_id_pressed(id: int) -> void:
	if id == Global.LayerTypes.TILEMAP:
		new_tile_map_layer_dialog.popup_centered()
	else:
		var project := Global.current_project
		var layer: BaseLayer
		match id:
			Global.LayerTypes.PIXEL:
				layer = PixelLayer.new(project)
			Global.LayerTypes.GROUP:
				layer = GroupLayer.new(project)
			Global.LayerTypes.THREE_D:
				layer = Layer3D.new(project)
				SteamManager.set_achievement("ACH_3D_LAYER")
			Global.LayerTypes.AUDIO:
				layer = AudioLayer.new(project)
		add_layer(layer, project)


func add_layer(layer: BaseLayer, project: Project) -> void:
	var current_layer := project.layers[project.current_layer]
	var cels := []
	for f in project.frames:
		cels.append(layer.new_empty_cel())

	var new_layer_idx := project.current_layer + 1
	if current_layer is GroupLayer:
		new_layer_idx = project.current_layer
		if !current_layer.expanded:
			current_layer.expanded = true
			for layer_button: LayerButton in Global.layer_vbox.get_children():
				layer_button.update_buttons()
				var expanded := project.layers[layer_button.layer_index].is_expanded_in_hierarchy()
				layer_button.visible = expanded
				Global.cel_vbox.get_child(layer_button.get_index()).visible = expanded
		# make layer child of group
		layer.parent = Global.current_project.layers[project.current_layer]
	else:
		# set the parent of layer to be the same as the layer below it
		layer.parent = Global.current_project.layers[project.current_layer].parent

	project.undos += 1
	project.undo_redo.create_action("Add Layer")
	project.undo_redo.add_do_method(project.add_layers.bind([layer], [new_layer_idx], [cels]))
	project.undo_redo.add_undo_method(project.remove_layers.bind([new_layer_idx]))
	project.undo_redo.add_do_method(project.change_cel.bind(-1, new_layer_idx))
	project.undo_redo.add_undo_method(project.change_cel.bind(-1, project.current_layer))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()


func _on_CloneLayer_pressed() -> void:
	var project := Global.current_project
	var source_layers := project.layers[project.current_layer].get_children(true)
	source_layers.append(project.layers[project.current_layer])

	var clones: Array[BaseLayer] = []
	var cels := []  # 2D Array of Cels
	for src_layer in source_layers:
		var cl_layer: BaseLayer
		if src_layer is LayerTileMap:
			cl_layer = LayerTileMap.new(project, src_layer.tileset)
		else:
			cl_layer = src_layer.get_script().new(project)
			if src_layer is AudioLayer:
				cl_layer.audio = src_layer.audio
		cl_layer.project = project
		cl_layer.index = src_layer.index
		var src_layer_data: Dictionary = src_layer.serialize()
		for link_set in src_layer_data.get("link_sets", []):
			link_set["cels"].clear()  # Clear away the indices
		cl_layer.deserialize(src_layer_data)
		clones.append(cl_layer)

		cels.append([])

		for frame in project.frames:
			var src_cel := frame.cels[src_layer.index]
			var new_cel: BaseCel
			if src_cel is Cel3D:
				new_cel = Cel3D.new(
					src_cel.size, false, src_cel.object_properties, src_cel.scene_properties
				)
			elif src_cel is CelTileMap:
				new_cel = CelTileMap.new(src_cel.tileset)
			else:
				new_cel = src_cel.get_script().new()

			if src_cel.link_set == null:
				new_cel.set_content(src_cel.copy_content())
			else:
				new_cel.link_set = cl_layer.cel_link_sets[src_layer.cel_link_sets.find(
					src_cel.link_set
				)]
				if new_cel.link_set["cels"].size() > 0:
					var linked_cel: BaseCel = new_cel.link_set["cels"][0]
					new_cel.set_content(linked_cel.get_content(), linked_cel.image_texture)
				else:
					new_cel.set_content(src_cel.copy_content())
				new_cel.link_set["cels"].append(new_cel)

			new_cel.opacity = src_cel.opacity
			cels[-1].append(new_cel)

	for cl_layer in clones:
		var p := source_layers.find(cl_layer.parent)
		if p > -1:  # Swap parent with clone if the parent is one of the source layers
			cl_layer.parent = clones[p]
		else:  # Add (Copy) to the name if its not a child of another copied layer
			cl_layer.name = str(cl_layer.name, " (", tr("copy"), ")")

	var indices: PackedInt32Array = range(
		project.current_layer + 1, project.current_layer + clones.size() + 1
	)

	project.undos += 1
	project.undo_redo.create_action("Add Layer")
	project.undo_redo.add_do_method(project.add_layers.bind(clones, indices, cels))
	project.undo_redo.add_undo_method(project.remove_layers.bind(indices))
	project.undo_redo.add_do_method(
		project.change_cel.bind(-1, project.current_layer + clones.size())
	)
	project.undo_redo.add_undo_method(project.change_cel.bind(-1, project.current_layer))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()


func _on_RemoveLayer_pressed() -> void:
	var project := Global.current_project
	if project.layers.size() == 1:
		return

	var layers := project.layers[project.current_layer].get_children(true)
	layers.append(project.layers[project.current_layer])
	var indices := PackedInt32Array()
	for l in layers:
		indices.append(l.index)

	var cels := []
	for l in layers:
		cels.append([])
		for f in project.frames:
			cels[-1].append(f.cels[l.index])

	project.undos += 1
	project.undo_redo.create_action("Remove Layer")
	project.undo_redo.add_do_method(project.remove_layers.bind(indices))
	project.undo_redo.add_undo_method(project.add_layers.bind(layers, indices, cels))
	project.undo_redo.add_do_method(project.change_cel.bind(-1, maxi(indices[0] - 1, 0)))
	project.undo_redo.add_undo_method(project.change_cel.bind(-1, project.current_layer))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()


## Move the layer up or down in layer order and/or reparent to be deeper/shallower in the
## layer hierarchy depending on its current index and parent
func change_layer_order(up: bool) -> void:
	var project := Global.current_project
	var layer := project.layers[project.current_layer]
	var child_count := layer.get_child_count(true)
	var from_indices: PackedInt32Array = range(layer.index - child_count, layer.index + 1)
	var from_parents := []
	for l in from_indices:
		from_parents.append(project.layers[l].parent)
	var to_parents := from_parents.duplicate()
	var to_index := layer.index - child_count  # the index where the LOWEST shifted layer should end up

	if up:
		var above_layer := project.layers[project.current_layer + 1]
		if layer.parent == above_layer:  # Above is the parent, leave the parent and go up
			to_parents[-1] = above_layer.parent
			to_index = to_index + 1
		elif layer.parent != above_layer.parent:  # Above layer must be deeper in the hierarchy
			# Move layer 1 level deeper in hierarchy. Done by setting its parent to the parent of
			# above_layer, and if that is multiple levels, drop levels until its just 1
			to_parents[-1] = above_layer.parent
			while to_parents[-1].parent != layer.parent:
				to_parents[-1] = to_parents[-1].parent
		elif above_layer.accepts_child(layer):
			to_parents[-1] = above_layer
		else:
			to_index = to_index + 1
	else:  # Down
		if layer.index == child_count:  # If at the very bottom of the layer stack
			if not is_instance_valid(layer.parent):
				return
			to_parents[-1] = layer.parent.parent  # Drop a level in the hierarchy
		else:
			var below_layer := project.layers[project.current_layer - 1 - child_count]
			if layer.parent != below_layer.parent:  # If there is a hierarchy change
				to_parents[-1] = layer.parent.parent  # Drop a level in the hierarchy
			elif below_layer.accepts_child(layer):
				to_parents[-1] = below_layer
				to_index = to_index - 1
			else:
				to_index = to_index - 1

	var to_indices: PackedInt32Array = range(to_index, to_index + child_count + 1)

	project.undo_redo.create_action("Change Layer Order")
	project.undo_redo.add_do_method(project.move_layers.bind(from_indices, to_indices, to_parents))
	project.undo_redo.add_undo_method(
		project.move_layers.bind(to_indices, from_indices, from_parents)
	)
	project.undo_redo.add_do_method(project.change_cel.bind(-1, to_index + child_count))
	project.undo_redo.add_undo_method(project.change_cel.bind(-1, project.current_layer))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()


func _on_MergeDownLayer_pressed() -> void:
	var project := Global.current_project
	var top_layer := project.layers[project.current_layer]
	var bottom_layer := project.layers[project.current_layer - 1]
	if not bottom_layer is PixelLayer:
		return
	var top_cels := []

	project.undos += 1
	project.undo_redo.create_action("Merge Layer")
	for frame in project.frames:
		var top_cel := frame.cels[top_layer.index]
		top_cels.append(top_cel)  # Store for undo purposes

		var top_image := top_layer.display_effects(top_cel)
		var bottom_cel := frame.cels[bottom_layer.index] as PixelCel
		var bottom_image := bottom_cel.get_image()
		var textures: Array[Image] = []
		textures.append(bottom_image)
		textures.append(top_image)
		var metadata_image := Image.create(2, 4, false, Image.FORMAT_R8)
		DrawingAlgos.set_layer_metadata_image(bottom_layer, bottom_cel, metadata_image, 0)
		metadata_image.set_pixel(0, 1, Color(1.0, 0.0, 0.0, 0.0))
		DrawingAlgos.set_layer_metadata_image(top_layer, top_cel, metadata_image, 1)
		var texture_array := Texture2DArray.new()
		texture_array.create_from_images(textures)
		var params := {
			"layers": texture_array, "metadata": ImageTexture.create_from_image(metadata_image)
		}
		var new_bottom_image := ImageExtended.create_custom(
			top_image.get_width(),
			top_image.get_height(),
			top_image.has_mipmaps(),
			top_image.get_format(),
			project.is_indexed()
		)
		# Merge the image itself.
		var gen := ShaderImageEffect.new()
		gen.generate_image(new_bottom_image, DrawingAlgos.blend_layers_shader, params, project.size)
		new_bottom_image.convert_rgb_to_indexed()
		if (
			bottom_cel.link_set != null
			and bottom_cel.link_set.size() > 1
			and not top_image.is_invisible()
		):
			# Unlink cel:
			project.undo_redo.add_do_method(bottom_layer.link_cel.bind(bottom_cel, null))
			project.undo_redo.add_undo_method(
				bottom_layer.link_cel.bind(bottom_cel, bottom_cel.link_set)
			)
			project.undo_redo.add_do_property(bottom_cel, "image", new_bottom_image)
			project.undo_redo.add_undo_property(bottom_cel, "image", bottom_cel.image)
		else:
			var undo_data := {}
			var redo_data := {}
			if bottom_cel is CelTileMap:
				(bottom_cel as CelTileMap).serialize_undo_data_source_image(
					new_bottom_image, redo_data, undo_data
				)
			new_bottom_image.add_data_to_dictionary(redo_data, bottom_image)
			bottom_image.add_data_to_dictionary(undo_data)
			project.deserialize_cel_undo_data(redo_data, undo_data)

	project.undo_redo.add_do_method(project.remove_layers.bind([top_layer.index]))
	project.undo_redo.add_undo_method(
		project.add_layers.bind([top_layer], [top_layer.index], [top_cels])
	)
	project.undo_redo.add_do_method(project.change_cel.bind(-1, bottom_layer.index))
	project.undo_redo.add_undo_method(project.change_cel.bind(-1, top_layer.index))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.commit_action()
	bottom_layer.visible = true


func _on_opacity_slider_value_changed(value: float) -> void:
	var new_opacity := value / 100.0
	for idx_pair in Global.current_project.selected_cels:
		var layer := Global.current_project.layers[idx_pair[1]]
		layer.opacity = new_opacity
	Global.canvas.queue_redraw()


func _on_timeline_settings_close_requested() -> void:
	timeline_settings.hide()


func _on_timeline_settings_visibility_changed() -> void:
	Global.can_draw = not timeline_settings.visible


# Methods to update the UI in response to changes in the current project


func _cel_switched() -> void:
	_toggle_frame_buttons()
	_toggle_layer_buttons()
	_fill_blend_modes_option_button()
	# Temporarily disconnect it in order to prevent layer opacity changing
	# in the rest of the selected layers, if there are any.
	opacity_slider.value_changed.disconnect(_on_opacity_slider_value_changed)
	_update_layer_ui()
	opacity_slider.value_changed.connect(_on_opacity_slider_value_changed)


func _update_layer_ui() -> void:
	var project := Global.current_project
	var layer := project.layers[project.current_layer]
	opacity_slider.value = layer.opacity * 100
	var blend_mode_index := blend_modes_button.get_item_index(layer.blend_mode)
	blend_modes_button.selected = blend_mode_index


func _toggle_frame_buttons() -> void:
	var project := Global.current_project
	Global.disable_button(delete_frame, project.frames.size() == 1)
	Global.disable_button(move_frame_left, project.current_frame == 0)
	Global.disable_button(move_frame_right, project.current_frame == project.frames.size() - 1)


func _toggle_layer_buttons() -> void:
	var project := Global.current_project
	if project.layers.is_empty() or project.current_layer >= project.layers.size():
		return
	var layer := project.layers[project.current_layer]
	var child_count := layer.get_child_count(true)

	Global.disable_button(
		remove_layer, layer.is_locked_in_hierarchy() or project.layers.size() == child_count + 1
	)
	Global.disable_button(move_up_layer, project.current_layer == project.layers.size() - 1)
	Global.disable_button(
		move_down_layer,
		project.current_layer == child_count and not is_instance_valid(layer.parent)
	)
	Global.disable_button(
		merge_down_layer,
		(
			project.current_layer == child_count
			or layer is GroupLayer
			or layer is AudioLayer
			or project.layers[project.current_layer - 1] is GroupLayer
			or project.layers[project.current_layer - 1] is Layer3D
			or project.layers[project.current_layer - 1] is AudioLayer
		)
	)
	Global.disable_button(layer_fx, layer is AudioLayer)


func project_changed() -> void:
	var project := Global.current_project
	fps_spinbox.value = project.fps
	_toggle_frame_buttons()
	_toggle_layer_buttons()
	# These must be removed from tree immediately to not mess up the indices of
	# the new buttons, so use either free or queue_free + parent.remove_child
	for layer_button in Global.layer_vbox.get_children():
		layer_button.free()
	for frame_button in Global.frame_hbox.get_children():
		frame_button.free()
	for cel_hbox in Global.cel_vbox.get_children():
		cel_hbox.free()

	for i in project.layers.size():
		project_layer_added(i)
	for f in project.frames.size():
		var button := FRAME_BUTTON_TSCN.instantiate() as Button
		button.frame = f
		Global.frame_hbox.add_child(button)

	# Press selected cel/frame/layer buttons
	for cel_index in project.selected_cels:
		var frame: int = cel_index[0]
		var layer: int = cel_index[1]
		if frame < Global.frame_hbox.get_child_count():
			var frame_button: BaseButton = Global.frame_hbox.get_child(frame)
			frame_button.button_pressed = true

		var vbox_child_count: int = Global.cel_vbox.get_child_count()
		if layer < vbox_child_count:
			var cel_hbox: HBoxContainer = Global.cel_vbox.get_child(vbox_child_count - 1 - layer)
			if frame < cel_hbox.get_child_count():
				var cel_button := cel_hbox.get_child(frame)
				cel_button.button_pressed = true

			var layer_button := Global.layer_vbox.get_child(vbox_child_count - 1 - layer)
			layer_button.button_pressed = true


func project_frame_added(frame: int) -> void:
	var project := Global.current_project
	var button := FRAME_BUTTON_TSCN.instantiate() as Button
	button.frame = frame
	Global.frame_hbox.add_child(button)
	Global.frame_hbox.move_child(button, frame)
	# Make it visible, yes 3 call_deferreds are required
	frame_scroll_container.call_deferred(
		&"call_deferred", &"call_deferred", &"ensure_control_visible", button
	)
	var layer := Global.cel_vbox.get_child_count() - 1
	for cel_hbox in Global.cel_vbox.get_children():
		var cel_button := project.frames[frame].cels[layer].instantiate_cel_button()
		cel_button.frame = frame
		cel_button.layer = layer
		cel_hbox.add_child(cel_button)
		cel_hbox.move_child(cel_button, frame)
		layer -= 1


func project_frame_removed(frame: int) -> void:
	Global.frame_hbox.get_child(frame).queue_free()
	Global.frame_hbox.remove_child(Global.frame_hbox.get_child(frame))
	for cel_hbox in Global.cel_vbox.get_children():
		cel_hbox.get_child(frame).free()


func project_layer_added(layer: int) -> void:
	var project := Global.current_project

	var layer_button := project.layers[layer].instantiate_layer_button() as LayerButton
	layer_button.layer_index = layer
	if project.layers[layer].name == "":
		project.layers[layer].set_name_to_default(Global.current_project.layers.size())

	var cel_hbox := HBoxContainer.new()
	cel_hbox.add_theme_constant_override("separation", 0)
	for f in project.frames.size():
		var cel_button := project.frames[f].cels[layer].instantiate_cel_button()
		cel_button.frame = f
		cel_button.layer = layer
		cel_hbox.add_child(cel_button)

	layer_button.visible = Global.current_project.layers[layer].is_expanded_in_hierarchy()
	cel_hbox.visible = layer_button.visible

	Global.layer_vbox.add_child(layer_button)
	var count := Global.layer_vbox.get_child_count()
	Global.layer_vbox.move_child(layer_button, count - 1 - layer)
	Global.cel_vbox.add_child(cel_hbox)
	Global.cel_vbox.move_child(cel_hbox, count - 1 - layer)
	update_global_layer_buttons()


func project_layer_removed(layer: int) -> void:
	var count := Global.layer_vbox.get_child_count()
	Global.layer_vbox.get_child(count - 1 - layer).free()
	Global.cel_vbox.get_child(count - 1 - layer).free()
	update_global_layer_buttons()


func project_cel_added(frame: int, layer: int) -> void:
	var cel_hbox := Global.cel_vbox.get_child(Global.cel_vbox.get_child_count() - 1 - layer)
	var cel_button := Global.current_project.frames[frame].cels[layer].instantiate_cel_button()
	cel_button.frame = frame
	cel_button.layer = layer
	cel_hbox.add_child(cel_button)
	cel_hbox.move_child(cel_button, frame)


func project_cel_removed(frame: int, layer: int) -> void:
	var cel_hbox := Global.cel_vbox.get_child(Global.cel_vbox.get_child_count() - 1 - layer)
	cel_hbox.get_child(frame).queue_free()
	cel_hbox.remove_child(cel_hbox.get_child(frame))


func _on_layer_fx_pressed() -> void:
	layer_effect_settings.popup_centered()
	Global.dialog_open(true)


func _on_cel_size_slider_value_changed(value: float) -> void:
	cel_size = value


func _on_onion_skinning_opacity_value_changed(value: float) -> void:
	var onion_skinning_opacity := value / 100.0
	Global.config_cache.set_value("timeline", "onion_skinning_opacity", onion_skinning_opacity)
	for onion_skinning_node: Node2D in get_tree().get_nodes_in_group("canvas_onion_skinning"):
		onion_skinning_node.opacity = onion_skinning_opacity
		onion_skinning_node.queue_redraw()


func _on_global_visibility_button_pressed() -> void:
	var layer_visible := !global_layer_visibility
	for layer_button: LayerButton in Global.layer_vbox.get_children():
		var layer: BaseLayer = Global.current_project.layers[layer_button.layer_index]
		if layer.parent == null and layer.visible != layer_visible:
			layer_button.visibility_button.pressed.emit()


func _on_global_lock_button_pressed() -> void:
	var locked := !global_layer_lock
	for layer_button: LayerButton in Global.layer_vbox.get_children():
		var layer: BaseLayer = Global.current_project.layers[layer_button.layer_index]
		if layer.parent == null and layer.locked != locked:
			layer_button.lock_button.pressed.emit()


func _on_global_expand_button_pressed() -> void:
	var expand := !global_layer_expand
	for layer_button: LayerButton in Global.layer_vbox.get_children():
		var layer: BaseLayer = Global.current_project.layers[layer_button.layer_index]
		if layer.parent == null and layer is GroupLayer and layer.expanded != expand:
			layer_button.expand_button.pressed.emit()


func update_global_layer_buttons() -> void:
	global_layer_visibility = false
	global_layer_lock = true
	global_layer_expand = true
	for layer: BaseLayer in Global.current_project.layers:
		if layer.parent == null:
			if layer.visible:
				global_layer_visibility = true
			if not layer.locked:
				global_layer_lock = false
			if layer is GroupLayer and not layer.expanded:
				global_layer_expand = false
			if global_layer_visibility and not global_layer_lock and not global_layer_expand:
				break
	if global_layer_visibility:
		Global.change_button_texturerect(%GlobalVisibilityButton.get_child(0), "layer_visible.png")
	else:
		Global.change_button_texturerect(
			%GlobalVisibilityButton.get_child(0), "layer_invisible.png"
		)
	if global_layer_lock:
		Global.change_button_texturerect(%GlobalLockButton.get_child(0), "lock.png")
	else:
		Global.change_button_texturerect(%GlobalLockButton.get_child(0), "unlock.png")
	if global_layer_expand:
		Global.change_button_texturerect(%GlobalExpandButton.get_child(0), "group_expanded.png")
	else:
		Global.change_button_texturerect(%GlobalExpandButton.get_child(0), "group_collapsed.png")


func _on_layer_frame_h_split_dragged(offset: int) -> void:
	if layer_frame_header_h_split.split_offset != offset:
		layer_frame_header_h_split.split_offset = offset
	if layer_frame_h_split.split_offset != offset:
		layer_frame_h_split.split_offset = offset
