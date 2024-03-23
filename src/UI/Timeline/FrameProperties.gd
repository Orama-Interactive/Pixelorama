extends ConfirmationDialog

var frame_indices := []
@onready var frame_num := $GridContainer/FrameNum
@onready var frame_dur := $GridContainer/FrameTime


func _on_FrameProperties_about_to_show() -> void:
	if frame_indices.size() == 0:
		frame_num.set_text("")
		return
	if frame_indices.size() == 1:
		frame_num.set_text(str(frame_indices[0] + 1))
	else:
		frame_num.set_text("[%s...%s]" % [frame_indices[0] + 1, frame_indices[-1] + 1])
	var duration: float = Global.current_project.frames[frame_indices[0]].duration
	frame_dur.set_value(duration)


func _on_FrameProperties_visibility_changed() -> void:
	Global.dialog_open(false)


func _on_FrameProperties_confirmed() -> void:
	var project := Global.current_project
	var new_duration: float = frame_dur.get_value()
	project.undos += 1
	project.undo_redo.create_action("Change frame duration")
	for frame in frame_indices:
		project.undo_redo.add_do_property(project.frames[frame], "duration", new_duration)
		project.undo_redo.add_undo_property(
			project.frames[frame], "duration", project.frames[frame].duration
		)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()
