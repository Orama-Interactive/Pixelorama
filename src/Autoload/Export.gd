extends Node

enum ExportTab { IMAGE = 0, SPRITESHEET = 1 }
enum Orientation { ROWS = 0, COLUMNS = 1 }
enum AnimationDirection { FORWARD = 0, BACKWARDS = 1, PING_PONG = 2 }
## See file_format_string, file_format_description, and ExportDialog.gd
enum FileFormat { PNG, WEBP, JPEG, GIF, APNG, MP4 }

## List of animated formats
var animated_formats := [FileFormat.GIF, FileFormat.APNG, FileFormat.MP4]

## A dictionary of custom exporter generators (received from extensions)
var custom_file_formats := {}
var custom_exporter_generators := {}

var current_tab := ExportTab.IMAGE
## All frames and their layers processed/blended into images
var processed_images: Array[Image] = []
var durations: PackedFloat32Array = []

# Spritesheet options
var orientation := Orientation.ROWS
var lines_count := 1  ## How many rows/columns before new line is added

# General options
var frame_current_tag := 0  ## Export only current frame tag
var export_layers := 0
var number_of_frames := 1
var direction := AnimationDirection.FORWARD
var resize := 100
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
	process_data(project)
	export_processed_images(true, Global.export_dialog, project)


func process_data(project := Global.current_project) -> void:
	match current_tab:
		ExportTab.IMAGE:
			process_animation(project)
		ExportTab.SPRITESHEET:
			process_spritesheet(project)


func process_spritesheet(project := Global.current_project) -> void:
	processed_images.clear()
	# Range of frames determined by tags
	var frames := _calculate_frames(project)
	# Then store the size of frames for other functions
	number_of_frames = frames.size()

	# If rows mode selected calculate columns count and vice versa
	var spritesheet_columns := (
		lines_count if orientation == Orientation.ROWS else frames_divided_by_spritesheet_lines()
	)
	var spritesheet_rows := (
		lines_count if orientation == Orientation.COLUMNS else frames_divided_by_spritesheet_lines()
	)

	var width := project.size.x * spritesheet_columns
	var height := project.size.y * spritesheet_rows

	var whole_image := Image.create(width, height, false, Image.FORMAT_RGBA8)
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
		else:
			if hh < spritesheet_rows:
				origin.y = project.size.y * hh
				hh += 1
			else:
				vv += 1
				origin.y = 0
				hh = 1
				origin.x = project.size.x * vv
		_blend_layers(whole_image, frame, origin)

	processed_images.append(whole_image)


func process_animation(project := Global.current_project) -> void:
	processed_images.clear()
	durations.clear()
	var frames := _calculate_frames(project)
	for frame in frames:
		var image := Image.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
		_blend_layers(image, frame)
		processed_images.append(image)
		durations.append(frame.duration * (1.0 / project.fps))


func _calculate_frames(project := Global.current_project) -> Array[Frame]:
	var frames: Array[Frame] = []
	if frame_current_tag > 1:  # Specific tag
		var frame_start: int = project.animation_tags[frame_current_tag - 2].from
		var frame_end: int = project.animation_tags[frame_current_tag - 2].to
		frames = project.frames.slice(frame_start - 1, frame_end - 1, 1, true)
	elif frame_current_tag == 1:  # Selected frames
		for cel in project.selected_cels:
			frames.append(project.frames[cel[0]])
	else:  # All frames
		frames = project.frames.duplicate()

	if direction == AnimationDirection.BACKWARDS:
		frames.reverse()
	elif direction == AnimationDirection.PING_PONG:
		var inverted_frames := frames.duplicate()
		inverted_frames.reverse()
		inverted_frames.remove_at(0)
		frames.append_array(inverted_frames)
	return frames


func export_processed_images(
	ignore_overwrites: bool, export_dialog: ConfirmationDialog, project := Global.current_project
) -> bool:
	# Stop export if directory path or file name are not valid
	var dir := DirAccess.open(project.directory_path)
	if not dir.dir_exists(project.directory_path) or not project.file_name.is_valid_filename():
		if not dir.dir_exists(project.directory_path) and project.file_name.is_valid_filename():
			export_dialog.open_path_validation_alert_popup(0)
		elif not project.file_name.is_valid_filename() and dir.dir_exists(project.directory_path):
			export_dialog.open_path_validation_alert_popup(1)
		else:
			export_dialog.open_path_validation_alert_popup()
		return false

	var multiple_files := false
	if current_tab == ExportTab.IMAGE and not is_single_file_format(project):
		multiple_files = true if processed_images.size() > 1 else false
	# Check export paths
	var export_paths: PackedStringArray = []
	var paths_of_existing_files := ""
	for i in range(processed_images.size()):
		stop_export = false
		var export_path := _create_export_path(multiple_files, project, i + 1)
		# If the user wants to create a new directory for each animation tag then check
		# if directories exist, and create them if not
		if multiple_files and new_dir_for_each_frame_tag:
			var frame_tag_directory := DirAccess.open(export_path.get_base_dir())
			if not frame_tag_directory.dir_exists(export_path.get_base_dir()):
				frame_tag_directory = DirAccess.open(project.directory_path)
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

	# override if a custom export is chosen
	if project.file_format in custom_exporter_generators.keys():
		# Divert the path to the custom exporter instead
		var custom_exporter: Object = custom_exporter_generators[project.file_format][0]
		if custom_exporter.has_method("override_export"):
			var result := true
			var details := {
				"processed_images": processed_images,
				"durations": durations,
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
		if project.file_format == FileFormat.MP4:
			var temp_path := "user://tmp"
			DirAccess.make_dir_absolute(temp_path)
			var temp_path_real := ProjectSettings.globalize_path(temp_path)
			var input_file_path := temp_path_real.path_join("input.txt")
			var input_file := FileAccess.open(input_file_path, FileAccess.WRITE)
			for i in range(processed_images.size()):
				var temp_file_name := str(i + 1).pad_zeros(number_of_digits) + ".png"
				var temp_file_path := temp_path_real.path_join(temp_file_name)
				processed_images[i].save_png(temp_file_path)
				input_file.store_line("file '" + temp_file_name + "'")
				input_file.store_line("duration %s" % durations[i])
			input_file.close()
			var ffmpeg_execute: PackedStringArray = [
				"-y", "-f", "concat", "-i", input_file_path, export_paths[0]
			]
			var output := []
			OS.execute("ffmpeg", ffmpeg_execute, output, true)
			print(output)
			var temp_dir := DirAccess.open(temp_path)
			for file in temp_dir.get_files():
				temp_dir.remove(file)
			DirAccess.remove_absolute(temp_path)
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
		var succeeded := true
		for i in range(processed_images.size()):
			if OS.has_feature("web"):
				if project.file_format == FileFormat.PNG:
					JavaScriptBridge.download_buffer(
						processed_images[i].save_png_to_buffer(),
						export_paths[i].get_file(),
						"image/png"
					)
				elif project.file_format == FileFormat.WEBP:
					JavaScriptBridge.download_buffer(
						processed_images[i].save_webp_to_buffer(),
						export_paths[i].get_file(),
						"image/webp"
					)
				elif project.file_format == FileFormat.JPEG:
					JavaScriptBridge.download_buffer(
						processed_images[i].save_jpg_to_buffer(),
						export_paths[i].get_file(),
						"image/jpeg"
					)

			else:
				var err: Error
				if project.file_format == FileFormat.PNG:
					err = processed_images[i].save_png(export_paths[i])
				elif project.file_format == FileFormat.WEBP:
					err = processed_images[i].save_webp(export_paths[i])
				elif project.file_format == FileFormat.JPEG:
					err = processed_images[i].save_jpg(export_paths[i])
				if err != OK:
					Global.error_dialog.set_text(
						tr("File failed to save. Error code %s (%s)") % [err, error_string(err)]
					)
					Global.error_dialog.popup_centered()
					Global.dialog_open(true)
					succeeded = false
		if succeeded:
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
	return true


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
		frame.content = processed_images[i]
		frame.duration = durations[i]
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
	for processed_image in processed_images:
		if resize != 100:
			processed_image.resize(
				processed_image.get_size().x * resize / 100,
				processed_image.get_size().y * resize / 100,
				interpolation
			)


func file_format_string(format_enum: int) -> String:
	match format_enum:
		FileFormat.PNG:
			return ".png"
		FileFormat.WEBP:
			return ".webp"
		FileFormat.JPEG:
			return ".jpg"
		FileFormat.GIF:
			return ".gif"
		FileFormat.APNG:
			return ".apng"
		FileFormat.MP4:
			return ".mp4"
		_:
			# If a file format description is not found, try generating one
			if custom_exporter_generators.has(format_enum):
				return custom_exporter_generators[format_enum][1]
			return ""


func file_format_description(format_enum: int) -> String:
	match format_enum:
		# these are overrides
		# (if they are not given, they will generate themselves based on the enum key name)
		FileFormat.PNG:
			return "PNG Image"
		FileFormat.WEBP:
			return "WEBP Image"
		FileFormat.JPEG:
			return "JPEG Image"
		FileFormat.GIF:
			return "GIF Image"
		FileFormat.APNG:
			return "APNG Image"
		FileFormat.MP4:
			return "MP4 Video"
		_:
			# If a file format description is not found, try generating one
			for key in custom_file_formats.keys():
				if custom_file_formats[key] == format_enum:
					return str(key.capitalize())
			return ""


## True when exporting to .gif and .apng (and potentially video formats in the future)
## False when exporting to .png, and other non-animated formats in the future
func is_single_file_format(project := Global.current_project) -> bool:
	return animated_formats.has(project.file_format)


func _create_export_path(multifile: bool, project: Project, frame := 0) -> String:
	var path := project.file_name
	# Only append frame number when there are multiple files exported
	if multifile:
		var path_extras := separator_character + str(frame).pad_zeros(number_of_digits)
		var frame_tag_and_start_id := _get_proccessed_image_animation_tag_and_start_id(
			project, frame - 1
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
				# (frame - start_id + 1) makes frames id to start from 1
				var tag_frame_number := str(frame - start_id + 1).pad_zeros(number_of_digits)
				path_extras = (
					separator_character + frame_tag_dir + separator_character + tag_frame_number
				)
			if new_dir_for_each_frame_tag:
				path += path_extras
				return project.directory_path.path_join(frame_tag_dir).path_join(
					path + file_format_string(project.file_format)
				)
		path += path_extras

	return project.directory_path.path_join(path + file_format_string(project.file_format))


func _get_proccessed_image_animation_tag_and_start_id(
	project: Project, processed_image_id: int
) -> Array:
	var result_animation_tag_and_start_id := []
	for animation_tag in project.animation_tags:
		# Check if processed image is in frame tag and assign frame tag and start id if yes
		# Then stop
		if (
			(processed_image_id + 1) >= animation_tag.from
			and (processed_image_id + 1) <= animation_tag.to
		):
			result_animation_tag_and_start_id = [animation_tag.name, animation_tag.from]
			break
	return result_animation_tag_and_start_id


func _blend_layers(
	image: Image, frame: Frame, origin := Vector2i.ZERO, project := Global.current_project
) -> void:
	if export_layers == 0:
		DrawingAlgos.blend_layers(image, frame, origin, project)
	elif export_layers == 1:
		DrawingAlgos.blend_layers(image, frame, origin, project, true)
	else:
		var layer := project.layers[export_layers - 2]
		var layer_image := Image.new()
		if layer is GroupLayer:
			layer_image.copy_from(layer.blend_children(frame, Vector2i.ZERO))
		else:
			layer_image.copy_from(frame.cels[export_layers - 2].get_image())
		image.blend_rect(layer_image, Rect2i(Vector2i.ZERO, project.size), origin)


func frames_divided_by_spritesheet_lines() -> int:
	return ceili(number_of_frames / float(lines_count))
