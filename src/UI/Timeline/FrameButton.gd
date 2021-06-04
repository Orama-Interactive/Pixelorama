extends Button


var frame := 0

onready var popup_menu : PopupMenu = $PopupMenu


func _ready() -> void:
	connect("pressed", self, "_button_pressed")


func _button_pressed() -> void:
	if Input.is_action_just_released("left_mouse"):
		Global.current_project.current_frame = frame
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


func _on_PopupMenu_id_pressed(id : int) -> void:
	match id:
		0: # Remove Frame
			Global.animation_timeline._on_DeleteFrame_pressed(frame)
		1: # Clone Frame
			Global.animation_timeline._on_CopyFrame_pressed(frame)
		2: # Move Left
			change_frame_order(-1)
		3: # Move Right
			change_frame_order(1)
		4: # Frame Properties
			Global.frame_properties.popup_centered()
			Global.dialog_open(true)
			Global.frame_properties.set_frame_label(frame)
			Global.frame_properties.set_frame_dur(Global.current_project.frames[frame].duration)


func change_frame_order(rate : int) -> void:
	var change = frame + rate
	var new_frames : Array = Global.current_project.frames.duplicate()
	var temp = new_frames[frame]
	new_frames[frame] = new_frames[change]
	new_frames[change] = temp

	Global.current_project.undo_redo.create_action("Change Frame Order")
	Global.current_project.undo_redo.add_do_property(Global.current_project, "frames", new_frames)

	if Global.current_project.current_frame == frame:
		Global.current_project.undo_redo.add_do_property(Global.current_project, "current_frame", change)
		Global.current_project.undo_redo.add_undo_property(Global.current_project, "current_frame", Global.current_project.current_frame)

	Global.current_project.undo_redo.add_undo_property(Global.current_project, "frames", Global.current_project.frames)

	Global.current_project.undo_redo.add_undo_method(Global, "undo")
	Global.current_project.undo_redo.add_do_method(Global, "redo")
	Global.current_project.undo_redo.commit_action()
