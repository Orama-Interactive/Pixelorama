# gdlint: ignore=max-public-methods
extends Node

var current_save_paths: PackedStringArray = []
## Stores a filename of a backup file in user:// until user saves manually
var backup_save_paths: PackedStringArray = []
var preview_dialog_tscn := preload("res://src/UI/Dialogs/PreviewDialog.tscn")
var preview_dialogs := []  ## Array of preview dialogs
var last_dialog_option := 0
var autosave_timer: Timer


func _ready() -> void:
	autosave_timer = Timer.new()
	autosave_timer.one_shot = false
	autosave_timer.timeout.connect(_on_Autosave_timeout)
	add_child(autosave_timer)
	update_autosave()


func handle_loading_file(file: String) -> void:
	file = file.replace("\\", "/")
	var file_ext := file.get_extension().to_lower()
	if file_ext == "pxo":  # Pixelorama project file
		open_pxo_file(file)

	elif file_ext == "tres":  # Godot resource file
		var resource := load(file)
		if resource is Palette:
			Palettes.import_palette(resource, file.get_file())
		else:
			var file_name: String = file.get_file()
			Global.error_dialog.set_text(tr("Can't load file '%s'.") % [file_name])
			Global.error_dialog.popup_centered()
			Global.dialog_open(true)
	elif file_ext == "tscn":  # Godot scene file
		return

	elif file_ext == "gpl" or file_ext == "pal" or file_ext == "json":
		Palettes.import_palette_from_path(file)

	elif file_ext in ["pck", "zip"]:  # Godot resource pack file
		Global.preferences_dialog.extensions.install_extension(file)

	elif file_ext == "shader" or file_ext == "gdshader":  # Godot shader file
		var shader := load(file)
		if not shader is Shader:
			return
		var file_name: String = file.get_file().get_basename()
		Global.control.find_child("ShaderEffect").change_shader(shader, file_name)

	else:  # Image files
		# Attempt to load as APNG.
		# Note that the APNG importer will *only* succeed for *animated* PNGs.
		# This is intentional as still images should still act normally.
		var apng_res := AImgIOAPNGImporter.load_from_file(file)
		if apng_res[0] == null:
			# No error - this is an APNG!
			handle_loading_aimg(file, apng_res[1])
			return
		# Attempt to load as a regular image.
		var image := Image.load_from_file(file)
		if not is_instance_valid(image):  # An error occurred
			var file_name: String = file.get_file()
			Global.error_dialog.set_text(tr("Can't load file '%s'.") % [file_name])
			Global.error_dialog.popup_centered()
			Global.dialog_open(true)
			return
		handle_loading_image(file, image)


func handle_loading_image(file: String, image: Image) -> void:
	var preview_dialog := preview_dialog_tscn.instantiate() as PreviewDialog
	preview_dialogs.append(preview_dialog)
	preview_dialog.path = file
	preview_dialog.image = image
	Global.control.add_child(preview_dialog)
	preview_dialog.popup_centered()
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
			frame.duration = aimg_frame.duration * project.fps
		var content := aimg_frame.content
		content.convert(Image.FORMAT_RGBA8)
		frame.cels.append(PixelCel.new(content, 1))
		project.frames.append(frame)

	set_new_imported_tab(project, path)


func open_pxo_file(path: String, untitled_backup := false, replace_empty := true) -> void:
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if FileAccess.get_open_error() == ERR_FILE_UNRECOGNIZED:
		# If the file is not compressed open it raw (pre-v0.7)
		file = FileAccess.open(path, FileAccess.READ)
	var err := FileAccess.get_open_error()
	if err != OK:
		Global.error_dialog.set_text(
			tr("File failed to open. Error code %s (%s)") % [err, error_string(err)]
		)
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)
		return

	var empty_project := Global.current_project.is_empty() and replace_empty
	var new_project: Project
	if empty_project:
		new_project = Global.current_project
		new_project.frames = []
		new_project.layers = []
		new_project.animation_tags.clear()
		new_project.name = path.get_file()
	else:
		new_project = Project.new([], path.get_file())

	var first_line := file.get_line()
	var test_json_conv := JSON.new()
	var error := test_json_conv.parse(first_line)
	if error != OK:
		print("Error, corrupt pxo file")
		file.close()
		return
	else:
		var result = test_json_conv.get_data()
		if typeof(result) != TYPE_DICTIONARY:
			print("Error, json parsed result is: %s" % typeof(result))
			file.close()
			return

		new_project.deserialize(result)
		for frame in new_project.frames:
			for cel in frame.cels:
				cel.load_image_data_from_pxo(file, new_project.size)

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
	if empty_project:
		new_project.change_project()
		Global.project_changed.emit()
		Global.cel_changed.emit()
	else:
		Global.projects.append(new_project)
		Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()

	if not untitled_backup:
		# Untitled backup should not change window title and save path
		current_save_paths[Global.current_project_index] = path
		Global.main_window.title = path.get_file() + " - Pixelorama " + Global.current_version
		Global.save_sprites_dialog.current_path = path
		# Set last opened project path and save
		Global.config_cache.set_value("preferences", "last_project_path", path)
		Global.config_cache.save("user://cache.ini")
		new_project.directory_path = path.get_base_dir()
		new_project.file_name = path.get_file().trim_suffix(".pxo")
		new_project.was_exported = false
		Global.top_menu_container.file_menu.set_item_text(
			Global.FileMenu.SAVE, tr("Save") + " %s" % path.get_file()
		)
		Global.top_menu_container.file_menu.set_item_text(Global.FileMenu.EXPORT, tr("Export"))

	save_project_to_recent_list(path)


func save_pxo_file(
	path: String, autosave: bool, use_zstd := true, project := Global.current_project
) -> bool:
	if !autosave:
		project.name = path.get_file()
	var serialized_data := project.serialize()
	if !serialized_data:
		Global.error_dialog.set_text(
			tr("File failed to save. Converting project data to dictionary failed.")
		)
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)
		return false
	var to_save := JSON.stringify(serialized_data)
	if !to_save:
		Global.error_dialog.set_text(
			tr("File failed to save. Converting dictionary to JSON failed.")
		)
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)
		return false

	# Check if a file with the same name exists. If it does, rename the new file temporarily.
	# Needed in case of a crash, so that the old file won't be replaced with an empty one.
	var temp_path := path
	var dir := DirAccess.open("user://")
	if dir.file_exists(path):
		temp_path = path + "1"

	var file: FileAccess
	if use_zstd:
		file = FileAccess.open_compressed(temp_path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	else:
		file = FileAccess.open(temp_path, FileAccess.WRITE)

	var err := FileAccess.get_open_error()
	if err != OK:
		if temp_path.is_valid_filename():
			return false
		Global.error_dialog.set_text(
			tr("File failed to save. Error code %s (%s)") % [err, error_string(err)]
		)
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)
		if file:  # this would be null if we attempt to save filenames such as "//\\||.pxo"
			file.close()
		return false

	if !autosave:
		current_save_paths[Global.current_project_index] = path

	file.store_line(to_save)
	for frame in project.frames:
		for cel in frame.cels:
			cel.save_image_data_to_pxo(file)
	for brush in project.brushes:
		file.store_buffer(brush.get_data())
	if project.tiles.has_mask:
		file.store_buffer(project.tiles.tile_mask.get_data())

	file.close()

	if temp_path != path:
		# Rename the new file to its proper name and remove the old file, if it exists.
		dir.rename(temp_path, path)

	if OS.has_feature("web") and !autosave:
		file = FileAccess.open(path, FileAccess.READ)
		if FileAccess.get_open_error() == OK:
			var file_data := Array(file.get_buffer(file.get_length()))
			JavaScriptBridge.download_buffer(file_data, path.get_file())
		file.close()
		# Remove the .pxo file from memory, as we don't need it anymore
		var browser_dir := DirAccess.open(path)
		browser_dir.remove(path)

	if autosave:
		Global.notification_label("File autosaved")
	else:
		# First remove backup then set current save path
		if project.has_changed:
			project.has_changed = false
		remove_backup(Global.current_project_index)
		Global.notification_label("File saved")
		Global.main_window.title = path.get_file() + " - Pixelorama " + Global.current_version

		# Set last opened project path and save
		Global.config_cache.set_value("preferences", "last_project_path", path)
		Global.config_cache.save("user://cache.ini")
		if !project.was_exported:
			project.file_name = path.get_file().trim_suffix(".pxo")
			project.directory_path = path.get_base_dir()
		Global.top_menu_container.file_menu.set_item_text(
			Global.FileMenu.SAVE, tr("Save") + " %s" % path.get_file()
		)

	save_project_to_recent_list(path)
	return true


func open_image_as_new_tab(path: String, image: Image) -> void:
	var project := Project.new([], path.get_file(), image.get_size())
	project.layers.append(PixelLayer.new(project))
	Global.projects.append(project)

	var frame := Frame.new()
	image.convert(Image.FORMAT_RGBA8)
	frame.cels.append(PixelCel.new(image, 1))

	project.frames.append(frame)
	set_new_imported_tab(project, path)


func open_image_as_spritesheet_tab_smart(
	path: String, image: Image, sliced_rects: Array[Rect2i], frame_size: Vector2i
) -> void:
	if sliced_rects.size() == 0:  # Image is empty sprite (manually set data to be consistent)
		frame_size = image.get_size()
		sliced_rects.append(Rect2i(Vector2i.ZERO, frame_size))
	var project := Project.new([], path.get_file(), frame_size)
	project.layers.append(PixelLayer.new(project))
	Global.projects.append(project)
	for rect in sliced_rects:
		var offset: Vector2 = (0.5 * (frame_size - rect.size)).floor()
		var frame := Frame.new()
		var cropped_image := Image.create(frame_size.x, frame_size.y, false, Image.FORMAT_RGBA8)
		image.convert(Image.FORMAT_RGBA8)
		cropped_image.blit_rect(image, rect, offset)
		frame.cels.append(PixelCel.new(cropped_image, 1))
		project.frames.append(frame)
	set_new_imported_tab(project, path)


func open_image_as_spritesheet_tab(path: String, image: Image, horiz: int, vert: int) -> void:
	horiz = mini(horiz, image.get_size().x)
	vert = mini(vert, image.get_size().y)
	var frame_width := image.get_size().x / horiz
	var frame_height := image.get_size().y / vert
	var project := Project.new([], path.get_file(), Vector2(frame_width, frame_height))
	project.layers.append(PixelLayer.new(project))
	Global.projects.append(project)
	for yy in range(vert):
		for xx in range(horiz):
			var frame := Frame.new()
			var cropped_image := image.get_region(
				Rect2i(frame_width * xx, frame_height * yy, frame_width, frame_height)
			)
			project.size = cropped_image.get_size()
			cropped_image.convert(Image.FORMAT_RGBA8)
			frame.cels.append(PixelCel.new(cropped_image, 1))
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
	project.undos += 1
	project.undo_redo.create_action("Add Spritesheet Layer")

	# Create new frames (if needed)
	var new_frames_size := maxi(project.frames.size(), start_frame + sliced_rects.size())
	var frames := []
	var frame_indices := []
	if new_frames_size > project.frames.size():
		var required_frames := new_frames_size - project.frames.size()
		frame_indices = range(
			project.current_frame + 1, project.current_frame + required_frames + 1
		)
		for i in required_frames:
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
			frames.append(new_frame)

	# Create new layer for spritesheet
	var layer := PixelLayer.new(project, file_name)
	var cels: Array[PixelCel] = []
	for f in new_frames_size:
		if f >= start_frame and f < (start_frame + sliced_rects.size()):
			# Slice spritesheet
			var offset: Vector2 = (0.5 * (frame_size - sliced_rects[f - start_frame].size)).floor()
			image.convert(Image.FORMAT_RGBA8)
			var cropped_image := Image.create(
				project_width, project_height, false, Image.FORMAT_RGBA8
			)
			cropped_image.blit_rect(image, sliced_rects[f - start_frame], offset)
			cels.append(PixelCel.new(cropped_image))
		else:
			cels.append(layer.new_empty_cel())

	project.undo_redo.add_do_method(project.add_frames.bind(frames, frame_indices))
	project.undo_redo.add_do_method(
		project.add_layers.bind([layer], [project.layers.size()], [cels])
	)
	project.undo_redo.add_do_method(
		project.change_cel.bind(new_frames_size - 1, project.layers.size())
	)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))

	project.undo_redo.add_undo_method(project.remove_layers.bind([project.layers.size()]))
	project.undo_redo.add_undo_method(project.remove_frames.bind(frame_indices))
	project.undo_redo.add_undo_method(
		project.change_cel.bind(project.current_frame, project.current_layer)
	)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()


func open_image_as_spritesheet_layer(
	_path: String, image: Image, file_name: String, horizontal: int, vertical: int, start_frame: int
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
	project.undos += 1
	project.undo_redo.create_action("Add Spritesheet Layer")

	# Create new frames (if needed)
	var new_frames_size := maxi(project.frames.size(), start_frame + (vertical * horizontal))
	var frames := []
	var frame_indices := []
	if new_frames_size > project.frames.size():
		var required_frames := new_frames_size - project.frames.size()
		frame_indices = range(
			project.current_frame + 1, project.current_frame + required_frames + 1
		)
		for i in required_frames:
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
			frames.append(new_frame)

	# Create new layer for spritesheet
	var layer := PixelLayer.new(project, file_name)
	var cels := []
	for f in new_frames_size:
		if f >= start_frame and f < (start_frame + (vertical * horizontal)):
			# Slice spritesheet
			var xx := (f - start_frame) % horizontal
			var yy := (f - start_frame) / horizontal
			image.convert(Image.FORMAT_RGBA8)
			var cropped_image := Image.create(
				project_width, project_height, false, Image.FORMAT_RGBA8
			)
			cropped_image.blit_rect(
				image,
				Rect2i(frame_width * xx, frame_height * yy, frame_width, frame_height),
				Vector2i.ZERO
			)
			cels.append(PixelCel.new(cropped_image))
		else:
			cels.append(layer.new_empty_cel())

	project.undo_redo.add_do_method(project.add_frames.bind(frames, frame_indices))
	project.undo_redo.add_do_method(
		project.add_layers.bind([layer], [project.layers.size()], [cels])
	)
	project.undo_redo.add_do_method(
		project.change_cel.bind(new_frames_size - 1, project.layers.size())
	)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))

	project.undo_redo.add_undo_method(project.remove_layers.bind([project.layers.size()]))
	project.undo_redo.add_undo_method(project.remove_frames.bind(frame_indices))
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
	project.undos += 1
	project.undo_redo.create_action("Replaced Cel")

	for i in project.frames.size():
		if i == frame_index:
			image.convert(Image.FORMAT_RGBA8)
			var cel := project.frames[i].cels[layer_index]
			if not cel is PixelCel:
				continue
			var cel_image := Image.create(project_width, project_height, false, Image.FORMAT_RGBA8)
			cel_image.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
			project.undo_redo.add_do_property(cel, "image", cel_image)
			project.undo_redo.add_undo_property(cel, "image", cel.get_image())

	project.undo_redo.add_do_property(project, "selected_cels", [])
	project.undo_redo.add_do_method(project.change_cel.bind(frame_index, layer_index))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))

	project.undo_redo.add_undo_property(project, "selected_cels", [])
	project.undo_redo.add_undo_method(
		project.change_cel.bind(project.current_frame, project.current_layer)
	)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()


func open_image_as_new_frame(image: Image, layer_index := 0) -> void:
	var project := Global.current_project
	var project_width := maxi(image.get_width(), project.size.x)
	var project_height := maxi(image.get_height(), project.size.y)
	if project.size < Vector2i(project_width, project_height):
		DrawingAlgos.resize_canvas(project_width, project_height, 0, 0)

	var frame := Frame.new()
	for i in project.layers.size():
		if i == layer_index:
			image.convert(Image.FORMAT_RGBA8)
			var cel_image := Image.create(project_width, project_height, false, Image.FORMAT_RGBA8)
			cel_image.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
			frame.cels.append(PixelCel.new(cel_image, 1))
		else:
			frame.cels.append(project.layers[i].new_empty_cel())

	project.undos += 1
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

	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Add Layer")
	for i in project.frames.size():
		if i == frame_index:
			image.convert(Image.FORMAT_RGBA8)
			var cel_image := Image.create(project_width, project_height, false, Image.FORMAT_RGBA8)
			cel_image.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
			cels.append(PixelCel.new(cel_image, 1))
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
	Global.canvas.add_child(ri)
	project.change_project()


## Useful for Web
func import_reference_image_from_image(image: Image) -> void:
	var project := Global.current_project
	var ri := ReferenceImage.new()
	ri.project = project
	ri.create_from_image(image)
	Global.canvas.add_child(ri)
	project.change_project()


func set_new_imported_tab(project: Project, path: String) -> void:
	var prev_project_empty := Global.current_project.is_empty()
	var prev_project_pos := Global.current_project_index

	Global.main_window.title = (
		path.get_file() + " (" + tr("imported") + ") - Pixelorama " + Global.current_version
	)
	if project.has_changed:
		Global.main_window.title = Global.main_window.title + "(*)"
	var file_name := path.get_basename().get_file()
	var directory_path := path.get_base_dir()
	project.directory_path = directory_path
	project.file_name = file_name
	project.was_exported = true
	if path.get_extension().to_lower() == "png":
		project.export_overwrite = true

	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()

	if prev_project_empty:
		Global.tabs.delete_tab(prev_project_pos)


func update_autosave() -> void:
	autosave_timer.stop()
	# Interval parameter is in minutes, wait_time is seconds
	autosave_timer.wait_time = Global.autosave_interval * 60
	if Global.enable_autosave:
		autosave_timer.start()


func _on_Autosave_timeout() -> void:
	for i in range(backup_save_paths.size()):
		if backup_save_paths[i] == "":
			# Create a new backup file if it doesn't exist yet
			backup_save_paths[i] = (
				"user://backup-" + str(Time.get_unix_time_from_system()) + "-%s" % i
			)

		store_backup_path(i)
		save_pxo_file(backup_save_paths[i], true, true, Global.projects[i])


## Backup paths are stored in two ways:
## 1) User already manually saved and defined a save path -> {current_save_path, backup_save_path}
## 2) User didn't manually save, "untitled" backup is stored -> {backup_save_path, backup_save_path}
func store_backup_path(i: int) -> void:
	if current_save_paths[i] != "":
		# Remove "untitled" backup if it existed on this project instance
		if Global.config_cache.has_section_key("backups", backup_save_paths[i]):
			Global.config_cache.erase_section_key("backups", backup_save_paths[i])

		Global.config_cache.set_value("backups", current_save_paths[i], backup_save_paths[i])
	else:
		Global.config_cache.set_value("backups", backup_save_paths[i], backup_save_paths[i])

	Global.config_cache.save("user://cache.ini")


func remove_backup(i: int) -> void:
	# Remove backup file
	if backup_save_paths[i] != "":
		if current_save_paths[i] != "":
			remove_backup_by_path(current_save_paths[i], backup_save_paths[i])
		else:
			# If manual save was not yet done - remove "untitled" backup
			remove_backup_by_path(backup_save_paths[i], backup_save_paths[i])
		backup_save_paths[i] = ""


func remove_backup_by_path(project_path: String, backup_path: String) -> void:
	DirAccess.open("user://").remove(backup_path)
	if Global.config_cache.has_section_key("backups", project_path):
		Global.config_cache.erase_section_key("backups", project_path)
	elif Global.config_cache.has_section_key("backups", backup_path):
		Global.config_cache.erase_section_key("backups", backup_path)
	Global.config_cache.save("user://cache.ini")


func reload_backup_file(project_paths: Array, backup_paths: Array) -> void:
	assert(project_paths.size() == backup_paths.size())
	# Clear non-existent backups
	var existing_backups_count := 0
	for i in range(backup_paths.size()):
		var dir := DirAccess.open("user://")
		if dir.file_exists(backup_paths[i]):
			project_paths[existing_backups_count] = project_paths[i]
			backup_paths[existing_backups_count] = backup_paths[i]
			existing_backups_count += 1
		else:
			if Global.config_cache.has_section_key("backups", backup_paths[i]):
				Global.config_cache.erase_section_key("backups", backup_paths[i])
				Global.config_cache.save("user://cache.ini")
	project_paths.resize(existing_backups_count)
	backup_paths.resize(existing_backups_count)

	# Load the backup files
	for i in range(project_paths.size()):
		open_pxo_file(backup_paths[i], project_paths[i] == backup_paths[i], i == 0)
		backup_save_paths[i] = backup_paths[i]

		# If project path is the same as backup save path -> the backup was untitled
		if project_paths[i] != backup_paths[i]:  # If the user has saved
			current_save_paths[i] = project_paths[i]
			Global.main_window.title = (
				project_paths[i].get_file() + " - Pixelorama(*) " + Global.current_version
			)
			Global.current_project.has_changed = true

	Global.notification_label("Backup reloaded")


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
