extends Button

var frame := 0
var layer := 0

onready var popup_menu := $PopupMenu

func _on_FrameButton_pressed() -> void:
	if Input.is_action_just_released("left_mouse"):
		Global.current_frame = frame
		Global.current_layer = layer
		print(str(frame), str(layer))
	elif Input.is_action_just_released("right_mouse"):
		if Global.canvases.size() == 1:
			popup_menu.set_item_disabled(0, true)
			popup_menu.set_item_disabled(2, true)
			popup_menu.set_item_disabled(3, true)
		else:
			popup_menu.set_item_disabled(0, false)
			if frame > 0:
				popup_menu.set_item_disabled(2, false)
			if frame < Global.canvases.size() - 1:
				popup_menu.set_item_disabled(3, false)
		popup_menu.popup(Rect2(get_global_mouse_position(), Vector2.ONE))
		pressed = !pressed
	else: # Middle mouse click
		pressed = !pressed
		if Global.canvases.size() > 1:
			remove_frame()

func _on_PopupMenu_id_pressed(ID : int) -> void:
	match ID:
		0: # Remove Frame
			remove_frame()

		1: # Clone Layer
			var canvas : Canvas = Global.canvases[frame]
			var new_canvas : Canvas = load("res://Prefabs/Canvas.tscn").instance()
			new_canvas.size = Global.canvas.size
			new_canvas.frame = Global.canvases.size()

			var new_canvases := Global.canvases.duplicate()
			new_canvases.append(new_canvas)
			var new_hidden_canvases := Global.hidden_canvases.duplicate()
			new_hidden_canvases.append(new_canvas)

			for layer in canvas.layers: # Copy every layer
				var sprite := Image.new()
				sprite.copy_from(layer[0])
				sprite.lock()
				var tex := ImageTexture.new()
				tex.create_from_image(sprite, 0)
				new_canvas.layers.append([sprite, tex, layer[2]])

			Global.undos += 1
			Global.undo_redo.create_action("Add Frame")
			Global.undo_redo.add_do_method(Global, "redo", [new_canvas])
			Global.undo_redo.add_undo_method(Global, "undo", [new_canvas])

			Global.undo_redo.add_do_property(Global, "canvases", new_canvases)
			Global.undo_redo.add_do_property(Global, "hidden_canvases", Global.hidden_canvases)
			Global.undo_redo.add_do_property(Global, "canvas", new_canvas)
			Global.undo_redo.add_do_property(Global, "current_frame", new_canvases.size() - 1)
			for child in Global.frame_containers.get_children():
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

		2: #Move Left
			change_frame_order(-1)
		3: #Move Right
			change_frame_order(1)

func remove_frame() -> void:
	var canvas : Canvas = Global.canvases[frame]
	var new_canvases := Global.canvases.duplicate()
	new_canvases.erase(canvas)
	var new_hidden_canvases := Global.hidden_canvases.duplicate()
	new_hidden_canvases.append(canvas)
	var current_frame := Global.current_frame
	if current_frame > 0 && current_frame == new_canvases.size(): #If it's the last frame
		current_frame -= 1

	Global.undos += 1
	Global.undo_redo.create_action("Remove Frame")

	Global.undo_redo.add_do_property(Global, "canvases", new_canvases)
	Global.undo_redo.add_do_property(Global, "hidden_canvases", new_hidden_canvases)
	Global.undo_redo.add_do_property(Global, "canvas", new_canvases[current_frame])
	Global.undo_redo.add_do_property(Global, "current_frame", current_frame)

	for i in range(frame, new_canvases.size()):
		var c : Canvas = new_canvases[i]
		Global.undo_redo.add_do_property(c, "frame", i)
		Global.undo_redo.add_undo_property(c, "frame", c.frame)

	Global.undo_redo.add_undo_property(Global, "canvases", Global.canvases)
	Global.undo_redo.add_undo_property(Global, "hidden_canvases", Global.hidden_canvases)
	Global.undo_redo.add_undo_property(Global, "canvas", canvas)
	Global.undo_redo.add_undo_property(Global, "current_frame", Global.current_frame)

	Global.undo_redo.add_do_method(Global, "redo", [canvas])
	Global.undo_redo.add_undo_method(Global, "undo", [canvas])
	Global.undo_redo.commit_action()

func change_frame_order(rate : int) -> void:
	var change = frame + rate
	var new_canvases := Global.canvases.duplicate()
	var temp = new_canvases[frame]
	new_canvases[frame] = new_canvases[change]
	new_canvases[change] = temp

	Global.undo_redo.create_action("Change Frame Order")
	Global.undo_redo.add_do_property(Global, "canvases", new_canvases)
	Global.undo_redo.add_do_property(Global.canvases[frame], "frame", change)
	Global.undo_redo.add_do_property(Global.canvases[change], "frame", frame)

	Global.undo_redo.add_undo_property(Global, "canvases", Global.canvases)
	Global.undo_redo.add_undo_property(Global.canvases[frame], "frame", frame)
	Global.undo_redo.add_undo_property(Global.canvases[change], "frame", change)

	Global.undo_redo.add_undo_method(Global, "undo", [Global.canvases[frame]])
	Global.undo_redo.add_do_method(Global, "redo", [Global.canvases[frame]])
	Global.undo_redo.commit_action()
