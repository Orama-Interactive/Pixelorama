class_name BaseAnimationExporter
extends Reference
# Represents a method for exporting animations.
# Please do NOT use project globals in this code.

var mime_type: String


# Exports an animation to a byte array of file data.
# fps_hint is only a hint, animations may have higher FPSes than this.
# The durations array (with durations listed in seconds) is the true reference.
# progress_report_obj.callv(progress_report_method, progress_report_args) is
#  called after each frame is handled.
func export_animation(
	_frames: Array,
	_durations: Array,
	_fps_hint: float,
	_progress_report_obj: Object,
	_progress_report_method,
	_progress_report_args
) -> PoolByteArray:
	return PoolByteArray()
