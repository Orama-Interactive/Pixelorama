extends GridContainer

var palette_button = preload("res://Prefabs/PaletteButton.tscn");

var current_palette = "Default"
var from_palette : = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_load_palettes()

	#Select default palette "Default"
	on_palette_select(current_palette)

func _clear_swatches() -> void:
	for child in get_children():
		if child is BaseButton:
			child.disconnect("pressed", self, "on_color_select")
			child.queue_free()

func on_palette_select(palette_name : String) -> void:
	_clear_swatches()
	if Global.palettes.has(palette_name): #Palette exists in memory
		current_palette = palette_name
		var palette : Dictionary = Global.palettes[palette_name]

		Global.remove_palette_button.disabled = true # Cannot remove by default
		if palette.has("editable"):
			if palette.editable:
				Global.remove_palette_button.disabled = false # Can remove if custom palette

		_display_palette(palette)
	else: #Use default on fail
		current_palette = "Default"
		_display_palette(Global.palettes["Default"])

func on_edit_palette() -> void:
	var palette : Dictionary = Global.palettes[current_palette]

	var create_new_palette := true # Create new palette by default
	if palette.has("editable"):
		if palette.editable:
			create_new_palette = false # Edit if already a custom palette

	if create_new_palette:
		from_palette = Global.palettes[current_palette]
		Global.new_palette_name_line_edit.text = "Custom_" + current_palette
		Global.new_palette_dialog.popup_centered()
	else:
		from_palette = {}
		Global.edit_palette_popup.open(current_palette)

func on_new_palette_confirmed() -> void:
	var new_palette_name : String = Global.new_palette_name_line_edit.text
	var result : String = create_new_palette(new_palette_name, from_palette)
	if not result.empty():
		Global.error_dialog.set_text(result);
		Global.error_dialog.popup_centered()

func create_new_palette(name : String, from_palette : Dictionary = {}) -> String: # Returns empty string, else error string
	var new_palette : Dictionary = {}

	# Check if new name is valid
	if name.empty():
		return "Error: Palette must have a valid name."
	if Global.palettes.has(name):
		return "Error: Palette '" + name + "' already exists!"

	new_palette.name = name

	# Check if source palette has data
	if from_palette.has("name"):
		new_palette = from_palette.duplicate()
		new_palette.name = name
		new_palette.editable = true
	else:
		new_palette.colors = []
		new_palette.comments = ""
		new_palette.editable = true

	# Add palette to Global and options
	Global.palettes[name] = new_palette
	Global.palette_option_button.add_item(name)
	var index := Global.palette_option_button.get_item_count() - 1
	Global.palette_option_button.set_item_metadata(index, name)
	Global.palette_option_button.select(index)

	save_palette(name, name + ".json")

	on_palette_select(name)
	return ""

func _display_palette(palette : Dictionary) -> void:
	var index := 0

	for color_data in palette.colors:
		var color = Color(color_data.data)
		var new_button = palette_button.instance()

		new_button.get_child(0).modulate = color
		new_button.hint_tooltip = color_data.data.to_upper() + " " + color_data.name
		new_button.connect("pressed", self, "on_color_select", [index])

		add_child(new_button)
		index += 1

func on_color_select(index : int) -> void:
	var color = Color(Global.palettes[current_palette].colors[index].data)

	if Input.is_action_just_released("left_mouse"):
		Global.left_color_picker.color = color
		Global.update_left_custom_brush()
	elif Input.is_action_just_released("right_mouse"):
		Global.right_color_picker.color = color
		Global.update_right_custom_brush()

func _load_palettes() -> void:
	var file := File.new()
	var dir := Directory.new()

	if not dir.dir_exists("user://palettes"):
		dir.make_dir("user://palettes");
	if not dir.dir_exists("user://palettes/custom"):
		dir.make_dir("user://palettes/custom")
	if not file.file_exists("user://palettes/default_palette.json"):
		dir.copy("res://Assets/Graphics/Palette/default_palette.json","user://palettes/default_palette.json");
	if not file.file_exists("user://palettes/bubblegum16.json"):
		dir.copy("res://Assets/Graphics/Palette/bubblegum16.json","user://palettes/bubblegum16.json");

	var palette_files : Array = get_palette_files("user://palettes")

	for file_name in palette_files:
		var result : String = load_palette("user://palettes/" + file_name)
		if result:
			Global.palette_option_button.add_item(result)
			var index := Global.palette_option_button.get_item_count() - 1
			Global.palette_option_button.set_item_metadata(index, result)
			if result == "Default":
				Global.palette_option_button.select(index)

	dir.open("user://palettes/custom")
	var custom_palette_files : Array = get_palette_files("user://palettes/custom")

	for file_name in custom_palette_files:
		var result : String = load_palette("user://palettes/custom/" + file_name)
		if result:
			Global.palette_option_button.add_item(result)
			var index := Global.palette_option_button.get_item_count() - 1
			Global.palette_option_button.set_item_metadata(index, result)

func get_palette_files(path : String) -> Array:
	var dir := Directory.new()
	var results = []

	dir.open(path)
	dir.list_dir_begin()

	while true:
		var file_name = dir.get_next()
		if file_name == "":
			break
		elif not file_name.begins_with(".") && file_name.to_lower().ends_with("json"):
			results.append(file_name)

	dir.list_dir_end()

	return results

func load_palette(path : String) -> String:
	# Open file for reading
	var file := File.new()
	file.open(path, File.READ)

	var text = file.get_as_text()
	var result_json = JSON.parse(text)
	var result = {}

	var palette_name = null # Default error condition

	if result_json.error != OK:  # If parse has errors
		print("Error: ", result_json.error)
		print("Error Line: ", result_json.error_line)
		print("Error String: ", result_json.error_string)
	else:  # If parse OK
		var data = result_json.result
		if data.has("name"): #If data is 'valid' palette file
			palette_name = data.name
			Global.palettes[data.name] = data

	file.close()

	return palette_name

func remove_current_palette() -> void:
	if Global.palettes[current_palette].has("editable"):
		if Global.palettes[current_palette].editable:
			_delete_palette_file(current_palette + ".json")
			Global.palettes.erase(current_palette)
			var selected_index := Global.palette_option_button.selected
			Global.palette_option_button.remove_item(selected_index)
			if(selected_index - 1 >= 0):
				Global.palette_option_button.select(selected_index - 1)
				on_palette_select(Global.palette_option_button.get_item_metadata(selected_index - 1))
	pass

func _delete_palette_file(file_name : String) -> void:
	var dir = Directory.new()
	dir.remove("user://palettes/custom/" + file_name)

func save_palette(palette_name : String, filename : String) -> void:
	var palette_data = Global.palettes[palette_name]
	# Open file for writing
	var file := File.new()
	file.open("user://palettes/custom/" + filename, File.WRITE)

	# Write palette data to file
	file.store_string(JSON.print(palette_data))
	file.close()
