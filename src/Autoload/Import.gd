extends Node


# Get hold of the brushes, including random brushes (subdirectories and % files
# in them, non % files get loaded independently.) nyaaa
# Returns a list of [
# [non random single png files in the root subdir],
# {
# map of subdirectories to lists of files for
# the randomised brush - if a directory contains no
# randomised files then it is not included in this.
# },
# {
# map of subdirectories to lists of files inside of them
# that are not for randomised brushes.
# }
# ]
# The separation of nonrandomised and randomised files
# in subdirectories allows different XDG_DATA_DIR overriding
# for each nyaa.
#
# Returns null if the directory gave an error opening.
#
func get_brush_files_from_directory(directory: String):  # -> Array
	var base_png_files := []  # list of files in the base directory
	var subdirectories := []  # list of subdirectories to process.

	var randomised_subdir_files_map: Dictionary = {}
	var nonrandomised_subdir_files_map: Dictionary = {}

	var main_directory := DirAccess.open(directory)
	if DirAccess.get_open_error() != OK:
		return null

	# Build first the list of base png files and all subdirectories to
	# scan later (skip navigational . and ..)
	main_directory.list_dir_begin()
	var fname: String = main_directory.get_next()
	while fname != "":
		if main_directory.current_is_dir():
			subdirectories.append(fname)
		else:  # Filter for pngs
			if fname.get_extension().to_lower() == "png":
				base_png_files.append(fname)

		# go to next
		fname = main_directory.get_next()
	main_directory.list_dir_end()

	# Now we iterate over subdirectories!
	for subdirectory in subdirectories:
		# Holds names of files that make this
		# a component of a randomised brush ^.^
		var randomised_files := []

		# Non-randomise-indicated image files
		var non_randomised_files := []

		var the_directory := DirAccess.open(directory.path_join(subdirectory))
		the_directory.include_navigational = true
		the_directory.list_dir_begin()
		var curr_file := the_directory.get_next()

		while curr_file != "":
			# only do stuff if we are actually dealing with a file
			# and png one at that nya
			if !the_directory.current_is_dir() and curr_file.get_extension().to_lower() == "png":
				# if we are a random element, add
				if "~" in curr_file:
					randomised_files.append(curr_file)
				else:
					non_randomised_files.append(curr_file)
			curr_file = the_directory.get_next()

		the_directory.list_dir_end()

		# Add these to the maps nyaa
		if len(randomised_files) > 0:
			randomised_subdir_files_map[subdirectory] = randomised_files
		if len(non_randomised_files) > 0:
			nonrandomised_subdir_files_map[subdirectory] = non_randomised_files
	# We are done generating the maps!
	return [base_png_files, randomised_subdir_files_map, nonrandomised_subdir_files_map]


# Add a randomised brush from the given list of files as a source.
# The tooltip name is what shows up on the tooltip
# and is probably in this case the name of the containing
# randomised directory.
func add_randomised_brush(fpaths: Array, tooltip_name: String) -> void:
	# Attempt to load the images from the file paths.
	var loaded_images: Array = []
	for file in fpaths:
		var image := Image.new()
		var err := image.load(file)
		if err == OK:
			image.convert(Image.FORMAT_RGBA8)
			loaded_images.append(image)

	# If any images were successfully loaded, then
	# we create the randomised brush button, copied
	# from find_brushes.

	if len(loaded_images) > 0:  # actually have images
		# to use.
		Brushes.add_file_brush(loaded_images, tooltip_name)


# Add a plain brush from the given path to the list of brushes.
# Taken, again, from find_brushes
func add_plain_brush(path: String, tooltip_name: String) -> void:
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		return
	# do the standard conversion thing...
	image.convert(Image.FORMAT_RGBA8)
	Brushes.add_file_brush([image], tooltip_name)


# Import brushes, in priority order, from the paths in question in priority order
# i.e. with an override system
# We use a very particular override system here where, for randomised brushes
# the directories containing them get overridden, but for nonrandomised files
# (including in directories containing randomised components too), the override
# is on a file-by-file basis nyaaaa ^.^
func import_brushes(priority_ordered_search_path: Array) -> void:
	# Maps for files in the base directory (name : true)
	var processed_basedir_paths: Dictionary = {}
	var randomised_brush_subdirectories: Dictionary = {}
	# Map from a subdirectory to a map similar to processed_basedir_files
	# i.e. once a filename has been dealt with, set it to true.
	var processed_subdir_paths: Dictionary = {}

	# Sets of results of get_brush_files_from_directory
	var all_available_paths: Array = []
	for directory in priority_ordered_search_path:
		all_available_paths.append(get_brush_files_from_directory(directory))

	# Now to process. Note these are in order of the
	# priority, as intended nyaa :)
	for i in range(len(all_available_paths)):
		var available_brush_file_information = all_available_paths[i]
		var current_main_directory: String = priority_ordered_search_path[i]
		if available_brush_file_information != null:
			# The brush files in the main directory
			var main_directory_file_paths: Array = available_brush_file_information[0]
			# The subdirectory/list-of-randomised-brush-files
			# map for this directory
			var randomised_brush_subdirectory_map: Dictionary = available_brush_file_information[1]
			# Map for subdirectories to non-randomised-brush files nyaa
			var nonrandomised_brush_subdir_map: Dictionary = available_brush_file_information[2]

			# Iterate over components and do stuff with them! nyaa
			# first for the main directory path...
			for subfile in main_directory_file_paths:
				if not (subfile in processed_basedir_paths):
					add_plain_brush(
						current_main_directory.path_join(subfile), subfile.get_basename()
					)
					processed_basedir_paths[subfile] = true

			# Iterate over the randomised brush files nyaa
			for randomised_subdir in randomised_brush_subdirectory_map:
				if not (randomised_subdir in randomised_brush_subdirectories):
					var full_paths := []
					# glue the proper path onto the single file names in the
					# random brush directory data system, so they can be
					# opened nya
					for non_extended_path in randomised_brush_subdirectory_map[randomised_subdir]:
						full_paths.append(
							current_main_directory.path_join(randomised_subdir).path_join(
								non_extended_path
							)
						)
					# Now load!
					add_randomised_brush(full_paths, randomised_subdir)
					# and mark that we are done in the overall map ^.^
					randomised_brush_subdirectories[randomised_subdir] = true
			# Now to iterate over the nonrandom brush files inside directories
			for nonrandomised_subdir in nonrandomised_brush_subdir_map:
				# initialise the set-map for this one if not already present :)
				if not (nonrandomised_subdir in processed_subdir_paths):
					processed_subdir_paths[nonrandomised_subdir] = {}
				# Get the paths within this subdirectory to check if they are
				# processed or not and if not, then process them.
				var relpaths_of_nonrandom_brushes: Array = nonrandomised_brush_subdir_map[nonrandomised_subdir]
				for relative_path in relpaths_of_nonrandom_brushes:
					if not (relative_path in processed_subdir_paths[nonrandomised_subdir]):
						# We are not yet processed
						var full_path: String = (
							current_main_directory
							. path_join(nonrandomised_subdir)
							. path_join(relative_path)
						)
						# Add the path with the tooltip including the directory
						add_plain_brush(
							full_path, nonrandomised_subdir.path_join(relative_path).get_basename()
						)
						# Mark this as a processed relpath
						processed_subdir_paths[nonrandomised_subdir][relative_path] = true


func import_patterns(priority_ordered_search_path: Array) -> void:
	for path in priority_ordered_search_path:
		var pattern_list := []
		var dir := DirAccess.open(path)
		if not is_instance_valid(dir):
			continue
		dir.list_dir_begin()
		var curr_file := dir.get_next()
		while curr_file != "":
			if curr_file.get_extension().to_lower() == "png":
				pattern_list.append(curr_file)
			curr_file = dir.get_next()
		dir.list_dir_end()

		for pattern in pattern_list:
			var image := Image.new()
			var err := image.load(path.path_join(pattern))
			if err == OK:
				image.convert(Image.FORMAT_RGBA8)
				var tooltip_name = pattern.get_basename()
				Global.patterns_popup.add(image, tooltip_name)


## Gets frame [member indices] of [member from_project] and dumps it in the current project.
func copy_frames_to_current_project(
	from_project: Project, indices: Array, destination: int, new_tag_from: AnimationTag = null
) -> void:
	var project: Project = Global.current_project
	if !project:
		return
	if from_project == project:  ## If we are copying tags within project
		Global.animation_timeline.copy_frames(indices, destination, true, new_tag_from)
		return
	var new_animation_tags := project.animation_tags.duplicate()
	# Loop through the tags to create new classes for them, so that they won't be the same
	# as project.animation_tags's classes. Needed for undo/redo to work properly.
	for i in new_animation_tags.size():
		new_animation_tags[i] = AnimationTag.new(
			new_animation_tags[i].name,
			new_animation_tags[i].color,
			new_animation_tags[i].from,
			new_animation_tags[i].to
		)
	var imported_frames: Array[Frame] = []  # The copied frames
	# the indices of newly copied frames
	var copied_indices: PackedInt32Array = range(
		destination + 1, (destination + 1) + indices.size()
	)
	project.undo_redo.create_action("Import Frames")
	# Step 1: calculate layers to generate
	var layer_to_names := PackedStringArray()  # names of currently existing layers
	for l in project.layers:
		layer_to_names.append(l.name)

	# the goal of this section is to mark existing layers with their indices else with -1
	var layer_from_to := {}  # indices of layers from and to
	for from in from_project.layers.size():
		var to := -1
		var pos := 0
		for i in layer_to_names.count(from_project.layers[from].name):
			pos = layer_to_names.find(from_project.layers[from].name, pos)
			# if layer types don't match, the destination is invalid.
			if project.layers[pos].get_layer_type() != from_project.layers[from].get_layer_type():
				# Don't give up if there is another layer with the same name, check that one as well
				pos += 1
				continue
			# if destination is already assigned to another layer, then don't use it here.
			if pos in layer_from_to.values():
				# Don't give up if there is another layer with the same name, check that one as well
				pos += 1
				continue
			to = pos
			break
		layer_from_to[from] = to

	# Step 2: generate required layers
	var combined_copy := Array()  # Makes calculations easy (contains preview of final layer order).
	combined_copy.append_array(project.layers)
	var added_layers := Array()  # Array of layers
	# Array of indices to add the respective layers (in added_layers) to
	var added_idx := PackedInt32Array()
	var added_cels := Array()  # Array of an Array of cels (added in same order as their layer)

	# Create destinations for layers that don't have one yet
	if layer_from_to.values().count(-1) > 0:
		# As it is extracted from a dictionary, so i assume the keys aren't sorted
		var from_layers_size = layer_from_to.keys().duplicate(true)
		from_layers_size.sort()  # it's values should now be from (layer size - 1) to zero
		for i in from_layers_size:
			if layer_from_to[i] == -1:
				var from_layer := from_project.layers[i]
				var type = from_layer.get_layer_type()
				var l: BaseLayer
				match type:
					Global.LayerTypes.PIXEL:
						l = PixelLayer.new(project)
					Global.LayerTypes.GROUP:
						l = GroupLayer.new(project)
					Global.LayerTypes.THREE_D:
						l = Layer3D.new(project)
					Global.LayerTypes.TILEMAP:
						l = LayerTileMap.new(project, from_layer.tileset)
						l.place_only_mode = from_layer.place_only_mode
						l.tile_size = from_layer.tile_size
						l.tile_shape = from_layer.tile_shape
						l.tile_layout = from_layer.tile_layout
						l.tile_offset_axis = from_layer.tile_offset_axis
					Global.LayerTypes.AUDIO:
						l = AudioLayer.new(project)
						l.audio = from_layer.audio
				if l == null:  # Ignore copying this layer if it isn't supported
					continue
				var cels := []
				for f in project.frames:
					cels.append(l.new_empty_cel())
				l.name = from_project.layers[i].name  # this will set it to the required layer name

				# Set an appropriate parent
				var new_layer_idx = combined_copy.size()
				layer_from_to[i] = new_layer_idx
				var from_children = from_project.layers[i].get_children(false)
				for from_child in from_children:  # If this layer had children
					var child_to_idx = layer_from_to[from_project.layers.find(from_child)]
					var to_child = combined_copy[child_to_idx]
					if to_child in added_layers:  # if child was added recently
						to_child.parent = l

				combined_copy.insert(new_layer_idx, l)
				added_layers.append(l)  # layer is now added
				added_idx.append(new_layer_idx)  # at index new_layer_idx
				added_cels.append(cels)  # with cels

	# Now initiate import
	for f in indices:
		var src_frame: Frame = from_project.frames[f]
		var new_frame := Frame.new()
		imported_frames.append(new_frame)
		new_frame.duration = src_frame.duration
		for to in combined_copy.size():
			var new_cel: BaseCel
			if to in layer_from_to.values():  # We have data to Import to this layer index
				var from = layer_from_to.find_key(to)
				# Cel we're copying from, the source
				var src_cel: BaseCel = from_project.frames[f].cels[from]
				new_cel = src_cel.duplicate_cel()
				if src_cel is Cel3D:
					new_cel.size_changed(project.size)
				elif src_cel is CelTileMap:
					var copied_content := src_cel.copy_content() as Array
					var src_img: ImageExtended = copied_content[0]
					var empty := project.new_empty_image()
					var copy := ImageExtended.new()
					copy.copy_from_custom(empty, project.is_indexed())
					copy.blit_rect(src_img, Rect2(Vector2.ZERO, src_img.get_size()), Vector2.ZERO)
					new_cel.set_content([copy, copied_content[1]])
					new_cel.set_indexed_mode(project.is_indexed())
				else:
					# Add more types here if they have a copy_content() method.
					if src_cel is PixelCel:
						var src_img: ImageExtended = src_cel.copy_content()
						var empty := project.new_empty_image()
						var copy := ImageExtended.new()
						copy.copy_from_custom(empty, project.is_indexed())
						copy.blit_rect(
							src_img, Rect2(Vector2.ZERO, src_img.get_size()), Vector2.ZERO
						)
						new_cel.set_content(copy)
						new_cel.set_indexed_mode(project.is_indexed())

			else:
				new_cel = combined_copy[to].new_empty_cel()
			new_frame.cels.append(new_cel)

		for tag in new_animation_tags:  # Loop through the tags to see if the frame is in one
			if copied_indices[0] >= tag.from && copied_indices[0] <= tag.to:
				tag.to += 1
			elif copied_indices[0] < tag.from:
				tag.from += 1
				tag.to += 1
	if new_tag_from:
		new_animation_tags.append(
			AnimationTag.new(
				new_tag_from.name, new_tag_from.color, copied_indices[0] + 1, copied_indices[-1] + 1
			)
		)
	project.undo_redo.add_undo_method(project.remove_frames.bind(copied_indices))
	project.undo_redo.add_do_method(project.add_layers.bind(added_layers, added_idx, added_cels))
	project.undo_redo.add_do_method(project.add_frames.bind(imported_frames, copied_indices))
	project.undo_redo.add_undo_method(project.remove_layers.bind(added_idx))
	# Note: temporarily set the selected cels to an empty array (needed for undo/redo)
	project.undo_redo.add_do_property(Global.current_project, "selected_cels", [])
	project.undo_redo.add_undo_property(Global.current_project, "selected_cels", [])

	var all_new_cels := []
	# Select all the new frames so that it is easier to move/offset collectively if user wants
	# To ease animation workflow, new current frame is the first copied frame instead of the last
	var range_start: int = copied_indices[-1]
	var range_end: int = copied_indices[0]
	var frame_diff_sign := signi(range_end - range_start)
	if frame_diff_sign == 0:
		frame_diff_sign = 1
	for i in range(range_start, range_end + frame_diff_sign, frame_diff_sign):
		for j in range(0, combined_copy.size()):
			var frame_layer := [i, j]
			if !all_new_cels.has(frame_layer):
				all_new_cels.append(frame_layer)
	project.undo_redo.add_do_property(Global.current_project, "selected_cels", all_new_cels)
	project.undo_redo.add_undo_method(
		project.change_cel.bind(project.current_frame, project.current_layer)
	)
	project.undo_redo.add_do_method(project.change_cel.bind(range_end))
	project.undo_redo.add_do_property(project, "animation_tags", new_animation_tags)
	project.undo_redo.add_undo_property(project, "animation_tags", project.animation_tags)
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()
