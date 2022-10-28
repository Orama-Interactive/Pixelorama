extends Node

enum ExportTab { FRAME = 0, SPRITESHEET = 1, ANIMATION = 2 }
enum Orientation { ROWS = 0, COLUMNS = 1 }
enum AnimationType { MULTIPLE_FILES = 0, ANIMATED = 1 }
enum AnimationDirection { FORWARD = 0, BACKWARDS = 1, PING_PONG = 2 }
# See file_format_string, file_format_description, and ExportDialog.gd
enum FileFormat { PNG = 0, GIF = 1, APNG = 2 }

var current_tab: int = ExportTab.FRAME
# Frame options
var frame_number := 1
# All frames and their layers processed/blended into images
var processed_images = []  # Image[]

# Spritesheet options
var frame_current_tag := 0  # Export only current frame tag
var number_of_frames := 1
var orientation: int = Orientation.ROWS

var lines_count := 1  # How many rows/columns before new line is added

var animation_type: int = AnimationType.MULTIPLE_FILES
var direction: int = AnimationDirection.FORWARD

# Options
var resize := 100
var interpolation := 0  # Image.Interpolation
var new_dir_for_each_frame_tag: bool = true  # you don't need to store this after export

# Export directory path and export file name
var directory_path := ""
var file_name := "untitled"
var file_format: int = FileFormat.PNG

var was_exported: bool = false

# Export coroutine signal
var stop_export = false

var file_exists_alert = "File %s already exists. Overwrite?"

# Export progress variables
var export_progress_fraction := 0.0
var export_progress := 0.0
onready var gif_export_thread := Thread.new()


func _exit_tree() -> void:
	if gif_export_thread.is_active():
		gif_export_thread.wait_to_finish()


func external_export() -> void:
	match current_tab:
		ExportTab.FRAME:
			process_frame()
		ExportTab.SPRITESHEET:
			process_spritesheet()
		ExportTab.ANIMATION:
			process_animation()
	export_processed_images(true, Global.export_dialog)


func process_frame() -> void:
	processed_images.clear()
	var frame = Global.current_project.frames[frame_number - 1]
	var image := Image.new()
	image.create(
		Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_RGBA8
	)
	blend_layers(image, frame)
	processed_images.append(image)


func process_spritesheet() -> void:
	processed_images.clear()
	# Range of frames determined by tags
	var frames := []
	if frame_current_tag > 0:
		var frame_start = Global.current_project.animation_tags[frame_current_tag - 1].from
		var frame_end = Global.current_project.animation_tags[frame_current_tag - 1].to
		frames = Global.current_project.frames.slice(frame_start - 1, frame_end - 1, 1, true)
	else:
		frames = Global.current_project.frames

	# Then store the size of frames for other functions
	number_of_frames = frames.size()

	# If rows mode selected calculate columns count and vice versa
	var spritesheet_columns = (
		lines_count
		if orientation == Orientation.ROWS
		else frames_divided_by_spritesheet_lines()
	)
	var spritesheet_rows = (
		lines_count
		if orientation == Orientation.COLUMNS
		else frames_divided_by_spritesheet_lines()
	)

	var width = Global.current_project.size.x * spritesheet_columns
	var height = Global.current_project.size.y * spritesheet_rows

	var whole_image := Image.new()
	whole_image.create(width, height, false, Image.FORMAT_RGBA8)
	var origin := Vector2.ZERO
	var hh := 0
	var vv := 0

	for frame in frames:
		if orientation == Orientation.ROWS:
			if vv < spritesheet_columns:
				origin.x = Global.current_project.size.x * vv
				vv += 1
			else:
				hh += 1
				origin.x = 0
				vv = 1
				origin.y = Global.current_project.size.y * hh
		else:
			if hh < spritesheet_rows:
				origin.y = Global.current_project.size.y * hh
				hh += 1
			else:
				vv += 1
				origin.y = 0
				hh = 1
				origin.x = Global.current_project.size.x * vv
		blend_layers(whole_image, frame, origin)

	processed_images.append(whole_image)


func process_animation() -> void:
	processed_images.clear()
	for frame in Global.current_project.frames:
		var image := Image.new()
		image.create(
			Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_RGBA8
		)
		blend_layers(image, frame)
		processed_images.append(image)


func export_processed_images(ignore_overwrites: bool, export_dialog: AcceptDialog) -> bool:
	# Stop export if directory path or file name are not valid
	var dir = Directory.new()
	if not dir.dir_exists(directory_path) or not file_name.is_valid_filename():
		if not dir.dir_exists(directory_path) and file_name.is_valid_filename():
			export_dialog.open_path_validation_alert_popup(0)
		elif not file_name.is_valid_filename() and dir.dir_exists(directory_path):
			export_dialog.open_path_validation_alert_popup(1)
		else:
			export_dialog.open_path_validation_alert_popup()
		return false

	# Check export paths
	var export_paths = []
	for i in range(processed_images.size()):
		stop_export = false
		var multiple_files := (
			true
			if (
				current_tab == ExportTab.ANIMATION
				and animation_type == AnimationType.MULTIPLE_FILES
			)
			else false
		)
		var export_path = create_export_path(multiple_files, i + 1)
		# If user want to create new directory for each animation tag then check
		# if directories exist and create them if not
		if multiple_files and new_dir_for_each_frame_tag:
			var frame_tag_directory := Directory.new()
			if not frame_tag_directory.dir_exists(export_path.get_base_dir()):
				frame_tag_directory.open(directory_path)
				frame_tag_directory.make_dir(export_path.get_base_dir().get_file())
		# Check if the file already exists
		var file_check: File = File.new()
		if file_check.file_exists(export_path):
			# Ask user if they want to overwrite the file
			if not was_exported or (was_exported and not ignore_overwrites):
				# Overwrite existing file?
				export_dialog.open_file_exists_alert_popup(file_exists_alert % export_path)
				# Stops the function until the user decides if they want to overwrite
				yield(export_dialog, "resume_export_function")
				if stop_export:
					# User decided to stop export
					return
		export_paths.append(export_path)
		# Only get one export path if single file animated image is exported
		if current_tab == ExportTab.ANIMATION and animation_type == AnimationType.ANIMATED:
			break

	# Scale images that are to export
	scale_processed_images()

	if current_tab == ExportTab.ANIMATION and animation_type == AnimationType.ANIMATED:
		var exporter: BaseAnimationExporter
		if file_format == FileFormat.APNG:
			exporter = APNGAnimationExporter.new()
		else:
			exporter = GIFAnimationExporter.new()
		var details = {
			"exporter": exporter, "export_dialog": export_dialog, "export_paths": export_paths
		}
		if OS.get_name() == "HTML5":
			export_animated(details)
		else:
			if gif_export_thread.is_active():
				gif_export_thread.wait_to_finish()
			gif_export_thread.start(self, "export_animated", details)
	else:
		for i in range(processed_images.size()):
			if OS.get_name() == "HTML5":
				JavaScript.download_buffer(
					processed_images[i].save_png_to_buffer(),
					export_paths[i].get_file(),
					"image/png"
				)
			else:
				var err = processed_images[i].save_png(export_paths[i])
				if err != OK:
					Global.error_dialog.set_text(tr("File failed to save. Error code %s") % err)
					Global.error_dialog.popup_centered()
					Global.dialog_open(true)

	# Store settings for quick export and when the dialog is opened again
	was_exported = true
	Global.current_project.was_exported = true
	if Global.current_project.export_overwrite:
		Global.top_menu_container.file_menu.set_item_text(
			6, tr("Overwrite") + " %s" % (file_name + Export.file_format_string(file_format))
		)
	else:
		Global.top_menu_container.file_menu.set_item_text(
			6, tr("Export") + " %s" % (file_name + file_format_string(file_format))
		)

	# Only show when not exporting gif - gif export finishes in thread
	if not (current_tab == ExportTab.ANIMATION and animation_type == AnimationType.ANIMATED):
		Global.notification_label("File(s) exported")
	return true


func export_animated(args: Dictionary) -> void:
	var exporter: BaseAnimationExporter = args["exporter"]
	# This is an ExportDialog (which refers back here).
	var export_dialog = args["export_dialog"]
	# Array of Image
	var sequence = []
	# Array of float
	var durations = []
	match direction:
		AnimationDirection.FORWARD:
			for i in range(processed_images.size()):
				sequence.push_back(processed_images[i])
				durations.push_back(Global.current_project.frames[i].duration)
		AnimationDirection.BACKWARDS:
			for i in range(processed_images.size() - 1, -1, -1):
				sequence.push_back(processed_images[i])
				durations.push_back(Global.current_project.frames[i].duration)
		AnimationDirection.PING_PONG:
			for i in range(0, processed_images.size()):
				sequence.push_back(processed_images[i])
				durations.push_back(Global.current_project.frames[i].duration)
			for i in range(processed_images.size() - 2, 0, -1):
				sequence.push_back(processed_images[i])
				durations.push_back(Global.current_project.frames[i].duration)

	# Stuff we need to deal with across all images
	for i in range(processed_images.size()):
		durations[i] *= 1 / Global.current_project.fps

	# Export progress popup
	# One fraction per each frame, one fraction for write to disk
	export_progress_fraction = 100.0 / len(sequence)
	export_progress = 0.0
	export_dialog.set_export_progress_bar(export_progress)
	export_dialog.toggle_export_progress_popup(true)

	# Export and save gif
	var file_data = exporter.export_animation(
		sequence,
		durations,
		Global.current_project.fps,
		self,
		"increase_export_progress",
		[export_dialog]
	)

	if OS.get_name() == "HTML5":
		JavaScript.download_buffer(file_data, args["export_paths"][0], exporter.mime_type)
	else:
		var file: File = File.new()
		file.open(args["export_paths"][0], File.WRITE)
		file.store_buffer(file_data)
		file.close()
	export_dialog.toggle_export_progress_popup(false)
	Global.notification_label("File(s) exported")


func increase_export_progress(export_dialog: Node) -> void:
	export_progress += export_progress_fraction
	export_dialog.set_export_progress_bar(export_progress)


func scale_processed_images() -> void:
	for processed_image in processed_images:
		if resize != 100:
			processed_image.unlock()
			processed_image.resize(
				processed_image.get_size().x * resize / 100,
				processed_image.get_size().y * resize / 100,
				interpolation
			)


func file_format_string(format_enum: int) -> String:
	match format_enum:
		FileFormat.PNG:
			return ".png"
		FileFormat.GIF:
			return ".gif"
		FileFormat.APNG:
			return ".apng"
		_:
			return ""


func file_format_description(format_enum: int) -> String:
	match format_enum:
		FileFormat.PNG:
			return "PNG Image"
		FileFormat.GIF:
			return "GIF Image"
		FileFormat.APNG:
			return "APNG Image"
		_:
			return ""


func create_export_path(multifile: bool, frame: int = 0) -> String:
	var path = file_name
	# Only append frame number when there are multiple files exported
	if multifile:
		var frame_tag_and_start_id = get_proccessed_image_animation_tag_and_start_id(frame - 1)
		# Check if exported frame is in frame tag
		if frame_tag_and_start_id != null:
			var frame_tag = frame_tag_and_start_id[0]
			var start_id = frame_tag_and_start_id[1]
			# Remove unallowed characters in frame tag directory
			var regex := RegEx.new()
			regex.compile("[^a-zA-Z0-9_]+")
			var frame_tag_dir = regex.sub(frame_tag, "", true)
			if new_dir_for_each_frame_tag:
				# Add frame tag if frame has one
				# (frame - start_id + 1) Makes frames id to start from 1 in each frame tag directory
				path += "_" + frame_tag_dir + "_" + String(frame - start_id + 1)
				return directory_path.plus_file(frame_tag_dir).plus_file(
					path + file_format_string(file_format)
				)
			else:
				# Add frame tag if frame has one
				# (frame - start_id + 1) Makes frames id to start from 1 in each frame tag
				path += "_" + frame_tag_dir + "_" + String(frame - start_id + 1)
		else:
			path += "_" + String(frame)

	return directory_path.plus_file(path + file_format_string(file_format))


func get_proccessed_image_animation_tag_and_start_id(processed_image_id: int) -> Array:
	var result_animation_tag_and_start_id = null
	for animation_tag in Global.current_project.animation_tags:
		# Check if processed image is in frame tag and assign frame tag and start id if yes
		# Then stop
		if (
			(processed_image_id + 1) >= animation_tag.from
			and (processed_image_id + 1) <= animation_tag.to
		):
			result_animation_tag_and_start_id = [animation_tag.name, animation_tag.from]
			break
	return result_animation_tag_and_start_id


# Blends canvas layers into passed image starting from the origin position
func blend_layers(image: Image, frame: Frame, origin: Vector2 = Vector2(0, 0)) -> void:
	image.lock()
	var layer_i := 0
	for cel in frame.cels:
		if Global.current_project.layers[layer_i].is_visible_in_hierarchy() and cel is PixelCel:
			var cel_image := Image.new()
			cel_image.copy_from(cel.image)
			cel_image.lock()
			if cel.opacity < 1:  # If we have cel transparency
				for xx in cel_image.get_size().x:
					for yy in cel_image.get_size().y:
						var pixel_color := cel_image.get_pixel(xx, yy)
						var alpha: float = pixel_color.a * cel.opacity
						cel_image.set_pixel(
							xx, yy, Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha)
						)
			image.blend_rect(cel_image, Rect2(Vector2.ZERO, Global.current_project.size), origin)
			cel_image.unlock()
		layer_i += 1
	image.unlock()


# Blends selected cels of the given frame into passed image starting from the origin position
func blend_selected_cels(image: Image, frame: Frame, origin: Vector2 = Vector2(0, 0)) -> void:
	image.lock()
	var layer_i := 0
	for cel_ind in frame.cels.size():
		var test_array = [Global.current_project.current_frame, cel_ind]
		if not test_array in Global.current_project.selected_cels:
			continue
		if not frame.cels[cel_ind] is PixelCel:
			continue

		var cel: PixelCel = frame.cels[cel_ind]

		if Global.current_project.layers[layer_i].is_visible_in_hierarchy():
			var cel_image := Image.new()
			cel_image.copy_from(cel.image)
			cel_image.lock()
			if cel.opacity < 1:  # If we have cel transparency
				for xx in cel_image.get_size().x:
					for yy in cel_image.get_size().y:
						var pixel_color := cel_image.get_pixel(xx, yy)
						var alpha: float = pixel_color.a * cel.opacity
						cel_image.set_pixel(
							xx, yy, Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha)
						)
			image.blend_rect(cel_image, Rect2(Vector2.ZERO, Global.current_project.size), origin)
			cel_image.unlock()
		layer_i += 1
	image.unlock()


func frames_divided_by_spritesheet_lines() -> int:
	return int(ceil(number_of_frames / float(lines_count)))
