extends Node

var xdg_data_home : String
var xdg_data_dirs : Array

# Default location for xdg_data_home relative to $HOME
const default_xdg_data_home_rel := ".local/share"
const default_xdg_data_dirs := ["/usr/local/share", "/usr/share"]

const config_subdir_name := "pixelorama"

const palettes_data_subdirectory := "Palettes"
const brushes_data_subdirectory := "Brushes"

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	if OS.has_feature("X11"):
		var home := OS.get_environment("HOME")
		xdg_data_home = home.plus_file(
			default_xdg_data_home_rel
		).plus_file(
			config_subdir_name
		)
		
		# Create defaults
		xdg_data_dirs = []
		for default_loc in default_xdg_data_dirs:
			xdg_data_dirs.append(
				default_loc.plus_file(config_subdir_name)
			)
			
		# Now check the XDG environment variables and if
		# present, replace the defaults with them!
		# See: https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
		# Checks the xdg data home var
		if OS.has_environment("XDG_DATA_HOME"):
			xdg_data_home = OS.get_environment("XDG_DATA_HOME").plus_file(config_subdir_name)
		# Checks the list of files var, and processes them.
		if OS.has_environment("XDG_DATA_DIRS"):
			var raw_env_var := OS.get_environment("XDG_DATA_DIRS")
			# includes empties.
			var unappended_subdirs := raw_env_var.split(":", true)
			xdg_data_dirs = []
			for unapp_subdir in unappended_subdirs:
				xdg_data_dirs.append(unapp_subdir.plus_file(config_subdir_name))
			
	else:
		xdg_data_home = Global.root_directory
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
	

# Get the path that we are ok to be writing palettes to:
func get_palette_write_path() -> String:
	return xdg_data_home.plus_file(palettes_data_subdirectory)
	
# Get the path that we are ok to be writing brushes to:
func get_brushes_write_path() -> String:
	return xdg_data_home.plus_file(brushes_data_subdirectory)



# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
