extends Button

var frame := 0

onready var popup_menu: PopupMenu = $PopupMenu
onready var frame_properties: ConfirmationDialog = Global.control.find_node("FrameProperties")


func _ready() -> void:
	connect("pressed", self, "_button_pressed")
	connect("mouse_entered", self, "_update_tooltip")


func _update_tooltip() -> void:
	var duration: float = Global.current_project.frames[frame].duration
	var duration_sec: float = duration * (1.0 / Global.current_project.fps)
	var duration_str := str(duration_sec)
	if "." in duration_str:  # If its a decimal value
		duration_str = "%.2f" % duration_sec  # Up to 2 decimal places
	hint_tooltip = "%s: %sx (%s sec)" % [tr("Duration"), str(duration), duration_str]


func _button_pressed() -> void:
	if Input.is_action_just_released("left_mouse"):
		Global.canvas.selection.transform_content_confirm()
		var prev_curr_frame: int = Global.current_project.current_frame
		if Input.is_action_pressed("shift"):
			var frame_diff_sign = sign(frame - prev_curr_frame)
			if frame_diff_sign == 0:
				frame_diff_sign = 1
			for i in range(prev_curr_frame, frame + frame_diff_sign, frame_diff_sign):
				for j in range(0, Global.current_project.layers.size()):
					var frame_layer := [i, j]
					if !Global.current_project.selected_cels.has(frame_layer):
						Global.current_project.selected_cels.append(frame_layer)
		elif Input.is_action_pressed("ctrl"):
			for j in range(0, Global.current_project.layers.size()):
				var frame_layer := [frame, j]
				if !Global.current_project.selected_cels.has(frame_layer):
					Global.current_project.selected_cels.append(frame_layer)
		else:  # If the button is pressed without Shift or Control
			Global.current_project.selected_cels.clear()
			var frame_layer := [frame, Global.current_project.current_layer]
			if !Global.current_project.selected_cels.has(frame_layer):
				Global.current_project.selected_cels.append(frame_layer)

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
	elif Input.is_action_just_released("middle_mouse"):
		pressed = !pressed
		Global.animation_timeline.delete_frames([frame])
	else:  # An example of this would be Space
		pressed = !pressed


func _on_PopupMenu_id_pressed(id: int) -> void:
	match id:
		0:  # Remove Frame
			Global.animation_timeline.delete_frames([frame])
		1:  # Clone Frame
			Global.animation_timeline.copy_frames([frame])
		2:  # Move Left
			change_frame_order(-1)
		3:  # Move Right
			change_frame_order(1)
		4:  # Frame Properties
			frame_properties.popup_centered()
			Global.dialog_open(true)
			frame_properties.set_frame_label(frame)
			frame_properties.set_frame_dur(Global.current_project.frames[frame].duration)


func change_frame_order(rate: int) -> void:
	var change = frame + rate
	var new_frames: Array = Global.current_project.frames.duplicate()
	var should_change := true

	# check if the frame moved is in the vicinity of a tag
	var new_animation_tags = Global.current_project.animation_tags.duplicate()
	# Loop through the tags to create new classes for them, so that they won't be the same
	# as Global.current_project.animation_tags's classes. Needed for undo/redo to work properly.
	for i in new_animation_tags.size():
		new_animation_tags[i] = AnimationTag.new(
			new_animation_tags[i].name,
			new_animation_tags[i].color,
			new_animation_tags[i].from,
			new_animation_tags[i].to
		)
	var corner_tags = []  # frame part of their boundary
	var boundary_tags = []  # frame touching their boundary
	for tag in new_animation_tags:
		if change > frame:  # Moving ahead
			if frame + 1 == tag.to:  # Last frame of tag
				corner_tags.append(tag)
			elif frame + 2 == tag.from:  # About to enter another tag
				boundary_tags.append(tag)
		if change < frame:  # Moving back
			if frame + 1 == tag.from:  # Last frame of tag
				corner_tags.append(tag)
			elif frame == tag.to:  # About to enter another tag
				boundary_tags.append(tag)
	# Now we use the filtered tags we stored
	if corner_tags.size() != 0:  # frame is just leaving the corners of a tag
		should_change = false  # frames don't need to be changed now
		for tag in corner_tags:
			if change > frame:  # Protocol for Moving ahead
				if tag.from == tag.to:
					new_animation_tags.erase(tag)
				else:
					tag.to -= 1
			if change < frame:  # Protocol for Moving behind
				if tag.from == tag.to:
					new_animation_tags.erase(tag)
				else:
					tag.from += 1
	# frame is about to enter another tag and NOT just left another tag
	elif corner_tags.size() == 0 and boundary_tags.size() != 0:
		should_change = false  # frames don't need to be changed now
		for tag in boundary_tags:
			if change > frame:  # Protocol for Moving ahead
				tag.from -= 1
			if change < frame:  # Protocol for Moving behind
				tag.to += 1

	if should_change:
		var temp = new_frames[frame]
		new_frames[frame] = new_frames[change]
		new_frames[change] = temp

	Global.current_project.undo_redo.create_action("Change Frame Order")
	Global.current_project.undo_redo.add_do_property(Global.current_project, "frames", new_frames)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "frames", Global.current_project.frames
	)

	if Global.current_project.current_frame == frame and should_change:
		Global.current_project.undo_redo.add_do_property(
			Global.current_project, "current_frame", change
		)
	else:
		Global.current_project.undo_redo.add_do_property(
			Global.current_project, "current_frame", Global.current_project.current_frame
		)

	Global.current_project.undo_redo.add_do_property(
		Global.current_project, "animation_tags", new_animation_tags
	)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "animation_tags", Global.current_project.animation_tags
	)

	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "current_frame", Global.current_project.current_frame
	)

	Global.current_project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	Global.current_project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	Global.current_project.undo_redo.commit_action()


func get_drag_data(_position) -> Array:
	var button := Button.new()
	button.rect_size = rect_size
	button.theme = Global.control.theme
	button.text = text
	set_drag_preview(button)

	return ["Frame", frame]


func can_drop_data(_pos, data) -> bool:
	if typeof(data) == TYPE_ARRAY:
		return data[0] == "Frame"
	else:
		return false


func drop_data(_pos, data) -> void:
	var new_frame = data[1]
	if frame == new_frame:
		return

	var new_frames: Array = Global.current_project.frames.duplicate()
	var temp = new_frames[frame]
	new_frames[frame] = new_frames[new_frame]
	new_frames[new_frame] = temp

	Global.current_project.undo_redo.create_action("Change Frame Order")
	Global.current_project.undo_redo.add_do_property(Global.current_project, "frames", new_frames)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "frames", Global.current_project.frames
	)

	if Global.current_project.current_frame == new_frame:
		Global.current_project.undo_redo.add_do_property(
			Global.current_project, "current_frame", frame
		)
	else:
		Global.current_project.undo_redo.add_do_property(
			Global.current_project, "current_frame", Global.current_project.current_frame
		)

	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, "current_frame", Global.current_project.current_frame
	)

	Global.current_project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	Global.current_project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	Global.current_project.undo_redo.commit_action()
