extends Button

var frame := 0
var layer := 0

onready var popup_menu : PopupMenu = $PopupMenu


func _ready() -> void:
	hint_tooltip = tr("Frame: %s, Layer: %s") % [frame + 1, layer]
	if Global.current_project.frames[frame] in Global.current_project.layers[layer].linked_cels:
		get_node("LinkedIndicator").visible = true
		popup_menu.set_item_text(4, "Unlink Cel")
		popup_menu.set_item_metadata(4, "Unlink Cel")
	else:
		get_node("LinkedIndicator").visible = false
		popup_menu.set_item_text(4, "Link Cel")
		popup_menu.set_item_metadata(4, "Link Cel")

	# Reset the checkers size because it assumes you want the same size as the canvas
	var checker = $CelTexture/TransparentChecker
	checker.rect_size = checker.get_parent().rect_size


func _on_CelButton_pressed() -> void:
	if Input.is_action_just_released("left_mouse"):
		Global.current_project.current_frame = frame
		Global.current_project.current_layer = layer
	elif Input.is_action_just_released("right_mouse"):
		if Global.current_project.frames.size() == 1:
			popup_menu.set_item_disabled(0, true)
			popup_menu.set_item_disabled(2, true)
			popup_menu.set_item_disabled(3, true)
		else:
			popup_menu.set_item_disabled(0, false)
			if frame > 0:
				popup_menu.set_item_disabled(2, false)
			if frame < Global.current_project.frames.size() - 1:
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
			var cel_index : int = Global.current_project.layers[layer].linked_cels.find(Global.current_project.frames[frame])
			var f = Global.current_project.frames[frame]
			var new_layers : Array = Global.current_project.layers.duplicate()
			# Loop through the array to create new classes for each element, so that they
			# won't be the same as the original array's classes. Needed for undo/redo to work properly.
			for i in new_layers.size():
				var new_linked_cels = new_layers[i].linked_cels.duplicate()
				new_layers[i] = Layer.new(new_layers[i].name, new_layers[i].visible, new_layers[i].locked, new_layers[i].frame_container, new_layers[i].new_cels_linked, new_linked_cels)
			var new_cels : Array = f.cels.duplicate()
			for i in new_cels.size():
				new_cels[i] = Cel.new(new_cels[i].image, new_cels[i].opacity)

			if popup_menu.get_item_metadata(4) == "Unlink Cel":
				new_layers[layer].linked_cels.remove(cel_index)
				var sprite := Image.new()
				sprite.copy_from(Global.current_project.frames[frame].cels[layer].image)
				sprite.lock()
				new_cels[layer].image = sprite

				Global.current_project.undo_redo.create_action("Unlink Cel")
				Global.current_project.undo_redo.add_do_property(Global.current_project, "layers", new_layers)
				Global.current_project.undo_redo.add_do_property(f, "cels", new_cels)
				Global.current_project.undo_redo.add_undo_property(Global.current_project, "layers", Global.current_project.layers)
				Global.current_project.undo_redo.add_undo_property(f, "cels", f.cels)

				Global.current_project.undo_redo.add_undo_method(Global, "undo")
				Global.current_project.undo_redo.add_do_method(Global, "redo")
				Global.current_project.undo_redo.commit_action()
			elif popup_menu.get_item_metadata(4) == "Link Cel":
				new_layers[layer].linked_cels.append(Global.current_project.frames[frame])
				Global.current_project.undo_redo.create_action("Link Cel")
				Global.current_project.undo_redo.add_do_property(Global.current_project, "layers", new_layers)
				if new_layers[layer].linked_cels.size() > 1:
					# If there are already linked cels, set the current cel's image
					# to the first linked cel's image
					new_cels[layer].image = new_layers[layer].linked_cels[0].cels[layer].image
					new_cels[layer].image_texture = new_layers[layer].linked_cels[0].cels[layer].image_texture
					Global.current_project.undo_redo.add_do_property(f, "cels", new_cels)
					Global.current_project.undo_redo.add_undo_property(f, "cels", f.cels)

				Global.current_project.undo_redo.add_undo_property(Global.current_project, "layers", Global.current_project.layers)
				Global.current_project.undo_redo.add_undo_method(Global, "undo")
				Global.current_project.undo_redo.add_do_method(Global, "redo")
				Global.current_project.undo_redo.commit_action()
		5: #Frame Properties
				Global.frame_properties.popup_centered()
				Global.dialog_open(true)
				Global.frame_properties.set_frame_label(frame)
				Global.frame_properties.set_frame_dur(Global.current_project.frame_duration[frame])

func change_frame_order(rate : int) -> void:
	var change = frame + rate
	var frame_duration : Array = Global.current_project.frame_duration.duplicate()
	if rate > 0: #There is no function in the class Array in godot to make this quickly and this is the fastest way to swap positions I think of
		frame_duration.insert(change + 1, frame_duration[frame])
		frame_duration.remove(frame)
	else:
		frame_duration.insert(change, frame_duration[frame])
		frame_duration.remove(frame + 1)

	var new_frames : Array = Global.current_project.frames.duplicate()
	var temp = new_frames[frame]
	new_frames[frame] = new_frames[change]
	new_frames[change] = temp

	Global.current_project.undo_redo.create_action("Change Frame Order")
	Global.current_project.undo_redo.add_do_property(Global.current_project, "frames", new_frames)
	Global.current_project.undo_redo.add_do_property(Global.current_project, "frame_duration", frame_duration)

	if Global.current_project.current_frame == frame:
		Global.current_project.undo_redo.add_do_property(Global.current_project, "current_frame", change)
		Global.current_project.undo_redo.add_undo_property(Global.current_project, "current_frame", Global.current_project.current_frame)

	Global.current_project.undo_redo.add_undo_property(Global.current_project, "frames", Global.current_project.frames)
	Global.current_project.undo_redo.add_undo_property(Global.current_project, "frame_duration", Global.current_project.frame_duration)

	Global.current_project.undo_redo.add_undo_method(Global, "undo")
	Global.current_project.undo_redo.add_do_method(Global, "redo")
	Global.current_project.undo_redo.commit_action()
