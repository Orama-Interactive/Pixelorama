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

onready var timeline_scroll: ScrollContainer = find_node("TimelineScroll")
onready var tag_scroll_container: ScrollContainer = find_node("TagScroll")
onready var fps_spinbox: SpinBox = find_node("FPSValue")
onready var onion_skinning_button: BaseButton = find_node("OnionSkinning")
onready var loop_animation_button: BaseButton = find_node("LoopAnim")


func _ready() -> void:
	timeline_scroll.get_h_scrollbar().connect("value_changed", self, "_h_scroll_changed")
	Global.animation_timer.wait_time = 1 / Global.current_project.fps
	fps_spinbox.value = Global.current_project.fps


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
		timeline_scroll.get_child(0).rect_size.x
		- 212
	)
	tag_scroll_container.scroll_horizontal = value


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
	var new_frames: Array = project.frames.duplicate()
	var new_layers: Array = project.duplicate_layers()
	new_frames.insert(frame_add_index, frame)

	for l_i in range(new_layers.size()):
		if new_layers[l_i].new_cels_linked:  # If the link button is pressed
			new_layers[l_i].linked_cels.append(frame)
			frame.cels[l_i].image = new_layers[l_i].linked_cels[0].cels[l_i].image
			frame.cels[l_i].image_texture = new_layers[l_i].linked_cels[0].cels[l_i].image_texture

	# Code to PUSH AHEAD tags starting after the frame
	var new_animation_tags := Global.current_project.animation_tags.duplicate()
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

	project.undo_redo.add_do_property(project, "frames", new_frames)
	project.undo_redo.add_do_property(project, "current_frame", project.current_frame + 1)
	Global.current_project.undo_redo.add_do_property(
		Global.current_project, "animation_tags", new_animation_tags
	)
	project.undo_redo.add_do_property(project, "layers", new_layers)

	project.undo_redo.add_undo_property(project, "frames", project.frames)
	project.undo_redo.add_undo_property(project, "current_frame", project.current_frame)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "animation_tags", Global.current_project.animation_tags
	)
	project.undo_redo.add_undo_property(project, "layers", project.layers)
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
	if Global.current_project.frames.size() == 1:
		return

	if frames.size() == 0:
		frames.append(Global.current_project.current_frame)

	var new_frames: Array = Global.current_project.frames.duplicate()
	var current_frame := Global.current_project.current_frame
	var new_layers: Array = Global.current_project.duplicate_layers()
	var frame_correction := 0  # Only needed for tag adjustment

	var new_animation_tags := Global.current_project.animation_tags.duplicate()
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
		var frame_to_delete: Frame = Global.current_project.frames[frame]
		new_frames.erase(frame_to_delete)
		if current_frame > 0 && current_frame == new_frames.size():  # If it's the last frame
			current_frame -= 1

		# Check if one of the cels of the frame is linked
		# if they are, unlink them too
		# this prevents removed cels being kept in linked memory
		for layer in new_layers:
			for linked in layer.linked_cels:
				if linked == Global.current_project.frames[frame]:
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

	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Remove Frame")

	Global.current_project.undo_redo.add_do_property(Global.current_project, "frames", new_frames)
	Global.current_project.undo_redo.add_do_property(
		Global.current_project, "current_frame", current_frame
	)
	Global.current_project.undo_redo.add_do_property(
		Global.current_project, "animation_tags", new_animation_tags
	)
	Global.current_project.undo_redo.add_do_property(Global.current_project, "layers", new_layers)

	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "frames", Global.current_project.frames
	)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "current_frame", Global.current_project.current_frame
	)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "animation_tags", Global.current_project.animation_tags
	)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "layers", Global.current_project.layers
	)

	Global.current_project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	Global.current_project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	Global.current_project.undo_redo.commit_action()


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

	if frames.size() == 0:
		frames.append(Global.current_project.current_frame)

	var new_frames := Global.current_project.frames.duplicate()
	var new_layers: Array = Global.current_project.duplicate_layers()

	var new_animation_tags := Global.current_project.animation_tags.duplicate()
	# Loop through the tags to create new classes for them, so that they won't be the same
	# as Global.current_project.animation_tags's classes. Needed for undo/redo to work properly.
	for i in new_animation_tags.size():
		new_animation_tags[i] = AnimationTag.new(
			new_animation_tags[i].name,
			new_animation_tags[i].color,
			new_animation_tags[i].from,
			new_animation_tags[i].to
		)

	for frm in frames.size():
		var frame = frames[(frames.size() - 1) - frm]
		var new_frame := Frame.new()
		new_frames.insert(frames[-1] + 1, new_frame)

		var prev_frame: Frame = Global.current_project.frames[frame]
		for cel in prev_frame.cels:  # Copy every cel
			var sprite := Image.new()
			sprite.copy_from(cel.image)
			var sprite_texture := ImageTexture.new()
			sprite_texture.create_from_image(sprite, 0)
			new_frame.cels.append(Cel.new(sprite, cel.opacity, sprite_texture))

		new_frame.duration = prev_frame.duration
		for l_i in range(new_layers.size()):
			if new_layers[l_i].new_cels_linked:  # If the link button is pressed
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

	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Add Frame")
	Global.current_project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	Global.current_project.undo_redo.add_undo_method(Global, "undo_or_redo", true)

	Global.current_project.undo_redo.add_do_property(Global.current_project, "frames", new_frames)
	Global.current_project.undo_redo.add_do_property(
		Global.current_project, "current_frame", frames[-1] + 1
	)
	Global.current_project.undo_redo.add_do_property(Global.current_project, "layers", new_layers)
	Global.current_project.undo_redo.add_do_property(
		Global.current_project, "animation_tags", new_animation_tags
	)

	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "frames", Global.current_project.frames
	)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "current_frame", frames[-1]
	)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "layers", Global.current_project.layers
	)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "animation_tags", Global.current_project.animation_tags
	)
	Global.current_project.undo_redo.commit_action()


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


func add_layer(is_new := true) -> void:
	Global.canvas.selection.transform_content_confirm()
	var new_layers: Array = Global.current_project.layers.duplicate()
	var l := Layer.new()
	if !is_new:  # Clone layer
		l.name = (
			Global.current_project.layers[Global.current_project.current_layer].name
			+ " ("
			+ tr("copy")
			+ ")"
		)
	new_layers.append(l)

	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Add Layer")

	for f in Global.current_project.frames:
		var new_layer := Image.new()
		if is_new:
			new_layer.create(
				Global.current_project.size.x,
				Global.current_project.size.y,
				false,
				Image.FORMAT_RGBA8
			)
		else:  # Clone layer
			new_layer.copy_from(f.cels[Global.current_project.current_layer].image)

		var new_cels: Array = f.cels.duplicate()
		new_cels.append(Cel.new(new_layer, 1))
		Global.current_project.undo_redo.add_do_property(f, "cels", new_cels)
		Global.current_project.undo_redo.add_undo_property(f, "cels", f.cels)

	Global.current_project.undo_redo.add_do_property(
		Global.current_project, "current_layer", Global.current_project.layers.size()
	)
	Global.current_project.undo_redo.add_do_property(Global.current_project, "layers", new_layers)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "current_layer", Global.current_project.current_layer
	)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "layers", Global.current_project.layers
	)

	Global.current_project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	Global.current_project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	Global.current_project.undo_redo.commit_action()


func _on_RemoveLayer_pressed() -> void:
	if Global.current_project.layers.size() == 1:
		return
	var new_layers: Array = Global.current_project.layers.duplicate()
	new_layers.remove(Global.current_project.current_layer)
	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Remove Layer")
	if Global.current_project.current_layer > 0:
		Global.current_project.undo_redo.add_do_property(
			Global.current_project, "current_layer", Global.current_project.current_layer - 1
		)
	else:
		Global.current_project.undo_redo.add_do_property(
			Global.current_project, "current_layer", Global.current_project.current_layer
		)

	for f in Global.current_project.frames:
		var new_cels: Array = f.cels.duplicate()
		new_cels.remove(Global.current_project.current_layer)
		Global.current_project.undo_redo.add_do_property(f, "cels", new_cels)
		Global.current_project.undo_redo.add_undo_property(f, "cels", f.cels)

	Global.current_project.undo_redo.add_do_property(Global.current_project, "layers", new_layers)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "current_layer", Global.current_project.current_layer
	)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "layers", Global.current_project.layers
	)
	Global.current_project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	Global.current_project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	Global.current_project.undo_redo.commit_action()


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
	var new_layers: Array = Global.current_project.duplicate_layers()

	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Merge Layer")
	for f in Global.current_project.frames:
		var new_cels: Array = f.cels.duplicate()
		for i in new_cels.size():
			new_cels[i] = Cel.new(new_cels[i].image, new_cels[i].opacity)
		var selected_layer := Image.new()
		selected_layer.copy_from(new_cels[Global.current_project.current_layer].image)

		selected_layer.lock()
		if f.cels[Global.current_project.current_layer].opacity < 1:  # If we have layer transparency
			for xx in selected_layer.get_size().x:
				for yy in selected_layer.get_size().y:
					var pixel_color: Color = selected_layer.get_pixel(xx, yy)
					var alpha: float = (
						pixel_color.a
						* f.cels[Global.current_project.current_layer].opacity
					)
					selected_layer.set_pixel(
						xx, yy, Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha)
					)
		selected_layer.unlock()

		var new_layer := Image.new()
		new_layer.copy_from(f.cels[Global.current_project.current_layer - 1].image)
		new_layer.blend_rect(
			selected_layer, Rect2(Vector2.ZERO, Global.current_project.size), Vector2.ZERO
		)
		new_cels.remove(Global.current_project.current_layer)
		if (
			!selected_layer.is_invisible()
			and (
				Global.current_project.layers[Global.current_project.current_layer - 1].linked_cels.size()
				> 1
			)
			and (
				f
				in Global.current_project.layers[(
					Global.current_project.current_layer
					- 1
				)].linked_cels
			)
		):
			new_layers[Global.current_project.current_layer - 1].linked_cels.erase(f)
			new_cels[Global.current_project.current_layer - 1].image = new_layer
		else:
			Global.current_project.undo_redo.add_do_property(
				f.cels[Global.current_project.current_layer - 1].image, "data", new_layer.data
			)
			Global.current_project.undo_redo.add_undo_property(
				f.cels[Global.current_project.current_layer - 1].image,
				"data",
				f.cels[Global.current_project.current_layer - 1].image.data
			)

		Global.current_project.undo_redo.add_do_property(f, "cels", new_cels)
		Global.current_project.undo_redo.add_undo_property(f, "cels", f.cels)

	new_layers.remove(Global.current_project.current_layer)
	Global.current_project.undo_redo.add_do_property(
		Global.current_project, "current_layer", Global.current_project.current_layer - 1
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


func _on_OpacitySlider_value_changed(value) -> void:
	var current_frame: Frame = Global.current_project.frames[Global.current_project.current_frame]
	var cel: Cel = current_frame.cels[Global.current_project.current_layer]
	cel.opacity = value / 100
	Global.layer_opacity_slider.value = value
	Global.layer_opacity_spinbox.value = value
	Global.canvas.update()


func _on_OnionSkinningSettings_popup_hide() -> void:
	Global.can_draw = true
