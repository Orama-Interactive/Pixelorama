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
	for child in Global.frame_container.get_children():
		var frame_button = child.get_node("FrameButton")
		Global.undo_redo.add_do_property(frame_button, "pressed", false)
		Global.undo_redo.add_undo_property(frame_button, "pressed", frame_button.pressed)
	for c in Global.canvases:
		Global.undo_redo.add_do_property(c, "visible", false)
		Global.undo_redo.add_undo_property(c, "visible", c.visible)

	Global.undo_redo.add_undo_property(Global, "canvases", Global.canvases)
	Global.undo_redo.add_undo_property(Global, "hidden_canvases", new_hidden_canvases)
	Global.undo_redo.add_undo_property(Global, "canvas", Global.canvas)
	Global.undo_redo.add_undo_property(Global, "current_frame", Global.current_frame)
	Global.undo_redo.commit_action()

func _on_LoopAnim_pressed() -> void:
	match animation_loop:
		0:
			# Make it loop
			animation_loop = 1
			Global.loop_animation_button.texture_normal = load("res://Assets/Graphics/%s Themes/Timeline/Loop.png" % Global.theme_type)
			Global.loop_animation_button.hint_tooltip = "Cycle loop"
		1:
			# Make it ping-pong
			animation_loop = 2
			Global.loop_animation_button.texture_normal = load("res://Assets/Graphics/%s Themes/Timeline/Loop_PingPong.png" % Global.theme_type)
			Global.loop_animation_button.hint_tooltip = "Ping-pong loop"
		2:
			# Make it stop
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
				0: #No loop
					Global.play_forward.pressed = false
					Global.play_backwards.pressed = false
					Global.animation_timer.stop()
				1: #Cycle loop
					Global.current_frame = 0
				2: #Ping pong loop
					animation_forward = false
					_on_AnimationTimer_timeout()

	else:
		if Global.current_frame > 0:
			Global.current_frame -= 1
		else:
			match animation_loop:
				0: #No loop
					Global.play_backwards.pressed = false
					Global.play_forward.pressed = false
					Global.animation_timer.stop()
				1: #Cycle loop
					Global.current_frame = Global.canvases.size() - 1
				2: #Ping pong loop
					animation_forward = true
					_on_AnimationTimer_timeout()

func _on_FPSValue_value_changed(value) -> void:
	fps = float(value)
	Global.animation_timer.wait_time = 1 / fps
	Global.timeline_seconds.update()

func _on_PastOnionSkinning_value_changed(value) -> void:
	Global.onion_skinning_past_rate = int(value)
	Global.canvas.update()

func _on_FutureOnionSkinning_value_changed(value) -> void:
	Global.onion_skinning_future_rate = int(value)
	Global.canvas.update()

func _on_BlueRedMode_toggled(button_pressed) -> void:
	Global.onion_skinning_blue_red = button_pressed
	Global.canvas.update()
