extends Node

# These are *with* the config subdirectory name
var xdg_data_home : String
var xdg_data_dirs : Array

# These are *without* the config subdirectory name
var raw_xdg_data_home : String
var raw_xdg_data_dirs : Array

# Default location for xdg_data_home relative to $HOME
const default_xdg_data_home_rel := ".local/share"
const default_xdg_data_dirs := ["/usr/local/share", "/usr/share"]

const config_subdir_name := "pixelorama"

const palettes_data_subdirectory := "Palettes"
const brushes_data_subdirectory := "Brushes"
const patterns_data_subdirectory := "Patterns"


# Get if we should use XDG standard or not nyaaaa
func use_xdg_standard() -> bool:
	# see: https://docs.godotengine.org/en/latest/getting_started/workflow/export/feature_tags.html
	# return OS.has_feature("Linux") or OS.has_feature("BSD")
	# Previous was unreliable and buggy >.< nyaa
	return OS.get_name() == "X11"


func _init() -> void:
	if use_xdg_standard():
		print("Detected system where we should use XDG basedir standard (currently Linux or BSD)")
		var home := OS.get_environment("HOME")
		raw_xdg_data_home = home.plus_file(
			default_xdg_data_home_rel
		)
		xdg_data_home = raw_xdg_data_home.plus_file(
			config_subdir_name
		)

		# Create defaults
		xdg_data_dirs = []
		raw_xdg_data_dirs = default_xdg_data_dirs
		for default_loc in raw_xdg_data_dirs:
			xdg_data_dirs.append(
				default_loc.plus_file(config_subdir_name)
			)

		# Now check the XDG environment variables and if
		# present, replace the defaults with them!
		# See: https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
		# Checks the xdg data home var
		if OS.has_environment("XDG_DATA_HOME"):
			raw_xdg_data_home = OS.get_environment("XDG_DATA_HOME")
			xdg_data_home = raw_xdg_data_home.plus_file(config_subdir_name)
		# Checks the list of files var, and processes them.
		if OS.has_environment("XDG_DATA_DIRS"):
			var raw_env_var := OS.get_environment("XDG_DATA_DIRS")
			# includes empties.
			var unappended_subdirs := raw_env_var.split(":", true)
			raw_xdg_data_dirs = unappended_subdirs
			xdg_data_dirs = []
			for unapp_subdir in raw_xdg_data_dirs:
				xdg_data_dirs.append(unapp_subdir.plus_file(config_subdir_name))
		xdg_data_dirs.append(Global.root_directory.plus_file(config_subdir_name))

	else:
		raw_xdg_data_home = Global.root_directory
		xdg_data_home = raw_xdg_data_home.plus_file(config_subdir_name)
		raw_xdg_data_dirs = []
		xdg_data_dirs = []


func append_file_to_all(basepaths: Array, subpath: String) -> Array:
	var res := []
	for _path in basepaths:
		res.append(_path.plus_file(subpath))
	return res


# Get search paths in order of priority
func get_search_paths_in_order() -> Array:
	return [xdg_data_home] + xdg_data_dirs


# Gets the paths, in order of search priority, for palettes.
func get_palette_search_path_in_order() -> Array:
	var base_paths := get_search_paths_in_order()
	return append_file_to_all(base_paths, palettes_data_subdirectory)


# Gets the paths, in order of search priority, for brushes.
func get_brushes_search_path_in_order() -> Array:
	var base_paths := get_search_paths_in_order()
	return append_file_to_all(base_paths, brushes_data_subdirectory)


# Gets the paths, in order of search priority, for patterns.
func get_patterns_search_path_in_order() -> Array:
	var base_paths := get_search_paths_in_order()
	return append_file_to_all(base_paths, patterns_data_subdirectory)


# Get the path that we are ok to be writing palettes to:
func get_palette_write_path() -> String:
	return xdg_data_home.plus_file(palettes_data_subdirectory)


# Get the path that we are ok to be writing brushes to:
func get_brushes_write_path() -> String:
	return xdg_data_home.plus_file(brushes_data_subdirectory)


# Get the path that we are ok to be writing patterns to:
func get_patterns_write_path() -> String:
	return xdg_data_home.plus_file(patterns_data_subdirectory)


# Ensure the user xdg directories exist:
func ensure_xdg_user_dirs_exist() -> void:
	if !OS.has_feature("standalone"): # Don't execute if we're in the editor
		return

	var base_dir := Directory.new()
	base_dir.open(raw_xdg_data_home)
	# Ensure the main config directory exists.
	if not base_dir.dir_exists(xdg_data_home):
		base_dir.make_dir(xdg_data_home)

	var actual_data_dir := Directory.new()
	actual_data_dir.open(xdg_data_home)
	var palette_writing_dir := get_palette_write_path()
	var brushes_writing_dir := get_brushes_write_path()
	var pattern_writing_dir := get_patterns_write_path()
	# Create the palette and brush dirs
	if not actual_data_dir.dir_exists(palette_writing_dir):
		print("Making directory %s" % [palette_writing_dir])
		actual_data_dir.make_dir(palette_writing_dir)
	if not actual_data_dir.dir_exists(brushes_writing_dir):
		print("Making directory %s" % [brushes_writing_dir])
		actual_data_dir.make_dir(brushes_writing_dir)
	if not actual_data_dir.dir_exists(pattern_writing_dir):
		print("Making directory %s" % [pattern_writing_dir])
		actual_data_dir.make_dir(pattern_writing_dir)
