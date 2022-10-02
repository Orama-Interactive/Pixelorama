class_name PaletteGrid
extends GridContainer

signal swatch_pressed(mouse_button, index)
signal swatch_double_clicked(mouse_button, index, position)
signal swatch_dropped(source_index, target_index)

const PaletteSwatchScene := preload("res://src/Palette/PaletteSwatch.tscn")
const DEFAULT_SWATCH_SIZE = 26
const MIN_SWATCH_SIZE = 8
const MAX_SWATCH_SIZE = 64

var swatches := []  # PaletteSwatch
var displayed_palette = null
var grid_window_origin := Vector2.ZERO
var grid_size := Vector2.ZERO
var swatch_size := Vector2(DEFAULT_SWATCH_SIZE, DEFAULT_SWATCH_SIZE)


func setup_swatches() -> void:
	# Colums cannot be 0
	columns = 1.0 if grid_size.x == 0.0 else grid_size.x
	if grid_size.x * grid_size.y > swatches.size():
		for i in range(swatches.size(), grid_size.x * grid_size.y):
			var swatch: PaletteSwatch = PaletteSwatchScene.instance()
			swatch.index = i
			clear_swatch(swatch)
			swatch.connect("pressed", self, "_on_PaletteSwatch_pressed", [i])
			swatch.connect("double_clicked", self, "_on_PaletteSwatch_double_clicked", [i])
			swatch.connect("dropped", self, "_on_PaletteSwatch_dropped")
			add_child(swatch)
			swatches.push_back(swatch)
	else:
		var diff = swatches.size() - grid_size.x * grid_size.y
		for _i in range(0, diff):
			var swatch = swatches.pop_back()
			remove_child(swatch)
			swatch.queue_free()

		for i in range(0, swatches.size()):
			clear_swatch(swatches[i])


func clear_swatch(swatch: PaletteSwatch) -> void:
	swatch.color = PaletteSwatch.DEFAULT_COLOR
	swatch.show_left_highlight = false
	swatch.show_right_highlight = false
	swatch.empty = true
	swatch.set_swatch_size(swatch_size)


# Origin determines a position in palette which will be displayed on top left of grid
func display_palette(palette: Palette) -> void:
	# Reset grid origin when palette changes
	if displayed_palette != palette:
		displayed_palette = palette
		grid_window_origin = Vector2.ZERO

	# Only display valid palette objects
	if not palette:
		return

	resize_grid()
	setup_swatches()

	# Create empty palette buttons
	for j in range(grid_size.y):
		for i in range(grid_size.x):
			var grid_index: int = i + grid_size.x * j
			var index: int = convert_grid_index_to_palette_index(grid_index)
			var swatch = swatches[grid_index]
			swatch.show_left_highlight = false
			swatch.show_right_highlight = false
			var color = palette.get_color(index)
			if color != null:
				swatch.color = color
				swatch.empty = false
			else:
				swatch.color = PaletteSwatch.DEFAULT_COLOR
				swatch.empty = true


func redraw_palette() -> void:
	display_palette(displayed_palette)


func scroll_palette(origin: Vector2) -> void:
	grid_window_origin = origin
	redraw_palette()


func find_and_select_color(mouse_button: int, target_color: Color) -> void:
	var old_index = Palettes.current_palette_get_selected_color_index(mouse_button)
	for color_ind in swatches.size():
		if target_color.is_equal_approx(swatches[color_ind].color):
			select_swatch(mouse_button, color_ind, old_index)
			match mouse_button:
				BUTTON_LEFT:
					Palettes.left_selected_color = color_ind
				BUTTON_RIGHT:
					Palettes.right_selected_color = color_ind
			break


# Displays a left/right highlight over a swatch
func select_swatch(mouse_button: int, palette_index: int, old_palette_index: int) -> void:
	var index = convert_palette_index_to_grid_index(palette_index)
	var old_index = convert_palette_index_to_grid_index(old_palette_index)
	if index >= 0 and index < swatches.size():
		# Remove highlight from old index swatch and add to index swatch
		if old_index >= 0 and old_index < swatches.size():
			# Old index could be undefined when no swatch was previously selected
			swatches[old_index].show_selected_highlight(false, mouse_button)
		swatches[index].show_selected_highlight(true, mouse_button)


func unselect_swatch(mouse_button: int, palette_index: int) -> void:
	var index = convert_palette_index_to_grid_index(palette_index)
	if index >= 0 and index < swatches.size():
		swatches[index].show_selected_highlight(false, mouse_button)


func set_swatch_color(palette_index: int, color: Color) -> void:
	var index = convert_palette_index_to_grid_index(palette_index)
	if index >= 0 and index < swatches.size():
		swatches[index].color = color


func get_swatch_color(palette_index: int) -> Color:
	var index = convert_palette_index_to_grid_index(palette_index)
	if index >= 0 and index < swatches.size():
		return swatches[index].color
	return Color.transparent


# Used to reload empty swatch color from a theme
func reset_empty_swatches_color() -> void:
	for swatch in swatches:
		if swatch.empty:
			swatch.empty = true


func _on_PaletteSwatch_pressed(mouse_button: int, index: int) -> void:
	var palette_index = convert_grid_index_to_palette_index(index)
	emit_signal("swatch_pressed", mouse_button, palette_index)


func _on_PaletteSwatch_double_clicked(mouse_button: int, position: Vector2, index: int) -> void:
	var palette_index = convert_grid_index_to_palette_index(index)
	emit_signal("swatch_double_clicked", mouse_button, palette_index, position)


func _on_PaletteSwatch_dropped(source_index: int, target_index: int) -> void:
	var palette_source_index = convert_grid_index_to_palette_index(source_index)
	var palette_target_index = convert_grid_index_to_palette_index(target_index)
	emit_signal("swatch_dropped", palette_source_index, palette_target_index)


# Grid index adds grid window origin
func convert_grid_index_to_palette_index(index: int) -> int:
	return (
		int(index / grid_size.x + grid_window_origin.y) * displayed_palette.width
		+ (index % int(grid_size.x) + grid_window_origin.x)
	)


func convert_palette_index_to_grid_index(palette_index: int) -> int:
	var x: int = palette_index % displayed_palette.width
	var y: int = palette_index / displayed_palette.width
	return int((x - grid_window_origin.x) + (y - grid_window_origin.y) * grid_size.x)


func resize_grid() -> void:
	if displayed_palette:
		var grid_x: int = rect_size.x / (swatch_size.x + get("custom_constants/hseparation"))
		var grid_y: int = rect_size.y / (swatch_size.y + get("custom_constants/vseparation"))

		grid_size.x = min(grid_x, displayed_palette.width)
		grid_size.y = min(grid_y, displayed_palette.height)


func change_swatch_size(size_diff: Vector2):
	swatch_size += size_diff
	if swatch_size.x < MIN_SWATCH_SIZE:
		swatch_size = Vector2(MIN_SWATCH_SIZE, MIN_SWATCH_SIZE)
	elif swatch_size.x > MAX_SWATCH_SIZE:
		swatch_size = Vector2(MAX_SWATCH_SIZE, MAX_SWATCH_SIZE)

	for swatch in swatches:
		swatch.set_swatch_size(swatch_size)
	redraw_palette()


func _on_PaletteGrid_resized():
	resize_grid()
	redraw_palette()
