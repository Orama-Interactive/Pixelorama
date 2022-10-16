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


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		drag_highlight.hide()


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
	if not timeline_container:
		return
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

	project.undos += 1
	project.undo_redo.create_action("Add Frame")

	for l in range(project.layers.size()):
		if project.layers[l].new_cels_linked:  # If the link button is pressed
			var prev_cel: BaseCel = project.frames[project.current_frame].cels[l]
			if prev_cel.link_set == null:
				prev_cel.link_set = {}
				project.undo_redo.add_do_method(
					project.layers[l], "link_cel", prev_cel, prev_cel.link_set
				)
				project.undo_redo.add_undo_method(project.layers[l], "link_cel", prev_cel, null)
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

	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.add_do_method(project, "add_frames", [frame], [frame_add_index])
	project.undo_redo.add_undo_method(project, "remove_frames", [frame_add_index])
	project.undo_redo.add_do_property(project, "animation_tags", new_animation_tags)
	project.undo_redo.add_undo_property(project, "animation_tags", project.animation_tags)
	project.undo_redo.add_do_property(project, "current_frame", project.current_frame + 1)
	project.undo_redo.add_undo_property(project, "current_frame", project.current_frame)
	project.undo_redo.commit_action()


func _on_DeleteFrame_pressed() -> void:
	var indices := []
	for cel in Global.current_project.selected_cels:
		var f: int = cel[0]
		if not f in indices:
			indices.append(f)
	indices.sort()
	delete_frames(indices)


func delete_frames(indices := []) -> void:
	var project: Project = Global.current_project
	if project.frames.size() == 1:
		return

	if indices.size() == project.frames.size():
		indices.remove(indices.size() - 1)  # Ensure the project has at least 1 frame
	elif indices.size() == 0:
		indices.append(project.current_frame)

	var current_frame: int = min(project.current_frame, project.frames.size() - indices.size() - 1)
	var frames := []
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
	project.undo_redo.add_do_method(project, "remove_frames", indices)
	project.undo_redo.add_undo_method(project, "add_frames", frames, indices)
	project.undo_redo.add_do_property(project, "animation_tags", new_animation_tags)
	project.undo_redo.add_undo_property(project, "animation_tags", project.animation_tags)
	project.undo_redo.add_do_property(project, "current_frame", current_frame)
	project.undo_redo.add_undo_property(project, "current_frame", project.current_frame)
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.commit_action()


func _on_CopyFrame_pressed() -> void:
	var indices := []
	for cel in Global.current_project.selected_cels:
		var f: int = cel[0]
		if not f in indices:
			indices.append(f)
	indices.sort()
	copy_frames(indices)


func copy_frames(indices := []) -> void:
	var project: Project = Global.current_project

	if indices.size() == 0:
		indices.append(project.current_frame)

	var copied_frames := []
	var copied_indices := range(indices[-1] + 1, indices[-1] + 1 + indices.size())

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

	for f in indices:
		var new_frame := Frame.new()
		copied_frames.append(new_frame)

		var src_frame: Frame = project.frames[f]

		new_frame.duration = src_frame.duration
		for l in range(project.layers.size()):
			var src_cel: BaseCel = project.frames[f].cels[l]  # Cel we're copying from, the source
			var new_cel: BaseCel = src_cel.get_script().new()
			if project.layers[l].new_cels_linked:
				if src_cel.link_set == null:
					src_cel.link_set = {}
					project.undo_redo.add_do_method(
						project.layers[l], "link_cel", src_cel, src_cel.link_set
					)
					project.undo_redo.add_undo_method(project.layers[l], "link_cel", src_cel, null)
				new_cel.set_content(src_cel.get_content(), src_cel.image_texture)
				new_cel.link_set = src_cel.link_set
			else:
				new_cel.set_content(src_cel.copy_content())
			new_cel.opacity = src_cel.opacity
			new_frame.cels.append(new_cel)

		# Loop through the tags to see if the frame is in one
		for tag in new_animation_tags:
			if indices[-1] + 1 >= tag.from && indices[-1] + 1 <= tag.to:
				tag.to += 1
			elif indices[-1] + 1 < tag.from:
				tag.from += 1
				tag.to += 1

	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.add_do_method(project, "add_frames", copied_frames, copied_indices)
	project.undo_redo.add_undo_method(project, "remove_frames", copied_indices)
	project.undo_redo.add_do_property(project, "current_frame", indices[-1] + 1)
	project.undo_redo.add_undo_property(project, "current_frame", indices[-1])
	project.undo_redo.add_do_property(project, "animation_tags", new_animation_tags)
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


# Called on each frame of the animation
func _on_AnimationTimer_timeout() -> void:
	if first_frame == last_frame:
		Global.play_forward.pressed = false
		Global.play_backwards.pressed = false
		Global.animation_timer.stop()
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
	var project: Project = Global.current_project

	var l := PixelLayer.new(project)
	var cels := []
	for f in project.frames:
		cels.append(l.new_empty_cel())

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
	var project: Project = Global.current_project

	var l := GroupLayer.new(project)
	var cels := []
	for f in project.frames:
		cels.append(l.new_empty_cel())

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
	var project: Project = Global.current_project
	var source_layers: Array = project.layers[project.current_layer].get_children(true)
	source_layers.append(project.layers[project.current_layer])

	var clones := []  # Array of Layers
	var cels := []  # 2D Array of Cels
	for src_layer in source_layers:
		var cl_layer: BaseLayer = src_layer.get_script().new(project)
		cl_layer.project = project
		cl_layer.index = src_layer.index
		cl_layer.deserialize(src_layer.serialize())
		clones.append(cl_layer)

		cels.append([])
		for i in cl_layer.cel_link_sets.size():
			cl_layer.cel_link_sets[i]["cels"] = []  # Set to a new empty array

		print(src_layer.cel_link_sets) # TODO: Remove

		for frame in project.frames:
			var src_cel: BaseCel = frame.cels[src_layer.index]
			var new_cel: BaseCel = src_cel.get_script().new()

			if src_cel.link_set == null:
				new_cel.set_content(src_cel.copy_content())
			else:
				# TODO: In this version, find is failing, for some reason the link_set isn't matching?
				#		Printing often shows that the cel's link_set doesn't match... but why?
				new_cel.link_set = cl_layer.cel_link_sets[src_layer.cel_link_sets.find(
					src_cel.link_set
				)]
				print(src_cel.link_set) # TODO: Remove
				if new_cel.link_set["cels"].size() > 0:
					var linked_cel: BaseCel = new_cel.link_set["cels"][0]
					new_cel.set_content(linked_cel.get_content(), linked_cel.image_texture)
				else:
					new_cel.set_content(src_cel.copy_content())
				new_cel.link_set["cels"].append(new_cel)

			new_cel.opacity = src_cel.opacity
			cels[-1].append(new_cel)

	for cl_layer in clones:
		var p = source_layers.find(cl_layer.parent)
		if p > -1:  # Swap parent with clone if the parent is one of the source layers
			cl_layer.parent = clones[p]
		else:  # Add (Copy) to the name if its not a child of another copied layer
			cl_layer.name = str(cl_layer.name, " (", tr("copy"), ")")

	var indices := range(project.current_layer + 1, project.current_layer + clones.size() + 1)

	project.undos += 1
	project.undo_redo.create_action("Add Layer")
	project.undo_redo.add_do_property(
		project, "current_layer", project.current_layer + clones.size()
	)
	project.undo_redo.add_undo_property(project, "current_layer", project.current_layer)
	project.undo_redo.add_do_method(project, "add_layers", clones, indices, cels)
	project.undo_redo.add_undo_method(project, "remove_layers", indices)
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.commit_action()


func _on_RemoveLayer_pressed() -> void:
	var project: Project = Global.current_project
	if project.layers.size() == 1:
		return

	var layers: Array = project.layers[project.current_layer].get_children(true)
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
	project.undo_redo.add_do_property(project, "current_layer", max(indices[0] - 1, 0))
	project.undo_redo.add_undo_property(project, "current_layer", project.current_layer)
	project.undo_redo.add_do_method(project, "remove_layers", indices)
	project.undo_redo.add_undo_method(project, "add_layers", layers, indices, cels)
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.commit_action()


# Move the layer up or down in layer order and/or reparent to be deeper/shallower in the
# layer hierarchy depending on its current index and parent
func change_layer_order(up: bool) -> void:
	var project: Project = Global.current_project
	var layer: BaseLayer = project.layers[project.current_layer]
	var child_count = layer.get_child_count(true)
	var from_indices := range(layer.index - child_count, layer.index + 1)
	var from_parents := []
	for l in from_indices:
		from_parents.append(project.layers[l].parent)
	var to_parents := from_parents.duplicate()
	var to_index = layer.index - child_count  # the index where the LOWEST shifted layer should end up

	if up:
		var above_layer: BaseLayer = project.layers[project.current_layer + 1]
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
			var below_layer: BaseLayer = project.layers[project.current_layer - 1 - child_count]
			if layer.parent != below_layer.parent:  # If there is a hierarchy change
				to_parents[-1] = layer.parent.parent  # Drop a level in the hierarchy
			elif below_layer.accepts_child(layer):
				to_parents[-1] = below_layer
				to_index = to_index - 1
			else:
				to_index = to_index - 1

	var to_indices := range(to_index, to_index + child_count + 1)

	project.undo_redo.create_action("Change Layer Order")
	project.undo_redo.add_do_property(project, "current_layer", to_index + child_count)
	project.undo_redo.add_undo_property(project, "current_layer", project.current_layer)
	project.undo_redo.add_do_method(project, "move_layers", from_indices, to_indices, to_parents)
	project.undo_redo.add_undo_method(
		project, "move_layers", to_indices, from_indices, from_parents
	)
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.commit_action()


func _on_MergeDownLayer_pressed() -> void:
	var project: Project = Global.current_project
	var top_layer: PixelLayer = project.layers[project.current_layer]
	var bottom_layer: PixelLayer = project.layers[project.current_layer - 1]
	var top_cels := []

	project.undos += 1
	project.undo_redo.create_action("Merge Layer")

	for frame in project.frames:
		top_cels.append(frame.cels[top_layer.index])  # Store for undo purposes

		var top_image := Image.new()
		top_image.copy_from(frame.cels[top_layer.index].image)

		top_image.lock()
		if frame.cels[top_layer.index].opacity < 1:  # If we have layer transparency
			for xx in top_image.get_size().x:
				for yy in top_image.get_size().y:
					var pixel_color: Color = top_image.get_pixel(xx, yy)
					var alpha: float = pixel_color.a * frame.cels[top_layer.index].opacity
					top_image.set_pixel(
						xx, yy, Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha)
					)
		top_image.unlock()
		var bottom_cel: BaseCel = frame.cels[bottom_layer.index]
		var bottom_image := Image.new()
		bottom_image.copy_from(bottom_cel.image)
		bottom_image.blend_rect(top_image, Rect2(Vector2.ZERO, project.size), Vector2.ZERO)
		if (
			bottom_cel.link_set != null
			and bottom_cel.link_set.size() > 1
			and not top_image.is_invisible()
		):
			# Unlink cel:
			project.undo_redo.add_do_method(bottom_layer, "link_cel", bottom_cel, null)
			project.undo_redo.add_undo_method(
				bottom_layer, "link_cel", bottom_cel, bottom_cel.link_set
			)
			project.undo_redo.add_do_property(bottom_cel, "image_texture", ImageTexture.new())
			project.undo_redo.add_undo_property(
				bottom_cel, "image_texture", bottom_cel.image_texture
			)
			project.undo_redo.add_do_property(bottom_cel, "image", bottom_image)
			project.undo_redo.add_undo_property(bottom_cel, "image", bottom_cel.image)
		else:
			project.undo_redo.add_do_property(bottom_cel.image, "data", bottom_image.data)
			project.undo_redo.add_undo_property(bottom_cel.image, "data", bottom_cel.image.data)

	project.undo_redo.add_do_property(project, "current_layer", bottom_layer.index)
	project.undo_redo.add_undo_property(project, "current_layer", top_layer.index)
	project.undo_redo.add_do_method(project, "remove_layers", [top_layer.index])
	project.undo_redo.add_undo_method(
		project, "add_layers", [top_layer], [top_layer.index], [top_cels]
	)
	project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	project.undo_redo.commit_action()


func _on_OpacitySlider_value_changed(value) -> void:
	var current_frame: Frame = Global.current_project.frames[Global.current_project.current_frame]
	var cel: BaseCel = current_frame.cels[Global.current_project.current_layer]
	cel.opacity = value / 100
	Global.canvas.update()


func _on_OnionSkinningSettings_popup_hide() -> void:
	Global.can_draw = true


# Methods to update the UI in response to changes in the current project


func project_changed() -> void:
	var project: Project = Global.current_project
	# These must be removed from tree immediately to not mess up the indices of
	# the new buttons, so use either free or queue_free + parent.remove_child
	for child in Global.layers_container.get_children():
		child.free()
	for child in Global.frame_ids.get_children():
		child.free()
	for container in Global.frames_container.get_children():
		container.free()

	for i in project.layers.size():
		project_layer_added(i)
	for f in project.frames.size():
		var button: Button = frame_button_node.instance()
		button.frame = f
		Global.frame_ids.add_child(button)

	# Press selected cel/frame/layer buttons
	for cel_index in project.selected_cels:
		var frame: int = cel_index[0]
		var layer: int = cel_index[1]
		if frame < Global.frame_ids.get_child_count():
			var frame_button: BaseButton = Global.frame_ids.get_child(frame)
			frame_button.pressed = true

		var container_child_count: int = Global.frames_container.get_child_count()
		if layer < container_child_count:
			var container = Global.frames_container.get_child(container_child_count - 1 - layer)
			if frame < container.get_child_count():
				var cel_button = container.get_child(frame)
				cel_button.pressed = true

			var layer_button = Global.layers_container.get_child(container_child_count - 1 - layer)
			layer_button.pressed = true


func project_frame_added(frame: int) -> void:
	var project: Project = Global.current_project
	var button: Button = frame_button_node.instance()
	button.frame = frame
	Global.frame_ids.add_child(button)
	Global.frame_ids.move_child(button, frame)

	var layer := Global.frames_container.get_child_count() - 1
	for container in Global.frames_container.get_children():
		var cel_button = project.frames[frame].cels[layer].instantiate_cel_button()
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

	var layer_button: LayerButton = project.layers[layer].instantiate_layer_button()
	layer_button.layer = layer
	if project.layers[layer].name == "":
		project.layers[layer].set_name_to_default(layer)

	var layer_cel_container := HBoxContainer.new()
	for f in project.frames.size():
		var cel_button = project.frames[f].cels[layer].instantiate_cel_button()
		cel_button.frame = f
		cel_button.layer = layer
		layer_cel_container.add_child(cel_button)

	layer_button.visible = Global.current_project.layers[layer].is_expanded_in_hierarchy()
	layer_cel_container.visible = layer_button.visible

	Global.layers_container.add_child(layer_button)
	var count := Global.layers_container.get_child_count()
	Global.layers_container.move_child(layer_button, count - 1 - layer)
	Global.frames_container.add_child(layer_cel_container)
	Global.frames_container.move_child(layer_cel_container, count - 1 - layer)


func project_layer_removed(layer: int) -> void:
	var count := Global.layers_container.get_child_count()
	Global.layers_container.get_child(count - 1 - layer).free()
	Global.frames_container.get_child(count - 1 - layer).free()


func project_cel_added(frame: int, layer: int) -> void:
	var container := Global.frames_container.get_child(
		Global.frames_container.get_child_count() - 1 - layer
	)
	var cel_button = Global.current_project.frames[frame].cels[layer].instantiate_cel_button()
	cel_button.frame = frame
	cel_button.layer = layer
	container.add_child(cel_button)
	container.move_child(cel_button, frame)


func project_cel_removed(frame: int, layer: int) -> void:
	var container := Global.frames_container.get_child(
		Global.frames_container.get_child_count() - 1 - layer
	)
	container.get_child(frame).queue_free()
	container.remove_child(container.get_child(frame))
