extends Node

enum ExportTab { IMAGE, SPRITESHEET }
enum Orientation { COLUMNS, ROWS, TAGS_BY_COLUMN, TAGS_BY_ROW }
enum AnimationDirection { FORWARD, BACKWARDS, PING_PONG }
## See file_format_string, file_format_description, and ExportDialog.gd
enum FileFormat { PNG, WEBP, JPEG, GIF, APNG, MP4, AVI, OGV, MKV, WEBM }
enum { VISIBLE_LAYERS, SELECTED_LAYERS }
enum ExportFrames { ALL_FRAMES, SELECTED_FRAMES }

## This path is used to temporarily store png files that FFMPEG uses to convert them to video
const TEMP_PATH := "user://tmp"

## List of animated formats
var animated_formats := [
	FileFormat.GIF,
	FileFormat.APNG,
	FileFormat.MP4,
	FileFormat.AVI,
	FileFormat.OGV,
	FileFormat.MKV,
	FileFormat.WEBM
]

var ffmpeg_formats := [
	FileFormat.MP4, FileFormat.AVI, FileFormat.OGV, FileFormat.MKV, FileFormat.WEBM
]
## A dictionary of [enum FileFormat] enums and their file extensions and short descriptions.
var file_format_dictionary := {
	FileFormat.PNG: [".png", "PNG Image"],
	FileFormat.WEBP: [".webp", "WebP Image"],
	FileFormat.JPEG: [".jpg", "JPG Image"],
	FileFormat.GIF: [".gif", "GIF Image"],
	FileFormat.APNG: [".apng", "APNG Image"],
	FileFormat.MP4: [".mp4", "MPEG-4 Video"],
	FileFormat.AVI: [".avi", "AVI Video"],
	FileFormat.OGV: [".ogv", "OGV Video"],
	FileFormat.MKV: [".mkv", "Matroska Video"],
	FileFormat.WEBM: [".webm", "WebM Video"],
}

## A dictionary of custom exporter generators (received from extensions)
var custom_file_formats := {}
var custom_exporter_generators := {}

var current_tab := ExportTab.IMAGE
## All frames and their layers processed/blended into images
var processed_images: Array[ProcessedImage] = []
## Dictionary of [Frame] and [Image] that contains all of the blended frames.
## Changes when [method cache_blended_frames] is called.
var blended_frames := {}
var export_json := false
var split_layers := false
var trim_images := false
var erase_unselected_area := false

# Spritesheet options
var orientation := Orientation.COLUMNS
var lines_count := 1  ## How many rows/columns before new line is added

# General options
var frame_current_tag := 0  ## Export only current frame tag
var export_layers := 0
var number_of_frames := 1
var direction := AnimationDirection.FORWARD
var resize := 100
var save_quality := 0.75  ## Used when saving jpg and webp images. Goes from 0 to 1.
var interpolation := Image.INTERPOLATE_NEAREST
var include_tag_in_filename := false
var new_dir_for_each_frame_tag := false  ## We don't need to store this after export
var number_of_digits := 4
var separator_character := "_"
var stop_export := false  ## Export coroutine signal

var file_exists_alert := "The following files already exist. Do you wish to overwrite them?\n%s"

# Export progress variables
var export_progress_fraction := 0.0
var export_progress := 0.0
@onready var gif_export_thread := Thread.new()


class ProcessedImage:
	var image: Image
	var frame_index: int
	var duration: float

	func _init(_image: Image, _frame_index: int, _duration := 1.0) -> void:
		image = _image
		frame_index = _frame_index
		duration = _duration


func _exit_tree() -> void:
	if gif_export_thread.is_started():
		gif_export_thread.wait_to_finish()


func _multithreading_enabled() -> bool:
	return ProjectSettings.get_setting("rendering/driver/threads/thread_model") == 2


func add_custom_file_format(
	format_name: String, extension: String, exporter_generator: Object, tab: int, is_animated: bool
) -> int:
	# Obtain a unique id
	var id := Export.FileFormat.size()
	for i in Export.custom_file_formats.size():
		var format_id = id + i
		if !Export.custom_file_formats.values().has(i):
			id = format_id
	# Add to custom_file_formats
	custom_file_formats.merge({format_name: id})
	custom_exporter_generators.merge({id: [exporter_generator, extension]})
	if is_animated:
		Export.animated_formats.append(id)
	# Add to export dialog
	match tab:
		ExportTab.IMAGE:
			Global.export_dialog.image_exports.append(id)
		ExportTab.SPRITESHEET:
			Global.export_dialog.spritesheet_exports.append(id)
		_:  # Both
			Global.export_dialog.image_exports.append(id)
			Global.export_dialog.spritesheet_exports.append(id)
	return id


func remove_custom_file_format(id: int) -> void:
	for key in custom_file_formats.keys():
		if custom_file_formats[key] == id:
			custom_file_formats.erase(key)
			# remove exporter generator
			Export.custom_exporter_generators.erase(id)
			#  remove from animated (if it is present there)
			Export.animated_formats.erase(id)
			#  remove from export dialog
			Global.export_dialog.image_exports.erase(id)
			Global.export_dialog.spritesheet_exports.erase(id)
			return


func external_export(project := Global.current_project) -> void:
	cache_blended_frames(project)
	process_data(project)
	export_processed_images(true, Global.export_dialog, project)


func process_data(project := Global.current_project) -> void:
	var frames := _calculate_frames(project)
	if frames.size() > blended_frames.size():
		cache_blended_frames(project)
	match current_tab:
		ExportTab.IMAGE:
			process_animation(project)
		ExportTab.SPRITESHEET:
			process_spritesheet(project)


func cache_blended_frames(project := Global.current_project) -> void:
	blended_frames.clear()
	var frames := _calculate_frames(project)
	for frame in frames:
		var image := project.new_empty_image()
		_blend_layers(image, frame)
		blended_frames[frame] = image


func process_spritesheet(project := Global.current_project) -> void:
	processed_images.clear()
	# Range of frames determined by tags
	var frames := _calculate_frames(project)
	# Then store the size of frames for other functions
	number_of_frames = frames.size()
	# Used when the orientation is based off the animation tags
	var tag_origins := {0: 0}
	var frames_without_tag := number_of_frames
	var spritesheet_columns := 1
	var spritesheet_rows := 1
	# If rows mode selected calculate columns count and vice versa
	if orientation == Orientation.COLUMNS:
		spritesheet_columns = frames_divided_by_spritesheet_lines()
		spritesheet_rows = lines_count
	elif orientation == Orientation.ROWS:
		spritesheet_columns = lines_count
		spritesheet_rows = frames_divided_by_spritesheet_lines()
	else:
		spritesheet_rows = project.animation_tags.size() + 1
		if spritesheet_rows == 1:
			spritesheet_columns = number_of_frames
		else:
			var max_tag_size := 1
			for tag in project.animation_tags:
				tag_origins[tag] = 0
				frames_without_tag -= tag.get_size()
				if tag.get_size() > max_tag_size:
					max_tag_size = tag.get_size()
			if frames_without_tag > max_tag_size:
				max_tag_size = frames_without_tag
			spritesheet_columns = max_tag_size
		if frames_without_tag == 0:
			# If all frames have a tag, remove the first row
			spritesheet_rows -= 1
		if orientation == Orientation.TAGS_BY_ROW:
			# Switch rows and columns
			var temp := spritesheet_rows
			spritesheet_rows = spritesheet_columns
			spritesheet_columns = temp
	var width := project.size.x * spritesheet_columns
	var height := project.size.y * spritesheet_rows
	var whole_image := Image.create(width, height, false, project.get_image_format())
	var origin := Vector2i.ZERO
	var hh := 0
	var vv := 0
	for frame in frames:
		if orientation == Orientation.ROWS:
			if vv < spritesheet_columns:
				origin.x = project.size.x * vv
				vv += 1
			else:
				hh += 1
				origin.x = 0
				vv = 1
				origin.y = project.size.y * hh
		elif orientation == Orientation.COLUMNS:
			if hh < spritesheet_rows:
				origin.y = project.size.y * hh
				hh += 1
			else:
				vv += 1
				origin.y = 0
				hh = 1
				origin.x = project.size.x * vv
		elif orientation == Orientation.TAGS_BY_COLUMN:
			var frame_index := project.frames.find(frame)
			var frame_has_tag := false
			for i in project.animation_tags.size():
				var tag := project.animation_tags[i]
				if tag.has_frame(frame_index):
					origin.x = project.size.x * tag_origins[tag]
					if frames_without_tag == 0:
						# If all frames have a tag, remove the first row
						origin.y = project.size.y * i
					else:
						origin.y = project.size.y * (i + 1)
					tag_origins[tag] += 1
					frame_has_tag = true
					break
			if not frame_has_tag:
				origin.x = project.size.x * tag_origins[0]
				origin.y = 0
				tag_origins[0] += 1
		elif orientation == Orientation.TAGS_BY_ROW:
			var frame_index := project.frames.find(frame)
			var frame_has_tag := false
			for i in project.animation_tags.size():
				var tag := project.animation_tags[i]
				if tag.has_frame(frame_index):
					origin.y = project.size.y * tag_origins[tag]
					if frames_without_tag == 0:
						# If all frames have a tag, remove the first row
						origin.x = project.size.x * i
					else:
						origin.x = project.size.x * (i + 1)
					tag_origins[tag] += 1
					frame_has_tag = true
					break
			if not frame_has_tag:
				origin.y = project.size.y * tag_origins[0]
				origin.x = 0
				tag_origins[0] += 1
		whole_image.blend_rect(blended_frames[frame], Rect2i(Vector2i.ZERO, project.size), origin)

	processed_images.append(ProcessedImage.new(whole_image, 0))


func process_animation(project := Global.current_project) -> void:
	processed_images.clear()
	var frames := _calculate_frames(project)
	for frame in frames:
		if split_layers:
			for cel in frame.cels:
				var image := Image.new()
				image.copy_from(cel.get_image())
				var duration := frame.get_duration_in_seconds(project.fps)
				processed_images.append(
					ProcessedImage.new(image, project.frames.find(frame), duration)
				)
		else:
			var image := project.new_empty_image()
			image.copy_from(blended_frames[frame])
			if erase_unselected_area and project.has_selection:
				var crop := project.new_empty_image()
				var selection_image = project.selection_map.return_cropped_copy(project.size)
				crop.blit_rect_mask(
					image, selection_image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO
				)
				image.copy_from(crop)
			if trim_images:
				image = image.get_region(image.get_used_rect())
			var duration := frame.get_duration_in_seconds(project.fps)
			processed_images.append(ProcessedImage.new(image, project.frames.find(frame), duration))


func _calculate_frames(project := Global.current_project) -> Array[Frame]:
	var tag_index := frame_current_tag - ExportFrames.size()
	if tag_index >= project.animation_tags.size():
		frame_current_tag = ExportFrames.ALL_FRAMES
	var frames: Array[Frame] = []
	if frame_current_tag >= ExportFrames.size():  # Export a specific tag
		var frame_start: int = project.animation_tags[tag_index].from
		var frame_end: int = project.animation_tags[tag_index].to
		frames = project.frames.slice(frame_start - 1, frame_end, 1, true)
	elif frame_current_tag == ExportFrames.SELECTED_FRAMES:
		for cel in project.selected_cels:
			var frame := project.frames[cel[0]]
			if not frames.has(frame):
				frames.append(frame)
	else:  # All frames
		frames = project.frames.duplicate()

	if direction == AnimationDirection.BACKWARDS:
		frames.reverse()
	elif direction == AnimationDirection.PING_PONG:
		var inverted_frames := frames.duplicate()
		inverted_frames.reverse()
		inverted_frames.remove_at(0)
		if inverted_frames.size() > 0:
			inverted_frames.remove_at(inverted_frames.size() - 1)
		frames.append_array(inverted_frames)
	return frames


func export_processed_images(
	ignore_overwrites: bool, export_dialog: ConfirmationDialog, project := Global.current_project
) -> bool:
	# Stop export if directory path or file name are not valid
	var dir_exists := DirAccess.dir_exists_absolute(project.export_directory_path)
	var is_valid_filename := project.file_name.is_valid_filename()
	if not dir_exists:
		if is_valid_filename:  # Directory path not valid, file name is valid
			export_dialog.open_path_validation_alert_popup(0)
		else:  # Both directory path and file name are invalid
			export_dialog.open_path_validation_alert_popup()
		return false
	if not is_valid_filename:  # Directory path is valid, file name is invalid
		export_dialog.open_path_validation_alert_popup(1)
		return false

	var multiple_files := false
	if current_tab == ExportTab.IMAGE and not is_single_file_format(project):
		multiple_files = true if processed_images.size() > 1 else false
	# Check export paths
	var export_paths: PackedStringArray = []
	var paths_of_existing_files := ""
	for i in processed_images.size():
		stop_export = false
		var frame_index := i + 1
		var layer_index := -1
		var actual_frame_index := processed_images[i].frame_index
		if split_layers:
			frame_index = i / project.layers.size() + 1
			layer_index = posmod(i, project.layers.size())
		var export_path := _create_export_path(
			multiple_files, project, frame_index, layer_index, actual_frame_index
		)
		# If the user wants to create a new directory for each animation tag then check
		# if directories exist, and create them if not
		if multiple_files and new_dir_for_each_frame_tag:
			var frame_tag_directory := DirAccess.open(export_path.get_base_dir())
			if not DirAccess.dir_exists_absolute(export_path.get_base_dir()):
				frame_tag_directory = DirAccess.open(project.export_directory_path)
				frame_tag_directory.make_dir(export_path.get_base_dir().get_file())

		if not ignore_overwrites:  # Check if the files already exist
			if FileAccess.file_exists(export_path):
				if not paths_of_existing_files.is_empty():
					paths_of_existing_files += "\n"
				paths_of_existing_files += export_path
		export_paths.append(export_path)
		# Only get one export path if single file animated image is exported
		if is_single_file_format(project):
			break

	if not paths_of_existing_files.is_empty():  # If files already exist
		# Ask user if they want to overwrite the files
		export_dialog.open_file_exists_alert_popup(tr(file_exists_alert) % paths_of_existing_files)
		# Stops the function until the user decides if they want to overwrite
		await export_dialog.resume_export_function
		if stop_export:  # User decided to stop export
			return false

	_scale_processed_images()
	if export_json:
		var json := JSON.stringify(project.serialize())
		var json_file_name := project.name + ".json"
		if OS.has_feature("web"):
			var json_buffer := json.to_utf8_buffer()
			JavaScriptBridge.download_buffer(json_buffer, json_file_name, "application/json")
		else:
			var json_path := project.export_directory_path.path_join(json_file_name)
			var json_file := FileAccess.open(json_path, FileAccess.WRITE)
			json_file.store_string(json)
	# override if a custom export is chosen
	if project.file_format in custom_exporter_generators.keys():
		# Divert the path to the custom exporter instead
		var custom_exporter: Object = custom_exporter_generators[project.file_format][0]
		if custom_exporter.has_method("override_export"):
			var result := true
			var details := {
				"processed_images": processed_images,
				"export_dialog": export_dialog,
				"export_paths": export_paths,
				"project": project
			}
			if _multithreading_enabled() and is_single_file_format(project):
				if gif_export_thread.is_started():
					gif_export_thread.wait_to_finish()
				var error = gif_export_thread.start(
					Callable(custom_exporter, "override_export").bind(details)
				)
				if error == OK:
					result = gif_export_thread.wait_to_finish()
			else:
				result = custom_exporter.call("override_export", details)
			return result

	if is_single_file_format(project):
		if is_using_ffmpeg(project.file_format):
			var video_exported := export_video(export_paths, project)
			if not video_exported:
				Global.popup_error(
					tr("Video failed to export. Ensure that FFMPEG is installed correctly.")
				)
				return false
		else:
			var exporter: AImgIOBaseExporter
			if project.file_format == FileFormat.APNG:
				exporter = AImgIOAPNGExporter.new()
			else:
				exporter = GIFAnimationExporter.new()
			var details := {
				"exporter": exporter,
				"export_dialog": export_dialog,
				"export_paths": export_paths,
				"project": project
			}
			if not _multithreading_enabled():
				export_animated(details)
			else:
				if gif_export_thread.is_started():
					gif_export_thread.wait_to_finish()
				gif_export_thread.start(export_animated.bind(details))
	else:
		for i in range(processed_images.size()):
			if OS.has_feature("web"):
				if project.file_format == FileFormat.PNG:
					JavaScriptBridge.download_buffer(
						processed_images[i].image.save_png_to_buffer(),
						export_paths[i].get_file(),
						"image/png"
					)
				elif project.file_format == FileFormat.WEBP:
					JavaScriptBridge.download_buffer(
						processed_images[i].image.save_webp_to_buffer(),
						export_paths[i].get_file(),
						"image/webp"
					)
				elif project.file_format == FileFormat.JPEG:
					JavaScriptBridge.download_buffer(
						processed_images[i].image.save_jpg_to_buffer(save_quality),
						export_paths[i].get_file(),
						"image/jpeg"
					)

			else:
				var err: Error
				if project.file_format == FileFormat.PNG:
					err = processed_images[i].image.save_png(export_paths[i])
				elif project.file_format == FileFormat.WEBP:
					err = processed_images[i].image.save_webp(export_paths[i])
				elif project.file_format == FileFormat.JPEG:
					err = processed_images[i].image.save_jpg(export_paths[i], save_quality)
				if err != OK:
					Global.popup_error(
						tr("File failed to save. Error code %s (%s)") % [err, error_string(err)]
					)
					return false

	Global.notification_label("File(s) exported")
	# Store settings for quick export and when the dialog is opened again
	var file_name_with_ext := project.file_name + file_format_string(project.file_format)
	project.was_exported = true
	if project.export_overwrite:
		Global.top_menu_container.file_menu.set_item_text(
			Global.FileMenu.EXPORT, tr("Overwrite") + " %s" % file_name_with_ext
		)
	else:
		Global.top_menu_container.file_menu.set_item_text(
			Global.FileMenu.EXPORT, tr("Export") + " %s" % file_name_with_ext
		)
	project.export_directory_path = export_paths[0].get_base_dir()
	Global.config_cache.set_value("data", "current_dir", project.export_directory_path)
	return true


## Uses FFMPEG to export a video
func export_video(export_paths: PackedStringArray, project: Project) -> bool:
	DirAccess.make_dir_absolute(TEMP_PATH)
	var video_duration := 0
	var temp_path_real := ProjectSettings.globalize_path(TEMP_PATH)
	var input_file_path := temp_path_real.path_join("input.txt")
	var input_file := FileAccess.open(input_file_path, FileAccess.WRITE)
	for i in range(processed_images.size()):
		var temp_file_name := str(i + 1).pad_zeros(number_of_digits) + ".png"
		var temp_file_path := temp_path_real.path_join(temp_file_name)
		processed_images[i].image.save_png(temp_file_path)
		input_file.store_line("file '" + temp_file_name + "'")
		input_file.store_line("duration %s" % processed_images[i].duration)
		video_duration += processed_images[i].duration
	input_file.close()

	# ffmpeg -y -f concat -i input.txt output_path
	var ffmpeg_execute: PackedStringArray = [
		"-y", "-f", "concat", "-i", input_file_path, export_paths[0]
	]
	var success := OS.execute(Global.ffmpeg_path, ffmpeg_execute, [], true)
	if success < 0 or success > 1:
		var fail_text := """Video failed to export. Make sure you have FFMPEG installed
			and have set the correct path in the preferences."""
		Global.popup_error(tr(fail_text))
		_clear_temp_folder()
		return false
	# Find audio layers
	var ffmpeg_combine_audio: PackedStringArray = ["-y"]
	var audio_layer_count := 0
	var max_audio_duration := 0
	var adelay_string := ""
	for layer in project.get_all_audio_layers():
		if layer.audio is AudioStreamMP3:
			var temp_file_name := str(audio_layer_count + 1).pad_zeros(number_of_digits) + ".mp3"
			var temp_file_path := temp_path_real.path_join(temp_file_name)
			var temp_audio_file := FileAccess.open(temp_file_path, FileAccess.WRITE)
			temp_audio_file.store_buffer(layer.audio.data)
			ffmpeg_combine_audio.append("-i")
			ffmpeg_combine_audio.append(temp_file_path)
			var delay := floori(layer.playback_position * 1000)
			# [n]adelay=delay_in_ms:all=1[na]
			adelay_string += (
				"[%s]adelay=%s:all=1[%sa];" % [audio_layer_count, delay, audio_layer_count]
			)
			audio_layer_count += 1
			if layer.get_audio_length() >= max_audio_duration:
				max_audio_duration = layer.get_audio_length()
	if audio_layer_count > 0:
		# If we have audio layers, merge them all into one file.
		for i in audio_layer_count:
			adelay_string += "[%sa]" % i
		var amix_inputs_string := "amix=inputs=%s[a]" % audio_layer_count
		var final_filter_string := adelay_string + amix_inputs_string
		var audio_file_path := temp_path_real.path_join("audio.mp3")
		ffmpeg_combine_audio.append_array(
			PackedStringArray(
				["-filter_complex", final_filter_string, "-map", '"[a]"', audio_file_path]
			)
		)
		# ffmpeg -i input1 -i input2 ... -i inputn -filter_complex amix=inputs=n output_path
		var combined_audio_success := OS.execute(Global.ffmpeg_path, ffmpeg_combine_audio, [], true)
		if combined_audio_success == 0 or combined_audio_success == 1:
			var copied_video := temp_path_real.path_join("video." + export_paths[0].get_extension())
			# Then mix the audio file with the video.
			DirAccess.copy_absolute(export_paths[0], copied_video)
			# ffmpeg -y -i video_file -i input_audio -c:v copy -map 0:v:0 -map 1:a:0 video_file
			var ffmpeg_final_video: PackedStringArray = [
				"-y", "-i", copied_video, "-i", audio_file_path
			]
			if max_audio_duration > video_duration:
				ffmpeg_final_video.append("-shortest")
			ffmpeg_final_video.append_array(
				["-c:v", "copy", "-map", "0:v:0", "-map", "1:a:0", export_paths[0]]
			)
			OS.execute(Global.ffmpeg_path, ffmpeg_final_video, [], true)
	_clear_temp_folder()
	return true


func _clear_temp_folder() -> void:
	var temp_dir := DirAccess.open(TEMP_PATH)
	for file in temp_dir.get_files():
		temp_dir.remove(file)
	DirAccess.remove_absolute(TEMP_PATH)


func export_animated(args: Dictionary) -> void:
	var project: Project = args["project"]
	var exporter: AImgIOBaseExporter = args["exporter"]
	# This is an ExportDialog (which refers back here).
	var export_dialog: ConfirmationDialog = args["export_dialog"]

	# Export progress popup
	# One fraction per each frame, one fraction for write to disk
	export_progress_fraction = 100.0 / processed_images.size()
	export_progress = 0.0
	export_dialog.set_export_progress_bar(export_progress)
	export_dialog.toggle_export_progress_popup(true)

	# Transform into AImgIO form
	var frames := []
	for i in range(processed_images.size()):
		var frame: AImgIOFrame = AImgIOFrame.new()
		frame.content = processed_images[i].image
		frame.duration = processed_images[i].duration
		frames.push_back(frame)

	# Export and save GIF/APNG
	var file_data := exporter.export_animation(
		frames, project.fps, self, "_increase_export_progress", [export_dialog]
	)

	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(file_data, args["export_paths"][0], exporter.mime_type)
	else:
		var file := FileAccess.open(args["export_paths"][0], FileAccess.WRITE)
		file.store_buffer(file_data)
		file.close()
	export_dialog.toggle_export_progress_popup(false)
	Global.notification_label("File(s) exported")


func _increase_export_progress(export_dialog: Node) -> void:
	export_progress += export_progress_fraction
	export_dialog.set_export_progress_bar(export_progress)


func _scale_processed_images() -> void:
	var resize_f := resize / 100.0
	for processed_image in processed_images:
		if is_equal_approx(resize, 1.0):
			continue
		var image := processed_image.image
		image.resize(image.get_size().x * resize_f, image.get_size().y * resize_f, interpolation)


func file_format_string(format_enum: int) -> String:
	if file_format_dictionary.has(format_enum):
		return file_format_dictionary[format_enum][0]
	# If a file format description is not found, try generating one
	if custom_exporter_generators.has(format_enum):
		return custom_exporter_generators[format_enum][1]
	return ""


func file_format_description(format_enum: int) -> String:
	if file_format_dictionary.has(format_enum):
		return file_format_dictionary[format_enum][1]
	# If a file format description is not found, try generating one
	for key in custom_file_formats.keys():
		if custom_file_formats[key] == format_enum:
			return str(key.capitalize())
	return ""


func get_file_format_from_extension(file_extension: String) -> FileFormat:
	if not file_extension.begins_with("."):
		file_extension = "." + file_extension
	for format: FileFormat in file_format_dictionary:
		var extension: String = file_format_dictionary[format][0]
		if file_extension.to_lower() == extension:
			return format
	return FileFormat.PNG


## True when exporting to .gif, .apng and video
## False when exporting to .png, .jpg and static .webp
func is_single_file_format(project := Global.current_project) -> bool:
	return animated_formats.has(project.file_format)


func is_using_ffmpeg(format: FileFormat) -> bool:
	return ffmpeg_formats.has(format)


func is_ffmpeg_installed() -> bool:
	if Global.ffmpeg_path.is_empty():
		return false
	var ffmpeg_executed := OS.execute(Global.ffmpeg_path, [])
	if ffmpeg_executed == 0 or ffmpeg_executed == 1:
		return true
	return false


func _create_export_path(
	multifile: bool, project: Project, frame := 0, layer := -1, actual_frame_index := 0
) -> String:
	var path := project.file_name
	if path.contains("{name}"):
		path = path.replace("{name}", project.name)
	var path_extras := ""
	# Only append frame number when there are multiple files exported
	if multifile:
		if layer > -1:
			var layer_name := project.layers[layer].name
			path_extras += "(%s) " % layer_name
		path_extras += separator_character + str(frame).pad_zeros(number_of_digits)
	var frame_tag_and_start_id := _get_processed_image_tag_name_and_start_id(
		project, actual_frame_index
	)
	# Check if exported frame is in frame tag
	if not frame_tag_and_start_id.is_empty():
		var frame_tag: String = frame_tag_and_start_id[0]
		var start_id: int = frame_tag_and_start_id[1]
		# Remove unallowed characters in frame tag directory
		var regex := RegEx.new()
		regex.compile("[^a-zA-Z0-9_]+")
		var frame_tag_dir := regex.sub(frame_tag, "", true)
		if include_tag_in_filename:
			# (actual_frame_index - start_id + 2) makes frames id to start from 1
			var tag_frame_number := str(actual_frame_index - start_id + 2).pad_zeros(
				number_of_digits
			)
			path_extras = (
				separator_character + frame_tag_dir + separator_character + tag_frame_number
			)
		if new_dir_for_each_frame_tag:
			path += path_extras
			return project.export_directory_path.path_join(frame_tag_dir).path_join(
				path + file_format_string(project.file_format)
			)
	path += path_extras

	return project.export_directory_path.path_join(path + file_format_string(project.file_format))


func _get_processed_image_tag_name_and_start_id(project: Project, processed_image_id: int) -> Array:
	var result_animation_tag_and_start_id := []
	for animation_tag in project.animation_tags:
		# Check if processed image is in frame tag and assign frame tag and start id if yes
		# Then stop
		if animation_tag.has_frame(processed_image_id):
			result_animation_tag_and_start_id = [animation_tag.name, animation_tag.from]
			break
	return result_animation_tag_and_start_id


func _blend_layers(
	image: Image, frame: Frame, origin := Vector2i.ZERO, project := Global.current_project
) -> void:
	if export_layers - 2 >= project.layers.size():
		export_layers = VISIBLE_LAYERS
	if export_layers == VISIBLE_LAYERS:
		var load_result_from_pxo := not project.save_path.is_empty() and not project.has_changed
		if load_result_from_pxo:
			# Attempt to read the image data directly from the pxo file, without having to blend
			# This is mostly useful for when running Pixelorama in headless mode
			# To handle exporting from a CLI
			var zip_reader := ZIPReader.new()
			var err := zip_reader.open(project.save_path)
			if err == OK:
				var frame_index := project.frames.find(frame) + 1
				var image_path := "image_data/final_images/%s" % frame_index
				if zip_reader.file_exists(image_path):
					# "Include blended" must be toggled on when saving the pxo file
					# in order for this to work.
					var image_data := zip_reader.read_file(image_path)
					var loaded_image := Image.create_from_data(
						project.size.x,
						project.size.y,
						image.has_mipmaps(),
						image.get_format(),
						image_data
					)
					image.blend_rect(loaded_image, Rect2i(Vector2i.ZERO, project.size), origin)
				else:
					load_result_from_pxo = false
				zip_reader.close()
			else:
				load_result_from_pxo = false
		if not load_result_from_pxo:
			DrawingAlgos.blend_layers(image, frame, origin, project)
	elif export_layers == SELECTED_LAYERS:
		DrawingAlgos.blend_layers(image, frame, origin, project, false, true)
	else:
		var layer := project.layers[export_layers - 2]
		var layer_image := Image.new()
		if layer is GroupLayer:
			layer_image.copy_from(layer.blend_children(frame, Vector2i.ZERO))
		else:
			layer_image.copy_from(layer.display_effects(frame.cels[export_layers - 2]))
		image.blend_rect(layer_image, Rect2i(Vector2i.ZERO, project.size), origin)


func frames_divided_by_spritesheet_lines() -> int:
	return ceili(number_of_frames / float(lines_count))
