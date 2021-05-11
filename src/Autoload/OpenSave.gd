extends Node


var current_save_paths := [] # Array of strings
# Stores a filename of a backup file in user:// until user saves manually
var backup_save_paths := [] # Array of strings

onready var autosave_timer : Timer


func _ready() -> void:
	autosave_timer = Timer.new()
	autosave_timer.one_shot = false
	autosave_timer.process_mode = Timer.TIMER_PROCESS_IDLE
	autosave_timer.connect("timeout", self, "_on_Autosave_timeout")
	add_child(autosave_timer)
	update_autosave()


func handle_loading_files(files : PoolStringArray) -> void:
	for file in files:
		file = file.replace("\\", "/")
		var file_ext : String = file.get_extension().to_lower()
		if file_ext == "pxo": # Pixelorama project file
			open_pxo_file(file)
		elif file_ext == "tres" or file_ext == "gpl" or file_ext == "pal" or file_ext == "json": # Palettes
			Palettes.import_palette(file)
		else: # Image files
			var image := Image.new()
			var err := image.load(file)
			if err != OK: # An error occured
				var file_name : String = file.get_file()
				Global.error_dialog.set_text(tr("Can't load file '%s'.\nError code: %s") % [file_name, str(err)])
				Global.error_dialog.popup_centered()
				Global.dialog_open(true)
				continue
			handle_loading_image(file, image)


func handle_loading_image(file : String, image : Image) -> void:
	var preview_dialog : ConfirmationDialog = preload("res://src/UI/Dialogs/PreviewDialog.tscn").instance()
	preview_dialog.path = file
	preview_dialog.image = image
	Global.control.add_child(preview_dialog)
	preview_dialog.popup_centered()
	Global.dialog_open(true)


func open_pxo_file(path : String, untitled_backup : bool = false, replace_empty : bool = true) -> void:
	var file := File.new()
	var err := file.open_compressed(path, File.READ, File.COMPRESSION_ZSTD)
	if err == ERR_FILE_UNRECOGNIZED:
		err = file.open(path, File.READ) # If the file is not compressed open it raw (pre-v0.7)

	if err != OK:
		Global.error_dialog.set_text(tr("File failed to open. Error code %s") % err)
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)
		file.close()
		return

	var empty_project : bool = Global.current_project.is_empty() and replace_empty
	var new_project : Project
	if empty_project:
		new_project = Global.current_project
		new_project.frames = []
		new_project.layers = []
		new_project.animation_tags.clear()
		new_project.name = path.get_file()
	else:
		new_project = Project.new([], path.get_file())

	var first_line := file.get_line()
	var dict := JSON.parse(first_line)
	if dict.error != OK:
		open_old_pxo_file(file, new_project, first_line)
	else:
		if typeof(dict.result) != TYPE_DICTIONARY:
			print("Error, json parsed result is: %s" % typeof(dict.result))
			file.close()
			return

		new_project.deserialize(dict.result)
		for frame in new_project.frames:
			for cel in frame.cels:
				var buffer := file.get_buffer(new_project.size.x * new_project.size.y * 4)
				cel.image.create_from_data(new_project.size.x, new_project.size.y, false, Image.FORMAT_RGBA8, buffer)
				cel.image = cel.image # Just to call image_changed

		if dict.result.has("brushes"):
			for brush in dict.result.brushes:
				var b_width = brush.size_x
				var b_height = brush.size_y
				var buffer := file.get_buffer(b_width * b_height * 4)
				var image := Image.new()
				image.create_from_data(b_width, b_height, false, Image.FORMAT_RGBA8, buffer)
				new_project.brushes.append(image)
				Brushes.add_project_brush(image)

	file.close()
	if !empty_project:
		Global.projects.append(new_project)
		Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	else:
		new_project.frames = new_project.frames # Just to call frames_changed
		new_project.layers = new_project.layers # Just to call layers_changed
	Global.canvas.camera_zoom()

	if not untitled_backup:
		# Untitled backup should not change window title and save path
		current_save_paths[Global.current_project_index] = path
		Global.window_title = path.get_file() + " - Pixelorama " + Global.current_version
		Global.save_sprites_dialog.current_path = path
		# Set last opened project path and save
		Global.config_cache.set_value("preferences", "last_project_path", path)
		Global.config_cache.save("user://cache.ini")
		Export.file_name = path.get_file().trim_suffix(".pxo")
		Export.directory_path = path.get_base_dir()
		new_project.directory_path = Export.directory_path
		new_project.file_name = Export.file_name
		Export.was_exported = false
		Global.top_menu_container.file_menu.set_item_text(4, tr("Save") + " %s" % path.get_file())
		Global.top_menu_container.file_menu.set_item_text(6, tr("Export"))

	Global.save_project_to_recent_list(path)


# For pxo files older than v0.8
func open_old_pxo_file(file : File, new_project : Project, first_line : String) -> void:
#	var file_version := file.get_line() # Example, "v0.7.10-beta"
	var file_version := first_line
	var file_ver_splitted := file_version.split("-")
	var file_ver_splitted_numbers := file_ver_splitted[0].split(".")

	# In the above example, the major version would return "0",
	# the minor version would return "7", the patch "10"
	# and the status would return "beta"
	var file_major_version = int(file_ver_splitted_numbers[0].replace("v", ""))
	var file_minor_version = int(file_ver_splitted_numbers[1])
	var file_patch_version := 0
	var _file_status_version : String

	if file_ver_splitted_numbers.size() > 2:
		file_patch_version = int(file_ver_splitted_numbers[2])
	if file_ver_splitted.size() > 1:
		_file_status_version = file_ver_splitted[1]

	if file_major_version == 0 and file_minor_version < 5:
		Global.notification_label("File is from an older version of Pixelorama, as such it might not work properly")

	var new_guides := true
	if file_major_version == 0:
		if file_minor_version < 7 or (file_minor_version == 7 and file_patch_version == 0):
			new_guides = false

	var frame := 0

	var linked_cels := []
	if file_major_version >= 0 and file_minor_version > 6:
		var global_layer_line := file.get_line()
		while global_layer_line == ".":
			var layer_name := file.get_line()
			var layer_visibility := file.get_8()
			var layer_lock := file.get_8()
			var layer_new_cels_linked := file.get_8()
			linked_cels.append(file.get_var())

			var l := Layer.new(layer_name, layer_visibility, layer_lock, HBoxContainer.new(), layer_new_cels_linked, [])
			new_project.layers.append(l)
			global_layer_line = file.get_line()

	var frame_line := file.get_line()
	while frame_line == "--": # Load frames
		var frame_class := Frame.new()
		var width := file.get_16()
		var height := file.get_16()

		var layer_i := 0
		var layer_line := file.get_line()
		while layer_line == "-": # Load layers
			var buffer := file.get_buffer(width * height * 4)
			if file_major_version == 0 and file_minor_version < 7:
				var layer_name_old_version = file.get_line()
				if frame == 0:
					var l := Layer.new(layer_name_old_version)
					new_project.layers.append(l)
			var cel_opacity := 1.0
			if file_major_version >= 0 and file_minor_version > 5:
				cel_opacity = file.get_float()
			var image := Image.new()
			image.create_from_data(width, height, false, Image.FORMAT_RGBA8, buffer)
			image.lock()
			frame_class.cels.append(Cel.new(image, cel_opacity))
			if file_major_version >= 0 and file_minor_version >= 7:
				if frame in linked_cels[layer_i]:
					new_project.layers[layer_i].linked_cels.append(frame_class)
					frame_class.cels[layer_i].image = new_project.layers[layer_i].linked_cels[0].cels[layer_i].image
					frame_class.cels[layer_i].image_texture = new_project.layers[layer_i].linked_cels[0].cels[layer_i].image_texture

			layer_i += 1
			layer_line = file.get_line()

		if !new_guides:
			var guide_line := file.get_line() # "guideline" no pun intended
			while guide_line == "|": # Load guides
				var guide := Guide.new()
				guide.type = file.get_8()
				if guide.type == guide.Types.HORIZONTAL:
					guide.add_point(Vector2(-99999, file.get_16()))
					guide.add_point(Vector2(99999, file.get_16()))
				else:
					guide.add_point(Vector2(file.get_16(), -99999))
					guide.add_point(Vector2(file.get_16(), 99999))
				guide.has_focus = false
				Global.canvas.add_child(guide)
				new_project.guides.append(guide)
				guide_line = file.get_line()

		new_project.size = Vector2(width, height)
		new_project.frames.append(frame_class)
		frame_line = file.get_line()
		frame += 1

	if new_guides:
		var guide_line := file.get_line() # "guideline" no pun intended
		while guide_line == "|": # Load guides
			var guide := Guide.new()
			guide.type = file.get_8()
			if guide.type == guide.Types.HORIZONTAL:
				guide.add_point(Vector2(-99999, file.get_16()))
				guide.add_point(Vector2(99999, file.get_16()))
			else:
				guide.add_point(Vector2(file.get_16(), -99999))
				guide.add_point(Vector2(file.get_16(), 99999))
			guide.has_focus = false
			Global.canvas.add_child(guide)
			new_project.guides.append(guide)
			guide_line = file.get_line()

	# Load tool options
	file.get_var()
	file.get_var()
	file.get_8()
	file.get_8()
	if file_major_version == 0 and file_minor_version < 7:
		file.get_var()
		file.get_var()

	# Load custom brushes
	var brush_line := file.get_line()
	while brush_line == "/":
		var b_width := file.get_16()
		var b_height := file.get_16()
		var buffer := file.get_buffer(b_width * b_height * 4)
		var image := Image.new()
		image.create_from_data(b_width, b_height, false, Image.FORMAT_RGBA8, buffer)
		new_project.brushes.append(image)
		Brushes.add_project_brush(image)
		brush_line = file.get_line()

	if file_major_version >= 0 and file_minor_version > 6:
		var tag_line := file.get_line()
		while tag_line == ".T/":
			var tag_name := file.get_line()
			var tag_color : Color = file.get_var()
			var tag_from := file.get_8()
			var tag_to := file.get_8()
			new_project.animation_tags.append(AnimationTag.new(tag_name, tag_color, tag_from, tag_to))
			new_project.animation_tags = new_project.animation_tags # To execute animation_tags_changed()
			tag_line = file.get_line()


func save_pxo_file(path : String, autosave : bool, use_zstd_compression := true, project : Project = Global.current_project) -> void:
	if !autosave:
		project.name = path.get_file()
	var serialized_data = project.serialize()
	if !serialized_data:
		Global.error_dialog.set_text(tr("File failed to save. Converting project data to dictionary failed."))
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)
		return
	var to_save = JSON.print(serialized_data)
	if !to_save:
		Global.error_dialog.set_text(tr("File failed to save. Converting dictionary to JSON failed."))
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)
		return

	var file : File = File.new()
	var err
	if use_zstd_compression:
		err = file.open_compressed(path, File.WRITE, File.COMPRESSION_ZSTD)
	else:
		err = file.open(path, File.WRITE)

	if err != OK:
		Global.error_dialog.set_text(tr("File failed to save. Error code %s") % err)
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)
		file.close()
		return

	if !autosave:
		current_save_paths[Global.current_project_index] = path

	file.store_line(to_save)
	for frame in project.frames:
		for cel in frame.cels:
			file.store_buffer(cel.image.get_data())

	for brush in project.brushes:
		file.store_buffer(brush.get_data())

	file.close()

	if OS.get_name() == "HTML5" and !autosave:
		err = file.open(path, File.READ)
		if !err:
			var file_data = Array(file.get_buffer(file.get_len()))
			JavaScript.eval("download('%s', %s, '');" % [path.get_file(), str(file_data)], true)
		file.close()
		# Remove the .pxo file from memory, as we don't need it anymore
		var dir = Directory.new()
		dir.remove(path)

	if autosave:
		Global.notification_label("File autosaved")
	else:
		# First remove backup then set current save path
		if project.has_changed:
			project.has_changed = false
		remove_backup(Global.current_project_index)
		Global.notification_label("File saved")
		Global.window_title = path.get_file() + " - Pixelorama " + Global.current_version

		# Set last opened project path and save
		Global.config_cache.set_value("preferences", "last_project_path", path)
		Global.config_cache.save("user://cache.ini")
		Export.file_name = path.get_file().trim_suffix(".pxo")
		Export.directory_path = path.get_base_dir()
		Export.was_exported = false
		project.was_exported = false
		Global.top_menu_container.file_menu.set_item_text(4, tr("Save") + " %s" % path.get_file())

	Global.save_project_to_recent_list(path)


func open_image_as_new_tab(path : String, image : Image) -> void:
	var project = Project.new([], path.get_file(), image.get_size())
	project.layers.append(Layer.new())
	Global.projects.append(project)

	var frame := Frame.new()
	image.convert(Image.FORMAT_RGBA8)
	image.lock()
	frame.cels.append(Cel.new(image, 1))

	project.frames.append(frame)
	set_new_tab(project, path)


func open_image_as_spritesheet_tab(path : String, image : Image, horizontal : int, vertical : int) -> void:
	var project = Project.new([], path.get_file())
	project.layers.append(Layer.new())
	Global.projects.append(project)
	horizontal = min(horizontal, image.get_size().x)
	vertical = min(vertical, image.get_size().y)
	var frame_width := image.get_size().x / horizontal
	var frame_height := image.get_size().y / vertical
	for yy in range(vertical):
		for xx in range(horizontal):
			var frame := Frame.new()
			var cropped_image := Image.new()
			cropped_image = image.get_rect(Rect2(frame_width * xx, frame_height * yy, frame_width, frame_height))
			project.size = cropped_image.get_size()
			cropped_image.convert(Image.FORMAT_RGBA8)
			cropped_image.lock()
			frame.cels.append(Cel.new(cropped_image, 1))

			for _i in range(1, project.layers.size()):
				var empty_sprite := Image.new()
				empty_sprite.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
				empty_sprite.fill(Color(0, 0, 0, 0))
				empty_sprite.lock()
				frame.cels.append(Cel.new(empty_sprite, 1))

			project.frames.append(frame)

	set_new_tab(project, path)


func open_image_as_spritesheet_layer(_path : String, image : Image, file_name : String, horizontal : int, vertical : int, start_frame : int) -> void:
	# data needed to slice images
	horizontal = min(horizontal, image.get_size().x)
	vertical = min(vertical, image.get_size().y)
	var frame_width := image.get_size().x / horizontal
	var frame_height := image.get_size().y / vertical

	# resize canvas to if "frame_width" or "frame_height" is too large
	var project_width :int = max(frame_width, Global.current_project.size.x)
	var project_height :int = max(frame_height, Global.current_project.size.y)
	DrawingAlgos.resize_canvas(project_width, project_height,0 ,0)

	# slice images
	var image_no :int = 0
	for yy in range(vertical):
		for xx in range(horizontal):
			var cropped_image := Image.new()
			cropped_image = image.get_rect(Rect2(frame_width * xx, frame_height * yy, frame_width, frame_height))
			if (start_frame + (image_no)) < Global.current_project.frames.size():
				# if frames are already present then fill those first
				if image_no == 0:
					open_image_as_new_layer(cropped_image, file_name, start_frame + image_no)
				else:
					open_image_at_frame(cropped_image, Global.current_project.layers.size() - 1, start_frame + image_no)
			else:
				# if no more frames are present then start making new frames
				open_image_as_new_frame(cropped_image, Global.current_project.layers.size() - 1)
			image_no += 1


func open_image_at_frame(image : Image, layer_index := 0, frame_index := 0) -> void:
	var project = Global.current_project
	image.crop(project.size.x, project.size.y)

	project.undos += 1
	project.undo_redo.create_action("Replaced Frame")

	var frames :Array = []
	# create a duplicate of "project.frames"
	for i in project.frames.size():
		var frame := Frame.new()
		frame.cels = project.frames[i].cels.duplicate(true)
		frames.append(frame)

	for i in project.frames.size():
		if i == frame_index:
			image.convert(Image.FORMAT_RGBA8)
			image.lock()
			frames[i].cels[layer_index] = (Cel.new(image, 1))
			project.undo_redo.add_do_property(project.frames[i], "cels", frames[i].cels)
			project.undo_redo.add_undo_property(project.frames[i], "cels", project.frames[i].cels)

	project.undo_redo.add_do_property(project, "frames", frames)
	project.undo_redo.add_do_property(project, "current_frame", frame_index)

	project.undo_redo.add_undo_property(project, "frames", project.frames)
	project.undo_redo.add_undo_property(project, "current_frame", project.current_frame)

	project.undo_redo.add_do_method(Global, "redo")
	project.undo_redo.add_undo_method(Global, "undo")
	project.undo_redo.commit_action()


func open_image_as_new_frame(image : Image, layer_index := 0) -> void:
	var project = Global.current_project
	image.crop(project.size.x, project.size.y)
	var new_frames : Array = project.frames.duplicate()

	var frame := Frame.new()
	for i in project.layers.size():
		if i == layer_index:
			image.convert(Image.FORMAT_RGBA8)
			image.lock()
			frame.cels.append(Cel.new(image, 1))
		else:
			var empty_image := Image.new()
			empty_image.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
			empty_image.lock()
			frame.cels.append(Cel.new(empty_image, 1))

	new_frames.append(frame)

	project.undos += 1
	project.undo_redo.create_action("Add Frame")
	project.undo_redo.add_do_method(Global, "redo")
	project.undo_redo.add_undo_method(Global, "undo")

	project.undo_redo.add_do_property(project, "frames", new_frames)
	project.undo_redo.add_do_property(project, "current_frame", new_frames.size() - 1)
	project.undo_redo.add_do_property(project, "current_layer", layer_index)

	project.undo_redo.add_undo_property(project, "frames", project.frames)
	project.undo_redo.add_undo_property(project, "current_frame", project.current_frame)
	project.undo_redo.add_undo_property(project, "current_layer", project.current_layer)
	project.undo_redo.commit_action()


func open_image_as_new_layer(image : Image, file_name : String, frame_index := 0) -> void:
	var project = Global.current_project
	image.crop(project.size.x, project.size.y)
	var new_layers : Array = Global.current_project.layers.duplicate()
	var layer := Layer.new(file_name)

	Global.current_project.undos += 1
	Global.current_project.undo_redo.create_action("Add Layer")
	for i in project.frames.size():
		var new_cels : Array = project.frames[i].cels.duplicate(true)
		if i == frame_index:
			image.convert(Image.FORMAT_RGBA8)
			image.lock()
			new_cels.append(Cel.new(image, 1))
		else:
			var empty_image := Image.new()
			empty_image.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
			empty_image.lock()
			new_cels.append(Cel.new(empty_image, 1))

		project.undo_redo.add_do_property(project.frames[i], "cels", new_cels)
		project.undo_redo.add_undo_property(project.frames[i], "cels", project.frames[i].cels)


	new_layers.append(layer)

	project.undo_redo.add_do_property(project, "current_layer", new_layers.size() - 1)
	project.undo_redo.add_do_property(project, "layers", new_layers)
	project.undo_redo.add_do_property(project, "current_frame", frame_index)

	project.undo_redo.add_undo_property(project, "current_layer", project.current_layer)
	project.undo_redo.add_undo_property(project, "layers", project.layers)
	project.undo_redo.add_undo_property(project, "current_frame", project.current_frame)

	project.undo_redo.add_undo_method(Global, "undo")
	project.undo_redo.add_do_method(Global, "redo")
	project.undo_redo.commit_action()


func set_new_tab(project : Project, path : String) -> void:
	Global.tabs.current_tab = Global.tabs.get_tab_count() - 1
	Global.canvas.camera_zoom()

	Global.window_title = path.get_file() + " (" + tr("imported") + ") - Pixelorama " + Global.current_version
	if project.has_changed:
		Global.window_title = Global.window_title + "(*)"
	var file_name := path.get_basename().get_file()
	var directory_path := path.get_basename().replace(file_name, "")
	project.directory_path = directory_path
	project.file_name = file_name
	Export.directory_path = directory_path
	Export.file_name = file_name


func update_autosave() -> void:
	autosave_timer.stop()
	autosave_timer.wait_time = Global.autosave_interval * 60 # Interval parameter is in minutes, wait_time is seconds
	if Global.enable_autosave:
		autosave_timer.start()


func _on_Autosave_timeout() -> void:
	for i in range(backup_save_paths.size()):
		if backup_save_paths[i] == "":
			# Create a new backup file if it doesn't exist yet
			backup_save_paths[i] = "user://backup-" + String(OS.get_unix_time()) + "-%s" % i

		store_backup_path(i)
		save_pxo_file(backup_save_paths[i], true, true, Global.projects[i])


# Backup paths are stored in two ways:
# 1) User already manually saved and defined a save path -> {current_save_path, backup_save_path}
# 2) User didn't manually saved, "untitled" backup is stored -> {backup_save_path, backup_save_path}
func store_backup_path(i : int) -> void:
	if current_save_paths[i] != "":
		# Remove "untitled" backup if it existed on this project instance
		if Global.config_cache.has_section_key("backups", backup_save_paths[i]):
			Global.config_cache.erase_section_key("backups", backup_save_paths[i])

		Global.config_cache.set_value("backups", current_save_paths[i], backup_save_paths[i])
	else:
		Global.config_cache.set_value("backups", backup_save_paths[i], backup_save_paths[i])

	Global.config_cache.save("user://cache.ini")


func remove_backup(i : int) -> void:
	# Remove backup file
	if backup_save_paths[i] != "":
		if current_save_paths[i] != "":
			remove_backup_by_path(current_save_paths[i], backup_save_paths[i])
		else:
			# If manual save was not yet done - remove "untitled" backup
			remove_backup_by_path(backup_save_paths[i], backup_save_paths[i])
		backup_save_paths[i] = ""


func remove_backup_by_path(project_path : String, backup_path : String) -> void:
	Directory.new().remove(backup_path)
	if Global.config_cache.has_section_key("backups", project_path):
		Global.config_cache.erase_section_key("backups", project_path)
	elif Global.config_cache.has_section_key("backups", backup_path):
		Global.config_cache.erase_section_key("backups", backup_path)
	Global.config_cache.save("user://cache.ini")


func reload_backup_file(project_paths : Array, backup_paths : Array) -> void:
	assert(project_paths.size() == backup_paths.size())
	# Clear non-existant backups
	var existing_backups_count := 0
	var dir := Directory.new()
	for i in range(backup_paths.size()):
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
		if project_paths[i] != backup_paths[i]: # If the user has saved
			current_save_paths[i] = project_paths[i]
			Global.window_title = project_paths[i].get_file() + " - Pixelorama(*) " + Global.current_version
			Global.current_project.has_changed = true

	Global.notification_label("Backup reloaded")
