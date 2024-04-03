extends ConfirmationDialog

var frame_indices := []
@onready var frame_num := $GridContainer/FrameNum
@onready var frame_dur := $GridContainer/FrameTime
@onready var user_data_text_edit := $GridContainer/UserDataTextEdit as TextEdit


func _on_FrameProperties_about_to_show() -> void:
	if frame_indices.size() == 0:
		frame_num.set_text("")
		return
	if frame_indices.size() == 1:
		frame_num.set_text(str(frame_indices[0] + 1))
	else:
		frame_num.set_text("[%s...%s]" % [frame_indices[0] + 1, frame_indices[-1] + 1])
	var frame := Global.current_project.frames[frame_indices[0]]
	var duration := frame.duration
	frame_dur.set_value(duration)
	user_data_text_edit.text = frame.user_data


func _on_FrameProperties_visibility_changed() -> void:
	Global.dialog_open(false)


func _on_FrameProperties_confirmed() -> void:
	var project := Global.current_project
	var new_duration: float = frame_dur.get_value()
	var new_user_data := user_data_text_edit.text
	project.undos += 1
	project.undo_redo.create_action("Change frame duration")
	for frame_idx in frame_indices:
		var frame := project.frames[frame_idx]
		project.undo_redo.add_do_property(frame, "duration", new_duration)
		project.undo_redo.add_do_property(frame, "user_data", new_user_data)
		project.undo_redo.add_undo_property(frame, "duration", frame.duration)
		project.undo_redo.add_undo_property(frame, "user_data", frame.user_data)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()
