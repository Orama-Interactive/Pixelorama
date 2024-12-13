extends Button

enum { PROPERTIES, REMOVE, CLONE, MOVE_LEFT, MOVE_RIGHT, NEW_TAG, IMPORT_TAG, REVERSE, CENTER }

var frame := 0

@onready var popup_menu: PopupMenu = $PopupMenu
@onready var frame_properties := Global.control.find_child("FrameProperties") as ConfirmationDialog
@onready var tag_properties := Global.control.find_child("TagProperties") as ConfirmationDialog
@onready var append_tag_dialog := Global.control.find_child("ImportTagDialog") as AcceptDialog


func _ready() -> void:
	Global.cel_switched.connect(func(): z_index = 1 if button_pressed else 0)
	custom_minimum_size.x = Global.animation_timeline.cel_size
	text = str(frame + 1)
	pressed.connect(_button_pressed)
	mouse_entered.connect(_update_tooltip)


func _update_tooltip() -> void:
	var frame_class := Global.current_project.frames[frame]
	var duration := frame_class.duration
	var duration_sec := frame_class.get_duration_in_seconds(Global.current_project.fps)
	var duration_str := str(duration_sec)
	if "." in duration_str:  # If its a decimal value
		duration_str = "%.2f" % duration_sec  # Up to 2 decimal places
	tooltip_text = "%s: %sx (%s sec)" % [tr("Duration"), str(duration), duration_str]


func _button_pressed() -> void:
	if Input.is_action_just_released("left_mouse"):
		Global.canvas.selection.transform_content_confirm()
		var prev_curr_frame := Global.current_project.current_frame
		if Input.is_action_pressed("shift"):
			var frame_diff_sign := signi(frame - prev_curr_frame)
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

		Global.current_project.change_cel(frame, -1)

	elif Input.is_action_just_released("right_mouse"):
		if Global.current_project.frames.size() == 1:
			popup_menu.set_item_disabled(REMOVE, true)
			popup_menu.set_item_disabled(MOVE_LEFT, true)
			popup_menu.set_item_disabled(MOVE_RIGHT, true)
			popup_menu.set_item_disabled(REVERSE, true)
		else:
			popup_menu.set_item_disabled(REMOVE, false)
			if Global.current_project.selected_cels.size() > 1:
				popup_menu.set_item_disabled(REVERSE, false)
			else:
				popup_menu.set_item_disabled(REVERSE, true)
			if frame > 0:
				popup_menu.set_item_disabled(MOVE_LEFT, false)
			if frame < Global.current_project.frames.size() - 1:
				popup_menu.set_item_disabled(MOVE_RIGHT, false)
		popup_menu.popup_on_parent(Rect2(get_global_mouse_position(), Vector2.ONE))
		button_pressed = !button_pressed
	elif Input.is_action_just_released("middle_mouse"):
		button_pressed = !button_pressed
		Global.animation_timeline.delete_frames(_get_frame_indices())
	else:  # An example of this would be Space
		button_pressed = !button_pressed


func _on_PopupMenu_id_pressed(id: int) -> void:
	var indices := _get_frame_indices()
	match id:
		PROPERTIES:
			frame_properties.frame_indices = indices
			frame_properties.popup_centered()
			Global.dialog_open(true)
		REMOVE:
			Global.animation_timeline.delete_frames(indices)
		CLONE:
			Global.animation_timeline.copy_frames(indices)
		MOVE_LEFT:
			Global.animation_timeline.move_frames(frame, -1)
		MOVE_RIGHT:
			Global.animation_timeline.move_frames(frame, 1)
		NEW_TAG:
			var current_tag_id := Global.current_project.animation_tags.size()
			tag_properties.show_dialog(Rect2i(), current_tag_id, false, indices)
		IMPORT_TAG:
			append_tag_dialog.prepare_and_show(frame)
		REVERSE:
			Global.animation_timeline.reverse_frames(indices)
		CENTER:
			DrawingAlgos.center(indices)


func _get_drag_data(_position: Vector2) -> Variant:
	var button := Button.new()
	button.size = size
	button.theme = Global.control.theme
	button.text = text
	set_drag_preview(button)

	return ["Frame", _get_frame_indices()]


func _can_drop_data(_pos: Vector2, data) -> bool:
	if typeof(data) != TYPE_ARRAY:
		Global.animation_timeline.drag_highlight.visible = false
		return false
	if data[0] != "Frame":
		Global.animation_timeline.drag_highlight.visible = false
		return false
	var drop_frames: PackedInt32Array = data[1]
	# Can't move to same frame
	for drop_frame in drop_frames:
		if drop_frame == frame:
			Global.animation_timeline.drag_highlight.visible = false
			return false
	var region: Rect2
	if Input.is_action_pressed("ctrl") and drop_frames.size() == 1:  # Swap frames
		region = get_global_rect()
	else:  # Move frames
		if _get_region_rect(0, 0.5).has_point(get_global_mouse_position()):
			region = _get_region_rect(-0.125, 0.125)
		else:
			region = _get_region_rect(0.875, 1.125)
	Global.animation_timeline.drag_highlight.global_position = region.position
	Global.animation_timeline.drag_highlight.size = region.size
	Global.animation_timeline.drag_highlight.visible = true
	return true


func _drop_data(_pos: Vector2, data) -> void:
	var drop_frames: PackedInt32Array = data[1]
	var project := Global.current_project
	project.undo_redo.create_action("Change Frame Order")
	if Input.is_action_pressed("ctrl") and drop_frames.size() == 1:  # Swap frames
		project.undo_redo.add_do_method(project.swap_frame.bind(frame, drop_frames[0]))
		project.undo_redo.add_undo_method(project.swap_frame.bind(frame, drop_frames[0]))
	else:  # Move frames
		var to_frame: int
		if _get_region_rect(0, 0.5).has_point(get_global_mouse_position()):  # Left
			to_frame = frame
		else:  # Right
			to_frame = frame + 1
		for drop_frame in drop_frames:
			if drop_frame < frame:
				to_frame -= 1
		var to_frames := range(to_frame, to_frame + drop_frames.size())
		project.undo_redo.add_do_method(project.move_frames.bind(drop_frames, to_frames))
		project.undo_redo.add_undo_method(project.move_frames.bind(to_frames, drop_frames))

	if project.current_frame in drop_frames:
		project.undo_redo.add_do_method(project.change_cel.bind(frame))
	else:
		project.undo_redo.add_do_method(project.change_cel.bind(project.current_frame))
	project.undo_redo.add_undo_method(project.change_cel.bind(project.current_frame))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.commit_action()


func _get_region_rect(x_begin: float, x_end: float) -> Rect2:
	var rect := get_global_rect()
	rect.position.x += rect.size.x * x_begin
	rect.size.x *= x_end - x_begin
	return rect


func _get_frame_indices() -> PackedInt32Array:
	var indices := []
	for cel in Global.current_project.selected_cels:
		var f: int = cel[0]
		if not f in indices:
			indices.append(f)
	indices.sort()
	if not frame in indices:
		indices = [frame]
	return indices
