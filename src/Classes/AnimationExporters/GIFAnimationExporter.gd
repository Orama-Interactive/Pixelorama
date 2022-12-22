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
	var f = frames[0]
	var exporter = GIFExporter.new(f.content.get_width(), f.content.get_height())
	for v in frames:
		exporter.add_frame(f.content, f.duration, MedianCutQuantization)
		progress_report_obj.callv(progress_report_method, progress_report_args)
	return exporter.export_file_data()
