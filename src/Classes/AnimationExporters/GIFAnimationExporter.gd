class_name GIFAnimationExporter
extends BaseAnimationExporter
# Acts as the interface between Pixelorama's format-independent interface and gdgifexporter.

# Gif exporter
const GIFExporter = preload("res://addons/gdgifexporter/exporter.gd")
const MedianCutQuantization = preload("res://addons/gdgifexporter/quantization/median_cut.gd")


func _init():
	mime_type = "image/gif"


func export_animation(
	images: Array,
	durations: Array,
	_fps_hint: float,
	progress_report_obj: Object,
	progress_report_method,
	progress_report_args
) -> PoolByteArray:
	var exporter = GIFExporter.new(images[0].get_width(), images[0].get_height())
	for i in range(images.size()):
		exporter.add_frame(images[i], durations[i], MedianCutQuantization)
		progress_report_obj.callv(progress_report_method, progress_report_args)
	return exporter.export_file_data()
