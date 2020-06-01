extends Panel

var fps := 6.0
var animation_loop := 1 # 0 is no loop, 1 is cycle loop, 2 is ping-pong loop
var animation_forward := true
var first_frame := 0
var last_frame : int = Global.canvases.size() - 1

var timeline_scroll : ScrollContainer
var tag_scroll_container : ScrollContainer


func _ready() -> void:
	timeline_scroll = Global.find_node_by_name(self, "TimelineScroll")
	tag_scroll_container = Global.find_node_by_name(self, "TagScroll")
	timeline_scroll.get_h_scrollbar().connect("value_changed", self, "_h_scroll_changed")
	Global.animation_timer.wait_time = 1 / fps


func _h_scroll_changed(value : float) -> void:
	# Let the main timeline ScrollContainer affect the tag ScrollContainer too
	tag_scroll_container.get_child(0).rect_min_size.x = timeline_scroll.get_child(0).rect_size.x - 212
	tag_scroll_container.scroll_horizontal = value


func add_frame() -> void:
	var new_canvas : Canvas = load("res://src/Canvas.tscn").instance()
	new_canvas.size = Global.canvas.size
	new_canvas.frame = Global.canvases.size()

	var new_canvases : Array = Global.canvases.duplicate()
	new_canvases.append(new_canvas)

	Global.undos += 1
	Global.undo_redo.create_action("Add Frame")
	Global.undo_redo.add_do_method(Global, "redo", [new_canvas])
	Global.undo_redo.add_undo_method(Global, "undo", [new_canvas])

	Global.undo_redo.add_do_property(Global, "canvases", new_canvases)
	Global.undo_redo.add_do_property(Global, "canvas", new_canvas)
	Global.undo_redo.add_do_property(Global, "current_frame", new_canvases.size() - 1)

	for c in Global.canvases:
		Global.undo_redo.add_do_property(c, "visible", false)
		Global.undo_redo.add_undo_property(c, "visible", c.visible)

	for l_i in range(Global.layers.size()):
		if Global.layers[l_i].new_cels_linked: # If the link button is pressed
			Global.layers[l_i].linked_cels.append(new_canvas)

	Global.undo_redo.add_undo_property(Global, "canvases", Global.canvases)
	Global.undo_redo.add_undo_property(Global, "canvas", Global.canvas)
	Global.undo_redo.add_undo_property(Global, "current_frame", Global.current_frame)
	Global.undo_redo.commit_action()


func _on_DeleteFrame_pressed(frame := -1) -> void:
	if Global.canvases.size() == 1:
		return
	if frame == -1:
		frame = Global.current_frame

	var canvas : Canvas = Global.canvases[frame]
	var new_canvases : Array = Global.canvases.duplicate()
	new_canvases.erase(canvas)
	var current_frame := Global.current_frame
	if current_frame > 0 && current_frame == new_canvases.size(): # If it's the last frame
		current_frame -= 1

	var new_animation_tags := Global.animation_tags.duplicate(true)
	# Loop through the tags to see if the frame is in one
	for tag in new_animation_tags:
		if frame + 1 >= tag[2] && frame + 1 <= tag[3]:
			if tag[3] == tag[2]: # If we're deleting the only frame in the tag
				new_animation_tags.erase(tag)
			else:
				tag[3] -= 1
		elif frame + 1 < tag[2]:
			tag[2] -= 1
			tag[3] -= 1

	# Check if one of the cels of the frame is linked
	# if they are, unlink them too
	# this prevents removed cels being kept in linked memory
	var new_layers : Array = Global.layers.duplicate(true)
	for layer in new_layers:
		for linked in layer.linked_cels:
			if linked == Global.canvases[frame]:
				layer.linked_cels.erase(linked)

	Global.undos += 1
	Global.undo_redo.create_action("Remove Frame")

	Global.undo_redo.add_do_property(Global, "canvases", new_canvases)
	Global.undo_redo.add_do_property(Global, "canvas", new_canvases[current_frame])
	Global.undo_redo.add_do_property(Global, "current_frame", current_frame)
	Global.undo_redo.add_do_property(Global, "animation_tags", new_animation_tags)
	Global.undo_redo.add_do_property(Global, "layers", new_layers)

	# Change the frame value of the canvaseso on the right
	# for example, if frame "3" was deleted, then "4" would have to become "3"
	for i in range(frame, new_canvases.size()):
		var c : Canvas = new_canvases[i]
		Global.undo_redo.add_do_property(c, "frame", i)
		Global.undo_redo.add_undo_property(c, "frame", c.frame)


	Global.undo_redo.add_undo_property(Global, "canvases", Global.canvases)
	Global.undo_redo.add_undo_property(Global, "canvas", canvas)
	Global.undo_redo.add_undo_property(Global, "current_frame", Global.current_frame)
	Global.undo_redo.add_undo_property(Global, "animation_tags", Global.animation_tags)
	Global.undo_redo.add_undo_property(Global, "layers", Global.layers)

	Global.undo_redo.add_do_method(Global, "redo", [canvas])
	Global.undo_redo.add_undo_method(Global, "undo", [canvas])
	Global.undo_redo.commit_action()


func _on_CopyFrame_pressed(frame := -1) -> void:
	if frame == -1:
		frame = Global.current_frame

	var canvas : Canvas = Global.canvases[frame]
	var new_canvas : Canvas = load("res://src/Canvas.tscn").instance()
	new_canvas.size = Global.canvas.size
	new_canvas.frame = Global.canvases.size()

	var new_canvases := Global.canvases.duplicate()
	new_canvases.insert(frame + 1, new_canvas)

	for layer in canvas.layers: # Copy every layer
		var sprite := Image.new()
		sprite.copy_from(layer[0])
		sprite.lock()
		var tex := ImageTexture.new()
		tex.create_from_image(sprite, 0)
		new_canvas.layers.append([sprite, tex, layer[2]])

	var new_animation_tags := Global.animation_tags.duplicate(true)
	# Loop through the tags to see if the frame is in one
	for tag in new_animation_tags:
		if frame + 1 >= tag[2] && frame + 1 <= tag[3]:
			tag[3] += 1

	Global.undos += 1
	Global.undo_redo.create_action("Add Frame")
	Global.undo_redo.add_do_method(Global, "redo", [new_canvas])
	Global.undo_redo.add_undo_method(Global, "undo", [new_canvas])

	Global.undo_redo.add_do_property(Global, "canvases", new_canvases)
	Global.undo_redo.add_do_property(Global, "canvas", new_canvas)
	Global.undo_redo.add_do_property(Global, "current_frame", frame + 1)
	Global.undo_redo.add_do_property(Global, "animation_tags", new_animation_tags)
	for i in range(Global.layers.size()):
		for child in Global.layers[i].frame_container.get_children():
			Global.undo_redo.add_do_property(child, "pressed", false)
			Global.undo_redo.add_undo_property(child, "pressed", child.pressed)
	for c in Global.canvases:
		Global.undo_redo.add_do_property(c, "visible", false)
		Global.undo_redo.add_undo_property(c, "visible", c.visible)

	for i in range(frame, new_canvases.size()):
		var c : Canvas = new_canvases[i]
		Global.undo_redo.add_do_property(c, "frame", i)
		Global.undo_redo.add_undo_property(c, "frame", c.frame)

	Global.undo_redo.add_undo_property(Global, "canvases", Global.canvases)
	Global.undo_redo.add_undo_property(Global, "canvas", Global.canvas)
	Global.undo_redo.add_undo_property(Global, "current_frame", frame)
	Global.undo_redo.add_undo_property(Global, "animation_tags", Global.animation_tags)
	Global.undo_redo.commit_action()


func _on_FrameTagButton_pressed() -> void:
	Global.tag_dialog.popup_centered()


func _on_OnionSkinning_pressed() -> void:
	Global.onion_skinning = !Global.onion_skinning
	Global.canvas.update()
	var texture_button : TextureRect = Global.onion_skinning_button.get_child(0)
	if Global.onion_skinning:
		Global.change_button_texturerect(texture_button, "onion_skinning.png")
	else:
		Global.change_button_texturerect(texture_button, "onion_skinning_off.png")


func _on_OnionSkinningSettings_pressed() -> void:
	$OnionSkinningSettings.popup(Rect2(Global.onion_skinning_button.rect_global_position.x - $OnionSkinningSettings.rect_size.x - 16, Global.onion_skinning_button.rect_global_position.y - 106, 136, 126))


func _on_LoopAnim_pressed() -> void:
	var texture_button : TextureRect = Global.loop_animation_button.get_child(0)
	match animation_loop:
		0: # Make it loop
			animation_loop = 1
			Global.change_button_texturerect(texture_button, "loop.png")
			Global.loop_animation_button.hint_tooltip = "Cycle loop"
		1: # Make it ping-pong
			animation_loop = 2
			Global.change_button_texturerect(texture_button, "loop_pingpong.png")
			Global.loop_animation_button.hint_tooltip = "Ping-pong loop"
		2: # Make it stop
			animation_loop = 0
			Global.change_button_texturerect(texture_button, "loop_none.png")
			Global.loop_animation_button.hint_tooltip = "No loop"


func _on_PlayForward_toggled(button_pressed : bool) -> void:
	if button_pressed:
		Global.change_button_texturerect(Global.play_forward.get_child(0), "pause.png")
	else:
		Global.change_button_texturerect(Global.play_forward.get_child(0), "play.png")

	play_animation(button_pressed, true)


func _on_PlayBackwards_toggled(button_pressed : bool) -> void:
	if button_pressed:
		Global.change_button_texturerect(Global.play_backwards.get_child(0), "pause.png")
	else:
		Global.change_button_texturerect(Global.play_backwards.get_child(0), "play_backwards.png")

	play_animation(button_pressed, false)


func _on_AnimationTimer_timeout() -> void:
	if first_frame == last_frame:
		$AnimationTimer.stop()
		return

	if animation_forward:
		if Global.current_frame < last_frame:
			Global.current_frame += 1
		else:
			match animation_loop:
				0: # No loop
					Global.play_forward.pressed = false
					Global.play_backwards.pressed = false
					Global.animation_timer.stop()
				1: # Cycle loop
					Global.current_frame = first_frame
				2: # Ping pong loop
					animation_forward = false
					_on_AnimationTimer_timeout()

	else:
		if Global.current_frame > first_frame:
			Global.current_frame -= 1
		else:
			match animation_loop:
				0: # No loop
					Global.play_backwards.pressed = false
					Global.play_forward.pressed = false
					Global.animation_timer.stop()
				1: # Cycle loop
					Global.current_frame = last_frame
				2: # Ping pong loop
					animation_forward = true
					_on_AnimationTimer_timeout()


func play_animation(play : bool, forward_dir : bool) -> void:
	first_frame = 0
	last_frame = Global.canvases.size() - 1
	if Global.play_only_tags:
		for tag in Global.animation_tags:
			if Global.current_frame + 1 >= tag[2] && Global.current_frame + 1 <= tag[3]:
				first_frame = tag[2] - 1
				last_frame = min(Global.canvases.size() - 1, tag[3] - 1)

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
		Global.animation_timer.wait_time = 1 / fps
		Global.animation_timer.start()
		animation_forward = forward_dir
	else:
		Global.animation_timer.stop()


func _on_NextFrame_pressed() -> void:
	if Global.current_frame < Global.canvases.size() - 1:
		Global.current_frame += 1


func _on_PreviousFrame_pressed() -> void:
	if Global.current_frame > 0:
		Global.current_frame -= 1


func _on_LastFrame_pressed() -> void:
	Global.current_frame = Global.canvases.size() - 1


func _on_FirstFrame_pressed() -> void:
	Global.current_frame = 0


func _on_FPSValue_value_changed(value : float) -> void:
	fps = float(value)
	Global.animation_timer.wait_time = 1 / fps


func _on_PastOnionSkinning_value_changed(value : float) -> void:
	Global.onion_skinning_past_rate = int(value)
	Global.canvas.update()


func _on_FutureOnionSkinning_value_changed(value : float) -> void:
	Global.onion_skinning_future_rate = int(value)
	Global.canvas.update()


func _on_BlueRedMode_toggled(button_pressed : bool) -> void:
	Global.onion_skinning_blue_red = button_pressed
	Global.canvas.update()


# Layer buttons

func add_layer(is_new := true) -> void:
	var new_layers : Array = Global.layers.duplicate()
	var l := Layer.new()
	if !is_new: # Clone layer
		l.name = Global.layers[Global.current_layer].name + " (" + tr("copy") + ")"
	new_layers.append(l)

	Global.undos += 1
	Global.undo_redo.create_action("Add Layer")

	for c in Global.canvases:
		var new_layer := Image.new()
		if is_new:
			new_layer.create(c.size.x, c.size.y, false, Image.FORMAT_RGBA8)
		else: # Clone layer
			new_layer.copy_from(c.layers[Global.current_layer][0])

		new_layer.lock()
		var new_layer_tex := ImageTexture.new()
		new_layer_tex.create_from_image(new_layer, 0)

		var new_canvas_layers : Array = c.layers.duplicate()
		# Store [Image, ImageTexture, Opacity]
		new_canvas_layers.append([new_layer, new_layer_tex, 1])
		Global.undo_redo.add_do_property(c, "layers", new_canvas_layers)
		Global.undo_redo.add_undo_property(c, "layers", c.layers)

	Global.undo_redo.add_do_property(Global, "current_layer", Global.current_layer + 1)
	Global.undo_redo.add_do_property(Global, "layers", new_layers)
	Global.undo_redo.add_undo_property(Global, "current_layer", Global.current_layer)
	Global.undo_redo.add_undo_property(Global, "layers", Global.layers)

	Global.undo_redo.add_undo_method(Global, "undo", [Global.canvas])
	Global.undo_redo.add_do_method(Global, "redo", [Global.canvas])
	Global.undo_redo.commit_action()


func _on_RemoveLayer_pressed() -> void:
	var new_layers : Array = Global.layers.duplicate()
	new_layers.remove(Global.current_layer)
	Global.undos += 1
	Global.undo_redo.create_action("Remove Layer")
	if Global.current_layer > 0:
		Global.undo_redo.add_do_property(Global, "current_layer", Global.current_layer - 1)
	else:
		Global.undo_redo.add_do_property(Global, "current_layer", Global.current_layer)

	for c in Global.canvases:
		var new_canvas_layers : Array = c.layers.duplicate()
		new_canvas_layers.remove(Global.current_layer)
		Global.undo_redo.add_do_property(c, "layers", new_canvas_layers)
		Global.undo_redo.add_undo_property(c, "layers", c.layers)

	Global.undo_redo.add_do_property(Global, "layers", new_layers)
	Global.undo_redo.add_undo_property(Global, "current_layer", Global.current_layer)
	Global.undo_redo.add_undo_property(Global, "layers", Global.layers)
	Global.undo_redo.add_do_method(Global, "redo", [Global.canvas])
	Global.undo_redo.add_undo_method(Global, "undo", [Global.canvas])
	Global.undo_redo.commit_action()


func change_layer_order(rate : int) -> void:
	var change = Global.current_layer + rate

	var new_layers : Array = Global.layers.duplicate()
	var temp = new_layers[Global.current_layer]
	new_layers[Global.current_layer] = new_layers[change]
	new_layers[change] = temp
	Global.undo_redo.create_action("Change Layer Order")
	for c in Global.canvases:
		var new_layers_canvas : Array = c.layers.duplicate()
		var temp_canvas = new_layers_canvas[Global.current_layer]
		new_layers_canvas[Global.current_layer] = new_layers_canvas[change]
		new_layers_canvas[change] = temp_canvas
		Global.undo_redo.add_do_property(c, "layers", new_layers_canvas)
		Global.undo_redo.add_undo_property(c, "layers", c.layers)

	Global.undo_redo.add_do_property(Global, "current_layer", change)
	Global.undo_redo.add_do_property(Global, "layers", new_layers)
	Global.undo_redo.add_undo_property(Global, "layers", Global.layers)
	Global.undo_redo.add_undo_property(Global, "current_layer", Global.current_layer)

	Global.undo_redo.add_undo_method(Global, "undo", [Global.canvas])
	Global.undo_redo.add_do_method(Global, "redo", [Global.canvas])
	Global.undo_redo.commit_action()


func _on_MergeDownLayer_pressed() -> void:
	var new_layers : Array = Global.layers.duplicate(true)

	Global.undos += 1
	Global.undo_redo.create_action("Merge Layer")
	for c in Global.canvases:
		var new_layers_canvas : Array = c.layers.duplicate(true)
		var selected_layer := Image.new()
		selected_layer.copy_from(new_layers_canvas[Global.current_layer][0])
		selected_layer.lock()

		if c.layers[Global.current_layer][2] < 1: # If we have layer transparency
			for xx in selected_layer.get_size().x:
				for yy in selected_layer.get_size().y:
					var pixel_color : Color = selected_layer.get_pixel(xx, yy)
					var alpha : float = pixel_color.a * c.layers[Global.current_layer][2]
					selected_layer.set_pixel(xx, yy, Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha))

		var new_layer := Image.new()
		new_layer.copy_from(c.layers[Global.current_layer - 1][0])
		new_layer.lock()
		DrawingAlgos.blend_rect(new_layer, selected_layer, Rect2(c.position, c.size), Vector2.ZERO)
		new_layers_canvas.remove(Global.current_layer)
		if !selected_layer.is_invisible() and Global.layers[Global.current_layer - 1].linked_cels.size() > 1 and (c in Global.layers[Global.current_layer - 1].linked_cels):
			new_layers[Global.current_layer - 1].linked_cels.erase(c)
			var tex := ImageTexture.new()
			tex.create_from_image(new_layer, 0)
			new_layers_canvas[Global.current_layer - 1][0] = new_layer
			new_layers_canvas[Global.current_layer - 1][1] = tex
		else:
			Global.undo_redo.add_do_property(c.layers[Global.current_layer - 1][0], "data", new_layer.data)
			Global.undo_redo.add_undo_property(c.layers[Global.current_layer - 1][0], "data", c.layers[Global.current_layer - 1][0].data)

		Global.undo_redo.add_do_property(c, "layers", new_layers_canvas)
		Global.undo_redo.add_undo_property(c, "layers", c.layers)

	new_layers.remove(Global.current_layer)
	Global.undo_redo.add_do_property(Global, "current_layer", Global.current_layer - 1)
	Global.undo_redo.add_do_property(Global, "layers", new_layers)
	Global.undo_redo.add_undo_property(Global, "layers", Global.layers)
	Global.undo_redo.add_undo_property(Global, "current_layer", Global.current_layer)

	Global.undo_redo.add_undo_method(Global, "undo", Global.canvases)
	Global.undo_redo.add_do_method(Global, "redo", Global.canvases)
	Global.undo_redo.commit_action()


func _on_OpacitySlider_value_changed(value) -> void:
	Global.canvas.layers[Global.current_layer][2] = value / 100
	Global.layer_opacity_slider.value = value
	Global.layer_opacity_slider.value = value
	Global.layer_opacity_spinbox.value = value
	Global.canvas.update()


func _on_OnionSkinningSettings_popup_hide() -> void:
	Global.can_draw = true
