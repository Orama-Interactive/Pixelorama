extends Node

signal palette_selected(palette_name: String)
signal new_palette_created
signal palette_removed
signal new_palette_imported

enum SortOptions {NEW_PALETTE, REVERSE, HUE, SATURATION, VALUE, LIGHTNESS, RED, GREEN, BLUE, ALPHA}
## Presets for creating a new palette
enum NewPalettePresetType {EMPTY, FROM_CURRENT_PALETTE, FROM_CURRENT_SPRITE, FROM_CURRENT_SELECTION}
## Color options when user creates a new palette from current sprite or selection
enum GetColorsFrom { CURRENT_FRAME, CURRENT_CEL, ALL_FRAMES }
const DEFAULT_PALETTE_NAME := "Default"
## Maximum allowed width of imported palettes.
const MAX_IMPORT_PAL_WIDTH := 1 << 14
var palettes_write_path := Global.home_data_directory.path_join("Palettes")
## All available palettes
var palettes: Dictionary[String, Palette] = {}
## Currently displayed palette
var current_palette: Palette = null
var auto_add_colors := false

# Indexes of colors that are selected in palette
# by left and right mouse button
var left_selected_color := -1
var right_selected_color := -1


func _ready() -> void:
	_load_palettes()


func does_palette_exist(palette_name: String, in_project := Global.current_project) -> bool:
	var keys = palettes.keys()
	if in_project:
		keys.append_array(in_project.palettes.keys())
	for name_to_test: String in keys:
		if name_to_test == palette_name:
			return true
	return false


func select_palette(palette_name: String) -> void:
	var project: Project = Global.current_project
	project.project_current_palette_name = ""
	current_palette = null
	if palettes.has(palette_name):
		current_palette = palettes.get(palette_name, null)
	elif project.palettes.has(palette_name):
		current_palette = project.palettes.get(palette_name, null)
		if current_palette:
			project.project_current_palette_name = palette_name
	else:
		# Attempt to find the last used palette (select if it's a global palette)
		var last_active_palette: String = Global.config_cache.get_value(
			"data", "last_palette", DEFAULT_PALETTE_NAME
		)
		current_palette = palettes.get(last_active_palette, null)
		if !current_palette:  # Fallback to the palette that the last palette is derived from
			current_palette = palettes.get(get_name_without_suffix(last_active_palette), null)
			if !current_palette:  # Fallback to default palette
				current_palette = palettes.get(DEFAULT_PALETTE_NAME, null)
		if current_palette:
			palette_name = current_palette.name
	_clear_selected_colors()
	if is_instance_valid(current_palette):
		Global.config_cache.set_value("data", "last_palette", current_palette.name)
	palette_selected.emit(palette_name)


func is_any_palette_selected() -> bool:
	if is_instance_valid(current_palette):
		return true
	return false


func _ensure_palette_directory_exists() -> void:
	var dir := DirAccess.open(Global.home_data_directory)
	if is_instance_valid(dir) and not dir.dir_exists(palettes_write_path):
		dir.make_dir(palettes_write_path)


func save_palette(palette: Palette = current_palette) -> void:
	if palette.is_project_palette:  # Failsafe
		return
	_ensure_palette_directory_exists()
	if not is_instance_valid(palette):
		return
	var old_name := palette.path.get_basename().get_file()
	# If the palette's name has changed, remove the old palette file
	if old_name != palette.name:
		DirAccess.remove_absolute(palette.path)
		palettes.erase(old_name)

	# Save palette
	var save_path := palettes_write_path.path_join(palette.name) + ".json"
	palette.path = save_path
	var err := palette.save_to_file()
	if err != OK:
		Global.popup_error("Failed to save palette. Error code %s (%s)" % [err, error_string(err)])


## Copies the current_palette and assigns it as the new current palette
func copy_current_palette(
	new_palette_name := current_palette.name, is_global := false, is_undoable := true
) -> void:
	new_palette_name = get_valid_name(new_palette_name)
	var comment := current_palette.comment
	_create_new_palette_from_current_palette(new_palette_name, comment, is_global, is_undoable)


## De-lists the palette from the project and global palette dictionaries
func unparent_palette(palette: Palette):
	if palette.name in palettes:
		palettes.erase(palette.name)
		return
	if Global.current_project:
		if palette.name in Global.current_project.palettes:
			Global.current_project.palettes.erase(palette.name)


func add_palette_as_project_palette(new_palette: Palette) -> void:
	new_palette.is_project_palette = true
	new_palette.name = get_valid_name(new_palette.name)
	Global.current_project.palettes[new_palette.name] = new_palette
	current_palette = new_palette
	new_palette_created.emit()


func undo_redo_add_palette(new_palette: Palette):
	var undo_redo := Global.current_project.undo_redo
	undo_redo.add_do_method(add_palette_as_project_palette.bind(new_palette))
	undo_redo.add_undo_method(palette_delete_and_reselect.bind(true, new_palette))
	if is_instance_valid(current_palette):
		undo_redo.add_undo_method(select_palette.bind(current_palette.name))


func get_valid_name(initial_palette_name: String, project := Global.current_project) -> String:
	var copies := 0
	# Remove any previous suffixes
	initial_palette_name = get_name_without_suffix(initial_palette_name)
	var palette_name := initial_palette_name
	while does_palette_exist(palette_name, project):
		var final_suffix = " copy" + (str(" ", copies) if copies != 0 else "")
		palette_name = initial_palette_name + final_suffix
		copies += 1
	return palette_name


func get_name_without_suffix(palette_name: String, include_count := false) -> String:
	# Remove any previous suffixes
	var result := palette_name
	if palette_name.contains("copy") and palette_name != "copy":
		result = palette_name.substr(0, palette_name.rfind("copy")).strip_edges()
		if include_count:
			var start = palette_name.rfind("copy") + 4  # NOTE: (4 == "copy".length())
			var length = palette_name.length() - start
			result += " " + palette_name.substr(start, length).strip_edges()
	return result


func create_new_palette(
	preset: int,
	palette_name: String,
	comment: String,
	width: int,
	height: int,
	add_alpha_colors: bool,
	get_colors_from: int,
	is_global: bool
) -> void:
	if !is_global:
		Global.current_project.undo_redo.create_action("Create new palette")
	_check_palette_settings_values(palette_name, width, height)
	match preset:
		NewPalettePresetType.EMPTY:
			_create_new_empty_palette(palette_name, comment, width, height, is_global)
		NewPalettePresetType.FROM_CURRENT_PALETTE:
			_create_new_palette_from_current_palette(palette_name, comment, is_global)
		NewPalettePresetType.FROM_CURRENT_SPRITE:
			_create_new_palette_from_current_sprite(
				palette_name, comment, width, height, add_alpha_colors, get_colors_from, is_global
			)
		NewPalettePresetType.FROM_CURRENT_SELECTION:
			_create_new_palette_from_current_selection(
				palette_name, comment, width, height, add_alpha_colors, get_colors_from, is_global
			)
	if !is_global:
		Global.current_project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
		Global.current_project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
		Global.current_project.undo_redo.commit_action()
	else:
		new_palette_created.emit()


func _create_new_empty_palette(
	palette_name: String, comment: String, width: int, height: int, is_global: bool
) -> void:
	var new_palette := Palette.new(palette_name, width, height, comment)
	if is_global:
		save_palette(new_palette)
		palettes[palette_name] = new_palette
		select_palette(palette_name)
	else:
		undo_redo_add_palette(new_palette)


func _create_new_palette_from_current_palette(
	palette_name: String, comment: String, is_global: bool, is_undoable := true
) -> void:
	if !current_palette:
		return
	var new_palette := current_palette.duplicate()
	new_palette.name = palette_name
	new_palette.comment = comment
	new_palette.is_project_palette = false
	new_palette.path = palettes_write_path.path_join(new_palette.name) + ".json"
	if is_global:
		save_palette(new_palette)
		palettes[palette_name] = new_palette
		select_palette(palette_name)
	else:
		if is_undoable:
			undo_redo_add_palette(new_palette)
		else:
			add_palette_as_project_palette(new_palette)
			select_palette(palette_name)


func _create_new_palette_from_current_selection(
	palette_name: String,
	comment: String,
	width: int,
	height: int,
	add_alpha_colors: bool,
	get_colors_from: int,
	is_global: bool
) -> void:
	var new_palette := Palette.new(palette_name, width, height, comment)
	var current_project := Global.current_project
	var pixels: Array[Vector2i] = []
	for x in current_project.size.x:
		for y in current_project.size.y:
			var pos := Vector2i(x, y)
			if current_project.selection_map.is_pixel_selected(pos):
				pixels.append(pos)
	_fill_new_palette_with_colors(pixels, new_palette, add_alpha_colors, get_colors_from, is_global)


func _create_new_palette_from_current_sprite(
	palette_name: String,
	comment: String,
	width: int,
	height: int,
	add_alpha_colors: bool,
	get_colors_from: int,
	is_global: bool
) -> void:
	var new_palette := Palette.new(palette_name, width, height, comment)
	var current_project := Global.current_project
	var pixels: Array[Vector2i] = []
	for x in current_project.size.x:
		for y in current_project.size.y:
			pixels.append(Vector2i(x, y))
	_fill_new_palette_with_colors(pixels, new_palette, add_alpha_colors, get_colors_from, is_global)


## Fills [param new_palette] with the colors of the [param pixels] of the current sprite.
## Used when creating a new palette from the UI.
func _fill_new_palette_with_colors(
	pixels: Array[Vector2i],
	new_palette: Palette,
	add_alpha_colors: bool,
	get_colors_from: int,
	is_global: bool
) -> void:
	var current_project := Global.current_project
	var cels: Array[BaseCel] = []
	match get_colors_from:
		GetColorsFrom.CURRENT_CEL:
			for cel_index in current_project.selected_cels:
				var cel := current_project.frames[cel_index[0]].cels[cel_index[1]]
				cels.append(cel)
		GetColorsFrom.CURRENT_FRAME:
			for cel in current_project.frames[current_project.current_frame].cels:
				cels.append(cel)
		GetColorsFrom.ALL_FRAMES:
			for frame in current_project.frames:
				for cel in frame.cels:
					cels.append(cel)

	for cel in cels:
		var cel_image := Image.new()
		cel_image.copy_from(cel.get_image())
		if cel_image.is_invisible():
			continue
		for i in pixels:
			var color := cel_image.get_pixelv(i)
			if color.a > 0:
				if not add_alpha_colors:
					color.a = 1
				if not new_palette.has_theme_color(color):
					new_palette.add_color(color)
	if is_global:
		save_palette(new_palette)
		palettes[new_palette.name] = new_palette
		select_palette(new_palette.name)
	else:
		undo_redo_add_palette(new_palette)


func current_palette_edit(
	palette_name: String, comment: String, width: int, height: int, is_global: bool
) -> void:
	_check_palette_settings_values(palette_name, width, height)
	if is_global:  # Create a global copy
		var palette_to_edit := current_palette
		if current_palette.is_project_palette:  # Create a global copy of the local palette
			palette_name = get_valid_name(palette_name)
			palette_to_edit = current_palette.duplicate()
		palette_to_edit.edit(palette_name, width, height, comment)
		save_palette(palette_to_edit)
		palettes[palette_name] = palette_to_edit
		select_palette(palette_name)
	else:
		# track old data
		var old_name = current_palette.name
		var old_width = current_palette.width
		var old_height = current_palette.height
		var old_comment = current_palette.comment
		var undo_redo := Global.current_project.undo_redo
		undo_redo.create_action("Edit Properties")
		# track the palette to edit
		var palette_to_edit := current_palette
		var palette_just_added := false
		if not current_palette.is_project_palette:  # Create a local copy of the global palette
			palette_to_edit = current_palette.duplicate()
			palette_just_added = true
		else:
			# unparent palette so that it can be manipulated without consequences
			undo_redo.add_do_method(unparent_palette.bind(palette_to_edit))
			undo_redo.add_undo_method(unparent_palette.bind(palette_to_edit))
		# Edit the data and re-parent the palette. Note that the conflicts in name will be auto
		# resolved when [method add_palette_as_project_palette] is called.
		undo_redo.add_do_method(palette_to_edit.edit.bind(palette_name, width, height, comment))
		undo_redo_add_palette(palette_to_edit)
		if not palette_just_added:
			# if the palette was already existing then re-set old data. Note that the conflicts in
			# name will be auto resolved when [method add_palette_as_project_palette] is called.
			undo_redo.add_undo_method(
				palette_to_edit.edit.bind(old_name, old_width, old_height, old_comment)
			)
			undo_redo.add_undo_method(add_palette_as_project_palette.bind(palette_to_edit))
		undo_redo.add_do_method(Global.undo_or_redo.bind(false))
		undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
		undo_redo.commit_action()


## Deletes palette but does not reselect
func _delete_palette(palette: Palette, permanent := true) -> void:
	if not palette.path.is_empty() and not palette.is_project_palette:
		if permanent:
			DirAccess.remove_absolute(palette.path)
		else:
			OS.move_to_trash(palette.path)
	unparent_palette(palette)
	palette_removed.emit()


## Deletes palette and reselects some other palette
func palette_delete_and_reselect(permanent := true, palette := current_palette) -> void:
	# NOTE: The undo redo for deletion is handled in
	# [method _on_edit_palette_dialog_deleted] of PalettePanel.gd
	_delete_palette(palette, permanent)
	if palettes.size() > 0:
		select_palette(palettes.keys()[0])
	else:
		if palette == current_palette:
			current_palette = null
		select_palette("")


func current_palette_add_color(mouse_button: int, start_index := 0) -> void:
	if (
		not current_palette.is_full()
		and (mouse_button == MOUSE_BUTTON_LEFT or mouse_button == MOUSE_BUTTON_RIGHT)
	):
		# Get color on left or right tool
		var color := Tools.get_assigned_color(mouse_button)
		current_palette.add_color(color, start_index)
		save_palette()


func current_palette_get_color(index: int) -> Color:
	return current_palette.get_color(index)


func current_palette_set_color(index: int, color: Color) -> void:
	current_palette.set_color(index, color)
	save_palette()


func current_palette_delete_color(index: int) -> void:
	current_palette.remove_color(index)
	save_palette()


func sort_colors(id: SortOptions, palette := current_palette) -> void:
	if id == SortOptions.NEW_PALETTE:
		return
	if id == SortOptions.REVERSE:
		palette.reverse_colors()
	else:
		palette.sort(id)
	save_palette()


func current_palette_swap_colors(source_index: int, target_index: int) -> void:
	current_palette.swap_colors(source_index, target_index)
	_select_color(MOUSE_BUTTON_LEFT, target_index)
	save_palette()


func current_palette_copy_colors(from: int, to: int) -> void:
	current_palette.copy_colors(from, to)
	save_palette()


func current_palette_insert_color(from: int, to: int) -> void:
	var from_color: Palette.PaletteColor = current_palette.colors[from]
	current_palette.remove_color(from)
	current_palette.insert_color(to, from_color.color)
	save_palette()


func current_palette_get_selected_color_index(mouse_button: int) -> int:
	match mouse_button:
		MOUSE_BUTTON_LEFT:
			return left_selected_color
		MOUSE_BUTTON_RIGHT:
			return right_selected_color
		_:
			return -1


func current_palette_select_color(mouse_button: int, index: int) -> void:
	var color := current_palette_get_color(index)
	if color == null:
		return

	_select_color(mouse_button, index)

	match mouse_button:
		MOUSE_BUTTON_LEFT:
			Tools.assign_color(color, mouse_button, true, left_selected_color)
		MOUSE_BUTTON_RIGHT:
			Tools.assign_color(color, mouse_button, true, right_selected_color)


func _select_color(mouse_button: int, index: int) -> void:
	match mouse_button:
		MOUSE_BUTTON_LEFT:
			left_selected_color = index
		MOUSE_BUTTON_RIGHT:
			right_selected_color = index


func _clear_selected_colors() -> void:
	left_selected_color = -1
	right_selected_color = -1


func _check_palette_settings_values(palette_name: String, width: int, height: int) -> bool:
	# Just in case. These values should be not allowed in gui.
	if palette_name.length() <= 0 or width <= 0 or height <= 0:
		printerr("Palette width, height and name length must be greater than 0!")
		return false
	return true


func _load_palettes() -> void:
	_ensure_palette_directory_exists()
	var search_locations := Global.path_join_array(Global.data_directories, "Palettes")
	var priority_ordered_files := _get_palette_priority_file_map(search_locations)

	# Iterate backwards, so any palettes defined in default files
	# get overwritten by those of the same name in user files
	search_locations.reverse()
	priority_ordered_files.reverse()
	for i in range(search_locations.size()):
		var base_directory := search_locations[i]
		var palette_files := priority_ordered_files[i]
		for file_name in palette_files:
			var path := base_directory.path_join(file_name)
			import_palette_from_path(path, false, true)

	if not current_palette && palettes.size() > 0:
		select_palette(palettes.keys()[0])


## This returns an array of arrays, with priorities.
## In particular, it takes an array of paths to look for
## arrays in, in order of file and palette override priority
## such that the files in the first directory override the second, third, etc.
## It returns an array of arrays, where each output array
## corresponds to the given input array at the same index, and
## contains the (relative to the given directory) palette files
## to load, excluding all ones already existing in higher-priority directories.
## This also means you can run backwards on the result
## so that palettes with the given palette name in the higher priority
## directories override those set in lower priority directories.
func _get_palette_priority_file_map(looking_paths: PackedStringArray) -> Array[PackedStringArray]:
	var final_list: Array[PackedStringArray] = []
	# Holds pattern files already found
	var working_file_set: Dictionary = {}
	for search_directory in looking_paths:
		var to_add_files: PackedStringArray = []
		var files := _get_palette_files(search_directory)
		# files to check
		for maybe_to_add in files:
			if not maybe_to_add in working_file_set:
				to_add_files.append(maybe_to_add)
				working_file_set[maybe_to_add] = true

		final_list.append(to_add_files)
	return final_list


## Get the palette files in a single directory.
## if it does not exist, return []
func _get_palette_files(path: String) -> PackedStringArray:
	var dir := DirAccess.open(path)
	var results: PackedStringArray = []

	if !dir:
		return []
	dir.list_dir_begin()

	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		elif (
			(not file_name.begins_with("."))
			&& file_name.to_lower().ends_with("json")
			&& not dir.current_is_dir()
		):
			results.append(file_name)

	dir.list_dir_end()
	return results


func import_palette_from_path(path: String, make_copy := false, is_initialising := false) -> void:
	if does_palette_exist(path.get_basename().get_file()):
		# If there is a palette with same name ignore import for now
		return

	var palette: Palette = null
	if FileAccess.file_exists(path):
		var palette_ext := path.to_lower().get_extension()
		if palette_ext in Global.SUPPORTED_IMAGE_TYPES:
			var image := Image.new()
			var err := image.load(path)
			if !err:
				palette = _import_image_palette(path, image)
		elif palette_ext == "gpl":
			var text := FileAccess.open(path, FileAccess.READ).get_as_text()
			palette = _import_gpl(path, text)
		elif palette_ext == "pal":
			var text := FileAccess.open(path, FileAccess.READ).get_as_text()
			palette = _import_pal_palette(path, text)
		elif palette_ext == "json":
			var text := FileAccess.open(path, FileAccess.READ).get_as_text()
			palette = Palette.new(path.get_basename().get_file())
			palette.path = path
			palette.deserialize(text)

	if is_instance_valid(palette):
		if make_copy:
			save_palette(palette)  # Makes a copy of the palette
		palettes[palette.name] = palette
		var default_palette_name: String = Global.config_cache.get_value(
			"data", "last_palette", DEFAULT_PALETTE_NAME
		)
		if is_initialising:
			# Store index of the default palette
			if palette.name == default_palette_name:
				select_palette(palette.name)
		else:
			new_palette_imported.emit()
			select_palette(palette.name)
	else:
		Global.popup_error(tr("Can't load file '%s'.\nThis is not a valid palette file.") % [path])


## Refer to app/core/gimppalette-load.c of the GNU Image Manipulation Program for the "living spec"
func _import_gpl(path: String, text: String) -> Palette:
	var result: Palette = null
	var lines := text.split("\n")
	var line_number := 0
	var palette_name := path.get_basename().get_file()
	var comments := ""
	var columns := 0
	var colors := PackedColorArray()

	for line in lines:
		# Check if the file is a valid palette
		if line_number == 0:
			if not "GIMP Palette" in line:
				return result

		# Comments
		if line.begins_with("#"):
			comments += line.trim_prefix("#") + "\n"
			# Some programs output palette name in a comment for old format
			if line.begins_with("#Palette Name: "):
				palette_name = line.replace("#Palette Name: ", "").strip_edges()
		elif line.begins_with("Name: "):
			palette_name = line.replace("Name: ", "").strip_edges()
		elif line.begins_with("Columns: "):
			# The width of the palette.
			line = line.trim_prefix("Columns: ").strip_edges()
			if !line.is_valid_int():
				continue
			columns = line.to_int()
		elif line_number > 0 && line.length() >= 9:
			line = line.replace("\t", " ")
			var color_data: PackedStringArray = line.split(" ", false, 4)
			var red: float = color_data[0].to_float() / 255.0
			var green: float = color_data[1].to_float() / 255.0
			var blue: float = color_data[2].to_float() / 255.0
			var color := Color(red, green, blue)
			if color_data.size() >= 4:
				# Ignore color name for now - result.add_color(color, color_data[3])
				colors.append(color)
			else:
				colors.append(color)
		line_number += 1

	if line_number > 0:
		return fill_imported_palette_with_colors(palette_name, colors, comments, columns)
	return result


func _import_pal_palette(path: String, text: String) -> Palette:
	var result: Palette = null
	var colors := PackedColorArray()
	var lines := text.split("\n")

	if not "JASC-PAL" in lines[0] or not "0100" in lines[1]:
		return result

	var num_colors := int(lines[2])

	for i in range(3, num_colors + 3):
		var color_data := lines[i].split(" ")
		var red := color_data[0].to_float() / 255.0
		var green := color_data[1].to_float() / 255.0
		var blue := color_data[2].to_float() / 255.0

		var color := Color(red, green, blue)
		colors.append(color)

	return fill_imported_palette_with_colors(path.get_basename().get_file(), colors)


func _import_image_palette(path: String, image: Image) -> Palette:
	var colors: PackedColorArray = []
	var height := image.get_height()
	var width := image.get_width()

	# Iterate all pixels and store unique colors to palette
	for y in range(0, height):
		for x in range(0, width):
			var color := image.get_pixel(x, y)
			if !colors.has(color):
				colors.append(color)

	return fill_imported_palette_with_colors(path.get_basename().get_file(), colors)


## Fills a new [Palette] with colors. Used when importing files. Dimensions are
## determined by taking colors as a one-dimensional array that is wrapped by
## width.
func fill_imported_palette_with_colors(
	palette_name: String,
	colors: PackedColorArray,
	comment := "",
	width := Palette.DEFAULT_WIDTH,
) -> Palette:
	if width <= 0:
		width = Palette.DEFAULT_WIDTH
	width = clampi(width, 1, MAX_IMPORT_PAL_WIDTH)
	var height := ceili(colors.size() / float(width))
	if height == 1:
		width = colors.size()
	var result := Palette.new(palette_name, width, height, comment)
	for color in colors:
		result.add_color(color)

	return result


func import_lospec_palette(url: String) -> void:
	var palette_name := url.get_slice("://", 1)
	var api_url := "https://lospec.com/palette-list/" + palette_name + ".json"
	print("Importing palette:", palette_name)

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_lospec_palette_downloaded.bind(http))
	var err := http.request(api_url)
	if err != OK:
		push_error("Failed to request palette: %s" % palette_name)


func _on_lospec_palette_downloaded(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
) -> void:
	http.queue_free()
	if response_code != 200 or result != HTTPRequest.RESULT_SUCCESS:
		push_error("Palette download failed: %s" % response_code)
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data or not typeof(data) == TYPE_DICTIONARY:
		push_error("Palette download failed")
	var colors_hex = data.colors
	var colors: PackedColorArray = []
	for color_hex in colors_hex:
		var color := Color(color_hex)
		colors.append(color)
	var palette := fill_imported_palette_with_colors(data["name"], colors, data["author"])
	save_palette(palette)
	palettes[palette.name] = palette
	select_palette(palette.name)
	new_palette_created.emit()
