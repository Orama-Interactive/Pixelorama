extends ConfirmationDialog

onready var frame_num = $VBoxContainer/GridContainer/FrameNum
onready var frame_dur = $VBoxContainer/GridContainer/FrameTime

func set_frame_label(frame : int) -> void:
	frame_num.set_text(str(frame + 1))

func set_frame_dur(duration : float) -> void:
	frame_dur.set_value(duration)	

func _on_FrameProperties_popup_hide() -> void:
	Global.dialog_open(false)

func _on_FrameProperties_confirmed():
	var frame : int = int(frame_num.get_text())
	var duration : float = frame_dur.get_value()
	var frame_duration = Global.current_project.frame_duration.duplicate()
	frame_duration[frame - 1] = duration 

	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Change frame duration")

	Global.current_project.undo_redo.add_do_property(Global.current_project, "frame_duration", frame_duration)
	Global.current_project.undo_redo.add_undo_property(Global.current_project, "frame_duration", Global.current_project.frame_duration)

	Global.current_project.undo_redo.add_do_method(Global, "redo")
	Global.current_project.undo_redo.add_undo_method(Global, "undo")
	Global.current_project.undo_redo.commit_action()
