extends GridContainer

var palette_button = preload("res://Prefabs/PaletteButton.tscn");

var current_palette = "Default"

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
		_display_palette(Global.palettes[palette_name])
	else: #Use default on fail
		current_palette = "Default"
		_display_palette(Global.palettes["Default"])

func _display_palette(palette : Array) -> void:
	var index := 0
	
	for color_data in palette:
		var color = Color(color_data.data)
		var new_button = palette_button.instance()
		
		new_button.get_child(0).modulate = color
		new_button.hint_tooltip = color_data.data.to_upper() + " " + color_data.name
		new_button.connect("pressed", self, "on_color_select", [index])
		
		add_child(new_button)
		index += 1

func on_color_select(index : int) -> void:
	var color = Color(Global.palettes[current_palette][index].data)
	
	if Input.is_action_just_released("left_mouse"):
		Global.left_color_picker.color = color
		Global.update_left_custom_brush()
	elif Input.is_action_just_released("right_mouse"):
		Global.right_color_picker.color = color
		Global.update_right_custom_brush()

func _load_palettes() -> void:
	var files := []

	var dir := Directory.new()

	if not dir.dir_exists("user://palettes"):
		dir.make_dir("user://palettes");
		dir.make_dir("user://palettes/custom");
		dir.copy("res://Assets/Graphics/Palette/default_palette.json","user://palettes/default_palette.json");
		dir.copy("res://Assets/Graphics/Palette/bubblegum16.json","user://palettes/bubblegum16.json");

	dir.open("user://palettes")
	dir.list_dir_begin()

	while true:
		var file_name = dir.get_next()
		if file_name == "":
			break
		elif not file_name.begins_with(".") && file_name.to_lower().ends_with("json"):
			files.append(file_name)

	dir.list_dir_end()

	for file_name in files:
		var result : String = load_palette("user://palettes/" + file_name)
		if result:
			Global.palette_option_button.add_item(result)
			var index := Global.palette_option_button.get_item_count() - 1
			Global.palette_option_button.set_item_metadata(index, result)
			if result == "Default":
				Global.palette_option_button.select(index)

	for item in Global.palette_option_button.items:
		print(item)

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
			Global.palettes[data.name] = data.colors

	file.close()

	return palette_name

func _save_palette(palette : Array, name : String, path : String) -> void:
	# Open file for writing
	var file := File.new()
	file.open(path, File.WRITE)

	# Create palette data
	var data := {}
	data.name = name
	data.colors = palette

	# Write palette data to file
	file.store_string(JSON.print(data))
	file.close()
