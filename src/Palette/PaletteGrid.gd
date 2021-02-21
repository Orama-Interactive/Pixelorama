extends GridContainer

signal swatch_pressed(mouse_button, index)
signal swatch_double_clicked(mouse_button, index, position)
signal swatch_dropped(source_index, target_index)

const PaletteSwatchScene := preload("res://src/Palette/PaletteSwatch.tscn")

var swatches := [] # PaletteSwatch

func display_palette(palette: Palette) -> void:
	# Remove all old swatches
	clear_swatches()

	# Only display valid palette objects
	if not palette:
		return

	# Setup palette area
	columns = palette.width

	# Create empty palette buttons
	for j in range(palette.height):
		for i in range(palette.width):

			var index: int = i + palette.width * j
			var swatch: PaletteSwatch = PaletteSwatchScene.instance()
			swatch.index = index
			swatch.connect("pressed", self, "_on_PaletteSwatch_pressed", [index])
			swatch.connect("double_clicked", self, "_on_PaletteSwatch_double_clicked", [index])
			swatch.connect("dropped", self, "_on_PaletteSwatch_dropped")

			var color = palette.get_color(index)
			if color != null:
				swatch.color = color
				swatch.show_left_highlight = false
				swatch.show_right_highlight = false
				swatch.empty = false
			else:
				swatch.color = PaletteSwatch.DEFAULT_COLOR
				swatch.show_left_highlight = false
				swatch.show_right_highlight = false
				swatch.empty = true

			add_child(swatch)
			swatches.push_back(swatch)


# Removes all swatches
func clear_swatches() -> void:
	swatches.clear()
	for swatch in get_children():
		swatch.queue_free()


# Displays a left/right highlight over a swatch
func select_swatch(mouse_button: int, index: int, old_index: int) -> void:
	if index >= 0 and index < swatches.size():
		# Remove highlight from old index swatch and add to index swatch
		swatches[old_index].show_selected_highlight(false, mouse_button)
		swatches[index].show_selected_highlight(true, mouse_button)


func unselect_swatch(mouse_button: int, index: int) -> void:
	if index >= 0 and index < swatches.size():
		swatches[index].show_selected_highlight(false, mouse_button)


func set_swatch_color(index: int, color: Color) -> void:
	if index >= 0 and index < swatches.size():
		swatches[index].color = color


func get_swatch_color(index: int) -> Color:
	if index >= 0 and index < swatches.size():
		return swatches[index].color
	return Color.transparent


# Used to reload empty swatch color from a theme
func reset_empty_swatches_color() -> void:
	for swatch in swatches:
		if swatch.empty:
			swatch.empty = true


func _on_PaletteSwatch_pressed(mouse_button: int, index: int) -> void:
	emit_signal("swatch_pressed", mouse_button, index)


func _on_PaletteSwatch_double_clicked(mouse_button: int, position: Vector2, index: int) -> void:
	emit_signal("swatch_double_clicked", mouse_button, index, position)


func _on_PaletteSwatch_dropped(source_index: int, target_index: int) -> void:
	emit_signal("swatch_dropped", source_index, target_index)
