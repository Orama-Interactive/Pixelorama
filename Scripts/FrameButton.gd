extends Button

var frame := 0
var layer := 0

onready var popup_menu := $PopupMenu


func _ready() -> void:
	hint_tooltip = "Frame: %s, Layer: %s" % [frame + 1, layer]
	if Global.canvases[frame] in Global.layers[layer][5]:
		get_node("LinkedIndicator").visible = true
		popup_menu.set_item_disabled(4, false) # Unlink cel
	else:
		get_node("LinkedIndicator").visible = false
		popup_menu.set_item_disabled(4, true) # Unlink cel


func _on_FrameButton_pressed() -> void:
	if Input.is_action_just_released("left_mouse"):
		Global.current_frame = frame
		Global.current_layer = layer
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
	elif Input.is_action_just_released("middle_mouse"): # Middle mouse click
		pressed = !pressed
		Global.animation_timeline._on_DeleteFrame_pressed(frame)
	else: # An example of this would be Space
		pressed = !pressed


func _on_PopupMenu_id_pressed(ID : int) -> void:
	match ID:
		0: # Remove Frame
			Global.animation_timeline._on_DeleteFrame_pressed(frame)
		1: # Clone Frame
			Global.animation_timeline._on_CopyFrame_pressed(frame)
		2: # Move Left
			change_frame_order(-1)
		3: # Move Right
			change_frame_order(1)
		4: # Unlink Cel
			var cel_index : int = Global.layers[layer][5].find(Global.canvases[frame])
			var c = Global.canvases[frame]
			var new_layers := Global.layers.duplicate(true)
			var new_canvas_layers : Array = c.layers.duplicate(true)

			new_layers[layer][5].remove(cel_index)
			var sprite := Image.new()
			sprite.copy_from(Global.canvases[frame].layers[layer][0])
			sprite.lock()
			var tex := ImageTexture.new()
			tex.create_from_image(sprite, 0)
			new_canvas_layers[layer][0] = sprite
			new_canvas_layers[layer][1] = tex

			Global.undo_redo.create_action("Unlink Cel")
			Global.undo_redo.add_do_property(Global, "layers", new_layers)
			Global.undo_redo.add_do_property(c, "layers", new_canvas_layers)
			Global.undo_redo.add_undo_property(Global, "layers", Global.layers)
			Global.undo_redo.add_undo_property(c, "layers", c.layers)

			Global.undo_redo.add_undo_method(Global, "undo", [Global.canvases[frame]], layer)
			Global.undo_redo.add_do_method(Global, "redo", [Global.canvases[frame]], layer)
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

	if Global.current_frame == frame:
		Global.undo_redo.add_do_property(Global, "current_frame", change)
		Global.undo_redo.add_undo_property(Global, "current_frame", Global.current_frame)

	Global.undo_redo.add_undo_property(Global, "canvases", Global.canvases)
	Global.undo_redo.add_undo_property(Global.canvases[frame], "frame", frame)
	Global.undo_redo.add_undo_property(Global.canvases[change], "frame", change)

	Global.undo_redo.add_undo_method(Global, "undo", [Global.canvases[frame]])
	Global.undo_redo.add_do_method(Global, "redo", [Global.canvases[frame]])
	Global.undo_redo.commit_action()
