class_name GIFAnimationExporter
extends AImgIOBaseExporter
# Acts as the interface between the AImgIO format-independent interface and gdgifexporter.
# Note that if the interface needs changing for new features, do just change it!

# Gif exporter
const GIFExporter = preload("res://addons/gdgifexporter/exporter.gd")
const MedianCutQuantization = preload("res://addons/gdgifexporter/quantization/median_cut.gd")


func _init():
	mime_type = "image/gif"


func export_animation(
	frames: Array,
	_fps_hint: float,
	progress_report_obj: Object,
	progress_report_method,
	progress_report_args
) -> PoolByteArray:
	var first_frame: AImgIOFrame = frames[0]
	var first_img := first_frame.content
	var exporter = GIFExporter.new(first_img.get_width(), first_img.get_height())
	for v in frames:
		var frame: AImgIOFrame = v
		exporter.add_frame(frame.content, frame.duration, MedianCutQuantization)
		progress_report_obj.callv(progress_report_method, progress_report_args)
	return exporter.export_file_data()
