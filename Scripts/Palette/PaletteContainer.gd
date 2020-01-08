extends GridContainer

const palette_button = preload("res://Prefabs/PaletteButton.tscn");
const palettes_path := "Palettes"

var current_palette = "Default"
var from_palette : Palette

func _ready() -> void:
	_load_palettes()

	# Select default palette "Default"
	on_palette_select(current_palette)

	var add_palette_menu : PopupMenu = Global.add_palette_button.get_child(0)
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

func on_import_palette() -> void:
	Global.palette_import_file_dialog.popup_centered()

func on_palette_import_file_selected(path : String) -> void:
	var palette : Palette = null
	if path.to_lower().ends_with("json"):
		palette = Palette.new().load_from_file(path)
	elif path.to_lower().ends_with("gpl"):
		palette = Import.import_gpl(path)

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
	else:
		Global.error_dialog.set_text("Invalid Palette file!")
		Global.error_dialog.popup_centered()

func _on_AddPalette_pressed() -> void:
	Global.add_palette_button.get_child(0).popup(Rect2(Global.add_palette_button.rect_global_position, Vector2.ONE))

func on_new_palette_confirmed() -> void:
	var new_palette_name : String = Global.new_palette_name_line_edit.text
	var result : String = create_new_palette(new_palette_name, from_palette)
	if not result.empty():
		Global.error_dialog.set_text(result)
		Global.error_dialog.popup_centered()

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
	var palette : Dictionary = Global.palettes[current_palette]

	var create_new_palette := true # Create new palette by default
	if palette.editable:
		create_new_palette = false # Edit if already a custom palette

	if create_new_palette:
		from_palette = Global.palettes[current_palette]
		Global.new_palette_dialog.window_title = "Create a new custom palette from existing default?"
		Global.new_palette_name_line_edit.text = "Custom_" + current_palette
		Global.new_palette_dialog.popup_centered()
	else:
		from_palette = null
		Global.edit_palette_popup.open(current_palette)

func _on_PaletteOptionButton_item_selected(ID : int) -> void:
	var palette_name = Global.palette_option_button.get_item_metadata(ID)
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
		Global.left_color_picker.color = color
		Global.update_left_custom_brush()
	elif Input.is_action_just_pressed("right_mouse"):
		Global.right_color_picker.color = color
		Global.update_right_custom_brush()

func _load_palettes() -> void:
	var dir := Directory.new()
	dir.open(".")
	if not dir.dir_exists(palettes_path):
		dir.make_dir(palettes_path)

	var palette_files : Array = get_palette_files(palettes_path)

	for file_name in palette_files:
		var palette : Palette = Palette.new().load_from_file(palettes_path.plus_file(file_name))
		if palette:
			Global.palettes[palette.name] = palette
			Global.palette_option_button.add_item(palette.name)
			var index: int = Global.palette_option_button.get_item_count() - 1
			Global.palette_option_button.set_item_metadata(index, palette.name)
			if palette.name == "Default":
				Global.palette_option_button.select(index)

	if not "Default" in Global.palettes && Global.palettes.size() > 0:
		Global.control._on_PaletteOptionButton_item_selected(0)

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

func save_palette(palette_name : String, filename : String) -> void:
	var palette = Global.palettes[palette_name]
	palette.save_to_file(palettes_path.plus_file(filename))

