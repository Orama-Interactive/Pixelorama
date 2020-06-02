extends Node

var current_save_path := ""
# Stores a filename of a backup file in user:// until user saves manually
var backup_save_path = ""

onready var autosave_timer : Timer


func _ready() -> void:
	autosave_timer = Timer.new()
	autosave_timer.one_shot = false
	autosave_timer.process_mode = Timer.TIMER_PROCESS_IDLE
	autosave_timer.connect("timeout", self, "_on_Autosave_timeout")
	add_child(autosave_timer)
	update_autosave()


func open_pxo_file(path : String, untitled_backup : bool = false) -> void:
	var file := File.new()
	var err := file.open_compressed(path, File.READ, File.COMPRESSION_ZSTD)
	if err == ERR_FILE_UNRECOGNIZED:
		err =  file.open(path, File.READ) # If the file is not compressed open it raw (pre-v0.7)

	if err != OK:
		Global.notification_label("File failed to open")
		file.close()
		return

	var file_version := file.get_line() # Example, "v0.7.10-beta"
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
	Global.layers.clear()

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
			Global.layers.append(l)
			global_layer_line = file.get_line()

	var frame_line := file.get_line()
	Global.clear_frames()
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
					Global.layers.append(l)
			var cel_opacity := 1.0
			if file_major_version >= 0 and file_minor_version > 5:
				cel_opacity = file.get_float()
			var image := Image.new()
			image.create_from_data(width, height, false, Image.FORMAT_RGBA8, buffer)
			image.lock()
			frame_class.cels.append(Cel.new(image, cel_opacity))
			if file_major_version >= 0 and file_minor_version >= 7:
				if frame in linked_cels[layer_i]:
					Global.layers[layer_i].linked_cels.append(frame_class)

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
				guide_line = file.get_line()

		Global.canvas.size = Vector2(width, height)
		Global.frames.append(frame_class)
		frame_line = file.get_line()
		frame += 1

	Global.frames = Global.frames # Just to call Global.frames_changed
	Global.current_layer = Global.layers.size() - 1
	Global.current_frame = frame - 1
	Global.layers = Global.layers # Just to call Global.layers_changed

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
			guide_line = file.get_line()

	# Load tool options
	Global.color_pickers[0].color = file.get_var()
	Global.color_pickers[1].color = file.get_var()
	Global.brush_sizes[0] = file.get_8()
	Global.brush_size_edits[0].value = Global.brush_sizes[0]
	Global.brush_sizes[1] = file.get_8()
	Global.brush_size_edits[1].value = Global.brush_sizes[1]
	if file_major_version == 0 and file_minor_version < 7:
		var left_palette = file.get_var()
		var right_palette = file.get_var()
		for color in left_palette:
			Global.color_pickers[0].get_picker().add_preset(color)
		for color in right_palette:
			Global.color_pickers[1].get_picker().add_preset(color)

	# Load custom brushes
	Global.custom_brushes.resize(Global.brushes_from_files)
	Global.remove_brush_buttons()

	var brush_line := file.get_line()
	while brush_line == "/":
		var b_width := file.get_16()
		var b_height := file.get_16()
		var buffer := file.get_buffer(b_width * b_height * 4)
		var image := Image.new()
		image.create_from_data(b_width, b_height, false, Image.FORMAT_RGBA8, buffer)
		Global.custom_brushes.append(image)
		Global.create_brush_button(image)
		brush_line = file.get_line()

	if file_major_version >= 0 and file_minor_version > 6:
		var tag_line := file.get_line()
		while tag_line == ".T/":
			var tag_name := file.get_line()
			var tag_color : Color = file.get_var()
			var tag_from := file.get_8()
			var tag_to := file.get_8()
			Global.animation_tags.append(AnimationTag.new(tag_name, tag_color, tag_from, tag_to))
			Global.animation_tags = Global.animation_tags # To execute animation_tags_changed()
			tag_line = file.get_line()

	file.close()
	Global.canvas.camera_zoom()

	if not untitled_backup:
		# Untitled backup should not change window title and save path
		current_save_path = path
		Global.window_title = path.get_file() + " - Pixelorama " + Global.current_version
		Global.project_has_changed = false


func save_pxo_file(path : String, autosave : bool) -> void:
	var file := File.new()
	var err := file.open_compressed(path, File.WRITE, File.COMPRESSION_ZSTD)
	if err == OK:
		# Store Pixelorama version
		file.store_line(Global.current_version)

		# Store Global layers
		for layer in Global.layers:
			file.store_line(".")
			file.store_line(layer.name)
			file.store_8(layer.visible)
			file.store_8(layer.locked)
			file.store_8(layer.new_cels_linked)
			var linked_cels := []
			for frame in layer.linked_cels:
				linked_cels.append(Global.frames.find(frame))
			file.store_var(linked_cels) # Linked cels as cel numbers

		file.store_line("END_GLOBAL_LAYERS")

		 # Store frames
		for frame in Global.frames:
			file.store_line("--")
			file.store_16(Global.canvas.size.x)
			file.store_16(Global.canvas.size.y)
			for cel in frame.cels: # Store canvas layers
				file.store_line("-")
				file.store_buffer(cel.image.get_data())
				file.store_float(cel.opacity)
			file.store_line("END_LAYERS")

		file.store_line("END_FRAMES")

		# Store guides
		for child in Global.canvas.get_children():
			if child is Guide:
				file.store_line("|")
				file.store_8(child.type)
				if child.type == child.Types.HORIZONTAL:
					file.store_16(child.points[0].y)
					file.store_16(child.points[1].y)
				else:
					file.store_16(child.points[1].x)
					file.store_16(child.points[0].x)
		file.store_line("END_GUIDES")

		# Save tool options
		var left_color : Color = Global.color_pickers[0].color
		var right_color : Color = Global.color_pickers[1].color
		var left_brush_size : int = Global.brush_sizes[0]
		var right_brush_size : int = Global.brush_sizes[1]
		file.store_var(left_color)
		file.store_var(right_color)
		file.store_8(left_brush_size)
		file.store_8(right_brush_size)

		# Save custom brushes
		for i in range(Global.brushes_from_files, Global.custom_brushes.size()):
			var brush = Global.custom_brushes[i]
			file.store_line("/")
			file.store_16(brush.get_size().x)
			file.store_16(brush.get_size().y)
			file.store_buffer(brush.get_data())
		file.store_line("END_BRUSHES")

		# Store animation tags
		for tag in Global.animation_tags:
			file.store_line(".T/")
			file.store_line(tag.name)
			file.store_var(tag.color)
			file.store_8(tag.from)
			file.store_8(tag.to)
		file.store_line("END_FRAME_TAGS")

		file.close()

		if Global.project_has_changed and not autosave:
			Global.project_has_changed = false

		if autosave:
			Global.notification_label("File autosaved")
		else:
			# First remove backup then set current save path
			remove_backup()
			current_save_path = path
			Global.notification_label("File saved")

		if backup_save_path == "":
			Global.window_title = path.get_file() + " - Pixelorama " + Global.current_version

	else:
		Global.notification_label("File failed to save")


func update_autosave() -> void:
	autosave_timer.stop()
	autosave_timer.wait_time = Global.autosave_interval * 60 # Interval parameter is in minutes, wait_time is seconds
	if Global.enable_autosave:
		autosave_timer.start()


func _on_Autosave_timeout() -> void:
	if backup_save_path == "":
		# Create a new backup file if it doesn't exist yet
		backup_save_path = "user://backup-" + String(OS.get_unix_time())

	store_backup_path()
	save_pxo_file(backup_save_path, true)


# Backup paths are stored in two ways:
# 1) User already manually saved and defined a save path -> {current_save_path, backup_save_path}
# 2) User didn't manually saved, "untitled" backup is stored -> {backup_save_path, backup_save_path}
func store_backup_path() -> void:
	if current_save_path != "":
		# Remove "untitled" backup if it existed on this project instance
		if Global.config_cache.has_section_key("backups", backup_save_path):
			Global.config_cache.erase_section_key("backups", backup_save_path)

		Global.config_cache.set_value("backups", current_save_path, backup_save_path)
	else:
		Global.config_cache.set_value("backups", backup_save_path, backup_save_path)

	Global.config_cache.save("user://cache.ini")


func remove_backup() -> void:
	# Remove backup file
	if backup_save_path != "":
		if current_save_path != "":
			remove_backup_by_path(current_save_path, backup_save_path)
		else:
			# If manual save was not yet done - remove "untitled" backup
			remove_backup_by_path(backup_save_path, backup_save_path)
		backup_save_path = ""


func remove_backup_by_path(project_path : String, backup_path : String) -> void:
	Directory.new().remove(backup_path)
	Global.config_cache.erase_section_key("backups", project_path)
	Global.config_cache.save("user://cache.ini")


func reload_backup_file(project_path : String, backup_path : String) -> void:
	# If project path is the same as backup save path -> the backup was untitled
	open_pxo_file(backup_path, project_path == backup_path)
	backup_save_path = backup_path

	if project_path != backup_path:
		current_save_path = project_path
		Global.window_title = project_path.get_file() + " - Pixelorama(*) " + Global.current_version
		Global.project_has_changed = true

	Global.notification_label("Backup reloaded")

