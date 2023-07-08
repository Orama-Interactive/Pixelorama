class_name AImgIOBaseExporter
extends RefCounted
# Represents a method for exporting animations.

var mime_type: String


# Exports an animation to a byte array of file data.
# The frames must be AImgIOFrame.
# fps_hint is only a hint, animations may have higher FPSes than this.
# The frame duration field (in seconds) is the true reference.
# progress_report_obj.callv(progress_report_method, progress_report_args) is
#  called after each frame is handled.
func export_animation(
	_frames: Array,
	_fps_hint: float,
	_progress_report_obj: Object,
	_progress_report_method,
	_progress_report_args
) -> PackedByteArray:
	return PackedByteArray()
