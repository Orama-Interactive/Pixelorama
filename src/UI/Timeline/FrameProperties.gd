extends ConfirmationDialog

onready var frame_num = $VBoxContainer/GridContainer/FrameNum
onready var frame_dur = $VBoxContainer/GridContainer/FrameTime


func set_frame_label(frame: int) -> void:
	frame_num.set_text(str(frame + 1))


func set_frame_dur(duration: float) -> void:
	frame_dur.set_value(duration)


func _on_FrameProperties_popup_hide() -> void:
	Global.dialog_open(false)


func _on_FrameProperties_confirmed():
	var frame: int = int(frame_num.get_text()) - 1
	var duration: float = frame_dur.get_value()
	var new_duration = Global.current_project.frames[frame].duration
	new_duration = duration

	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Change frame duration")

	Global.current_project.undo_redo.add_do_property(
		Global.current_project.frames[frame], "duration", new_duration
	)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project.frames[frame],
		"duration",
		Global.current_project.frames[frame].duration
	)

	Global.current_project.undo_redo.add_do_method(Global, "undo_or_redo", false)
	Global.current_project.undo_redo.add_undo_method(Global, "undo_or_redo", true)
	Global.current_project.undo_redo.commit_action()
