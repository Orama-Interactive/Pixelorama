extends WindowDialog

var palette_button = preload("res://src/Palette/PaletteButton.tscn")

var current_palette : String
var current_swatch := -1
var working_palette : Palette

onready var color_picker = $VBoxContainer/HBoxContainer/EditPaletteColorPicker
onready var palette_grid = $VBoxContainer/HBoxContainer/VBoxContainer/Panel/ScrollContainer/EditPaletteGridContainer
onready var color_name_edit = $VBoxContainer/PaletteOptions/EditPaletteColorNameLineEdit
onready var palette_name_edit = $VBoxContainer/PaletteOptions/EditPaletteNameLineEdit
onready var left_color_button = $VBoxContainer/HBoxContainer/VBoxContainer/CenterContainer/HBoxContainer/LeftColor/NinePatchRect
onready var right_color_button = $VBoxContainer/HBoxContainer/VBoxContainer/CenterContainer/HBoxContainer/RightColor/NinePatchRect
onready var dummyBtn = $DummyBtn


func _ready() -> void:
	$VBoxContainer/HBoxContainer/EditPaletteColorPicker.presets_visible = false


func open(palette : String) -> void:
	current_palette = palette
	palette_name_edit.text = current_palette
	if Global.palettes.has(palette):
		working_palette = Global.palettes[palette].duplicate()
		_display_palette()
		self.popup_centered()
		Global.dialog_open(true)

	left_color_button.modulate = Tools.get_assigned_color(BUTTON_LEFT)
	right_color_button.modulate = Tools.get_assigned_color(BUTTON_RIGHT)


func _display_palette() -> void:
	_clear_swatches()
	var index := 0

	for color_data in working_palette.colors:
		var color = color_data.color
		var new_button = palette_button.instance()

		new_button.color = color
		new_button.get_child(0).modulate = color
		new_button.hint_tooltip = color_data.data.to_upper() + " " + color_data.name
		new_button.draggable = true
		new_button.index = index
		new_button.connect("on_drop_data", self, "on_move_swatch")
		new_button.connect("pressed", self, "on_swatch_select", [new_button])
		new_button.group = dummyBtn.group

		palette_grid.add_child(new_button)
		index += 1

	if index > 0: # If there are colors, select the first
		on_swatch_select(palette_grid.get_child(0))


func _clear_swatches() -> void:
	for child in palette_grid.get_children():
		if child is BaseButton and child.text != "Dummy":
			child.disconnect("on_drop_data", self, "on_move_swatch")
			child.queue_free()


func on_swatch_select(new_button) -> void:
	current_swatch = new_button.index
	color_name_edit.text = working_palette.get_color_name(current_swatch)
	color_picker.color = working_palette.get_color(current_swatch)


func on_move_swatch(from : int, to : int) -> void:
	working_palette.move_color(from, to)
	palette_grid.move_child(palette_grid.get_child(from), to)
	current_swatch = to

	re_index_swatches()


func _on_AddSwatchButton_pressed() -> void:
	var color : Color = color_picker.color
	var new_index : int = working_palette.colors.size()
	working_palette.add_color(color)

	var new_button = palette_button.instance()

	new_button.color = color
	new_button.get_child(0).modulate = color
	new_button.hint_tooltip = "#" + working_palette.get_color_data(new_index).to_upper() + " " + working_palette.get_color_name(new_index)
	new_button.draggable = true
	var index : int = palette_grid.get_child_count()
	new_button.index = index
	new_button.connect("on_drop_data", self, "on_move_swatch")
	new_button.connect("pressed", self, "on_swatch_select", [new_button])
	new_button.group = dummyBtn.group

	palette_grid.add_child(new_button)
	on_swatch_select(new_button)


func _on_RemoveSwatchButton_pressed() -> void:
	if working_palette.colors.size() > 0:
		working_palette.remove_color(current_swatch)
		palette_grid.remove_child(palette_grid.get_child(current_swatch))
		re_index_swatches()

		if current_swatch == working_palette.colors.size():
			current_swatch -= 1

		if current_swatch >= 0:
			on_swatch_select(palette_grid.get_child(current_swatch))


func re_index_swatches() -> void:
	# Re-index swatches with new order
	var index := 0
	for child in palette_grid.get_children():
		child.index = index
		index += 1


# Rename a palette, copying to user directory if necessary.
func rename_palette_file_with_priority_dirs(old_fname: String, new_fname: String) -> void:
	var user_write_directory: String = Global.directory_module.get_palette_write_path()
	var usrwrite_dir := Directory.new()
	usrwrite_dir.open(user_write_directory)
	if usrwrite_dir.file_exists(old_fname):
		usrwrite_dir.rename(old_fname, new_fname)
	else:
		# Scan through the main system directories
		var priority_dirs : Array = Global.directory_module.get_palette_search_path_in_order()
		var best_clone_location = Global.palette_container.get_best_palette_file_location(
			priority_dirs,
			old_fname
		)
		if best_clone_location != null:
			usrwrite_dir.copy(best_clone_location, new_fname)


func _on_EditPaletteSaveButton_pressed() -> void:
	if palette_name_edit.text != current_palette:
		Global.palettes.erase(current_palette)
		rename_palette_file_with_priority_dirs(
			current_palette + ".json",
			palette_name_edit.text + ".json"
		)
		current_palette = palette_name_edit.text
		working_palette.name = current_palette

		var optionbutton_index = Global.palette_option_button.selected
		Global.palette_option_button.set_item_text(optionbutton_index, current_palette)
		Global.palette_option_button.set_item_metadata(optionbutton_index, current_palette)
		Global.palette_option_button.text = current_palette

	Global.palettes[current_palette] = working_palette
	Global.palette_container.on_palette_select(current_palette)
	Global.palette_container.save_palette(current_palette, working_palette.name + ".json")
	self.hide()


func _on_EditPaletteCancelButton_pressed() -> void:
	self.hide()


func _on_EditPaletteColorNameLineEdit_text_changed(new_text : String) -> void:
	if current_swatch >= 0 && current_swatch < working_palette.colors.size():
		working_palette.set_color_name(current_swatch, new_text)
		_refresh_hint_tooltip(current_swatch)


func _on_EditPaletteColorPicker_color_changed(color : Color) -> void:
	if current_swatch >= 0 && current_swatch < working_palette.colors.size():
		palette_grid.get_child(current_swatch).get_child(0).modulate = color
		working_palette.set_color(current_swatch, color)
		_refresh_hint_tooltip(current_swatch)


func _refresh_hint_tooltip(_index : int) -> void:
	palette_grid.get_child(current_swatch).hint_tooltip = "#" + working_palette.get_color_data(current_swatch).to_upper() + " " + working_palette.get_color_name(current_swatch)


func _on_LeftColor_pressed() -> void:
	color_picker.color = Tools.get_assigned_color(BUTTON_LEFT)
	_on_EditPaletteColorPicker_color_changed(color_picker.color)


func _on_RightColor_pressed() -> void:
	color_picker.color = Tools.get_assigned_color(BUTTON_RIGHT)
	_on_EditPaletteColorPicker_color_changed(color_picker.color)


func _on_EditPalettePopup_popup_hide() -> void:
	Global.dialog_open(false)
