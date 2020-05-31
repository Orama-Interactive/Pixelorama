extends GridContainer

const palette_button = preload("res://src/Palette/PaletteButton.tscn")

var current_palette = "Default"
var from_palette : Palette


func _ready() -> void:
	_load_palettes()

	# Select default palette "Default"
	on_palette_select(current_palette)

	var add_palette_menu : PopupMenu = Global.add_palette_button.get_node("PopupMenu")
	add_palette_menu.connect("id_pressed", self, "add_palette_menu_id_pressed")


func _clear_swatches() -> void:
	for child in get_children():
		if child is BaseButton:
			child.disconnect("pressed", self, "on_color_select")
			child.queue_free()


func on_palette_select(palette_name : String) -> void:
	_clear_swatches()
	if Global.palettes.has(palette_name): # Palette exists in memory
		current_palette = palette_name
		var palette : Palette = Global.palettes[palette_name]
		_display_palette(palette)


func on_new_empty_palette() -> void:
	Global.new_palette_dialog.window_title = "Create a new empty palette?"
	Global.new_palette_name_line_edit.text = "Custom_Palette"
	from_palette = null
	Global.new_palette_dialog.popup_centered()
	Global.dialog_open(true)


func on_import_palette() -> void:
	Global.palette_import_file_dialog.popup_centered()
	Global.dialog_open(true)


func on_palette_import_file_selected(path : String) -> void:
	var palette : Palette = null
	if path.to_lower().ends_with("json"):
		palette = Palette.new().load_from_file(path)
	elif path.to_lower().ends_with("gpl"):
		palette = Import.import_gpl(path)
	elif path.to_lower().ends_with("png"):
		palette = Import.import_png_palette(path)

	if palette:
		if not Global.palettes.has(palette.name):
			Global.palettes[palette.name] = palette
			Global.palette_option_button.add_item(palette.name)
			var index: int = Global.palette_option_button.get_item_count() - 1
			Global.palette_option_button.set_item_metadata(index, palette.name)
			Global.palette_option_button.select(index)
			on_palette_select(palette.name)
			save_palette(palette.name, palette.name + ".json")
		else:
			Global.error_dialog.set_text(tr("Error: Palette named '%s' already exists!") % palette.name)
			Global.error_dialog.popup_centered()
			Global.dialog_open(true)
	else:
		Global.error_dialog.set_text("Invalid Palette file!")
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)


func _on_AddPalette_pressed() -> void:
	Global.add_palette_button.get_node("PopupMenu").popup(Rect2(Global.add_palette_button.rect_global_position, Vector2.ONE))


func on_new_palette_confirmed() -> void:
	var new_palette_name : String = Global.new_palette_name_line_edit.text
	var result : String = create_new_palette(new_palette_name, from_palette)
	if not result.empty():
		Global.error_dialog.set_text(result)
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)


func add_palette_menu_id_pressed(id : int) -> void:
	match id:
		0:	# New Empty Palette
			Global.palette_container.on_new_empty_palette()
		1:	# Import Palette
			Global.palette_container.on_import_palette()


func create_new_palette(name : String, _from_palette : Palette) -> String: # Returns empty string, else error string
	var new_palette : Palette = Palette.new()

	# Check if new name is valid
	if name.empty():
		return tr("Error: Palette must have a valid name.")
	if Global.palettes.has(name):
		return tr("Error: Palette named '%s' already exists!") % name

	new_palette.name = name
	# Check if source palette has data
	if _from_palette:
		new_palette = _from_palette.duplicate()
		new_palette.name = name
		new_palette.editable = true

	# Add palette to Global and options
	Global.palettes[name] = new_palette
	Global.palette_option_button.add_item(name)
	var index : int = Global.palette_option_button.get_item_count() - 1
	Global.palette_option_button.set_item_metadata(index, name)
	Global.palette_option_button.select(index)

	save_palette(name, name + ".json")

	on_palette_select(name)
	return ""


func on_edit_palette() -> void:
	var palette : Palette = Global.palettes[current_palette]

	var create_new_palette := true # Create new palette by default
	if palette.editable:
		create_new_palette = false # Edit if already a custom palette

	if create_new_palette:
		from_palette = Global.palettes[current_palette]
		Global.new_palette_dialog.window_title = "Create a new custom palette from existing default?"
		Global.new_palette_name_line_edit.text = "Custom_" + current_palette
		Global.new_palette_dialog.popup_centered()
		Global.dialog_open(true)
	else:
		from_palette = null
		Global.edit_palette_popup.open(current_palette)


func _on_PaletteOptionButton_item_selected(ID : int) -> void:
	var palette_name = Global.palette_option_button.get_item_metadata(ID)
	if palette_name != null:
		on_palette_select(palette_name)


func _display_palette(palette : Palette) -> void:
	var index := 0

	for color_data in palette.colors:
		var color = color_data.color
		var new_button = palette_button.instance()

		new_button.get_child(0).modulate = color
		new_button.hint_tooltip = "#" + color_data.data.to_upper() + " " + color_data.name
		new_button.connect("pressed", self, "on_color_select", [index])

		add_child(new_button)
		index += 1


func on_color_select(index : int) -> void:
	var color : Color = Global.palettes[current_palette].get_color(index)

	if Input.is_action_just_pressed("left_mouse"):
		Global.color_pickers[0].color = color
		Global.update_left_custom_brush()
	elif Input.is_action_just_pressed("right_mouse"):
		Global.color_pickers[1].color = color
		Global.update_right_custom_brush()


func _load_palettes() -> void:
	Global.directory_module.ensure_xdg_user_dirs_exist()
	var search_locations = Global.directory_module.get_palette_search_path_in_order()
	var priority_ordered_files := get_palette_priority_file_map(search_locations)

	# Iterate backwards, so any palettes defined in default files
	# get overwritten by those of the same name in user files
	search_locations.invert()
	priority_ordered_files.invert()
	for i in range(len(search_locations)):
		var base_directory : String = search_locations[i]
		var palette_files : Array = priority_ordered_files[i]
		for file_name in palette_files:
			var palette : Palette = Palette.new().load_from_file(base_directory.plus_file(file_name))
			if palette:
				Global.palettes[palette.name] = palette
				Global.palette_option_button.add_item(palette.name)
				var index: int = Global.palette_option_button.get_item_count() - 1
				Global.palette_option_button.set_item_metadata(index, palette.name)
				if palette.name == "Default":
					# You need these two lines because when you remove a palette
					# Then this just won't work and _on_PaletteOptionButton_item_selected
					# method won't fire.
					Global.palette_option_button.selected = index
					on_palette_select("Default")
					Global.palette_option_button.select(index)

	if not "Default" in Global.palettes && Global.palettes.size() > 0:
		Global.palette_container._on_PaletteOptionButton_item_selected(0)


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
		elif (not file_name.begins_with(".")) && file_name.to_lower().ends_with("json") && not dir.current_is_dir():
			results.append(file_name)

	dir.list_dir_end()
	return results


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


# Locate the highest priority palette by the given relative filename
# If none is found in the directories, then do nothing and return
# null
func get_best_palette_file_location(looking_paths: Array, fname: String):  # -> String:
	var priority_fmap : Array = get_palette_priority_file_map(looking_paths)
	for i in range(len(looking_paths)):
		var base_path : String = looking_paths[i]
		var the_files : Array = priority_fmap[i]
		if the_files.has(fname):
			return base_path.plus_file(fname)

	return null


func remove_palette(palette_name : String) -> void:
	# Don't allow user to remove palette if there is no one left
	if Global.palettes.size() < 2:
		Global.error_dialog.set_text("You can't remove more palettes!")
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)
		return
	# Don't allow user to try to remove not existing palettes
	if not palette_name in Global.palettes:
		Global.error_dialog.set_text("Cannot remove the palette, because it doesn't exist!")
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)
		return
	Global.directory_module.ensure_xdg_user_dirs_exist()
	var palette = Global.palettes[palette_name]
	var result = palette.remove_file()
	# Inform user if pallete hasn't been removed from disk because of an error
	if result != OK:
		Global.error_dialog.set_text(tr("An error occured while removing the palette! Error code: %s") % str(result))
		Global.error_dialog.popup_centered()
		Global.dialog_open(true)
	# Remove palette in the program anyway, because if you don't do it
	# then Pixelorama will crash
	Global.palettes.erase(palette_name)
	Global.palette_option_button.clear()
	current_palette = "Default"
	_load_palettes()


func save_palette(palette_name : String, filename : String) -> void:
	Global.directory_module.ensure_xdg_user_dirs_exist()
	var palette = Global.palettes[palette_name]
	var palettes_write_path: String = Global.directory_module.get_palette_write_path()
	palette.save_to_file(palettes_write_path.plus_file(filename))


func _on_NewPaletteDialog_popup_hide() -> void:
	Global.dialog_open(false)


func _on_RemovePalette_pressed() -> void:
	remove_palette(current_palette)
