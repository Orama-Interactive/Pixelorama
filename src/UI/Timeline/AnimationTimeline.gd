extends Panel

var is_animation_running := false
var animation_loop := 1  # 0 is no loop, 1 is cycle loop, 2 is ping-pong loop
var animation_forward := true
var first_frame := 0
var last_frame := 0
var is_mouse_hover := false
var cel_size := 36 setget cel_size_changed
var min_cel_size := 36
var max_cel_size := 144
var past_above_canvas := true
var future_above_canvas := true

var frame_button_node = preload("res://src/UI/Timeline/FrameButton.tscn")

onready var old_scroll: int = 0  # The previous scroll state of $ScrollContainer
onready var tag_spacer = find_node("TagSpacer")
onready var start_spacer = find_node("StartSpacer")

onready var timeline_scroll: ScrollContainer = find_node("TimelineScroll")
onready var main_scroll: ScrollContainer = find_node("ScrollContainer")
onready var timeline_container: VBoxContainer = find_node("TimelineContainer")
onready var tag_scroll_container: ScrollContainer = find_node("TagScroll")
onready var fps_spinbox: SpinBox = find_node("FPSValue")
onready var onion_skinning_button: BaseButton = find_node("OnionSkinning")
onready var loop_animation_button: BaseButton = find_node("LoopAnim")
onready var drag_highlight: ColorRect = find_node("DragHighlight")


func _ready() -> void:
	timeline_scroll.get_h_scrollbar().connect("value_changed", self, "_h_scroll_changed")
	Global.animation_timer.wait_time = 1 / Global.current_project.fps
	fps_spinbox.value = Global.current_project.fps

	# Set important size_flags (intentionally set at runtime)
	# Otherwise you yont be able to see "TimelineScroll" in editor
	find_node("EndSpacer").size_flags_horizontal = SIZE_EXPAND_FILL
	timeline_scroll.size_flags_horizontal = SIZE_FILL

# TODO L: See if these two should be kept or done another way:
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		drag_highlight.hide()

func can_drop_data(_position, _data) -> bool:
	drag_highlight.hide()
	print ("can drag?")
	return false


func _input(event: InputEvent) -> void:
	var mouse_pos := get_global_mouse_position()
	var timeline_rect := Rect2(rect_global_position, rect_size)
	if timeline_rect.has_point(mouse_pos):
		if Input.is_key_pressed(KEY_CONTROL):
			self.cel_size += (
				2 * int(event.is_action("zoom_in"))
				- 2 * int(event.is_action("zoom_out"))
			)


func _h_scroll_changed(value: float) -> void:
	# Let the main timeline ScrollContainer affect the tag ScrollContainer too
	tag_scroll_container.get_child(0).rect_min_size.x = (
		timeline_scroll.scroll_horizontal
		+ tag_scroll_container.rect_size.x * 3
	)
	old_scroll = value  # Needed for (_on_TimelineContainer_item_rect_changed)
	var diff = start_spacer.rect_min_size.x - value
	var a = main_scroll.scroll_horizontal
	var b = timeline_scroll.scroll_horizontal
	if a > b:
		tag_scroll_container.scroll_horizontal = 0
		tag_spacer.rect_min_size.x = diff
	else:
		tag_spacer.rect_min_size.x = 0
		tag_scroll_container.scroll_horizontal = -diff


# the below two signals control scrolling functionality
func _on_AnimationTimeline_item_rect_changed() -> void:
	# Timeline size
	timeline_scroll.rect_min_size.x = rect_size.x


func _on_TimelineContainer_item_rect_changed() -> void:
	# Layer movement
	var limit = timeline_container.rect_size.x - main_scroll.rect_size.x
	var amount = main_scroll.scroll_horizontal
	start_spacer.rect_min_size.x = min(amount, max(0, limit - 1))

	# Tag movement
	var diff = start_spacer.rect_min_size.x - old_scroll
	var a = main_scroll.scroll_horizontal
	var b = timeline_scroll.scroll_horizontal
	if a > b:
		tag_spacer.rect_min_size.x = diff
		tag_scroll_container.scroll_horizontal = 0
	else:
		tag_spacer.rect_min_size.x = 0
		tag_scroll_container.scroll_horizontal = -diff


func cel_size_changed(value: int) -> void:
	cel_size = clamp(value, min_cel_size, max_cel_size)
	for layer_button in Global.layers_container.get_children():
		layer_button.rect_min_size.y = cel_size
		layer_button.rect_size.y = cel_size
	for container in Global.frames_container.get_children():
		for cel_button in container.get_children():
			cel_button.rect_min_size.x = cel_size
			cel_button.rect_min_size.y = cel_size
			cel_button.rect_size.x = cel_size
			cel_button.rect_size.y = cel_size

	for frame_id in Global.frame_ids.get_children():
		frame_id.rect_min_size.x = cel_size
		frame_id.rect_size.x = cel_size

	for tag_c in Global.tag_container.get_children():
		var tag_base_size = cel_size + 4
		var tag: AnimationTag = tag_c.tag
		# Added 1 to answer to get starting position of next cel
		tag_c.rect_position.x = (tag.from - 1) * tag_base_size + 1
		var tag_size: int = tag.to - tag.from
		# We dont need the 4 pixels at the end of last cel
		tag_c.rect_min_size.x = (tag_size + 1) * tag_base_size - 4
		# We dont need the 4 pixels at the end of last cel
		tag_c.rect_size.x = (tag_size + 1) * tag_base_size - 4
		tag_c.get_node("Line2D").points[2] = Vector2(tag_c.rect_min_size.x, 0)
		tag_c.get_node("Line2D").points[3] = Vector2(tag_c.rect_min_size.x, 32)


func add_frame() -> void:
	var project: Project = Global.current_project
	var frame_add_index := project.current_frame + 1
	var frame: Frame = project.new_empty_frame()
	var new_layers: Array = project.duplicate_layers()

	for l_i in range(new_layers.size()):
		if new_layers[l_i].new_cels_linked:  # If the link button is pressed
			new_layers[l_i].linked_cels.append(frame)
			frame.cels[l_i].image = new_layers[l_i].linked_cels[0].cels[l_i].image
			frame.cels[l_i].image_texture = new_layers[l_i].linked_cels[0].cels[l_i].image_texture

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

	project.undos += 1
	project.undo_redo.create_action("Add Frame")
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.add_do_method(project, "add_frames", [frame], [frame_add_index])
	project.undo_redo.add_undo_method(project, "remove_frames", [frame_add_index])
	project.undo_redo.add_do_property(project, "layers", new_layers)
	project.undo_redo.add_undo_property(project, "layers", project.layers)
	project.undo_redo.add_do_property(project, "animation_tags", new_animation_tags)
	project.undo_redo.add_undo_property(project, "animation_tags", project.animation_tags)
	project.undo_redo.add_do_property(project, "current_frame", project.current_frame + 1)
	project.undo_redo.add_undo_property(project, "current_frame", project.current_frame)
	project.undo_redo.commit_action()


func _on_DeleteFrame_pressed(frame := -1) -> void:
	var frames := []
	for cel in Global.current_project.selected_cels:
		frame = cel[0]
		if not frame in frames:
			frames.append(frame)
	frames.sort()
	delete_frames(frames)


func delete_frames(frames := []) -> void:
	# TODO R0: If there is mulitple frames, it is currently possible to select and delete them all
	var project: Project = Global.current_project
	if project.frames.size() == 1:
		return

	if frames.size() == 0:
		frames.append(project.current_frame)

	var new_frames: Array = project.frames.duplicate()
	var current_frame := project.current_frame
	var new_layers: Array = project.duplicate_layers()
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

	for frame in frames:
		if new_frames.size() == 1:  # If only 1 frame
			break
		var frame_to_delete: Frame = project.frames[frame]
		new_frames.erase(frame_to_delete)
		if current_frame > 0 && current_frame == new_frames.size():  # If it's the last frame
			current_frame -= 1

		# Check if one of the cels of the frame is linked
		# if they are, unlink them too
		# this prevents removed cels being kept in linked memory
		for layer in new_layers:
			for linked in layer.linked_cels:
				if linked == project.frames[frame]:
					layer.linked_cels.erase(linked)

		# Loop through the tags to see if the frame is in one
		frame -= frame_correction  # Erasing made frames indexes 1 step ahead their intended tags
		var tag_correction := 0  # needed when tag is erased
		for tag_ind in new_animation_tags.size():
			var tag = new_animation_tags[tag_ind - tag_correction]
			if frame + 1 >= tag.from && frame + 1 <= tag.to:
				if tag.from == tag.to:  # If we're deleting the only frame in the tag
					new_animation_tags.erase(tag)
					tag_correction += 1
				else:
					tag.to -= 1
			elif frame + 1 < tag.from:
				tag.from -= 1
				tag.to -= 1
		frame_correction += 1  # Compensation for the next batch

	var frame_refs := []
	for f in frames:
		frame_refs.append(project.frames[f])

	project.undos += 1
	project.undo_redo.create_action("Remove Frame")
	project.undo_redo.add_do_method(project, "remove_frames", frames)
	project.undo_redo.add_undo_method(project, "add_frames", frame_refs, frames)
	project.undo_redo.add_do_property(project, "layers", new_layers)
	project.undo_redo.add_undo_property(project, "layers", Global.current_project.layers)
	project.undo_redo.add_do_property(project, "animation_tags", new_animation_tags)
	project.undo_redo.add_undo_property(project, "animation_tags", project.animation_tags)
	project.undo_redo.add_do_property(project, "current_frame", current_frame)
	project.undo_redo.add_undo_property(project, "current_frame", project.current_frame)
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.commit_action()

# TODO L: Is there any point in frame here being a func parameter? Same with _on_DeleteFrame_presssed above (and maybe more)
func _on_CopyFrame_pressed(frame := -1) -> void:
	var frames := []
	for cel in Global.current_project.selected_cels:
		frame = cel[0]
		if not frame in frames:
			frames.append(frame)
	frames.sort()
	copy_frames(frames)


func copy_frames(frames := []) -> void:
	Global.canvas.selection.transform_content_confirm()
	var project: Project = Global.current_project

	if frames.size() == 0:
		frames.append(project.current_frame)

	var new_layers: Array = project.duplicate_layers()
	var copied_frames := []
	var copied_indices := range(frames[-1] + 1, frames[-1] + 1 + frames.size())

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

	for frame in frames:
		var new_frame := Frame.new()
		copied_frames.append(new_frame)

		var prev_frame: Frame = project.frames[frame]
		for cel in prev_frame.cels:
			new_frame.cels.append(cel.copy())

		new_frame.duration = prev_frame.duration
		for l_i in range(new_layers.size()):
			if new_layers[l_i].get("new_cels_linked"):  # If the link button is pressed
				new_layers[l_i].linked_cels.append(new_frame)
				new_frame.cels[l_i].image = new_layers[l_i].linked_cels[0].cels[l_i].image
				new_frame.cels[l_i].image_texture = new_layers[l_i].linked_cels[0].cels[l_i].image_texture

		# Loop through the tags to see if the frame is in one
		for tag in new_animation_tags:
			if frames[-1] + 1 >= tag.from && frames[-1] + 1 <= tag.to:
				tag.to += 1
			elif frames[-1] + 1 < tag.from:
				tag.from += 1
				tag.to += 1

	project.undos += 1
	project.undo_redo.create_action("Add Frame")
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.add_do_method(project, "add_frames", copied_frames, copied_indices)
	project.undo_redo.add_undo_method(project, "remove_frames", copied_indices)

	project.undo_redo.add_do_property(project, "current_frame", frames[-1] + 1)
	project.undo_redo.add_do_property(project, "layers", new_layers)
	project.undo_redo.add_do_property(project, "animation_tags", new_animation_tags)

	project.undo_redo.add_undo_property(project, "current_frame", frames[-1])
	project.undo_redo.add_undo_property(project, "layers", project.layers)
	project.undo_redo.add_undo_property(project, "animation_tags", project.animation_tags)
	project.undo_redo.commit_action()


func _on_FrameTagButton_pressed() -> void:
	find_node("FrameTagDialog").popup_centered()


func _on_MoveLeft_pressed() -> void:
	var frame: int = Global.current_project.current_frame
	if frame == 0:
		return
	Global.frame_ids.get_child(frame).change_frame_order(-1)


func _on_MoveRight_pressed() -> void:
	var frame: int = Global.current_project.current_frame
	if frame == Global.current_project.frames.size() - 1:  # using last_frame caused problems
		return
	Global.frame_ids.get_child(frame).change_frame_order(1)


func _on_OnionSkinning_pressed() -> void:
	Global.onion_skinning = !Global.onion_skinning
	Global.canvas.refresh_onion()
	var texture_button: TextureRect = onion_skinning_button.get_child(0)
	if Global.onion_skinning:
		Global.change_button_texturerect(texture_button, "onion_skinning.png")
	else:
		Global.change_button_texturerect(texture_button, "onion_skinning_off.png")


func _on_OnionSkinningSettings_pressed() -> void:
	$OnionSkinningSettings.popup(
		Rect2(
			onion_skinning_button.rect_global_position.x - $OnionSkinningSettings.rect_size.x - 16,
			onion_skinning_button.rect_global_position.y - 106,
			136,
			126
		)
	)


func _on_LoopAnim_pressed() -> void:
	var texture_button: TextureRect = loop_animation_button.get_child(0)
	match animation_loop:
		0:  # Make it loop
			animation_loop = 1
			Global.change_button_texturerect(texture_button, "loop.png")
			loop_animation_button.hint_tooltip = "Cycle loop"
		1:  # Make it ping-pong
			animation_loop = 2
			Global.change_button_texturerect(texture_button, "loop_pingpong.png")
			loop_animation_button.hint_tooltip = "Ping-pong loop"
		2:  # Make it stop
			animation_loop = 0
			Global.change_button_texturerect(texture_button, "loop_none.png")
			loop_animation_button.hint_tooltip = "No loop"


func _on_PlayForward_toggled(button_pressed: bool) -> void:
	if button_pressed:
		Global.change_button_texturerect(Global.play_forward.get_child(0), "pause.png")
	else:
		Global.change_button_texturerect(Global.play_forward.get_child(0), "play.png")

	play_animation(button_pressed, true)


func _on_PlayBackwards_toggled(button_pressed: bool) -> void:
	if button_pressed:
		Global.change_button_texturerect(Global.play_backwards.get_child(0), "pause.png")
	else:
		Global.change_button_texturerect(Global.play_backwards.get_child(0), "play_backwards.png")

	play_animation(button_pressed, false)


func _on_AnimationTimer_timeout() -> void:
	if first_frame == last_frame:
		$AnimationTimer.stop()
		return

	Global.canvas.selection.transform_content_confirm()
	var fps = Global.current_project.fps
	if animation_forward:
		if Global.current_project.current_frame < last_frame:
			Global.current_project.selected_cels.clear()
			Global.current_project.current_frame += 1
			Global.animation_timer.wait_time = (
				Global.current_project.frames[Global.current_project.current_frame].duration
				* (1 / fps)
			)
			Global.animation_timer.start()  # Change the frame, change the wait time and start a cycle
		else:
			match animation_loop:
				0:  # No loop
					Global.play_forward.pressed = false
					Global.play_backwards.pressed = false
					Global.animation_timer.stop()
					is_animation_running = false
				1:  # Cycle loop
					Global.current_project.selected_cels.clear()
					Global.current_project.current_frame = first_frame
					Global.animation_timer.wait_time = (
						Global.current_project.frames[Global.current_project.current_frame].duration
						* (1 / fps)
					)
					Global.animation_timer.start()
				2:  # Ping pong loop
					animation_forward = false
					_on_AnimationTimer_timeout()

	else:
		if Global.current_project.current_frame > first_frame:
			Global.current_project.selected_cels.clear()
			Global.current_project.current_frame -= 1
			Global.animation_timer.wait_time = (
				Global.current_project.frames[Global.current_project.current_frame].duration
				* (1 / fps)
			)
			Global.animation_timer.start()
		else:
			match animation_loop:
				0:  # No loop
					Global.play_backwards.pressed = false
					Global.play_forward.pressed = false
					Global.animation_timer.stop()
					is_animation_running = false
				1:  # Cycle loop
					Global.current_project.selected_cels.clear()
					Global.current_project.current_frame = last_frame
					Global.animation_timer.wait_time = (
						Global.current_project.frames[Global.current_project.current_frame].duration
						* (1 / fps)
					)
					Global.animation_timer.start()
				2:  # Ping pong loop
					animation_forward = true
					_on_AnimationTimer_timeout()


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
				last_frame = min(Global.current_project.frames.size() - 1, tag.to - 1)

	if first_frame == last_frame:
		if forward_dir:
			Global.play_forward.pressed = false
		else:
			Global.play_backwards.pressed = false
		return

	if forward_dir:
		Global.play_backwards.disconnect("toggled", self, "_on_PlayBackwards_toggled")
		Global.play_backwards.pressed = false
		Global.change_button_texturerect(Global.play_backwards.get_child(0), "play_backwards.png")
		Global.play_backwards.connect("toggled", self, "_on_PlayBackwards_toggled")
	else:
		Global.play_forward.disconnect("toggled", self, "_on_PlayForward_toggled")
		Global.play_forward.pressed = false
		Global.change_button_texturerect(Global.play_forward.get_child(0), "play.png")
		Global.play_forward.connect("toggled", self, "_on_PlayForward_toggled")

	if play:
		Global.animation_timer.set_one_shot(true)  # wait_time can't change correctly if it's playing
		var duration: float = Global.current_project.frames[Global.current_project.current_frame].duration
		var fps = Global.current_project.fps
		Global.animation_timer.wait_time = duration * (1 / fps)
		Global.animation_timer.start()
		animation_forward = forward_dir
	else:
		Global.animation_timer.stop()

	is_animation_running = play


func _on_NextFrame_pressed() -> void:
	Global.canvas.selection.transform_content_confirm()
	Global.current_project.selected_cels.clear()
	if Global.current_project.current_frame < Global.current_project.frames.size() - 1:
		Global.current_project.current_frame += 1


func _on_PreviousFrame_pressed() -> void:
	Global.canvas.selection.transform_content_confirm()
	Global.current_project.selected_cels.clear()
	if Global.current_project.current_frame > 0:
		Global.current_project.current_frame -= 1


func _on_LastFrame_pressed() -> void:
	Global.canvas.selection.transform_content_confirm()
	Global.current_project.selected_cels.clear()
	Global.current_project.current_frame = Global.current_project.frames.size() - 1


func _on_FirstFrame_pressed() -> void:
	Global.canvas.selection.transform_content_confirm()
	Global.current_project.selected_cels.clear()
	Global.current_project.current_frame = 0


func _on_FPSValue_value_changed(value: float) -> void:
	Global.current_project.fps = float(value)
	Global.animation_timer.wait_time = 1 / Global.current_project.fps


func _on_PastOnionSkinning_value_changed(value: float) -> void:
	Global.onion_skinning_past_rate = int(value)
	Global.canvas.update()


func _on_FutureOnionSkinning_value_changed(value: float) -> void:
	Global.onion_skinning_future_rate = int(value)
	Global.canvas.update()


func _on_BlueRedMode_toggled(button_pressed: bool) -> void:
	Global.onion_skinning_blue_red = button_pressed
	Global.canvas.update()


func _on_PastPlacement_item_selected(index: int) -> void:
	past_above_canvas = (index == 0)
	Global.canvas.get_node("OnionPast").set("show_behind_parent", !past_above_canvas)


func _on_FuturePlacement_item_selected(index: int) -> void:
	future_above_canvas = (index == 0)
	Global.canvas.get_node("OnionFuture").set("show_behind_parent", !future_above_canvas)


# Layer buttons


func _on_AddLayer_pressed() -> void:
	Global.canvas.selection.transform_content_confirm() # TODO R2: Figure out once and for all, do these belong here, or in the project reversable functions (where these will be called on undo as well)
	var project: Project = Global.current_project

	var l := PixelLayer.new()
	var cels := []
	for f in project.frames:
		var new_cel_image := Image.new()
		new_cel_image.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
		cels.append(PixelCel.new(new_cel_image, 1))

	project.undos += 1
	project.undo_redo.create_action("Add Layer")
	project.undo_redo.add_do_property(project, "current_layer", project.layers.size())
	project.undo_redo.add_undo_property(project, "current_layer", project.current_layer)
	project.undo_redo.add_do_method(project, "add_layers", [l], [project.layers.size()], [cels])
	project.undo_redo.add_undo_method(project, "remove_layers", [project.layers.size()])
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.commit_action()


func _on_AddGroup_pressed() -> void:
	Global.canvas.selection.transform_content_confirm()
	var project: Project = Global.current_project

	var l := GroupLayer.new()
	var cels := []
	for f in project.frames:
		cels.append(GroupCel.new())

	project.undos += 1
	project.undo_redo.create_action("Add Layer")
	project.undo_redo.add_do_property(project, "current_layer", project.layers.size())
	project.undo_redo.add_undo_property(project, "current_layer", project.current_layer)
	project.undo_redo.add_do_method(project, "add_layers", [l], [project.layers.size()], [cels])
	project.undo_redo.add_undo_method(project, "remove_layers", [project.layers.size()])
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.commit_action()


func _on_CloneLayer_pressed() -> void:
	# TODO L: Multiple layer support here would be nice
	Global.canvas.selection.transform_content_confirm()

	var project: Project = Global.current_project
	var l: BaseLayer = project.layers[project.current_layer].copy()
	l.name = str(project.layers[project.current_layer].name, " (", tr("copy"), ")")
	var cels := []
	for f in project.frames:
		cels.append(f.cels[project.current_layer].copy())

	# TODO R0: Copies don't have linked cels properly set up...

	project.undos += 1
	project.undo_redo.create_action("Add Layer")
	project.undo_redo.add_do_property(project, "current_layer", project.current_layer + 1)
	project.undo_redo.add_undo_property(project, "current_layer", project.current_layer)
	project.undo_redo.add_do_method(project, "add_layers", [l], [project.current_layer + 1], [cels])
	project.undo_redo.add_undo_method(project, "remove_layers", [project.current_layer + 1])
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.commit_action()


func _on_RemoveLayer_pressed() -> void:
	# TODO R0: It is currently possible to delete all layers (by having all layers in a group and deleting the group)
	var project: Project = Global.current_project
	if project.layers.size() == 1:
		return

	var layers : Array = project.layers[project.current_layer].get_children_recursive()
	layers.append(project.layers[project.current_layer])
	var indices := []
	for l in layers:
		indices.append(l.index)

	var cels := []
	for l in layers:
		cels.append([])
		for f in project.frames:
			cels[-1].append(f.cels[l.index])

	project.undos += 1
	project.undo_redo.create_action("Remove Layer")
	# TODO R3: what should be the new current layer?
	project.undo_redo.add_do_property(project, "current_layer", max(indices[0] - 1, 0))
	project.undo_redo.add_undo_property(project, "current_layer", project.current_layer)
	project.undo_redo.add_do_method(project, "remove_layers", indices)
	project.undo_redo.add_undo_method(project, "add_layers", layers, indices, cels)
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.commit_action()

# TODO L: Refactor this (maybe completely remove)
func change_layer_order(rate: int) -> void:
	var change = Global.current_project.current_layer + rate

	var new_layers: Array = Global.current_project.layers.duplicate()
	var temp = new_layers[Global.current_project.current_layer]
	new_layers[Global.current_project.current_layer] = new_layers[change]
	new_layers[change] = temp
	Global.current_project.undo_redo.create_action("Change Layer Order")
	for f in Global.current_project.frames:
		var new_cels: Array = f.cels.duplicate()
		var temp_canvas = new_cels[Global.current_project.current_layer]
		new_cels[Global.current_project.current_layer] = new_cels[change]
		new_cels[change] = temp_canvas
		Global.current_project.undo_redo.add_do_property(f, "cels", new_cels)
		Global.current_project.undo_redo.add_undo_property(f, "cels", f.cels)

	Global.current_project.undo_redo.add_do_property(
		Global.current_project, "current_layer", change
	)
	Global.current_project.undo_redo.add_do_property(Global.current_project, "layers", new_layers)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "layers", Global.current_project.layers
	)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "current_layer", Global.current_project.current_layer
	)

	Global.current_project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	Global.current_project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	Global.current_project.undo_redo.commit_action()


func _on_MergeDownLayer_pressed() -> void:
	var project: Project = Global.current_project
	var top_layer: PixelLayer = project.layers[project.current_layer]
	var bottom_layer : PixelLayer = project.layers[project.current_layer - 1]
	var new_linked_cels: Array = bottom_layer.linked_cels.duplicate()

	project.undos += 1
	project.undo_redo.create_action("Merge Layer")

	for f in project.frames:
		# TODO Later: top_image here doesn't really need to be a copy if there isn't layer transparency
		#			though this probably will be rewriten with blend modes anyway...
		var top_image := Image.new()
		top_image.copy_from(f.cels[top_layer.index].image)

		top_image.lock()
		if f.cels[top_layer.index].opacity < 1:  # If we have layer transparency
			for xx in top_image.get_size().x:
				for yy in top_image.get_size().y:
					var pixel_color: Color = top_image.get_pixel(xx, yy)
					var alpha: float = pixel_color.a * f.cels[top_layer.index].opacity
					top_image.set_pixel(
						xx, yy, Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha)
					)
		top_image.unlock()

		var bottom_image := Image.new()
		bottom_image.copy_from(f.cels[bottom_layer.index].image)
		bottom_image.blend_rect(top_image, Rect2(Vector2.ZERO, project.size), Vector2.ZERO)
		if (
			!top_image.is_invisible()
			and bottom_layer.linked_cels.size() > 1
			and f in bottom_layer.linked_cels
		):
			new_linked_cels.erase(f)
			project.undo_redo.add_do_property(f.cels[bottom_layer.index], "image_texture", ImageTexture.new())
			project.undo_redo.add_undo_property(
				f.cels[bottom_layer.index], "image_texture", f.cels[bottom_layer.index].image_texture
			)
			project.undo_redo.add_do_property(f.cels[bottom_layer.index], "image", bottom_image)
			project.undo_redo.add_undo_property(
				f.cels[bottom_layer.index], "image", f.cels[bottom_layer.index].image
			)
		else:
			project.undo_redo.add_do_property(
				f.cels[bottom_layer.index].image, "data", bottom_image.data
			)
			project.undo_redo.add_undo_property(
				f.cels[bottom_layer.index].image, "data", f.cels[bottom_layer.index].image.data
			)

	var top_cels := []
	for f in project.frames:
		top_cels.append(f.cels[top_layer.index])

	project.undo_redo.add_do_property(project, "current_layer", bottom_layer.index)
	project.undo_redo.add_undo_property(project, "current_layer", top_layer.index)
	project.undo_redo.add_do_property(bottom_layer, "linked_cels", new_linked_cels)
	project.undo_redo.add_undo_property(bottom_layer, "linked_cels", bottom_layer.linked_cels)
	project.undo_redo.add_do_method(project, "remove_layers", [top_layer.index])
	project.undo_redo.add_undo_method(project, "add_layers", [top_layer], [top_layer.index], [top_cels])
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.commit_action()


func _on_OpacitySlider_value_changed(value) -> void:
	var current_frame: Frame = Global.current_project.frames[Global.current_project.current_frame]
	var cel: BaseCel = current_frame.cels[Global.current_project.current_layer]
	cel.opacity = value / 100
	Global.layer_opacity_slider.value = value
	Global.layer_opacity_spinbox.value = value
	Global.canvas.update()


func _on_OnionSkinningSettings_popup_hide() -> void:
	Global.can_draw = true


func project_changed() -> void:
	# TODO R0: When changing project the selcted frames will be 1 less (1 further to the left)
	#				then they should be
	# TODO R0: If you draw in the automatically created project, then load/create a new project,
	#				then going back to the automatically created project tab, you can't add/remove
	#				layers/frames (and probaly other issues).
	#				THIS HASN't BEEN REPEATED
	var project: Project = Global.current_project # TODO R3: maybe pass in instead?
	# TODO R0: Could using queue_free rather than free (or remove and queue_free) actually cause bugs?
	#				This caused the bug where changing the project would have the wrong frame button
	#				selected, but only when move_children was not called
	for child in Global.layers_container.get_children():
		child.queue_free()
	for child in Global.frame_ids.get_children():
#		child.queue_free()
		child.free()
	for container in Global.frames_container.get_children():
		container.queue_free()

	for i in range(project.layers.size()):  # TODO R2: Could this be faster if it did it in reverse order?
		project_layer_added(i)
	for f in range(project.frames.size()):
		var button: Button = frame_button_node.instance()
		button.frame = f
		Global.frame_ids.add_child(button)
#		Global.frame_ids.move_child(button, f) # TODO R0: Is this needed? Shouldn't they be in order already? (Perhaps commenting it out caused one of the above issues?)

	# TODO R3: Remove and inline what's needed here if this isn't used anywhere else:
	Global.current_project._update_animation_timeline_selection()


func project_frame_added(frame: int) -> void:
	var project: Project = Global.current_project # TODO R3: maybe pass in instead?
	var button: Button = frame_button_node.instance()
	button.frame = frame
	Global.frame_ids.add_child(button)
	Global.frame_ids.move_child(button, frame)

	var layer := Global.frames_container.get_child_count() - 1
	for container in Global.frames_container.get_children():
		var cel_button = project.frames[frame].cels[layer].create_cel_button()
		cel_button.frame = frame
		cel_button.layer = layer
		container.add_child(cel_button)
		container.move_child(cel_button, frame)
		layer -= 1


func project_frame_removed(frame: int) -> void:
	Global.frame_ids.get_child(frame).queue_free()
	Global.frame_ids.remove_child(Global.frame_ids.get_child(frame))
	for container in Global.frames_container.get_children():
		container.get_child(frame).free()


func project_layer_added(layer: int) -> void:
	var project: Project = Global.current_project

	# TODO R1: Could this function be organized in a better way?
	var layer_button: LayerButton = project.layers[layer].create_layer_button()
	layer_button.layer = layer # TODO R1: See if needed
	if project.layers[layer].name == "": # TODO R1: This probably could be somewhere else... add_layer(s) in project?
		project.layers[layer].name = project.layers[layer].get_default_name(layer)

	Global.layers_container.add_child(layer_button)
	var count := Global.layers_container.get_child_count()
	Global.layers_container.move_child(layer_button, count - 1 - layer)

	var layer_cel_container := HBoxContainer.new()
	# TODO R3: Is there any need for a name (and why is it LAYERSSS in one place, and FRAMESS in another?)
	# TODO R0: Could the order here affect performance?
	layer_cel_container.name = "LAYERSSS " + str(layer)
	Global.frames_container.add_child(layer_cel_container)
	Global.frames_container.move_child(layer_cel_container, count - 1 - layer)
	for f in range(project.frames.size()):
		var cel_button = project.frames[f].cels[layer].create_cel_button()
		cel_button.frame = f
		cel_button.layer = layer# - 1 # TODO R1: See if needed
		layer_cel_container.add_child(cel_button)

	layer_button.visible = Global.current_project.layers[layer].is_expanded_in_hierarchy()
	layer_cel_container.visible = layer_button.visible


func project_layer_removed(layer: int) -> void:
	var count := Global.layers_container.get_child_count()
	Global.layers_container.get_child(count - 1 - layer).free()
	Global.frames_container.get_child(count - 1 - layer).free()


func project_cel_added(frame: int, layer: int) -> void:
	var container := Global.frames_container.get_child(
		Global.frames_container.get_child_count() - 1 - layer
	)
	var cel_button = Global.current_project.frames[frame].cels[layer].create_cel_button()
	cel_button.frame = frame
	cel_button.layer = layer
	container.add_child(cel_button)
	container.move_child(cel_button, frame)


func project_cel_removed(frame: int, layer: int) -> void:
	var container := Global.frames_container.get_child(
		Global.frames_container.get_child_count() - 1 - layer
	)
	container.get_child(frame).free()
