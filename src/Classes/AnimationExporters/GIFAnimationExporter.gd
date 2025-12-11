class_name GIFAnimationExporter
extends AImgIOBaseExporter
## Acts as the interface between the AImgIO format-independent interface and gdgifexporter.
## Note that if the interface needs changing for new features, do just change it!

## Gif exporter
const GIFExporter := preload("res://addons/gdgifexporter/exporter.gd")
const MedianCutQuantization := preload("res://addons/gdgifexporter/quantization/median_cut.gd")


func _init() -> void:
	mime_type = "image/gif"


func export_animation(
	frames: Array,
	_fps_hint: float,
	progress_report_obj: Object,
	progress_report_method,
	progress_report_args,
	buffer_file: FileAccess = null
) -> PackedByteArray:
	var first_frame: AImgIOFrame = frames[0]
	var first_img := first_frame.content
	var exporter := GIFExporter.new(first_img.get_width(), first_img.get_height())
	for v in frames:
		var frame: AImgIOFrame = v
		exporter.add_frame(frame.content, frame.duration, MedianCutQuantization)
		# Directly store data to buffer file if it is given, this preserves
		# GIF if export is canceled for some reason
		if buffer_file:
			buffer_file.store_buffer(exporter.data)
			exporter.data.clear()  # Clear data so it can be filled with next frame data
		progress_report_obj.callv(progress_report_method, progress_report_args)
		await RenderingServer.frame_post_draw
	if buffer_file:
		buffer_file.store_buffer(exporter.export_file_data())
		return PackedByteArray()
	return exporter.export_file_data()
