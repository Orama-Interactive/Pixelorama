class_name PaletteGrid
extends GridContainer

signal swatch_pressed(mouse_button: int, index: int)
signal swatch_double_clicked(mouse_button: int, index: int, position: Vector2)
signal swatch_dropped(source_index: int, target_index: int)

const DEFAULT_SWATCH_SIZE := Vector2(26, 26)
const MIN_SWATCH_SIZE := Vector2(8, 8)
const MAX_SWATCH_SIZE := Vector2(64, 64)

var swatches: Array[PaletteSwatch] = []
var current_palette: Palette = null
var grid_window_origin := Vector2i.ZERO
var grid_size := Vector2i.ZERO
var grid_locked := true:
	set(value):
		grid_locked = value
		if grid_locked:
			columns = maxi(1, grid_size.x)
		else:
			_on_resized()
var swatch_size := DEFAULT_SWATCH_SIZE


func _ready() -> void:
	swatch_size = Global.config_cache.get_value("palettes", "swatch_size", DEFAULT_SWATCH_SIZE)
	Palettes.palette_selected.connect(select_palette)
	Tools.color_changed.connect(find_and_select_color)
	resized.connect(_on_resized)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.ctrl_pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			change_swatch_size(Vector2i.ONE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			change_swatch_size(-Vector2i.ONE)
		else:
			return
		resize_grid()
		get_window().set_input_as_handled()


func select_palette(_new_palette_name: String) -> void:
	var new_palette := Palettes.current_palette
	if current_palette != new_palette:
		current_palette = new_palette
		grid_window_origin = Vector2.ZERO
	resize_grid()
	find_and_select_color({"color": Tools._slots[MOUSE_BUTTON_LEFT].color}, MOUSE_BUTTON_LEFT)
	find_and_select_color({"color": Tools._slots[MOUSE_BUTTON_RIGHT].color}, MOUSE_BUTTON_RIGHT)
	var left_selected := Palettes.left_selected_color
	var right_selected := Palettes.right_selected_color
	select_swatch(MOUSE_BUTTON_LEFT, left_selected, left_selected)
	select_swatch(MOUSE_BUTTON_RIGHT, right_selected, right_selected)


func setup_swatches() -> void:
	if grid_locked:
		columns = maxi(1, grid_size.x)  # Columns cannot be 0
	for child in get_children():
		child.queue_free()
	swatches.clear()
	for i in range(grid_size.x * grid_size.y):
		var swatch := PaletteSwatch.new()
		swatch.index = i
		init_swatch(swatch)
		swatch.pressed.connect(_on_palette_swatch_pressed.bind(i))
		swatch.double_clicked.connect(_on_palette_swatch_double_clicked.bind(i))
		swatch.dropped.connect(_on_palette_swatch_dropped)
		add_child(swatch)
		swatches.push_back(swatch)


func init_swatch(swatch: PaletteSwatch) -> void:
	swatch.color_index = swatch.index
	var color = current_palette.get_color(swatch.index)
	if color != null:
		swatch.set_swatch_color(color)
		swatch.empty = false
	else:
		swatch.set_swatch_color(PaletteSwatch.DEFAULT_COLOR)
		swatch.empty = true
	swatch.set_swatch_size(swatch_size)


## Called when the color changes, either the left or the right, determined by [param mouse_button].
## If current palette has [param color_info], then select the first slot that has it.
## This is helpful when we select color indirectly (e.g through colorpicker)
func find_and_select_color(color_info: Dictionary, mouse_button: int) -> void:
	var target_color: Color = color_info.get("color", Color(0, 0, 0, 0))
	var palette_color_index: int = color_info.get("index", -1)
	if not is_instance_valid(current_palette):
		return
	var selected_index := Palettes.current_palette_get_selected_color_index(mouse_button)
	if palette_color_index != -1:  # If color has a defined index in palette then priortize index
		if selected_index == palette_color_index:  # Index already selected
			return
		select_swatch(mouse_button, palette_color_index, selected_index)
		match mouse_button:
			MOUSE_BUTTON_LEFT:
				Palettes.left_selected_color = palette_color_index
			MOUSE_BUTTON_RIGHT:
				Palettes.right_selected_color = palette_color_index
		return
	else:  # If it doesn't then select the first match in the palette
		if get_swatch_color(selected_index) == target_color:  # Color already selected
			return
		for color_ind in swatches.size():
			if (
				target_color.is_equal_approx(swatches[color_ind].color)
				or target_color.to_html() == swatches[color_ind].color.to_html()
			):
				var index := convert_grid_index_to_palette_index(color_ind)
				select_swatch(mouse_button, index, selected_index)
				match mouse_button:
					MOUSE_BUTTON_LEFT:
						Palettes.left_selected_color = index
					MOUSE_BUTTON_RIGHT:
						Palettes.right_selected_color = index
				return
	# Unselect swatches when tools color is changed
	var swatch_to_unselect := -1
	if mouse_button == MOUSE_BUTTON_LEFT:
		swatch_to_unselect = Palettes.left_selected_color
		Palettes.left_selected_color = -1
	elif mouse_button == MOUSE_BUTTON_RIGHT:
		swatch_to_unselect = Palettes.right_selected_color
		Palettes.right_selected_color = -1

	unselect_swatch(mouse_button, swatch_to_unselect)


## Displays a left/right highlight over a swatch
func select_swatch(mouse_button: int, palette_index: int, old_palette_index: int) -> void:
	if not is_instance_valid(current_palette):
		return
	var index := convert_palette_index_to_grid_index(palette_index)
	var old_index := convert_palette_index_to_grid_index(old_palette_index)
	if index >= 0 and index < swatches.size():
		# Remove highlight from old index swatch and add to index swatch
		if old_index >= 0 and old_index < swatches.size():
			# Old index could be undefined when no swatch was previously selected
			swatches[old_index].show_selected_highlight(false, mouse_button)
		swatches[index].show_selected_highlight(true, mouse_button)


func unselect_swatch(mouse_button: int, palette_index: int) -> void:
	var index := convert_palette_index_to_grid_index(palette_index)
	if index >= 0 and index < swatches.size():
		swatches[index].show_selected_highlight(false, mouse_button)


func set_swatch_color(palette_index: int, color: Color) -> void:
	var index := convert_palette_index_to_grid_index(palette_index)
	if index >= 0 and index < swatches.size():
		swatches[index].set_swatch_color(color)


func get_swatch_color(palette_index: int) -> Color:
	var index := convert_palette_index_to_grid_index(palette_index)
	if index >= 0 and index < swatches.size():
		return swatches[index].color
	return Color.TRANSPARENT


## Grid index adds grid window origin
func convert_grid_index_to_palette_index(index: int) -> int:
	return (
		(index / grid_size.x + grid_window_origin.y) * current_palette.width
		+ (index % grid_size.x + grid_window_origin.x)
	)


func convert_palette_index_to_grid_index(palette_index: int) -> int:
	var x := palette_index % current_palette.width
	var y := palette_index / current_palette.width
	return (x - grid_window_origin.x) + (y - grid_window_origin.y) * grid_size.x


func resize_grid() -> void:
	if is_instance_valid(current_palette):
		grid_size.x = current_palette.width
		grid_size.y = current_palette.height
	else:
		grid_size = Vector2i.ZERO
	setup_swatches()


func change_swatch_size(size_diff: Vector2) -> void:
	swatch_size += size_diff
	if swatch_size.x < MIN_SWATCH_SIZE.x:
		swatch_size = MIN_SWATCH_SIZE
	elif swatch_size.x > MAX_SWATCH_SIZE.x:
		swatch_size = MAX_SWATCH_SIZE

	for swatch in get_children():
		swatch.set_swatch_size(swatch_size)

	Global.config_cache.set_value("palettes", "swatch_size", swatch_size)


func _on_resized() -> void:
	if not grid_locked:
		columns = maxi(1, size.x / 36.5)


func _on_palette_swatch_pressed(mouse_button: int, index: int) -> void:
	var palette_index := convert_grid_index_to_palette_index(index)
	swatch_pressed.emit(mouse_button, palette_index)


func _on_palette_swatch_double_clicked(mouse_button: int, pos: Vector2, index: int) -> void:
	var palette_index := convert_grid_index_to_palette_index(index)
	swatch_double_clicked.emit(mouse_button, palette_index, pos)


func _on_palette_swatch_dropped(source_index: int, target_index: int) -> void:
	var palette_source_index := convert_grid_index_to_palette_index(source_index)
	var palette_target_index := convert_grid_index_to_palette_index(target_index)
	swatch_dropped.emit(palette_source_index, palette_target_index)
