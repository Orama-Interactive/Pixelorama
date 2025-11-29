# gdlint: ignore=max-public-methods
extends Node

signal project_saved
signal reference_image_imported
signal shader_copied(file_path: String)

const BACKUPS_DIRECTORY := "user://backups"
const SHADERS_DIRECTORY := "user://shaders"
const FONT_FILE_EXTENSIONS: PackedStringArray = [
	"ttf", "otf", "woff", "woff2", "pfb", "pfm", "fnt", "font"
]
const GifImporter := preload("uid://bml2q6e8rr82h")

var current_session_backup := ""
var had_backups_on_startup := false
var preview_dialog_tscn := preload("res://src/UI/Dialogs/ImportPreviewDialog.tscn")
var preview_dialogs := []  ## Array of preview dialogs
var last_dialog_option := 0
var autosave_timer: Timer

# custom importer related dictionaries (received from extensions)
var custom_import_names := {}  ## Contains importer names as keys and ids as values
var custom_importer_scenes := {}  ## Contains ids keys and import option preloads as values


func _ready() -> void:
	autosave_timer = Timer.new()
	autosave_timer.one_shot = false
	autosave_timer.timeout.connect(_on_Autosave_timeout)
	add_child(autosave_timer)
	update_autosave()
	# Remove empty sessions
	for session_folder in DirAccess.get_directories_at(BACKUPS_DIRECTORY):
		if DirAccess.get_files_at(BACKUPS_DIRECTORY.path_join(session_folder)).size() == 0:
			DirAccess.remove_absolute(BACKUPS_DIRECTORY.path_join(session_folder))
	var backups := DirAccess.get_directories_at(OpenSave.BACKUPS_DIRECTORY)
	had_backups_on_startup = backups.size() > 0
	# Make folder for current session
	var date_time: Dictionary = Time.get_datetime_dict_from_system()
	var string_dict = {}
	for key in date_time.keys():
		var value = int(date_time[key])
		var value_string = str(value)
		if value <= 9:
			value_string = str("0", value_string)
		string_dict[key] = value_string
	current_session_backup = BACKUPS_DIRECTORY.path_join(
		str(
			string_dict.year,
			"_",
			string_dict.month,
			"_",
			string_dict.day,
			"_",
			string_dict.hour,
			"_",
			string_dict.minute,
			"_",
			string_dict.second
		)
	)
	DirAccess.make_dir_recursive_absolute(current_session_backup)
	enforce_backed_sessions_limit()


func handle_loading_file(file: String, force_import_dialog_on_images := false) -> void:
	file = file.replace("\\", "/")
	var file_ext := file.get_extension().to_lower()
	if file_ext == "pxo":  # Pixelorama project file
		open_pxo_file(file)

	elif file_ext == "tres":  # Godot resource file
		var resource := load(file)
		if resource is VisualShader:
			var new_path := SHADERS_DIRECTORY.path_join(file.get_file())
			DirAccess.copy_absolute(file, new_path)
			shader_copied.emit(new_path)
	elif file_ext == "tscn":  # Godot scene file
		return

	elif file_ext == "gpl" or file_ext == "pal" or file_ext == "json":
		Palettes.import_palette_from_path(file, true)

	elif file_ext in ["pck", "zip"]:  # Godot resource pack file
		Global.control.get_node("Extensions").install_extension(file)

	elif file_ext == "gdshader":  # Godot shader file
		var shader := load(file)
		if not shader is Shader:
			return
		var new_path := SHADERS_DIRECTORY.path_join(file.get_file())
		DirAccess.copy_absolute(file, new_path)
		shader_copied.emit(new_path)
	elif file_ext == "mp3" or file_ext == "wav":  # Audio file
		open_audio_file(file)
	elif file_ext in FONT_FILE_EXTENSIONS:
		var font_file := open_font_file(file)
		if font_file.data.is_empty():
			return
		if not DirAccess.dir_exists_absolute(Global.FONTS_DIR_PATH):
			DirAccess.make_dir_absolute(Global.FONTS_DIR_PATH)
		var new_path := Global.FONTS_DIR_PATH.path_join(file.get_file())
		DirAccess.copy_absolute(file, new_path)
		Global.loaded_fonts.append(font_file)
	elif file_ext == "gif":
		if not open_gif_file(file):
			handle_loading_video(file)
	elif file_ext == "ora":
		open_ora_file(file)
	elif file_ext == "kra":
		KritaParser.open_kra_file(file)
	elif file_ext == "ase" or file_ext == "aseprite":
		AsepriteParser.open_aseprite_file(file)
	elif file_ext == "psd":
		PhotoshopParser.open_photoshop_file(file)
	elif file_ext == "piskel":
		open_piskel_file(file)
	else:  # Image files
		# Attempt to load as APNG.
		# Note that the APNG importer will *only* succeed for *animated* PNGs.
		# This is intentional as still images should still act normally.
		var apng_res := AImgIOAPNGImporter.load_from_file(file)
		if apng_res[0] == null:
			# No error - this is an APNG!
			if typeof(apng_res[1]) == TYPE_ARRAY:
				handle_loading_aimg(file, apng_res[1])
			elif typeof(apng_res[1]) == TYPE_STRING:
				print(apng_res[1])
			return
		# Attempt to load as a regular image.
		var image := Image.load_from_file(file)
		if not is_instance_valid(image):  # Failed to import as image
			if handle_loading_video(file):
				return  # Succeeded in loading as video, so return early before the error appears
			var file_name: String = file.get_file()
			Global.popup_error(tr("Can't load file '%s'.") % [file_name])
			return
		handle_loading_image(file, image, force_import_dialog_on_images)


func add_import_option(import_name: StringName, import_scene: PackedScene) -> int:
	# Change format name if another one uses the same name
	var existing_format_names := (
		ImportPreviewDialog.ImageImportOptions.keys() + custom_import_names.keys()
	)
	for i in range(existing_format_names.size()):
		var test_name := import_name
		if i != 0:
			test_name = str(test_name, "_", i)
		if !existing_format_names.has(test_name):
			import_name = test_name
			break

	# Obtain a unique id
	# Start with the least possible id for custom exporter
	var id := ImportPreviewDialog.ImageImportOptions.size()
	for i in custom_import_names.size():
		# Increment ids by 1 till we find one that isn't in use
		var format_id := id + i + 1
		if !custom_import_names.values().has(i):
			id = format_id
	# Add to custom_file_formats
	custom_import_names.merge({import_name: id})
	custom_importer_scenes.merge({id: import_scene})
	return id


## Mostly used for downloading images from the Internet. Tries multiple file extensions
## in case the extension of the file is wrong, which is common for images on the Internet.
func load_image_from_buffer(buffer: PackedByteArray) -> Image:
	var image := Image.new()
	var err := image.load_png_from_buffer(buffer)
	if err != OK:
		err = image.load_jpg_from_buffer(buffer)
		if err != OK:
			err = image.load_webp_from_buffer(buffer)
			if err != OK:
				err = image.load_tga_from_buffer(buffer)
				if err != OK:
					image.load_bmp_from_buffer(buffer)
	return image


func handle_loading_image(file: String, image: Image, force_import_dialog := false) -> void:
	if (
		Global.projects.size() <= 1
		and Global.current_project.is_empty()
		and not force_import_dialog
	):
		open_image_as_new_tab(file, image)
		return
	var preview_dialog := preview_dialog_tscn.instantiate() as ImportPreviewDialog
	# add custom importers to preview dialog
	for import_name in custom_import_names.keys():
		var id = custom_import_names[import_name]
		var new_import_option = custom_importer_scenes[id].instantiate()
		preview_dialog.custom_importers[id] = new_import_option
	preview_dialogs.append(preview_dialog)
	preview_dialog.path = file
	preview_dialog.image = image
	Global.control.add_child(preview_dialog)
	preview_dialog.popup_centered_clamped()
	Global.dialog_open(true)


## For loading the output of AImgIO as a project
func handle_loading_aimg(path: String, frames: Array) -> void:
	var project := Project.new([], path.get_file(), frames[0].content.get_size())
	project.layers.append(PixelLayer.new(project))
	Global.projects.append(project)

	# Determine FPS as 1, unless all frames agree.
	project.fps = 1
	var first_duration: float = frames[0].duration
	var frames_agree := true
	for v in frames:
		var aimg_frame: AImgIOFrame = v
		if aimg_frame.duration != first_duration:
			frames_agree = false
			break
	if frames_agree and (first_duration > 0.0):
		project.fps = 1.0 / first_duration
	# Convert AImgIO frames to Pixelorama frames
	for v in frames:
		var aimg_frame: AImgIOFrame = v
		var frame := Frame.new()
		if not frames_agree:
			frame.set_duration_in_seconds(aimg_frame.duration, project.fps)
		var content := aimg_frame.content
		content.convert(project.get_image_format())
		var image_extended := ImageExtended.new()
		image_extended.copy_from_custom(content)
		frame.cels.append(PixelCel.new(image_extended, 1))
		project.frames.append(frame)

	set_new_imported_tab(project, path)


## Uses FFMPEG to attempt to load a video file as a new project. Works by splitting the video file
## to multiple png images for each of the video's frames,
## and then it imports these images as frames of a new project.
## TODO: Don't allow large files (how large?) to be imported, to avoid crashes due to lack of memory
## TODO: Find the video's fps and use that for the new project.
func handle_loading_video(file: String) -> bool:
	DirAccess.make_dir_absolute(Export.TEMP_PATH)
	var temp_path_real := ProjectSettings.globalize_path(Export.TEMP_PATH)
	var output_file_path := temp_path_real.path_join("%04d.png")
	# ffmpeg -y -i input_file %04d.png
	var ffmpeg_execute: PackedStringArray = ["-y", "-i", file, output_file_path]
	var success := OS.execute(Global.ffmpeg_path, ffmpeg_execute, [], true)
	if success < 0 or success > 1:  # FFMPEG is probably not installed correctly
		DirAccess.remove_absolute(Export.TEMP_PATH)
		return false
	var images_to_import: Array[Image] = []
	var project_size := Vector2i.ZERO
	var temp_dir := DirAccess.open(Export.TEMP_PATH)
	for temp_file in temp_dir.get_files():
		var temp_image := Image.load_from_file(Export.TEMP_PATH.path_join(temp_file))
		temp_dir.remove(temp_file)
		if not is_instance_valid(temp_image):
			continue
		images_to_import.append(temp_image)
		if temp_image.get_width() > project_size.x:
			project_size.x = temp_image.get_width()
		if temp_image.get_height() > project_size.y:
			project_size.y = temp_image.get_height()
	if images_to_import.size() == 0 or project_size == Vector2i.ZERO:
		DirAccess.remove_absolute(Export.TEMP_PATH)
		return false  # We didn't find any images, return
	# If we found images, create a new project out of them
	var new_project := Project.new([], file.get_basename().get_file(), project_size)
	new_project.layers.append(PixelLayer.new(new_project))
	for temp_image in images_to_import:
		open_image_as_new_frame(temp_image, 0, new_project, false)
	Global.projects.append(new_project)
	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()
	var output_audio_file := temp_path_real.path_join("audio.mp3")
	# ffmpeg -y -i input_file -vn audio.mp3
	var ffmpeg_execute_audio: PackedStringArray = ["-y", "-i", file, "-vn", output_audio_file]
	OS.execute(Global.ffmpeg_path, ffmpeg_execute_audio, [], true)
	if FileAccess.file_exists(output_audio_file):
		open_audio_file(output_audio_file)
		temp_dir.remove("audio.mp3")
	DirAccess.remove_absolute(Export.TEMP_PATH)
	return true


func open_pxo_file(path: String, is_backup := false, replace_empty := true) -> void:
	var empty_project := Global.current_project.is_empty() and replace_empty
	var new_project: Project
	var zip_reader := ZIPReader.new()
	var err := zip_reader.open(path)
	if err == FAILED:
		# Most likely uses the old pxo format, load that
		new_project = open_v0_pxo_file(path, empty_project)
		if not is_instance_valid(new_project):
			return
	elif err != OK:
		Global.popup_error(tr("File failed to open. Error code %s (%s)") % [err, error_string(err)])
		return
	else:  # Parse the ZIP file
		if empty_project:
			new_project = Global.current_project
			new_project.frames = []
			new_project.layers = []
			new_project.animation_tags.clear()
			new_project.name = path.get_file().get_basename()
		else:
			new_project = Project.new([], path.get_file().get_basename())
		var data_json := zip_reader.read_file("data.json").get_string_from_utf8()
		var test_json_conv := JSON.new()
		var error := test_json_conv.parse(data_json)
		if error != OK:
			print("Error, corrupt pxo file. Error code %s (%s)" % [error, error_string(error)])
			zip_reader.close()
			return
		var result = test_json_conv.get_data()
		if typeof(result) != TYPE_DICTIONARY:
			print("Error, json parsed result is: %s" % typeof(result))
			zip_reader.close()
			return

		new_project.deserialize(result, zip_reader)
		if result.has("brushes"):
			var brush_index := 0
			for brush in result.brushes:
				var b_width: int = brush.size_x
				var b_height: int = brush.size_y
				var image_data := zip_reader.read_file("image_data/brushes/brush_%s" % brush_index)
				var image := Image.create_from_data(
					b_width, b_height, false, Image.FORMAT_RGBA8, image_data
				)
				new_project.brushes.append(image)
				Brushes.add_project_brush(image)
				brush_index += 1
		if result.has("tile_mask") and result.has("has_mask"):
			if result.has_mask:
				var t_width = result.tile_mask.size_x
				var t_height = result.tile_mask.size_y
				var image_data := zip_reader.read_file("image_data/tile_map")
				var image := Image.create_from_data(
					t_width, t_height, false, Image.FORMAT_RGBA8, image_data
				)
				new_project.tiles.tile_mask = image
			else:
				new_project.tiles.reset_mask()
		if result.has("tilesets"):
			for i in result.tilesets.size():
				var tileset_dict: Dictionary = result.tilesets[i]
				var tileset := new_project.tilesets[i]
				var tile_size := tileset.tile_size
				var tile_amount: int = tileset_dict.tile_amount
				for j in tile_amount:
					var image_data := zip_reader.read_file("tilesets/%s/%s" % [i, j])
					var image := Image.create_from_data(
						tile_size.x, tile_size.y, false, new_project.get_image_format(), image_data
					)
					if j > tileset.tiles.size() - 1:
						tileset.add_tile(image, null, 0)
					else:
						tileset.tiles[j].image = image
			for cel in new_project.get_all_pixel_cels():
				if cel is CelTileMap:
					cel.find_times_used_of_tiles()
		zip_reader.close()
	new_project.export_directory_path = path.get_base_dir()

	if empty_project:
		new_project.change_project()
		Global.project_switched.emit()
		Global.cel_switched.emit()
	else:
		Global.projects.append(new_project)
		Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()

	if is_backup:
		new_project.backup_path = path
	else:
		# Loading a backup should not change window title and save path
		new_project.save_path = path
		get_window().title = new_project.name + " - Pixelorama " + Global.current_version
		# Set last opened project path and save
		Global.config_cache.set_value("data", "current_dir", path.get_base_dir())
		Global.config_cache.set_value("data", "last_project_path", path)
		Global.config_cache.save(Global.CONFIG_PATH)
		new_project.file_name = path.get_file().trim_suffix(".pxo")
		new_project.was_exported = false
		Global.top_menu_container.file_menu.set_item_text(
			Global.FileMenu.SAVE, tr("Save") + " %s" % path.get_file()
		)
		Global.top_menu_container.file_menu.set_item_text(Global.FileMenu.EXPORT, tr("Export"))

	save_project_to_recent_list(path)


func open_v0_pxo_file(path: String, empty_project: bool) -> Project:
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if FileAccess.get_open_error() == ERR_FILE_UNRECOGNIZED:
		# If the file is not compressed open it raw (pre-v0.7)
		file = FileAccess.open(path, FileAccess.READ)
	var err := FileAccess.get_open_error()
	if err != OK:
		Global.popup_error(tr("File failed to open. Error code %s (%s)") % [err, error_string(err)])
		return null

	var first_line := file.get_line()
	var test_json_conv := JSON.new()
	var error := test_json_conv.parse(first_line)
	if error != OK:
		print("Error, corrupt legacy pxo file. Error code %s (%s)" % [error, error_string(error)])
		file.close()
		return null

	var result = test_json_conv.get_data()
	if typeof(result) != TYPE_DICTIONARY:
		print("Error, json parsed result is: %s" % typeof(result))
		file.close()
		return null

	var new_project: Project
	if empty_project:
		new_project = Global.current_project
		new_project.frames = []
		new_project.layers = []
		new_project.animation_tags.clear()
		new_project.name = path.get_file().get_basename()
	else:
		new_project = Project.new([], path.get_file().get_basename())
	new_project.deserialize(result, null, file)
	if result.has("brushes"):
		for brush in result.brushes:
			var b_width = brush.size_x
			var b_height = brush.size_y
			var buffer := file.get_buffer(b_width * b_height * 4)
			var image := Image.create_from_data(
				b_width, b_height, false, Image.FORMAT_RGBA8, buffer
			)
			new_project.brushes.append(image)
			Brushes.add_project_brush(image)

	if result.has("tile_mask") and result.has("has_mask"):
		if result.has_mask:
			var t_width = result.tile_mask.size_x
			var t_height = result.tile_mask.size_y
			var buffer := file.get_buffer(t_width * t_height * 4)
			var image := Image.create_from_data(
				t_width, t_height, false, Image.FORMAT_RGBA8, buffer
			)
			new_project.tiles.tile_mask = image
		else:
			new_project.tiles.reset_mask()
	file.close()
	return new_project


func save_pxo_file(
	path: String, autosave: bool, include_blended := false, project := Global.current_project
) -> bool:
	if not autosave:
		project.name = path.get_file().trim_suffix(".pxo")
	var serialized_data := project.serialize()
	if not serialized_data:
		Global.popup_error(tr("File failed to save. Converting project data to dictionary failed."))
		return false
	var to_save := JSON.stringify(serialized_data)
	if not to_save:
		Global.popup_error(tr("File failed to save. Converting dictionary to JSON failed."))
		return false

	# Check if a file with the same name exists. If it does, rename the new file temporarily.
	# Needed in case of a crash, so that the old file won't be replaced with an empty one.
	var temp_path := path
	if FileAccess.file_exists(path):
		temp_path = path + "1"

	var zip_packer := ZIPPacker.new()
	var err := zip_packer.open(temp_path)
	if err != OK:
		Global.popup_error(tr("File failed to save. Error code %s (%s)") % [err, error_string(err)])
		if temp_path.is_valid_filename():
			return false
		if zip_packer:  # this would be null if we attempt to save filenames such as "//\\||.pxo"
			zip_packer.close()
		return false
	zip_packer.start_file("data.json")
	zip_packer.write_file(to_save.to_utf8_buffer())
	zip_packer.close_file()

	zip_packer.start_file("mimetype")
	zip_packer.write_file("image/pxo".to_utf8_buffer())
	zip_packer.close_file()

	var current_frame := project.frames[project.current_frame]
	# Generate a preview image of the current frame.
	# File managers can later use this as a thumbnail for pxo files.
	var preview := project.new_empty_image()
	DrawingAlgos.blend_layers(preview, current_frame, Vector2i.ZERO, project)
	var new_width := preview.get_width()
	var new_height := preview.get_height()
	var aspect_ratio := float(new_width) / float(new_height)
	if new_width > new_height:
		new_width = 256
		new_height = new_width / aspect_ratio
	else:
		new_height = 256
		new_width = new_height * aspect_ratio
	var scaled_preview := Image.new()
	scaled_preview.copy_from(preview)
	scaled_preview.resize(new_width, new_height, Image.INTERPOLATE_NEAREST)
	zip_packer.start_file("preview.png")
	zip_packer.write_file(scaled_preview.save_png_to_buffer())
	zip_packer.close_file()

	if not autosave:
		project.save_path = path

	var frame_index := 1
	for frame in project.frames:
		if not autosave and include_blended:
			var blended := project.new_empty_image()
			if frame == current_frame:
				blended = preview
			else:
				DrawingAlgos.blend_layers(blended, frame, Vector2i.ZERO, project)
			zip_packer.start_file("image_data/final_images/%s" % frame_index)
			zip_packer.write_file(blended.get_data())
			zip_packer.close_file()
		var cel_index := 1
		for cel in frame.cels:
			var cel_image := cel.get_image() as ImageExtended
			if is_instance_valid(cel_image) and cel is PixelCel:
				zip_packer.start_file("image_data/frames/%s/layer_%s" % [frame_index, cel_index])
				zip_packer.write_file(cel_image.get_data())
				zip_packer.close_file()
				zip_packer.start_file(
					"image_data/frames/%s/indices_layer_%s" % [frame_index, cel_index]
				)
				zip_packer.write_file(cel_image.indices_image.get_data())
				zip_packer.close_file()
			cel_index += 1
		frame_index += 1
	var brush_index := 0
	for brush in project.brushes:
		zip_packer.start_file("image_data/brushes/brush_%s" % brush_index)
		zip_packer.write_file(brush.get_data())
		zip_packer.close_file()
		brush_index += 1
	if project.tiles.has_mask:
		zip_packer.start_file("image_data/tile_map")
		zip_packer.write_file(project.tiles.tile_mask.get_data())
		zip_packer.close_file()
	for i in project.tilesets.size():
		var tileset := project.tilesets[i]
		var tileset_path := "tilesets/%s" % i
		for j in tileset.tiles.size():
			var tile := tileset.tiles[j]
			zip_packer.start_file(tileset_path.path_join(str(j)))
			zip_packer.write_file(tile.image.get_data())
			zip_packer.close_file()
	var audio_layers := project.get_all_audio_layers()
	for i in audio_layers.size():
		var layer := audio_layers[i]
		var audio_path := "audio/%s" % i
		if layer.audio is AudioStreamMP3:
			zip_packer.start_file(audio_path)
			zip_packer.write_file(layer.audio.data)
			zip_packer.close_file()
		elif layer.audio is AudioStreamWAV:
			var tmp_wav := FileAccess.create_temp(FileAccess.READ, "tmp", "wav")
			layer.audio.save_to_wav(tmp_wav.get_path())
			zip_packer.start_file(audio_path)
			zip_packer.write_file(tmp_wav.get_buffer(tmp_wav.get_length()))
			zip_packer.close_file()
	zip_packer.close()

	if temp_path != path:
		# Rename the new file to its proper name and remove the old file, if it exists.
		DirAccess.rename_absolute(temp_path, path)

	if OS.has_feature("web") and not autosave:
		var file := FileAccess.open(path, FileAccess.READ)
		if FileAccess.get_open_error() == OK:
			var file_data := file.get_buffer(file.get_length())
			JavaScriptBridge.download_buffer(file_data, path.get_file())
		file.close()
		# Remove the .pxo file from memory, as we don't need it anymore
		DirAccess.remove_absolute(path)

	if autosave:
		Global.notification_label("Backup saved")
	else:
		# First remove backup then set current save path
		if project.has_changed:
			project.has_changed = false
		Global.notification_label("File saved")
		get_window().title = project.name + " - Pixelorama " + Global.current_version

		# Set last opened project path and save
		Global.config_cache.set_value("data", "current_dir", path.get_base_dir())
		Global.config_cache.set_value("data", "last_project_path", path)
		Global.config_cache.save(Global.CONFIG_PATH)
		if !project.was_exported:
			project.file_name = path.get_file().trim_suffix(".pxo")
			project.export_directory_path = path.get_base_dir()
		Global.top_menu_container.file_menu.set_item_text(
			Global.FileMenu.SAVE, tr("Save") + " %s" % path.get_file()
		)
		project_saved.emit()
		SteamManager.set_achievement("ACH_SAVE")
		save_project_to_recent_list(path)
	return true


func open_image_as_new_tab(path: String, image: Image) -> void:
	var project := Project.new([], path.get_file(), image.get_size())
	var layer := PixelLayer.new(project)
	project.layers.append(layer)
	Global.projects.append(project)

	var frame := Frame.new()
	image.convert(project.get_image_format())
	frame.cels.append(layer.new_cel_from_image(image))

	project.frames.append(frame)
	set_new_imported_tab(project, path)


func open_image_as_spritesheet_tab_smart(
	path: String, image: Image, sliced_rects: Array[Rect2i], frame_size: Vector2i
) -> void:
	if sliced_rects.size() == 0:  # Image is empty sprite (manually set data to be consistent)
		frame_size = image.get_size()
		sliced_rects.append(Rect2i(Vector2i.ZERO, frame_size))
	var project := Project.new([], path.get_file(), frame_size)
	var layer := PixelLayer.new(project)
	project.layers.append(layer)
	Global.projects.append(project)
	for rect in sliced_rects:
		var offset: Vector2 = (0.5 * (frame_size - rect.size)).floor()
		var frame := Frame.new()
		var cropped_image := Image.create(
			frame_size.x, frame_size.y, false, project.get_image_format()
		)
		image.convert(project.get_image_format())
		cropped_image.blit_rect(image, rect, offset)
		frame.cels.append(layer.new_cel_from_image(cropped_image))
		project.frames.append(frame)
	set_new_imported_tab(project, path)


func open_image_as_spritesheet_tab(
	path: String, image: Image, horiz: int, vert: int, detect_empty := true
) -> void:
	horiz = mini(horiz, image.get_size().x)
	vert = mini(vert, image.get_size().y)
	var frame_width := image.get_size().x / horiz
	var frame_height := image.get_size().y / vert
	var project := Project.new([], path.get_file(), Vector2(frame_width, frame_height))
	var layer := PixelLayer.new(project)
	project.layers.append(layer)
	Global.projects.append(project)
	for yy in range(vert):
		for xx in range(horiz):
			var cropped_image := image.get_region(
				Rect2i(frame_width * xx, frame_height * yy, frame_width, frame_height)
			)
			if not detect_empty:
				if cropped_image.get_used_rect().size == Vector2i.ZERO:
					continue  # We don't need this Frame
			var frame := Frame.new()
			project.size = cropped_image.get_size()
			cropped_image.convert(project.get_image_format())
			frame.cels.append(layer.new_cel_from_image(cropped_image))
			project.frames.append(frame)
	set_new_imported_tab(project, path)


func open_image_as_spritesheet_layer_smart(
	_path: String,
	image: Image,
	file_name: String,
	sliced_rects: Array[Rect2i],
	start_frame: int,
	frame_size: Vector2i
) -> void:
	# Resize canvas to if "frame_size.x" or "frame_size.y" is too large
	var project := Global.current_project
	var project_width := maxi(frame_size.x, project.size.x)
	var project_height := maxi(frame_size.y, project.size.y)
	if project.size < Vector2i(project_width, project_height):
		DrawingAlgos.resize_canvas(project_width, project_height, 0, 0)

	# Initialize undo mechanism
	project.undo_redo.create_action("Add Spritesheet Layer")

	var max_frames_size := maxi(project.frames.size(), start_frame + sliced_rects.size())
	var new_frames := []
	var frame_indices := PackedInt32Array([])
	# Create new layer for spritesheet
	var layer := PixelLayer.new(project, file_name)
	var cels: Array[PixelCel] = []
	for f in max_frames_size:
		if f >= start_frame and f < (start_frame + sliced_rects.size()):
			# Slice spritesheet
			var offset: Vector2 = (0.5 * (frame_size - sliced_rects[f - start_frame].size)).floor()
			image.convert(project.get_image_format())
			var cropped_image := Image.create(
				project_width, project_height, false, project.get_image_format()
			)
			cropped_image.blit_rect(image, sliced_rects[f - start_frame], offset)
			cels.append(layer.new_cel_from_image(cropped_image))
		else:
			cels.append(layer.new_empty_cel())
		# If amount of cels exceede our project frames, then add new frame
		if cels.size() > project.frames.size():
			var new_frame := Frame.new()
			for l in range(project.layers.size()):  # Create as many cels as there are layers
				new_frame.cels.append(project.layers[l].new_empty_cel())
				if project.layers[l].new_cels_linked:
					var prev_cel := project.frames[project.current_frame].cels[l]
					if prev_cel.link_set == null:
						prev_cel.link_set = {}
						project.undo_redo.add_do_method(
							project.layers[l].link_cel.bind(prev_cel, prev_cel.link_set)
						)
						project.undo_redo.add_undo_method(
							project.layers[l].link_cel.bind(prev_cel, null)
						)
					new_frame.cels[l].set_content(prev_cel.get_content(), prev_cel.image_texture)
					new_frame.cels[l].link_set = prev_cel.link_set
			new_frames.append(new_frame)

	if not new_frames.is_empty():  # if new frames got added
		frame_indices = range(
			project.frames.size(), project.frames.size() + new_frames.size()
		)
		project.undo_redo.add_do_method(project.add_frames.bind(new_frames, frame_indices))
		project.undo_redo.add_undo_method(project.remove_frames.bind(frame_indices))
	project.undo_redo.add_do_method(
		project.add_layers.bind([layer], [project.layers.size()], [cels])
	)
	project.undo_redo.add_do_method(
		project.change_cel.bind(cels.size() - 1, project.layers.size())
	)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))

	project.undo_redo.add_undo_method(project.remove_layers.bind([project.layers.size()]))
	project.undo_redo.add_undo_method(
		project.change_cel.bind(project.current_frame, project.current_layer)
	)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()


func open_image_as_spritesheet_layer(
	_path: String,
	image: Image,
	file_name: String,
	horizontal: int,
	vertical: int,
	start_frame: int,
	detect_empty := true
) -> void:
	# Data needed to slice images
	horizontal = mini(horizontal, image.get_size().x)
	vertical = mini(vertical, image.get_size().y)
	var frame_width := image.get_size().x / horizontal
	var frame_height := image.get_size().y / vertical

	# Resize canvas to if "frame_width" or "frame_height" is too large
	var project := Global.current_project
	var project_width := maxi(frame_width, project.size.x)
	var project_height := maxi(frame_height, project.size.y)
	if project.size < Vector2i(project_width, project_height):
		DrawingAlgos.resize_canvas(project_width, project_height, 0, 0)

	# Initialize undo mechanism
	project.undo_redo.create_action("Add Spritesheet Layer")
	var max_frames_size := maxi(project.frames.size(), start_frame + (vertical * horizontal))
	var new_frames := []
	var frame_indices := PackedInt32Array([])
	# Create new layer for spritesheet
	var layer := PixelLayer.new(project, file_name)
	var cels := []
	var tile_count := vertical * horizontal
	for f in max_frames_size:
		if f >= start_frame and f < start_frame + tile_count:  # Entered region of spritesheet
			# Slice spritesheet
			var tile_idx := f - start_frame
			var xx := tile_idx % horizontal
			var yy := tile_idx / horizontal
			image.convert(project.get_image_format())
			var cropped_image := Image.create(
				project_width, project_height, false, project.get_image_format()
			)
			cropped_image.blit_rect(
				image,
				Rect2i(frame_width * xx, frame_height * yy, frame_width, frame_height),
				Vector2i.ZERO
			)
			if not detect_empty:
				if cropped_image.get_used_rect().size == Vector2i.ZERO:
					continue  # We don't need this cel
			cels.append(layer.new_cel_from_image(cropped_image))
		else:
			cels.append(layer.new_empty_cel())
		# If amount of cels exceede our project frames, then add new frame
		if cels.size() > project.frames.size():
			var new_frame := Frame.new()
			for l in range(project.layers.size()):  # Create as many cels as there are layers
				new_frame.cels.append(project.layers[l].new_empty_cel())
				if project.layers[l].new_cels_linked:
					var prev_cel := project.frames[project.current_frame].cels[l]
					if prev_cel.link_set == null:
						prev_cel.link_set = {}
						project.undo_redo.add_do_method(
							project.layers[l].link_cel.bind(prev_cel, prev_cel.link_set)
						)
						project.undo_redo.add_undo_method(
							project.layers[l].link_cel.bind(prev_cel, null)
						)
					new_frame.cels[l].set_content(prev_cel.get_content(), prev_cel.image_texture)
					new_frame.cels[l].link_set = prev_cel.link_set
			new_frames.append(new_frame)

	if not new_frames.is_empty():  # if new frames got added
		frame_indices = range(
			project.frames.size(), project.frames.size() + new_frames.size()
		)
		project.undo_redo.add_do_method(project.add_frames.bind(new_frames, frame_indices))
		project.undo_redo.add_undo_method(project.remove_frames.bind(frame_indices))
	project.undo_redo.add_do_method(
		project.add_layers.bind([layer], [project.layers.size()], [cels])
	)
	project.undo_redo.add_do_method(
		project.change_cel.bind(cels.size() - 1, project.layers.size())
	)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))

	project.undo_redo.add_undo_method(project.remove_layers.bind([project.layers.size()]))
	project.undo_redo.add_undo_method(
		project.change_cel.bind(project.current_frame, project.current_layer)
	)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()


func open_image_at_cel(image: Image, layer_index := 0, frame_index := 0) -> void:
	var project := Global.current_project
	var project_width := maxi(image.get_width(), project.size.x)
	var project_height := maxi(image.get_height(), project.size.y)
	if project.size < Vector2i(project_width, project_height):
		DrawingAlgos.resize_canvas(project_width, project_height, 0, 0)
	project.undo_redo.create_action("Replaced Cel")

	var cel := project.frames[frame_index].cels[layer_index]
	if not cel is PixelCel:
		return
	image.convert(project.get_image_format())
	var cel_image := (cel as PixelCel).get_image()
	var undo_data := {}
	if cel is CelTileMap:
		undo_data[cel] = (cel as CelTileMap).serialize_undo_data()
	cel_image.add_data_to_dictionary(undo_data)
	cel_image.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	cel_image.convert_rgb_to_indexed()
	var redo_data := {}
	if cel is CelTileMap:
		(cel as CelTileMap).update_tilemap()
		redo_data[cel] = (cel as CelTileMap).serialize_undo_data()
	cel_image.add_data_to_dictionary(redo_data)
	project.deserialize_cel_undo_data(redo_data, undo_data)
	project.undo_redo.add_do_property(project, "selected_cels", [])
	project.undo_redo.add_do_method(project.change_cel.bind(frame_index, layer_index))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))

	project.undo_redo.add_undo_property(project, "selected_cels", [])
	project.undo_redo.add_undo_method(
		project.change_cel.bind(project.current_frame, project.current_layer)
	)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()


func open_image_as_new_frame(
	image: Image, layer_index := 0, project := Global.current_project, undo := true
) -> void:
	var project_width := maxi(image.get_width(), project.size.x)
	var project_height := maxi(image.get_height(), project.size.y)
	if project.size < Vector2i(project_width, project_height):
		DrawingAlgos.resize_canvas(project_width, project_height, 0, 0)

	var frame := Frame.new()
	for i in project.layers.size():
		var layer := project.layers[i]
		if i == layer_index and layer is PixelLayer:
			image.convert(project.get_image_format())
			var cel_image := Image.create(
				project_width, project_height, false, project.get_image_format()
			)
			cel_image.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
			frame.cels.append(layer.new_cel_from_image(cel_image))
		else:
			frame.cels.append(project.layers[i].new_empty_cel())
	if not undo:
		project.frames.append(frame)
		return
	project.undo_redo.create_action("Add Frame")
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_do_method(project.add_frames.bind([frame], [project.frames.size()]))
	project.undo_redo.add_do_method(project.change_cel.bind(project.frames.size(), layer_index))

	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_undo_method(project.remove_frames.bind([project.frames.size()]))
	project.undo_redo.add_undo_method(
		project.change_cel.bind(project.current_frame, project.current_layer)
	)
	project.undo_redo.commit_action()


func open_image_as_new_layer(image: Image, file_name: String, frame_index := 0) -> void:
	var project := Global.current_project
	var project_width := maxi(image.get_width(), project.size.x)
	var project_height := maxi(image.get_height(), project.size.y)
	if project.size < Vector2i(project_width, project_height):
		DrawingAlgos.resize_canvas(project_width, project_height, 0, 0)
	var layer := PixelLayer.new(project, file_name)
	var cels := []

	Global.current_project.undo_redo.create_action("Add Layer")
	for i in project.frames.size():
		if i == frame_index:
			image.convert(project.get_image_format())
			var cel_image := Image.create(
				project_width, project_height, false, project.get_image_format()
			)
			cel_image.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
			cels.append(layer.new_cel_from_image(cel_image))
		else:
			cels.append(layer.new_empty_cel())

	project.undo_redo.add_do_method(
		project.add_layers.bind([layer], [project.layers.size()], [cels])
	)
	project.undo_redo.add_do_method(project.change_cel.bind(frame_index, project.layers.size()))

	project.undo_redo.add_undo_method(project.remove_layers.bind([project.layers.size()]))
	project.undo_redo.add_undo_method(
		project.change_cel.bind(project.current_frame, project.current_layer)
	)

	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.commit_action()


func import_reference_image_from_path(path: String) -> void:
	var project := Global.current_project
	var ri := ReferenceImage.new()
	ri.project = project
	ri.deserialize({"image_path": path})
	Global.canvas.reference_image_container.add_child(ri)
	reference_image_imported.emit()


## Useful for Web
func import_reference_image_from_image(image: Image) -> void:
	var project := Global.current_project
	var ri := ReferenceImage.new()
	ri.project = project
	ri.create_from_image(image)
	Global.canvas.reference_image_container.add_child(ri)
	reference_image_imported.emit()


func open_image_as_tileset(
	path: String,
	image: Image,
	horiz: int,
	vert: int,
	tile_shape: TileSet.TileShape,
	tile_offset_axis: TileSet.TileOffsetAxis,
	project := Global.current_project,
	detect_empty := true
) -> void:
	image.convert(project.get_image_format())
	horiz = mini(horiz, image.get_size().x)
	vert = mini(vert, image.get_size().y)
	var frame_width := image.get_size().x / horiz
	var frame_height := image.get_size().y / vert
	var tile_size := Vector2i(frame_width, frame_height)
	var tileset := TileSetCustom.new(tile_size, path.get_basename().get_file(), tile_shape)
	tileset.tile_offset_axis = tile_offset_axis
	for yy in range(vert):
		for xx in range(horiz):
			var cropped_image := image.get_region(
				Rect2i(frame_width * xx, frame_height * yy, frame_width, frame_height)
			)
			if not detect_empty:
				if cropped_image.get_used_rect().size == Vector2i.ZERO:
					continue  # We don't need this Frame
			@warning_ignore("int_as_enum_without_cast")
			tileset.add_tile(cropped_image, null, 0)
	project.tilesets.append(tileset)


func open_image_as_tileset_smart(
	path: String,
	image: Image,
	sliced_rects: Array[Rect2i],
	tile_size: Vector2i,
	tile_shape: TileSet.TileShape,
	tile_offset_axis: TileSet.TileOffsetAxis,
	project := Global.current_project
) -> void:
	image.convert(project.get_image_format())
	if sliced_rects.size() == 0:  # Image is empty sprite (manually set data to be consistent)
		tile_size = image.get_size()
		sliced_rects.append(Rect2i(Vector2i.ZERO, tile_size))
	var tileset := TileSetCustom.new(tile_size, path.get_basename().get_file(), tile_shape)
	tileset.tile_offset_axis = tile_offset_axis
	for rect in sliced_rects:
		var offset: Vector2 = (0.5 * (tile_size - rect.size)).floor()
		var cropped_image := Image.create(
			tile_size.x, tile_size.y, false, project.get_image_format()
		)
		cropped_image.blit_rect(image, rect, offset)
		@warning_ignore("int_as_enum_without_cast")
		tileset.add_tile(cropped_image, null, 0)
	project.tilesets.append(tileset)


func set_new_imported_tab(project: Project, path: String) -> void:
	var prev_project_empty := Global.current_project.is_empty()
	var prev_project_pos := Global.current_project_index

	get_window().title = (
		path.get_file() + " (" + tr("imported") + ") - Pixelorama " + Global.current_version
	)
	if project.has_changed:
		get_window().title = get_window().title + "(*)"
	var file_name := path.get_basename().get_file()
	project.export_directory_path = path.get_base_dir()
	project.file_name = file_name
	project.was_exported = true
	if path.get_extension().to_lower() == "png":
		project.export_overwrite = true

	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()

	if prev_project_empty:
		Global.tabs.delete_tab(prev_project_pos)


func open_audio_file(path: String) -> void:
	var audio_stream: AudioStream
	var file := FileAccess.open(path, FileAccess.READ)
	if path.get_extension().to_lower() == "mp3":
		audio_stream = AudioStreamMP3.new()
		audio_stream.data = file.get_buffer(file.get_length())
	elif path.get_extension().to_lower() == "wav":
		audio_stream = AudioStreamWAV.load_from_buffer(file.get_buffer(file.get_length()))
	if not is_instance_valid(audio_stream):
		return
	var project := Global.current_project
	for layer in project.layers:
		if layer is AudioLayer and not is_instance_valid(layer.audio):
			layer.audio = audio_stream
			return
	var new_layer := AudioLayer.new(project, path.get_basename().get_file())
	new_layer.audio = audio_stream
	Global.animation_timeline.add_layer(new_layer, project)


func open_font_file(path: String) -> FontFile:
	var font_file := FontFile.new()
	if path.to_lower().get_extension() == "fnt" or path.to_lower().get_extension() == "font":
		font_file.load_bitmap_font(path)
	else:
		font_file.load_dynamic_font(path)
	return font_file


func open_gif_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	var importer := GifImporter.new(file)
	var result = importer.import()
	file.close()
	if result != GifImporter.Error.OK:
		printerr("An error has occurred while importing: %d" % [result])
		return false
	var imported_frames := importer.frames
	if imported_frames.size() == 0:
		printerr("An error has occurred while importing the gif")
		return false
	var new_project := Project.new([], path.get_file().get_basename())
	var size := Vector2i(importer.get_logical_screen_width(), importer.get_logical_screen_height())
	new_project.size = size
	new_project.fps = 1.0
	var layer := PixelLayer.new(new_project)
	new_project.layers.append(layer)
	for gif_frame in imported_frames:
		var frame_image := gif_frame.image
		frame_image.crop(new_project.size.x, new_project.size.y)
		var cel := layer.new_cel_from_image(frame_image)
		var delay := gif_frame.delay
		if delay <= 0.0:
			delay = 0.1
		var frame := Frame.new([cel], delay)
		new_project.frames.append(frame)
	new_project.save_path = path.get_basename() + ".pxo"
	new_project.file_name = new_project.name
	Global.projects.append(new_project)
	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()
	return true


# Based on https://www.openraster.org/
func open_ora_file(path: String) -> void:
	var zip_reader := ZIPReader.new()
	var err := zip_reader.open(path)
	if err != OK:
		print("Error opening ora file: ", error_string(err))
		return
	var data_xml := zip_reader.read_file("stack.xml")
	var parser := XMLParser.new()
	err = parser.open_buffer(data_xml)
	if err != OK:
		print("Error parsing XML from ora file: ", error_string(err))
		zip_reader.close()
		return
	var new_project := Project.new([Frame.new()], path.get_file().get_basename())
	var selected_layer: BaseLayer
	var stacks_found := 0
	var current_stack: Array[GroupLayer] = []
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name := parser.get_node_name()
			if node_name == "image":
				var width := parser.get_named_attribute_value_safe("w")
				if not width.is_empty():
					new_project.size.x = str_to_var(width)
				var height := parser.get_named_attribute_value_safe("h")
				if not height.is_empty():
					new_project.size.y = str_to_var(height)
			elif node_name == "layer" or node_name == "stack":
				for prev_layer in new_project.layers:
					prev_layer.index += 1
				var layer_name := parser.get_named_attribute_value_safe("name")
				var layer: BaseLayer
				if node_name == "stack":
					stacks_found += 1
					if stacks_found == 1:
						continue
					layer = GroupLayer.new(new_project, layer_name)
					if current_stack.size() > 0:
						layer.parent = current_stack[-1]
					current_stack.append(layer)
				else:
					layer = PixelLayer.new(new_project, layer_name)
					if current_stack.size() > 0:
						layer.parent = current_stack[-1]
				new_project.layers.insert(0, layer)
				if new_project.layers.size() == 1:
					selected_layer = layer
				layer.index = 0
				layer.opacity = float(parser.get_named_attribute_value_safe("opacity"))
				if parser.get_named_attribute_value_safe("selected") == "true":
					selected_layer = layer
				layer.visible = parser.get_named_attribute_value_safe("visibility") != "hidden"
				layer.locked = parser.get_named_attribute_value_safe("edit-locked") == "true"
				var blend_mode := parser.get_named_attribute_value_safe("composite-op")
				match blend_mode:
					"svg:multiply":
						layer.blend_mode = BaseLayer.BlendModes.MULTIPLY
					"svg:screen":
						layer.blend_mode = BaseLayer.BlendModes.SCREEN
					"svg:overlay":
						layer.blend_mode = BaseLayer.BlendModes.OVERLAY
					"svg:darken":
						layer.blend_mode = BaseLayer.BlendModes.DARKEN
					"svg:lighten":
						layer.blend_mode = BaseLayer.BlendModes.LIGHTEN
					"svg:color-dodge":
						layer.blend_mode = BaseLayer.BlendModes.COLOR_DODGE
					"svg:hard-light":
						layer.blend_mode = BaseLayer.BlendModes.HARD_LIGHT
					"svg:soft-light":
						layer.blend_mode = BaseLayer.BlendModes.SOFT_LIGHT
					"svg:difference":
						layer.blend_mode = BaseLayer.BlendModes.DIFFERENCE
					"svg:color":
						layer.blend_mode = BaseLayer.BlendModes.COLOR
					"svg:luminosity":
						layer.blend_mode = BaseLayer.BlendModes.LUMINOSITY
					"svg:hue":
						layer.blend_mode = BaseLayer.BlendModes.HUE
					"svg:saturation":
						layer.blend_mode = BaseLayer.BlendModes.SATURATION
					"svg:dst-out":
						layer.blend_mode = BaseLayer.BlendModes.ERASE
					_:
						if "divide" in blend_mode:  # For example, krita:divide
							layer.blend_mode = BaseLayer.BlendModes.DIVIDE
				# Create cel
				var cel := layer.new_empty_cel()
				if cel is PixelCel:
					var image_path := parser.get_named_attribute_value_safe("src")
					var image_data := zip_reader.read_file(image_path)
					var image := Image.new()
					image.load_png_from_buffer(image_data)
					var image_rect := Rect2i(Vector2i.ZERO, image.get_size())
					var image_x := int(parser.get_named_attribute_value("x"))
					var image_y := int(parser.get_named_attribute_value("y"))
					cel.get_image().blit_rect(image, image_rect, Vector2i(image_x, image_y))
				new_project.frames[0].cels.insert(0, cel)
		elif parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			var node_name := parser.get_node_name()
			if node_name == "stack":
				current_stack.pop_back()
	zip_reader.close()
	new_project.order_layers()
	new_project.selected_cels.clear()
	new_project.change_cel(0, new_project.layers.find(selected_layer))
	new_project.save_path = path.get_basename() + ".pxo"
	new_project.file_name = new_project.name
	Global.projects.append(new_project)
	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()


func open_piskel_file(path: String) -> void:
	var file_json = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(file_json) != TYPE_DICTIONARY:
		return
	var piskel: Dictionary = file_json.piskel
	var project_name: String = piskel.get("name", path.get_file().get_basename())
	var new_project := Project.new([], project_name)
	new_project.size = Vector2i(piskel.width, piskel.height)
	new_project.fps = piskel.fps
	new_project.save_path = path.get_basename() + ".pxo"
	new_project.file_name = new_project.name
	var n_of_frames := 0
	for i in piskel.layers.size():
		var piskel_layer_str = piskel.layers[i]
		var piskel_layer: Dictionary = JSON.parse_string(piskel_layer_str)
		var layer := PixelLayer.new(new_project, piskel_layer.name)
		layer.opacity = piskel_layer.opacity
		layer.index = i
		if piskel_layer.frameCount > n_of_frames:
			for j in range(n_of_frames, piskel_layer.frameCount):
				var frame := Frame.new()
				new_project.frames.append(frame)
			n_of_frames = piskel_layer.frameCount
		var layer_image: Image = null
		for chunk in piskel_layer.chunks:
			var chunk_image := Image.new()
			var base64_str: String = chunk.base64PNG.trim_prefix("data:image/png;base64,")
			chunk_image.load_png_from_buffer(Marshalls.base64_to_raw(base64_str))
			if not is_instance_valid(layer_image):
				layer_image = chunk_image
			else:
				var src_rect := Rect2i(Vector2i.ZERO, chunk_image.get_size())
				layer_image.blend_rect(chunk_image, src_rect, Vector2i.ZERO)
		for j in new_project.frames.size():
			var region := Rect2i(Vector2i(j * new_project.size.x, 0), new_project.size)
			var cel_image := layer_image.get_region(region)
			var cel := layer.new_cel_from_image(cel_image)
			new_project.frames[j].cels.append(cel)
		new_project.layers.append(layer)
	new_project.order_layers()
	Global.projects.append(new_project)
	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()


func enforce_backed_sessions_limit() -> void:
	# Enforce session limit
	var old_folders = DirAccess.get_directories_at(BACKUPS_DIRECTORY)
	if old_folders.size() > Global.max_backed_sessions:
		var excess = old_folders.size() - Global.max_backed_sessions
		for i in excess:
			# Remove oldest folder. The array is sorted alphabetically so the oldest folder
			# is the first in array
			var oldest = BACKUPS_DIRECTORY.path_join(old_folders[0])
			for file in DirAccess.get_files_at(oldest):
				DirAccess.remove_absolute(oldest.path_join(file))
			DirAccess.remove_absolute(oldest)
			old_folders.remove_at(0)


func update_autosave() -> void:
	if not is_instance_valid(autosave_timer):
		return
	autosave_timer.stop()
	# Interval parameter is in minutes, wait_time is seconds
	autosave_timer.wait_time = Global.autosave_interval * 60
	if Global.enable_autosave:
		autosave_timer.start()


func _on_Autosave_timeout() -> void:
	for i in Global.projects.size():
		var project := Global.projects[i]
		var p_name: String = project.file_name
		if project.backup_path.is_empty():
			project.backup_path = (current_session_backup.path_join(
				"(" + p_name + " backup)-" + str(Time.get_unix_time_from_system()) + "-%s" % i
			))
		if not DirAccess.dir_exists_absolute(current_session_backup):
			DirAccess.make_dir_recursive_absolute(current_session_backup)
		save_pxo_file(project.backup_path, true, false, project)


func save_project_to_recent_list(path: String) -> void:
	var top_menu_container := Global.top_menu_container
	if path.get_file().substr(0, 7) == "backup-" or path == "":
		return

	if top_menu_container.recent_projects.has(path):
		top_menu_container.recent_projects.erase(path)

	if top_menu_container.recent_projects.size() >= 5:
		top_menu_container.recent_projects.pop_front()
	top_menu_container.recent_projects.push_back(path)

	Global.config_cache.set_value("data", "recent_projects", top_menu_container.recent_projects)

	top_menu_container.recent_projects_submenu.clear()
	top_menu_container.update_recent_projects_submenu()
