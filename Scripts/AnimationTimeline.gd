extends Panel

var fps := 6.0
var animation_loop := 0 # 0 is no loop, 1 is cycle loop, 2 is ping-pong loop
var animation_forward := true

func add_frame() -> void:
	var new_canvas : Canvas = load("res://Prefabs/Canvas.tscn").instance()
	new_canvas.size = Global.canvas.size
	new_canvas.frame = Global.canvases.size()

	var new_canvases: Array = Global.canvases.duplicate()
	new_canvases.append(new_canvas)
	var new_hidden_canvases: Array = Global.hidden_canvases.duplicate()
	new_hidden_canvases.append(new_canvas)

	Global.undos += 1
	Global.undo_redo.create_action("Add Frame")
	Global.undo_redo.add_do_method(Global, "redo", [new_canvas])
	Global.undo_redo.add_undo_method(Global, "undo", [new_canvas])

	Global.undo_redo.add_do_property(Global, "canvases", new_canvases)
	Global.undo_redo.add_do_property(Global, "hidden_canvases", Global.hidden_canvases)
	Global.undo_redo.add_do_property(Global, "canvas", new_canvas)
	Global.undo_redo.add_do_property(Global, "current_frame", new_canvases.size() - 1)

	for c in Global.canvases:
		Global.undo_redo.add_do_property(c, "visible", false)
		Global.undo_redo.add_undo_property(c, "visible", c.visible)

	for l_i in range(Global.layers.size()):
		if Global.layers[l_i][4]: # If the link button is pressed
#			var new_layers : Array = Global.layers.duplicate()
#			new_layers[l_i][5].append(new_canvas)
			Global.layers[l_i][5].append(new_canvas)

	Global.undo_redo.add_undo_property(Global, "canvases", Global.canvases)
	Global.undo_redo.add_undo_property(Global, "hidden_canvases", new_hidden_canvases)
	Global.undo_redo.add_undo_property(Global, "canvas", Global.canvas)
	Global.undo_redo.add_undo_property(Global, "current_frame", Global.current_frame)
	Global.undo_redo.commit_action()

func _on_LoopAnim_pressed() -> void:
	match animation_loop:
		0: # Make it loop
			animation_loop = 1
			Global.loop_animation_button.texture_normal = load("res://Assets/Graphics/%s Themes/Timeline/Loop.png" % Global.theme_type)
			Global.loop_animation_button.hint_tooltip = "Cycle loop"
		1: # Make it ping-pong
			animation_loop = 2
			Global.loop_animation_button.texture_normal = load("res://Assets/Graphics/%s Themes/Timeline/Loop_PingPong.png" % Global.theme_type)
			Global.loop_animation_button.hint_tooltip = "Ping-pong loop"
		2: # Make it stop
			animation_loop = 0
			Global.loop_animation_button.texture_normal = load("res://Assets/Graphics/%s Themes/Timeline/Loop_None.png" % Global.theme_type)
			Global.loop_animation_button.hint_tooltip = "No loop"

func _on_PlayForward_toggled(button_pressed : bool) -> void:
	Global.play_backwards.pressed = false
	if Global.canvases.size() == 1:
		Global.play_forward.pressed = false
		return

	if button_pressed:
		Global.animation_timer.wait_time = 1 / fps
		Global.animation_timer.start()
		animation_forward = true
	else:
		Global.animation_timer.stop()

func _on_PlayBackwards_toggled(button_pressed : bool) -> void:
	Global.play_forward.pressed = false
	if Global.canvases.size() == 1:
		Global.play_backwards.pressed = false
		return

	if button_pressed:
		Global.animation_timer.wait_time = 1 / fps
		Global.animation_timer.start()
		animation_forward = false
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

func _on_AnimationTimer_timeout() -> void:
	if animation_forward:
		if Global.current_frame < Global.canvases.size() - 1:
			Global.current_frame += 1
		else:
			match animation_loop:
				0: # No loop
					Global.play_forward.pressed = false
					Global.play_backwards.pressed = false
					Global.animation_timer.stop()
				1: # Cycle loop
					Global.current_frame = 0
				2: # Ping pong loop
					animation_forward = false
					_on_AnimationTimer_timeout()

	else:
		if Global.current_frame > 0:
			Global.current_frame -= 1
		else:
			match animation_loop:
				0: # No loop
					Global.play_backwards.pressed = false
					Global.play_forward.pressed = false
					Global.animation_timer.stop()
				1: # Cycle loop
					Global.current_frame = Global.canvases.size() - 1
				2: # Ping pong loop
					animation_forward = true
					_on_AnimationTimer_timeout()

func _on_FPSValue_value_changed(value) -> void:
	fps = float(value)
	Global.animation_timer.wait_time = 1 / fps

func _on_PastOnionSkinning_value_changed(value) -> void:
	Global.onion_skinning_past_rate = int(value)
	Global.canvas.update()

func _on_FutureOnionSkinning_value_changed(value) -> void:
	Global.onion_skinning_future_rate = int(value)
	Global.canvas.update()

func _on_BlueRedMode_toggled(button_pressed) -> void:
	Global.onion_skinning_blue_red = button_pressed
	Global.canvas.update()

# Layer buttons

func add_layer(is_new := true) -> void:
	var layer_name = null
	if !is_new: # Clone layer
		layer_name = Global.layers[Global.current_layer][0] + " (" + tr("copy") + ")"

	var new_layers : Array = Global.layers.duplicate()

	# Store [Layer name (0), Layer visibility boolean (1), Layer lock boolean (2), Frame container (3),
	# will new frames be linked boolean (4), Array of linked frames (5)]
	new_layers.append([layer_name, true, false, HBoxContainer.new(), false, []])

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
	var new_layers : Array = Global.layers.duplicate()
	new_layers.remove(Global.current_layer)

	Global.undos += 1
	Global.undo_redo.create_action("Merge Layer")
	for c in Global.canvases:
		var new_layers_canvas : Array = c.layers.duplicate()
		new_layers_canvas.remove(Global.current_layer)
		var selected_layer = c.layers[Global.current_layer][0]
		if c.layers[Global.current_layer][2] < 1: # If we have layer transparency
			for xx in selected_layer.get_size().x:
				for yy in selected_layer.get_size().y:
					var pixel_color : Color = selected_layer.get_pixel(xx, yy)
					var alpha : float = pixel_color.a * c.layers[Global.current_layer][4]
					selected_layer.set_pixel(xx, yy, Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha))

		var new_layer := Image.new()
		new_layer.copy_from(c.layers[Global.current_layer - 1][0])
		new_layer.lock()
		c.blend_rect(new_layer, selected_layer, Rect2(c.position, c.size), Vector2.ZERO)

		Global.undo_redo.add_do_property(c, "layers", new_layers_canvas)
		Global.undo_redo.add_do_property(c.layers[Global.current_layer - 1][0], "data", new_layer.data)
		Global.undo_redo.add_undo_property(c, "layers", c.layers)
		Global.undo_redo.add_undo_property(c.layers[Global.current_layer - 1][0], "data", c.layers[Global.current_layer - 1][0].data)

	Global.undo_redo.add_do_property(Global, "current_layer", Global.current_layer - 1)
	Global.undo_redo.add_do_property(Global, "layers", new_layers)
	Global.undo_redo.add_undo_property(Global, "layers", Global.layers)
	Global.undo_redo.add_undo_property(Global, "current_layer", Global.current_layer)

	for c in Global.canvases:
		Global.undo_redo.add_undo_method(Global, "undo", [c])
		Global.undo_redo.add_do_method(Global, "redo", [c])
	Global.undo_redo.commit_action()

func _on_OpacitySlider_value_changed(value) -> void:
	Global.canvas.layers[Global.current_layer][2] = value / 100
	Global.layer_opacity_slider.value = value
	Global.layer_opacity_spinbox.value = value
	Global.canvas.update()
