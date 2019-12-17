extends WindowDialog

onready var palette_grid = $VBoxContainer/HBoxContainer/Panel/EditPaletteGridContainer
onready var color_name_edit = $VBoxContainer/HBoxContainer3/EditPaletteColorNameLineEdit
onready var color_picker = $VBoxContainer/HBoxContainer/EditPaletteColorPicker

var palette_button = preload("res://Prefabs/PaletteButton.tscn");

var current_palette : String
var current_swatch := -1
var working_palette : Dictionary


func open(palette : String) -> void:
	current_palette = palette
	if Global.palettes.has(palette):
		working_palette = Global.palettes[palette].duplicate()

		_display_palette()

		self.popup_centered()
	pass

func _display_palette() -> void:
	_clear_swatches()
	var index := 0

	for color_data in working_palette.colors:
		var color = Color(color_data.data)
		var new_button = palette_button.instance()

		new_button.color = color
		new_button.get_child(0).modulate = color
		new_button.hint_tooltip = color_data.data.to_upper() + " " + color_data.name
		new_button.draggable = true
		new_button.index = index
		new_button.connect("on_drop_data", self, "on_move_swatch")
		new_button.connect("pressed", self, "on_swatch_select", [index])

		palette_grid.add_child(new_button)
		index += 1

func _clear_swatches() -> void:
	for child in palette_grid.get_children():
		if child is BaseButton:
			child.disconnect("on_drop_data", self, "on_move_swatch")
			child.queue_free()

func on_swatch_select(index : int) -> void:
	current_swatch = index
	color_name_edit.text = working_palette.colors[index].name
	color_picker.color = working_palette.colors[index].data
	pass

func on_move_swatch(from : int, to : int) -> void:
	var color_to_move = working_palette.colors[from]
	working_palette.colors.remove(from)
	working_palette.colors.insert(to, color_to_move)

	palette_grid.move_child(palette_grid.get_child(from), to)

	# Re-index swatches with new order
	var index := 0
	for child in palette_grid.get_children():
		child.index = index
		index += 1
	pass

func _on_AddSwatchButton_pressed() -> void:
	var color = Color.white
	var color_data = {}
	color_data.data = color.to_html(true)
	color_data.name = "no name"
	working_palette.colors.push_back(color_data)
	var new_button = palette_button.instance()

	new_button.color = color
	new_button.get_child(0).modulate = color
	new_button.hint_tooltip = color_data.data.to_upper() + " " + color_data.name
	new_button.draggable = true
	var index : int = palette_grid.get_child_count()
	new_button.index = index
	new_button.connect("on_drop_data", self, "on_move_swatch")
	new_button.connect("pressed", self, "on_swatch_select", [index])

	palette_grid.add_child(new_button)
	pass # Replace with function body.

func _on_RemoveSwatchButton_pressed() -> void:
	working_palette.colors.remove(current_swatch)
	palette_grid.remove_child(palette_grid.get_child(current_swatch))
	pass # Replace with function body.

func _on_EditPaletteSaveButton_pressed() -> void:
	Global.palettes[current_palette] = working_palette
	Global.palette_container.on_palette_select(current_palette)
	Global.palette_container.save_palette(current_palette, working_palette.name + ".json")
	self.hide()
	pass # Replace with function body.

func _on_EditPaletteCancelButton_pressed() -> void:
	self.hide()
	pass # Replace with function body.

func _on_EditPaletteColorNameLineEdit_text_changed(new_text) -> void:
	if current_swatch > 0 && current_swatch < working_palette.colors.size():
		working_palette.colors[current_swatch].name = new_text
		_refresh_hint_tooltip(current_swatch)
	pass

func _on_EditPaletteColorPicker_color_changed(color) -> void:
	if current_swatch > 0 && current_swatch < working_palette.colors.size():
		palette_grid.get_child(current_swatch).get_child(0).modulate = color
		working_palette.colors[current_swatch].data = color.to_html(true)
		_refresh_hint_tooltip(current_swatch)
	pass

func _refresh_hint_tooltip(index : int):
	palette_grid.get_child(current_swatch).hint_tooltip = working_palette.colors[current_swatch].data.to_upper() + " " + working_palette.colors[current_swatch].name
	pass
