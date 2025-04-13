class_name PalettePanel
extends Container

const CREATE_PALETTE_SCENE_PATH := "res://src/Palette/CreatePaletteDialog.tscn"
const EDIT_PALETTE_SCENE_PATH := "res://src/Palette/EditPaletteDialog.tscn"

var palettes_path_id := {}
var palettes_id_path := {}

var edited_swatch_index := -1
var edited_swatch_color := Color.TRANSPARENT

var create_palette_dialog: ConfirmationDialog:
	get:
		if not is_instance_valid(create_palette_dialog):
			create_palette_dialog = load(CREATE_PALETTE_SCENE_PATH).instantiate()
			create_palette_dialog.saved.connect(_on_create_palette_dialog_saved)
			add_child(create_palette_dialog)
		return create_palette_dialog
var edit_palette_dialog: ConfirmationDialog:
	get:
		if not is_instance_valid(edit_palette_dialog):
			edit_palette_dialog = load(EDIT_PALETTE_SCENE_PATH).instantiate()
			edit_palette_dialog.deleted.connect(_on_edit_palette_dialog_deleted)
			edit_palette_dialog.exported.connect(_on_edit_palette_dialog_exported)
			edit_palette_dialog.saved.connect(_on_edit_palette_dialog_saved)
			add_child(edit_palette_dialog)
		return edit_palette_dialog

@onready var palette_select := $"%PaletteSelect"
@onready var palette_grid := $"%PaletteGrid" as PaletteGrid
@onready var palette_scroll := $"%PaletteScroll"

@onready var add_color_button := $"%AddColor"
@onready var delete_color_button := $"%DeleteColor"
@onready var sort_button := %Sort as MenuButton
@onready var sort_button_popup := sort_button.get_popup()

## This color picker button itself is hidden, but its popup is used to edit color swatches.
@onready var hidden_color_picker := $"%HiddenColorPickerButton" as ColorPickerButton


func _ready() -> void:
	sort_button_popup.add_check_item("Create a new palette", Palettes.SortOptions.NEW_PALETTE)
	sort_button_popup.set_item_checked(Palettes.SortOptions.NEW_PALETTE, true)
	sort_button_popup.add_item("Reverse colors", Palettes.SortOptions.REVERSE)
	sort_button_popup.add_separator()
	sort_button_popup.add_item("Sort by hue", Palettes.SortOptions.HUE)
	sort_button_popup.add_item("Sort by saturation", Palettes.SortOptions.SATURATION)
	sort_button_popup.add_item("Sort by value", Palettes.SortOptions.VALUE)
	sort_button_popup.add_separator()
	sort_button_popup.add_item("Sort by lightness", Palettes.SortOptions.LIGHTNESS)
	sort_button_popup.add_separator()
	sort_button_popup.add_item("Sort by red", Palettes.SortOptions.RED)
	sort_button_popup.add_item("Sort by green", Palettes.SortOptions.GREEN)
	sort_button_popup.add_item("Sort by blue", Palettes.SortOptions.BLUE)
	sort_button_popup.add_item("Sort by alpha", Palettes.SortOptions.ALPHA)
	Palettes.palette_selected.connect(select_palette)
	Palettes.new_palette_created.connect(_new_palette_created)
	Palettes.new_palette_imported.connect(setup_palettes_selector)
	sort_button_popup.id_pressed.connect(sort_pressed)

	setup_palettes_selector()
	redraw_current_palette()

	# Hide presets from color picker
	hidden_color_picker.get_picker().presets_visible = false


## Setup palettes selector with available palettes
func setup_palettes_selector() -> void:
	# Clear selector
	palettes_path_id.clear()
	palettes_id_path.clear()
	palette_select.clear()

	var id := 0
	for palette_name in Palettes.palettes:
		# Add palette selector item
		palette_select.add_item(Palettes.palettes[palette_name].name, id)

		# Map palette paths to item id's and otherwise
		palettes_path_id[palette_name] = id
		palettes_id_path[id] = palette_name
		id += 1


func select_palette(palette_name: String) -> void:
	var palette_id = palettes_path_id.get(palette_name)
	if palette_id != null:
		palette_select.selected = palette_id
	palette_grid.set_palette(Palettes.current_palette)
	palette_scroll.resize_grid()
	palette_scroll.set_sliders(Palettes.current_palette, palette_grid.grid_window_origin)

	var left_selected := Palettes.current_palette_get_selected_color_index(MOUSE_BUTTON_LEFT)
	var right_selected := Palettes.current_palette_get_selected_color_index(MOUSE_BUTTON_RIGHT)
	palette_grid.select_swatch(MOUSE_BUTTON_LEFT, left_selected, left_selected)
	palette_grid.select_swatch(MOUSE_BUTTON_RIGHT, right_selected, right_selected)

	toggle_add_delete_buttons()


## Select and display current palette
func redraw_current_palette() -> void:
	if is_instance_valid(Palettes.current_palette):
		Palettes.select_palette(Palettes.current_palette.name)
		add_color_button.show()
		delete_color_button.show()
		sort_button.show()
	else:
		add_color_button.hide()
		delete_color_button.hide()
		sort_button.hide()


func toggle_add_delete_buttons() -> void:
	if not is_instance_valid(Palettes.current_palette):
		return
	add_color_button.disabled = Palettes.current_palette.is_full()
	if add_color_button.disabled:
		add_color_button.mouse_default_cursor_shape = CURSOR_FORBIDDEN
	else:
		add_color_button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	delete_color_button.disabled = Palettes.current_palette.is_empty()
	sort_button.disabled = Palettes.current_palette.is_empty()
	if delete_color_button.disabled:
		delete_color_button.mouse_default_cursor_shape = CURSOR_FORBIDDEN
		sort_button.mouse_default_cursor_shape = CURSOR_FORBIDDEN
	else:
		delete_color_button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
		sort_button.mouse_default_cursor_shape = CURSOR_POINTING_HAND


func _on_AddPalette_pressed() -> void:
	create_palette_dialog.open(Palettes.current_palette)


func _on_EditPalette_pressed() -> void:
	edit_palette_dialog.open(Palettes.current_palette)


func _on_PaletteSelect_item_selected(index: int) -> void:
	Palettes.select_palette(palettes_id_path.get(index))


func _on_AddColor_gui_input(event: InputEvent) -> void:
	if Palettes.is_any_palette_selected():
		if (
			event is InputEventMouseButton
			and event.pressed
			and (
				event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT
			)
		):
			# Gets the grid index that corresponds to the top left of current grid window
			# Color will be added at the start of the currently scrolled part of palette
			# - not the absolute beginning of palette
			var start_index := palette_grid.convert_grid_index_to_palette_index(0)
			Palettes.current_palette_add_color(event.button_index, start_index)
			redraw_current_palette()
			toggle_add_delete_buttons()


func _on_DeleteColor_gui_input(event: InputEvent) -> void:
	if Palettes.is_any_palette_selected():
		if event is InputEventMouseButton and event.pressed:
			var selected_color_index := Palettes.current_palette_get_selected_color_index(
				event.button_index
			)

			if selected_color_index != -1:
				Palettes.current_palette_delete_color(selected_color_index)
				redraw_current_palette()
				toggle_add_delete_buttons()


func sort_pressed(id: Palettes.SortOptions) -> void:
	var new_palette := sort_button_popup.is_item_checked(Palettes.SortOptions.NEW_PALETTE)
	if id == Palettes.SortOptions.NEW_PALETTE:
		sort_button_popup.set_item_checked(Palettes.SortOptions.NEW_PALETTE, not new_palette)
		return
	if new_palette:
		Palettes.copy_palette()
		setup_palettes_selector()
	Palettes.current_palette_sort_colors(id)
	redraw_current_palette()


func _on_create_palette_dialog_saved(
	preset: int,
	palette_name: String,
	comment: String,
	width: int,
	height: int,
	add_alpha_colors: bool,
	colors_from: int
) -> void:
	Palettes.create_new_palette(
		preset, palette_name, comment, width, height, add_alpha_colors, colors_from
	)


func _on_edit_palette_dialog_saved(
	palette_name: String, comment: String, width: int, height: int
) -> void:
	Palettes.current_palette_edit(palette_name, comment, width, height)
	setup_palettes_selector()
	redraw_current_palette()


func _on_PaletteGrid_swatch_double_clicked(_mb: int, index: int, click_position: Vector2) -> void:
	var color := Palettes.current_palette_get_color(index)
	edited_swatch_index = index
	hidden_color_picker.color = color
	hidden_color_picker.color_changed.emit(hidden_color_picker.color)

	# Open color picker popup with its right bottom corner next to swatch
	var popup := hidden_color_picker.get_popup()
	var popup_position := click_position - Vector2(popup.size)
	popup.popup_on_parent(Rect2i(popup_position, Vector2i.ONE))


func _on_PaletteGrid_swatch_dropped(source_index: int, target_index: int) -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		Palettes.current_palette_insert_color(source_index, target_index)
	elif Input.is_key_pressed(KEY_CTRL):
		Palettes.current_palette_copy_colors(source_index, target_index)
	else:
		Palettes.current_palette_swap_colors(source_index, target_index)

	redraw_current_palette()


func _on_PaletteGrid_swatch_pressed(mouse_button: int, index: int) -> void:
	# Gets previously selected color index
	var old_index := Palettes.current_palette_get_selected_color_index(mouse_button)
	Palettes.current_palette_select_color(mouse_button, index)
	palette_grid.select_swatch(mouse_button, index, old_index)


func _on_ColorPicker_color_changed(color: Color) -> void:
	if edited_swatch_index != -1:
		edited_swatch_color = color
		palette_grid.set_swatch_color(edited_swatch_index, color)

		if (
			edited_swatch_index
			== Palettes.current_palette_get_selected_color_index(MOUSE_BUTTON_LEFT)
		):
			Tools.assign_color(color, MOUSE_BUTTON_LEFT)
		if (
			edited_swatch_index
			== Palettes.current_palette_get_selected_color_index(MOUSE_BUTTON_RIGHT)
		):
			Tools.assign_color(color, MOUSE_BUTTON_RIGHT)
		Palettes.current_palette_set_color(edited_swatch_index, edited_swatch_color)


## Saves edited swatch to palette file when color selection dialog is closed
func _on_HiddenColorPickerButton_popup_closed() -> void:
	Palettes.current_palette_set_color(edited_swatch_index, edited_swatch_color)


func _on_edit_palette_dialog_deleted(permanent: bool) -> void:
	Palettes.current_palete_delete(permanent)
	setup_palettes_selector()
	redraw_current_palette()


func _new_palette_created() -> void:
	setup_palettes_selector()
	redraw_current_palette()


func _on_edit_palette_dialog_exported(path := "") -> void:
	var image := Palettes.current_palette.convert_to_image()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(
			image.save_png_to_buffer(), Palettes.current_palette.name, "image/png"
		)
	if path.is_empty():
		return
	var extension := path.get_extension()
	match extension:
		"png":
			image.save_png(path)
		"jpg", "jpeg":
			image.save_jpg(path)
		"webp":
			image.save_webp(path)
