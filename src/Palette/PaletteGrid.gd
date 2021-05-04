extends GridContainer
class_name PaletteGrid

signal swatch_pressed(mouse_button, index)
signal swatch_double_clicked(mouse_button, index, position)
signal swatch_dropped(source_index, target_index)

const PaletteSwatchScene := preload("res://src/Palette/PaletteSwatch.tscn")

# Must be integer values
const MAX_GRID_SIZE = Vector2(8, 8)

var swatches := [] # PaletteSwatch

var displayed_palette = null
var grid_window_origin := Vector2.ZERO
var grid_size := Vector2(8, 8)


func _ready():
	init_swatches()


func init_swatches() -> void:
	columns = grid_size.x
	for j in range(grid_size.y):
		for i in range(grid_size.x):
			var index: int = i + grid_size.x * j
			var swatch: PaletteSwatch = PaletteSwatchScene.instance()
			swatch.index = index
			swatch.color = PaletteSwatch.DEFAULT_COLOR
			swatch.show_left_highlight = false
			swatch.show_right_highlight = false
			swatch.empty = true
			swatch.connect("pressed", self, "_on_PaletteSwatch_pressed", [index])
			swatch.connect("double_clicked", self, "_on_PaletteSwatch_double_clicked", [index])
			swatch.connect("dropped", self, "_on_PaletteSwatch_dropped")
			add_child(swatch)
			swatches.push_back(swatch)


# Origin determines a position in palette which will be displayed on top left of grid
func display_palette(palette: Palette) -> void:
	# Reset grid origin when palette changes
	if displayed_palette != palette:
		displayed_palette = palette
		grid_window_origin = Vector2.ZERO

	# Only display valid palette objects
	if not palette:
		return

	if swatches.size() == 0:
		init_swatches()

	if palette.width < MAX_GRID_SIZE.x or palette.height < MAX_GRID_SIZE.y:
		grid_size = Vector2(palette.width, palette.height)
		clear_swatches()
		init_swatches()
	elif palette.width >= MAX_GRID_SIZE.x and palette.height >= MAX_GRID_SIZE.y and grid_size != MAX_GRID_SIZE:
		grid_size = MAX_GRID_SIZE
		clear_swatches()
		init_swatches()

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


func scroll_palette(origin: Vector2) -> void:
	grid_window_origin = origin
	display_palette(displayed_palette)


# Removes all swatches
func clear_swatches() -> void:
	swatches.clear()
	for swatch in get_children():
		swatch.queue_free()


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
	return int(index / grid_size.x + grid_window_origin.y) * displayed_palette.width + (index % int(grid_size.x) + grid_window_origin.x)


func convert_palette_index_to_grid_index(palette_index: int) -> int:
	var x: int = palette_index % displayed_palette.width
	var y: int = palette_index / displayed_palette.height
	return int((x - grid_window_origin.x) + (y - grid_window_origin.y) * grid_size.x)
