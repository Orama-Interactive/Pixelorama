extends Node

const DEFAULT_PALETTE_NAME = "Default"

# Presets for creating a new palette
enum NewPalettePresetType {
	Empty = 0,
	FromCurrentPalette = 1,
	FromCurrentSprite = 2,
	FromCurrentSelection = 3
}

# Color options when user creates a new palette from current sprite or selection
enum GetColorsFrom {
	CurrentFrame = 0,
	CurrentCel = 1,
	AllFrames = 2
}

# All available palettes
var palettes := {}

# Currently displayed palette
var current_palette = null

# Indexes of colors that are selected in palette
# by left and right mouse button
var left_selected_color := -1
var right_selected_color := -1


func _ready() -> void:
	load_palettes()
	pass


func get_palettes() -> Dictionary:
	return palettes


func get_current_palette() -> Palette:
	return current_palette


func does_palette_exist(palette_name: String) -> bool:
	for palette_path in palettes.keys():
		var file_name = palette_path.get_basename().get_file()
		var stripped_palette_name = Palette.strip_unvalid_characters(palette_name)
		if file_name == stripped_palette_name:
			return true
	return false


func select_palette(palette_path: String) -> void:
	current_palette = palettes.get(palette_path)
	clear_selected_colors()


func is_any_palette_selected() -> bool:
	if self.current_palette:
		return true
	return false


func current_palette_save() -> String:
	var save_path = ""
	if current_palette:
		save_path = save_palette(self.current_palette)
	return save_path


func save_palette(palette: Palette) -> String:
	Global.directory_module.ensure_xdg_user_dirs_exist()
	var palettes_write_path: String = Global.directory_module.get_palette_write_path()

	# Save old resource name and set new resource name
	var old_resource_name = palette.resource_name
	palette.set_resource_name(palette.name)

	# If resource name changed remove the old palette file
	if old_resource_name != palette.resource_name:
		var old_palette = palettes_write_path.plus_file(old_resource_name) + ".tres"
		delete_palette(old_palette)

	# Save palette
	var save_path = palettes_write_path.plus_file(palette.resource_name) + ".tres"
	palette.resource_path = save_path
	var err = ResourceSaver.save(save_path, palette)
	if err != OK:
		Global.notification_label("Failed to save palette")
	return save_path


func create_new_palette(preset: int, name: String, comment: String, width: int, height: int, add_alpha_colors: bool, get_colors_from: int) -> void:
	check_palette_settings_values(name, width, height)
	match preset:
		NewPalettePresetType.Empty:
			create_new_empty_palette(name, comment, width, height)
		NewPalettePresetType.FromCurrentPalette:
			create_new_palette_from_current_palette(name, comment)
		NewPalettePresetType.FromCurrentSprite:
			create_new_palette_from_current_sprite(name, comment, width, height, add_alpha_colors, get_colors_from)
		NewPalettePresetType.FromCurrentSelection:
			create_new_palette_from_current_selection(name, comment, width, height, add_alpha_colors, get_colors_from)


func create_new_empty_palette(name: String, comment: String, width: int, height: int) -> void:
	var new_palette: Palette = Palette.new(name, width, height, comment)
	var palette_path := save_palette(new_palette)
	palettes[palette_path] = new_palette
	select_palette(palette_path)


func create_new_palette_from_current_palette(name: String, comment: String) -> void:
	var new_palette: Palette = current_palette.duplicate()
	new_palette.name = name
	new_palette.comment = comment
	new_palette.set_resource_name(name)
	var palette_path := save_palette(new_palette)
	palettes[palette_path] = new_palette
	select_palette(palette_path)


func create_new_palette_from_current_selection(name: String, comment: String, width: int, height: int, add_alpha_colors: bool, get_colors_from: int):
	var new_palette: Palette = Palette.new(name, width, height, comment)
	var current_project = Global.current_project
	var pixels := []
	for x in current_project.size.x:
		for y in current_project.size.y:
			var pos := Vector2(x, y)
			if current_project.selection_bitmap.get_bit(pos):
				pixels.append(pos)
	fill_new_palette_with_colors(pixels, new_palette, add_alpha_colors, get_colors_from)


func create_new_palette_from_current_sprite(name: String, comment: String, width: int, height: int, add_alpha_colors: bool, get_colors_from: int):
	var new_palette: Palette = Palette.new(name, width, height, comment)
	var current_project = Global.current_project
	var pixels := []
	for x in current_project.size.x:
		for y in current_project.size.y:
			pixels.append(Vector2(x, y))
	fill_new_palette_with_colors(pixels, new_palette, add_alpha_colors, get_colors_from)


func fill_new_palette_with_colors(pixels: Array, new_palette: Palette, add_alpha_colors: bool, get_colors_from: int):
	var current_project = Global.current_project
	var cels := []
	match get_colors_from:
		GetColorsFrom.CurrentCel:
			cels.append(current_project.frames[current_project.current_frame].cels[current_project.current_layer])
		GetColorsFrom.CurrentFrame:
			for cel in current_project.frames[current_project.current_frame].cels:
				cels.append(cel)
		GetColorsFrom.AllFrames:
			for frame in current_project.frames:
				for cel in frame.cels:
					cels.append(cel)

	for cel in cels:
		var cel_image := Image.new()
		cel_image.copy_from(cel.image)
		cel_image.lock()
		if cel_image.is_invisible():
			continue
		for i in pixels:
			var color : Color = cel_image.get_pixelv(i)
			if color.a > 0:
				if not add_alpha_colors:
					color.a = 1
				if not new_palette.has_color(color):
					new_palette.add_color(color)
		cel_image.unlock()

	var palette_path := save_palette(new_palette)
	palettes[palette_path] = new_palette
	select_palette(palette_path)


func current_palette_edit(name: String, comment: String, width: int, height: int) -> void:
	check_palette_settings_values(name, width, height)
	current_palette.edit(name, width, height, comment)
	var palette_path = current_palette_save()
	palettes[palette_path] = current_palette


func delete_palette(path: String) -> void:
	var dir = Directory.new()
	dir.remove(path)
	palettes.erase(path)


func current_palete_delete() -> void:
	delete_palette(current_palette.resource_path)

	if palettes.size() > 0:
		select_palette(palettes.keys()[0])
	else:
		current_palette = null


func current_palette_add_color(mouse_button: int, start_index: int = 0) -> void:
	if not current_palette.is_full() and (mouse_button == BUTTON_LEFT or mouse_button == BUTTON_RIGHT):
		# Get color on left or right tool
		var color = Tools.get_assigned_color(mouse_button)
		current_palette.add_color(color, start_index)
		current_palette_save()


func current_palette_get_color(index: int) -> Color:
	return current_palette.get_color(index)


func current_palette_set_color(index: int, color: Color) -> void:
	current_palette.set_color(index, color)
	current_palette_save()


func current_palette_delete_color(index: int) -> void:
	current_palette.remove_color(index)
	current_palette_save()


func current_palette_swap_colors(source_index: int, target_index: int) -> void:
	current_palette.swap_colors(source_index, target_index)
	select_color(BUTTON_LEFT, target_index)
	current_palette_save()


func current_palette_copy_colors(from: int, to: int) -> void:
	current_palette.copy_colors(from, to)
	current_palette_save()


func current_palette_insert_color(from: int, to: int) -> void:
	var from_color = current_palette.colors[from]
	current_palette.remove_color(from)
	current_palette.insert_color(to, from_color.color)
	current_palette_save()


func current_palette_get_selected_color_index(mouse_button: int) -> int:
	match mouse_button:
		BUTTON_LEFT:
			return left_selected_color
		BUTTON_RIGHT:
			return right_selected_color
		_:
			return -1


func current_palette_select_color(mouse_button: int, index: int) -> void:
	var color = current_palette_get_color(index)
	if color == null:
		return

	match mouse_button:
		BUTTON_LEFT:
			Tools.assign_color(color, mouse_button)
		BUTTON_RIGHT:
			Tools.assign_color(color, mouse_button)

	select_color(mouse_button, index)


func select_color(mouse_button: int, index: int) -> void:
	match mouse_button:
		BUTTON_LEFT:
			left_selected_color = index
		BUTTON_RIGHT:
			right_selected_color = index


func clear_selected_colors() -> void:
	left_selected_color = -1
	right_selected_color = -1


func current_palette_is_empty() -> bool:
	return current_palette.is_empty()


func current_palette_is_full() -> bool:
	return current_palette.is_full()


func check_palette_settings_values(name: String, width: int, height: int) -> bool:
	# Just in case. These values should be not allowed in gui.
	if name.length() <= 0 or width <= 0 or height <= 0:
		printerr("Palette width, height and name length must be greater than 0!")
		return false
	return true


func load_palettes() -> void:
	Global.directory_module.ensure_xdg_user_dirs_exist()
	var search_locations = Global.directory_module.get_palette_search_path_in_order()
	var priority_ordered_files := get_palette_priority_file_map(search_locations)
	var palettes_write_path: String = Global.directory_module.get_palette_write_path()

	# Iterate backwards, so any palettes defined in default files
	# get overwritten by those of the same name in user files
	search_locations.invert()
	priority_ordered_files.invert()
	for i in range(len(search_locations)):
		# If palette is not in palettes write path - make it's copy in the write path
		var make_copy := false
		if search_locations[i] != palettes_write_path:
			make_copy = true

		var base_directory : String = search_locations[i]
		var palette_files : Array = priority_ordered_files[i]
		for file_name in palette_files:
			var palette: Palette = load(base_directory.plus_file(file_name))
			if palette:
				if make_copy:
					# Makes a copy of the palette
					save_palette(palette)
				palette.resource_name = palette.resource_path.get_file().trim_suffix(".tres")
				# On Windows for some reason paths can contain "res://" in front of them which breaks saving
				palette.resource_path = palette.resource_path.trim_prefix("res://")
				palettes[palette.resource_path] = palette

				# Store index of the default palette
				if palette.name == DEFAULT_PALETTE_NAME:
					select_palette(palette.resource_path)

	if not current_palette && palettes.size() > 0:
		select_palette(palettes.keys()[0])


# This returns an array of arrays, with priorities.
# In particular, it takes an array of paths to look for
# arrays in, in order of file and palette override priority
# such that the files in the first directory override the
# second, third, etc. ^.^
# It returns an array of arrays, where each output array
# corresponds to the given input array at the same index, and
# contains the (relative to the given directory) palette files
# to load, excluding all ones already existing in higher-priority
# directories. nya
# in particular, this also means you can run backwards on the result
# so that palettes with the given palette name in the higher priority
# directories override those set in lower priority directories :)
func get_palette_priority_file_map(looking_paths: Array) -> Array:
	var final_list := []
	# Holds pattern files already found
	var working_file_set : Dictionary = {}
	for search_directory in looking_paths:
		var to_add_files := []
		var files = get_palette_files(search_directory)
		# files to check
		for maybe_to_add in files:
			if not maybe_to_add in working_file_set:
				to_add_files.append(maybe_to_add)
				working_file_set[maybe_to_add] = true

		final_list.append(to_add_files)
	return final_list


# Get the palette files in a single directory.
# if it does not exist, return []
func get_palette_files(path : String ) -> Array:
	var dir := Directory.new()
	var results = []

	if not dir.dir_exists(path):
		return []

	dir.open(path)
	dir.list_dir_begin()

	while true:
		var file_name = dir.get_next()
		if file_name == "":
			break
		elif (not file_name.begins_with(".")) && file_name.to_lower().ends_with("tres") && not dir.current_is_dir():
			results.append(file_name)

	dir.list_dir_end()
	return results


# Locate the highest priority palette by the given relative filename
# If none is found in the directories, then do nothing and return null
func get_best_palette_file_location(looking_paths: Array, fname: String):  # -> String:
	var priority_fmap : Array = get_palette_priority_file_map(looking_paths)
	for i in range(len(looking_paths)):
		var base_path : String = looking_paths[i]
		var the_files : Array = priority_fmap[i]
		if the_files.has(fname):
			return base_path.plus_file(fname)
	return null


func import_palette(path: String) -> void:
	if does_palette_exist(path.get_basename().get_file()):
		# If there is a palette with same name ignore import for now
		return

	var palette : Palette = null
	match path.to_lower().get_extension():
		"tres":
			palette = load(path)
		"gpl":
			var file = File.new()
			if file.file_exists(path):
				file.open(path, File.READ)
				var text = file.get_as_text()
				file.close()
				palette = import_gpl(path, text)
		"pal":
			var file = File.new()
			if file.file_exists(path):
				file.open(path, File.READ)
				var text = file.get_as_text()
				file.close()
				palette = import_pal_palette(path, text)
		"png", "bmp", "hdr", "jpg", "jpeg", "svg", "tga", "webp":
			var image := Image.new()
			var err := image.load(path)
			if !err:
				palette = import_image_palette(path, image)
		"json":
			var file = File.new()
			if file.file_exists(path):
				file.open(path, File.READ)
				var text = file.get_as_text()
				file.close()
				palette = import_json_palette(text)

	if palette:
		var palette_path := save_palette(palette)
		palettes[palette_path] = palette
		select_palette(palette_path)
		Global.palette_panel.setup_palettes_selector()
		Global.palette_panel.select_palette(palette_path)


func import_gpl(path: String, text: String) -> Palette:
	# Refer to app/core/gimppalette-load.c of the GIMP for the "living spec"
	var result : Palette = null
	var lines = text.split('\n')
	var line_number := 0
	var comments := ""
	for line in lines:
		# Check if valid Gimp Palette Library file
		if line_number == 0:
			if not "GIMP Palette" in line:
				break
			else:
				# Use filename as palette name in case reading old
				# palette format (must read more to determine)
				result = Palette.new(path.get_basename().get_file())

		# Comments
		if line.begins_with('#'):
			comments += line.trim_prefix('#') + '\n'
			# Some programs output palette name in a comment for old format
			if line.begins_with("#Palette Name: "):
				result.name = line.replace("#Palette Name: ", "")
			pass
		elif line.begins_with("Name: "):
			result.name = line.replace("Name: ", "")
			pass
		elif line.begins_with("Columns: "):
			# Number of colors in this palette. Unecessary and often wrong
			pass
		elif line_number > 0 && line.length() >= 9:
			line = line.replace("\t", " ")
			var color_data : PoolStringArray = line.split(" ", false, 4)
			var red : float = color_data[0].to_float() / 255.0
			var green : float = color_data[1].to_float() / 255.0
			var blue : float = color_data[2].to_float() / 255.0
			var color = Color(red, green, blue)
			if color_data.size() >= 4:
				# Ignore color name for now - result.add_color(color, color_data[3])
				result.add_color(color)
				#
			else:
				result.add_color(color)
		line_number += 1

	if result:
		result.comment = comments

	return result


func import_pal_palette(path: String, text: String) -> Palette:
	var result: Palette = null

	var lines = text.split('\n')

	if not 'JASC-PAL' in lines[0] or not '0100' in lines[1]:
		return result
	else:
		result = Palette.new(path.get_basename().get_file())

	var num_colors = int(lines[2])

	for i in range(3, num_colors + 3):
		var color_data = lines[i].split(' ')
		var red : float = color_data[0].to_float() / 255.0
		var green : float = color_data[1].to_float() / 255.0
		var blue : float = color_data[2].to_float() / 255.0

		var color = Color(red, green, blue)
		result.add_color(color)

	return result


func import_image_palette(path: String, image: Image) -> Palette:
	var result: Palette = Palette.new(path.get_basename().get_file())

	var height: int = image.get_height()
	var width: int = image.get_width()

	# Iterate all pixels and store unique colors to palete
	image.lock()
	for y in range(0, height):
		for x in range(0, width):
			var color: Color = image.get_pixel(x, y)
			if not result.has_color(color):
				result.add_color(color)
	image.unlock()

	return result


# Import of deprecated older json palette format
func import_json_palette(text: String):
	var result: Palette = Palette.new()
	var result_json = JSON.parse(text)

	if result_json.error != OK:  # If parse has errors
		printerr("JSON palette import error")
		printerr("Error: ", result_json.error)
		printerr("Error Line: ", result_json.error_line)
		printerr("Error String: ", result_json.error_string)
		result = null
	else:  # If parse OK
		var data = result_json.result
		if data.has("name"): # If data is 'valid' palette file
			result.name = data.name
			if data.has("comments"):
				result.comment = data.comments
			if data.has("colors"):
				for color_data in data.colors:
					var color: Color = Color(color_data.data)
					result.add_color(color)

	return result
