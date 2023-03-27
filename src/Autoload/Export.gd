extends Node

enum ExportTab { IMAGE = 0, SPRITESHEET = 1 }
enum Orientation { ROWS = 0, COLUMNS = 1 }
enum AnimationDirection { FORWARD = 0, BACKWARDS = 1, PING_PONG = 2 }
# See file_format_string, file_format_description, and ExportDialog.gd
enum FileFormat { PNG = 0, GIF = 1, APNG = 2 }

var current_tab: int = ExportTab.IMAGE
# All frames and their layers processed/blended into images
var processed_images := []  # Image[]
var durations := []  # Array of floats

# Spritesheet options
var orientation: int = Orientation.ROWS
var lines_count := 1  # How many rows/columns before new line is added

# General options
var frame_current_tag := 0  # Export only current frame tag
var export_layers := 0
var number_of_frames := 1
var direction: int = AnimationDirection.FORWARD
var resize := 100
var interpolation := 0  # Image.Interpolation
var new_dir_for_each_frame_tag := false  # we don't need to store this after export

# Export coroutine signal
var stop_export := false

var file_exists_alert := "The following files already exist. Do you wish to overwrite them?\n%s"

# Export progress variables
var export_progress_fraction := 0.0
var export_progress := 0.0
onready var gif_export_thread := Thread.new()


func _exit_tree() -> void:
	if gif_export_thread.is_active():
		gif_export_thread.wait_to_finish()


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
	var frames := calculate_frames(project)
	# Then store the size of frames for other functions
	number_of_frames = frames.size()

	# If rows mode selected calculate columns count and vice versa
	var spritesheet_columns := (
		lines_count
		if orientation == Orientation.ROWS
		else frames_divided_by_spritesheet_lines()
	)
	var spritesheet_rows := (
		lines_count
		if orientation == Orientation.COLUMNS
		else frames_divided_by_spritesheet_lines()
	)

	var width := project.size.x * spritesheet_columns
	var height := project.size.y * spritesheet_rows

	var whole_image := Image.new()
	whole_image.create(width, height, false, Image.FORMAT_RGBA8)
	var origin := Vector2.ZERO
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
		blend_layers(whole_image, frame, origin)

	processed_images.append(whole_image)


func process_animation(project := Global.current_project) -> void:
	processed_images.clear()
	durations.clear()
	var frames := calculate_frames(project)
	for frame in frames:
		var image := Image.new()
		image.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
		blend_layers(image, frame)
		processed_images.append(image)
		durations.append(frame.duration * (1.0 / project.fps))


func calculate_frames(project := Global.current_project) -> Array:
	var frames := []
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
		frames.invert()
	elif direction == AnimationDirection.PING_PONG:
		var inverted_frames := frames.duplicate()
		inverted_frames.invert()
		inverted_frames.remove(0)
		frames.append_array(inverted_frames)
	return frames


func export_processed_images(
	ignore_overwrites: bool, export_dialog: ConfirmationDialog, project := Global.current_project
) -> bool:
	# Stop export if directory path or file name are not valid
	var dir := Directory.new()
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
	var export_paths := []
	var paths_of_existing_files := ""
	for i in range(processed_images.size()):
		stop_export = false
		var export_path := create_export_path(multiple_files, project, i + 1)
		# If the user wants to create a new directory for each animation tag then check
		# if directories exist, and create them if not
		if multiple_files and new_dir_for_each_frame_tag:
			var frame_tag_directory := Directory.new()
			if not frame_tag_directory.dir_exists(export_path.get_base_dir()):
				frame_tag_directory.open(project.directory_path)
				frame_tag_directory.make_dir(export_path.get_base_dir().get_file())

		if not ignore_overwrites:  # Check if the files already exist
			var file_check: File = File.new()
			if file_check.file_exists(export_path):
				if not paths_of_existing_files.empty():
					paths_of_existing_files += "\n"
				paths_of_existing_files += export_path
		export_paths.append(export_path)
		# Only get one export path if single file animated image is exported
		if is_single_file_format(project):
			break

	if not paths_of_existing_files.empty():  # If files already exist
		# Ask user if they want to overwrite the files
		export_dialog.open_file_exists_alert_popup(tr(file_exists_alert) % paths_of_existing_files)
		# Stops the function until the user decides if they want to overwrite
		yield(export_dialog, "resume_export_function")
		if stop_export:  # User decided to stop export
			return

	scale_processed_images()

	if is_single_file_format(project):
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

	# Only show when not exporting gif - gif export finishes in thread
	if not is_single_file_format(project):
		Global.notification_label("File(s) exported")
	return true


func export_animated(args: Dictionary) -> void:
	var project: Project = args["project"]
	var exporter: AImgIOBaseExporter = args["exporter"]
	# This is an ExportDialog (which refers back here).
	var export_dialog: ConfirmationDialog = args["export_dialog"]

	# Export progress popup
	# One fraction per each frame, one fraction for write to disk
	export_progress_fraction = 100.0 / len(processed_images)
	export_progress = 0.0
	export_dialog.set_export_progress_bar(export_progress)
	export_dialog.toggle_export_progress_popup(true)

	# Transform into AImgIO form
	var frames := []
	for i in range(len(processed_images)):
		var frame: AImgIOFrame = AImgIOFrame.new()
		frame.content = processed_images[i]
		frame.duration = durations[i]
		frames.push_back(frame)

	# Export and save GIF/APNG
	var file_data := exporter.export_animation(
		frames, project.fps, self, "increase_export_progress", [export_dialog]
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


func is_single_file_format(project := Global.current_project) -> bool:
	# True when exporting to .gif and .apng (and potentially video formats in the future)
	# False when exporting to .png, and other non-animated formats in the future
	return project.file_format == FileFormat.GIF or project.file_format == FileFormat.APNG


func create_export_path(multifile: bool, project: Project, frame: int = 0) -> String:
	var path := project.file_name
	# Only append frame number when there are multiple files exported
	if multifile:
		var frame_tag_and_start_id := get_proccessed_image_animation_tag_and_start_id(
			project, frame - 1
		)
		# Check if exported frame is in frame tag
		if frame_tag_and_start_id != null:
			var frame_tag: String = frame_tag_and_start_id[0]
			var start_id: int = frame_tag_and_start_id[1]
			# Remove unallowed characters in frame tag directory
			var regex := RegEx.new()
			regex.compile("[^a-zA-Z0-9_]+")
			var frame_tag_dir := regex.sub(frame_tag, "", true)
			if new_dir_for_each_frame_tag:
				# Add frame tag if frame has one
				# (frame - start_id + 1) Makes frames id to start from 1 in each frame tag directory
				path += "_" + frame_tag_dir + "_" + String(frame - start_id + 1)
				return project.directory_path.plus_file(frame_tag_dir).plus_file(
					path + file_format_string(project.file_format)
				)
			else:
				# Add frame tag if frame has one
				# (frame - start_id + 1) Makes frames id to start from 1 in each frame tag
				path += "_" + frame_tag_dir + "_" + String(frame - start_id + 1)
		else:
			path += "_" + String(frame)

	return project.directory_path.plus_file(path + file_format_string(project.file_format))


func get_proccessed_image_animation_tag_and_start_id(
	project: Project, processed_image_id: int
) -> Array:
	var result_animation_tag_and_start_id = null
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


func blend_layers(
	image: Image, frame: Frame, origin := Vector2.ZERO, project := Global.current_project
) -> void:
	if export_layers == 0:
		blend_all_layers(image, frame, origin, project)
	elif export_layers == 1:
		blend_selected_cels(image, frame, origin, project)
	else:
		var layer: BaseLayer = project.layers[export_layers - 2]
		var layer_image := Image.new()
		if layer is PixelLayer:
			layer_image.copy_from(frame.cels[export_layers - 2].image)
		elif layer is GroupLayer:
			layer_image.copy_from(layer.blend_children(frame, Vector2.ZERO))
		image.blend_rect(layer_image, Rect2(Vector2.ZERO, project.size), origin)


# Blends canvas layers into passed image starting from the origin position
func blend_all_layers(
	image: Image, frame: Frame, origin := Vector2.ZERO, project := Global.current_project
) -> void:
	var layer_i := 0
	for cel in frame.cels:
		if project.layers[layer_i].is_visible_in_hierarchy() and cel is PixelCel:
			var cel_image := Image.new()
			cel_image.copy_from(cel.image)
			if cel.opacity < 1:  # If we have cel transparency
				cel_image.lock()
				for xx in cel_image.get_size().x:
					for yy in cel_image.get_size().y:
						var pixel_color := cel_image.get_pixel(xx, yy)
						var alpha: float = pixel_color.a * cel.opacity
						cel_image.set_pixel(
							xx, yy, Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha)
						)
				cel_image.unlock()
			image.blend_rect(cel_image, Rect2(Vector2.ZERO, project.size), origin)
		layer_i += 1


# Blends selected cels of the given frame into passed image starting from the origin position
func blend_selected_cels(
	image: Image, frame: Frame, origin := Vector2(0, 0), project := Global.current_project
) -> void:
	for cel_ind in frame.cels.size():
		var test_array := [project.current_frame, cel_ind]
		if not test_array in project.selected_cels:
			continue
		if not frame.cels[cel_ind] is PixelCel:
			continue
		if not project.layers[cel_ind].is_visible_in_hierarchy():
			continue
		var cel: PixelCel = frame.cels[cel_ind]
		var cel_image := Image.new()
		cel_image.copy_from(cel.image)
		if cel.opacity < 1:  # If we have cel transparency
			cel_image.lock()
			for xx in cel_image.get_size().x:
				for yy in cel_image.get_size().y:
					var pixel_color := cel_image.get_pixel(xx, yy)
					var alpha: float = pixel_color.a * cel.opacity
					cel_image.set_pixel(
						xx, yy, Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha)
					)
			cel_image.unlock()
		image.blend_rect(cel_image, Rect2(Vector2.ZERO, project.size), origin)


func frames_divided_by_spritesheet_lines() -> int:
	return int(ceil(number_of_frames / float(lines_count)))
