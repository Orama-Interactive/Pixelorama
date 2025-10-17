class_name PalettePanel
extends Container

const CREATE_PALETTE_SCENE_PATH := "res://src/Palette/CreatePaletteDialog.tscn"
const EDIT_PALETTE_SCENE_PATH := "res://src/Palette/EditPaletteDialog.tscn"

var palettes_name_id := {}
var palettes_id_name := {}

var edited_swatch_index := -1
var edited_swatch_color := Color.TRANSPARENT
var sort_submenu := PopupMenu.new()

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

@onready var palette_select := $"%PaletteSelect" as OptionButton
@onready var palette_grid := $"%PaletteGrid" as PaletteGrid
@onready var palette_scroll := $"%PaletteScroll"

@onready var add_color_button := $"%AddColor"
@onready var delete_color_button := $"%DeleteColor"
@onready var sort_button := %Sort as MenuButton
@onready var sort_button_popup := sort_button.get_popup()

## This color picker button itself is hidden, but its popup is used to edit color swatches.
@onready var hidden_color_picker := $"%HiddenColorPickerButton" as ColorPickerButton


func _ready() -> void:
	sort_button_popup.add_check_item("Auto add new colors", 0)
	sort_submenu.add_check_item("Create a new palette", Palettes.SortOptions.NEW_PALETTE)
	sort_submenu.set_item_checked(Palettes.SortOptions.NEW_PALETTE, true)
	sort_submenu.add_item("Reverse colors", Palettes.SortOptions.REVERSE)
	sort_submenu.add_separator()
	sort_submenu.add_item("Sort by hue", Palettes.SortOptions.HUE)
	sort_submenu.add_item("Sort by saturation", Palettes.SortOptions.SATURATION)
	sort_submenu.add_item("Sort by value", Palettes.SortOptions.VALUE)
	sort_submenu.add_separator()
	sort_submenu.add_item("Sort by lightness", Palettes.SortOptions.LIGHTNESS)
	sort_submenu.add_separator()
	sort_submenu.add_item("Sort by red", Palettes.SortOptions.RED)
	sort_submenu.add_item("Sort by green", Palettes.SortOptions.GREEN)
	sort_submenu.add_item("Sort by blue", Palettes.SortOptions.BLUE)
	sort_submenu.add_item("Sort by alpha", Palettes.SortOptions.ALPHA)
	sort_button_popup.add_child(sort_submenu)
	sort_button_popup.add_submenu_node_item("Palette Sort", sort_submenu)

	Palettes.palette_selected.connect(select_palette)
	Palettes.new_palette_created.connect(_new_palette_created)
	Palettes.palette_removed.connect(setup_palettes_selector)
	Palettes.new_palette_imported.connect(setup_palettes_selector)
	Global.project_switched.connect(_project_switched)
	sort_submenu.id_pressed.connect(sort_pressed)
	sort_button_popup.id_pressed.connect(
		func(id: int):
			if id == 0:
				sort_button_popup.set_item_checked(0, not Palettes.auto_add_colors)
				Palettes.auto_add_colors = sort_button_popup.is_item_checked(0)
	)

	setup_palettes_selector()
	redraw_current_palette()

	# Hide presets from color picker
	hidden_color_picker.get_picker().presets_visible = false
	hidden_color_picker.get_picker().visibility_changed.connect(_on_colorpicker_visibility_changed)


## Setup palettes selector with available palettes
func setup_palettes_selector() -> void:
	# Clear selector
	palettes_name_id.clear()
	palettes_id_name.clear()
	palette_select.clear()

	var id := 0
	for palette_name in Palettes.palettes:
		# Add palette selector item
		palette_select.add_item(Palettes.palettes[palette_name].name, id)

		# Map palette name to item id's and otherwise
		palettes_name_id[palette_name] = id
		palettes_id_name[id] = palette_name
		id += 1
	var project := Global.current_project
	if project:
		if project.palettes.size() > 0:
			palette_select.add_separator("")
			id += 1
		for palette_name in project.palettes:
			# Add palette selector item
			var disp_name := Palettes.get_name_without_suffix(
				project.palettes[palette_name].name, true
			)
			palette_select.add_item("%s (project palette)" % disp_name, id)

			# Map palette name to item id's and otherwise
			palettes_name_id[palette_name] = id
			palettes_id_name[id] = palette_name
			id += 1


func select_palette(palette_name: String) -> void:
	var palette_id = palettes_name_id.get(palette_name)
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
	sort_button_popup.set_item_disabled(1, Palettes.current_palette.is_empty())
	if delete_color_button.disabled:
		delete_color_button.mouse_default_cursor_shape = CURSOR_FORBIDDEN
	else:
		delete_color_button.mouse_default_cursor_shape = CURSOR_POINTING_HAND


func _on_AddPalette_pressed() -> void:
	create_palette_dialog.open(Palettes.current_palette)


func _on_EditPalette_pressed() -> void:
	edit_palette_dialog.open(Palettes.current_palette)


func _on_PaletteSelect_item_selected(index: int) -> void:
	Palettes.select_palette(palettes_id_name.get(index))


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
			var new_color := Tools.get_assigned_color(event.button_index)
			_current_palette_undo_redo_add_color(new_color, start_index)


func _on_DeleteColor_gui_input(event: InputEvent) -> void:
	if Palettes.is_any_palette_selected():
		if event is InputEventMouseButton and event.pressed:
			var selected_color_index := Palettes.current_palette_get_selected_color_index(
				event.button_index
			)

			if selected_color_index != -1:
				_current_palette_undo_redo_remove_color(selected_color_index)


func sort_pressed(id: Palettes.SortOptions) -> void:
	var new_palette := sort_submenu.is_item_checked(Palettes.SortOptions.NEW_PALETTE)
	if id == Palettes.SortOptions.NEW_PALETTE:
		sort_submenu.set_item_checked(Palettes.SortOptions.NEW_PALETTE, not new_palette)
		return
	if Palettes.current_palette.is_project_palette or new_palette:
		var palette_to_sort := Palettes.current_palette
		var undo_redo := Global.current_project.undo_redo
		undo_redo.create_action("Sort Palette")
		if new_palette:
			palette_to_sort = palette_to_sort.duplicate()
			palette_to_sort.is_project_palette = true
			Palettes.undo_redo_add_palette(palette_to_sort)
			undo_redo.add_undo_method(
				Palettes.palette_delete_and_reselect.bind(true, palette_to_sort)
			)
		else:
			var old_colors := Palette.duplicate_color_data(palette_to_sort.colors)
			undo_redo.add_undo_method(palette_to_sort.set_color_data.bind(old_colors))
			undo_redo.add_undo_method(redraw_current_palette)
		undo_redo.add_do_method(Palettes.sort_colors.bind(id, palette_to_sort))
		undo_redo.add_do_method(redraw_current_palette)
		commit_undo()
	else:
		Palettes.sort_colors(id)
		redraw_current_palette()


func _on_create_palette_dialog_saved(
	preset: int,
	palette_name: String,
	comment: String,
	width: int,
	height: int,
	add_alpha_colors: bool,
	colors_from: int,
	is_global: bool
) -> void:
	Palettes.create_new_palette(
		preset, palette_name, comment, width, height, add_alpha_colors, colors_from, is_global
	)


func _on_edit_palette_dialog_saved(
	palette_name: String, comment: String, width: int, height: int, is_global
) -> void:
	Palettes.current_palette_edit(palette_name, comment, width, height, is_global)
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


func _on_PaletteGrid_swatch_dropped(s_index: int, t_index: int) -> void:
	var undo_redo := Global.current_project.undo_redo
	undo_redo.create_action("Swatch dropped")
	var palette_in_focus = Palettes.current_palette
	if not palette_in_focus.is_project_palette:
		palette_in_focus = palette_in_focus.duplicate()
		palette_in_focus.is_project_palette = true
		undo_redo.add_do_method(Palettes.add_palette_as_project_palette.bind(palette_in_focus))
	if Input.is_key_pressed(KEY_SHIFT):
		undo_redo.add_do_method(Palettes.current_palette_insert_color.bind(s_index, t_index))
		undo_redo.add_undo_method(
			palette_in_focus.set_color_data.bind(palette_in_focus.get_color_data())
		)
		undo_redo.add_undo_property(palette_in_focus, "width", palette_in_focus.width)
		undo_redo.add_undo_property(palette_in_focus, "height", palette_in_focus.height)
		undo_redo.add_undo_property(palette_in_focus, "colors_max", palette_in_focus.colors_max)
	elif Input.is_key_pressed(KEY_CTRL):
		undo_redo.add_do_method(Palettes.current_palette_copy_colors.bind(s_index, t_index))
		var old_color = palette_in_focus.get_color(t_index)
		undo_redo.add_undo_method(palette_in_focus.set_color.bind(t_index, old_color))
	else:
		undo_redo.add_do_method(Palettes.current_palette_swap_colors.bind(s_index, t_index))
		undo_redo.add_undo_method(Palettes.current_palette_swap_colors.bind(t_index, s_index))
	if Palettes.current_palette != palette_in_focus:
		undo_redo.add_undo_method(Palettes.palette_delete_and_reselect.bind(true, palette_in_focus))
	undo_redo.add_do_method(redraw_current_palette)
	undo_redo.add_undo_method(redraw_current_palette)
	commit_undo()


func _on_PaletteGrid_swatch_pressed(mouse_button: int, index: int) -> void:
	# NOTE: here index is relative to palette, not the grid
	# Gets previously selected color index
	var old_index := Palettes.current_palette_get_selected_color_index(mouse_button)
	var is_empty_swatch = Palettes.current_palette.get_color(index) == null
	if is_empty_swatch:  # Add colors with Left/Right Click
		var new_color := Tools.get_assigned_color(mouse_button)
		_current_palette_undo_redo_add_color(new_color, index)
	else:
		if Input.is_key_pressed(KEY_CTRL):  # Delete colors with Ctrl + Click
			_current_palette_undo_redo_remove_color(index)
			return
	# Gets previously selected color index
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


func _on_colorpicker_visibility_changed() -> void:
	var undo_redo := Global.current_project.undo_redo
	if hidden_color_picker.get_picker().is_visible_in_tree():
		undo_redo.create_action("Change swatch color")
		var old_color := Palettes.current_palette_get_color(edited_swatch_index)
		if not Palettes.current_palette.is_project_palette:
			# Reset color on the original palette, and make a copy instead
			undo_redo.add_do_method(
				Palettes.current_palette_set_color.bind(edited_swatch_index, old_color)
			)
			Palettes.copy_current_palette(Palettes.current_palette.name)
		undo_redo.add_undo_method(
			Palettes.current_palette_set_color.bind(edited_swatch_index, old_color)
		)
		undo_redo.add_undo_method(
			palette_grid.set_swatch_color.bind(edited_swatch_index, old_color)
		)
	else:
		undo_redo.add_do_method(
			Palettes.current_palette_set_color.bind(edited_swatch_index, edited_swatch_color)
		)
		undo_redo.add_do_method(
			palette_grid.set_swatch_color.bind(edited_swatch_index, edited_swatch_color)
		)
		commit_undo()


func _on_edit_palette_dialog_deleted(permanent: bool) -> void:
	if Palettes.current_palette.is_project_palette:
		var undo_redo = Global.current_project.undo_redo
		undo_redo.create_action("Remove project palette")
		undo_redo.add_do_method(Palettes.palette_delete_and_reselect)
		undo_redo.add_undo_method(
			Palettes.add_palette_as_project_palette.bind(Palettes.current_palette)
		)
		undo_redo.add_do_method(setup_palettes_selector)
		undo_redo.add_do_method(redraw_current_palette)
		undo_redo.add_undo_method(setup_palettes_selector)
		undo_redo.add_undo_method(redraw_current_palette)
		undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
		undo_redo.add_do_method(Global.undo_or_redo.bind(false))
		undo_redo.commit_action()
	else:
		Palettes.palette_delete_and_reselect(permanent)
		setup_palettes_selector()
		redraw_current_palette()


func _project_switched() -> void:
	var proj_palette_name := Global.current_project.project_current_palette_name
	setup_palettes_selector()
	# Switch to the recent active project palette if it exists
	if proj_palette_name != "":
		Palettes.select_palette(proj_palette_name)
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


## Helper methods for undo/redo


func commit_undo() -> void:
	var undo_redo := Global.current_project.undo_redo
	undo_redo.add_undo_method(Global.general_undo)
	undo_redo.add_do_method(Global.general_redo)
	undo_redo.commit_action()


func _current_palette_undo_redo_add_color(color: Color, start_index := 0) -> void:
	var undo_redo := Global.current_project.undo_redo
	undo_redo.create_action("Add palette color")
	var palette_in_focus = Palettes.current_palette
	if not palette_in_focus.is_project_palette:
		palette_in_focus = palette_in_focus.duplicate()
		palette_in_focus.is_project_palette = true
		Palettes.undo_redo_add_palette(palette_in_focus)
		undo_redo.add_do_property(
			palette_grid, "grid_window_origin", palette_grid.grid_window_origin
		)
	# Get an estimate of where the color will end up (used for undo)
	var index := start_index
	var color_max: int = palette_in_focus.colors_max
	# If palette is full automatically increase the palette height
	if palette_in_focus.is_full():
		color_max = palette_in_focus.width * (palette_in_focus.height + 1)
	for i in range(start_index, color_max):
		if not palette_in_focus.colors.has(i):
			index = i
			break
	undo_redo.add_do_method(palette_in_focus.add_color.bind(color, start_index))
	undo_redo.add_undo_method(palette_in_focus.remove_color.bind(index))
	undo_redo.add_do_method(redraw_current_palette)
	undo_redo.add_undo_method(redraw_current_palette)
	undo_redo.add_do_method(toggle_add_delete_buttons)
	undo_redo.add_undo_method(toggle_add_delete_buttons)
	commit_undo()


func _current_palette_undo_redo_remove_color(index := 0) -> void:
	var undo_redo := Global.current_project.undo_redo
	undo_redo.create_action("Remove palette color")
	var old_color := Palettes.current_palette_get_color(index)
	var palette_in_focus = Palettes.current_palette
	if not palette_in_focus.is_project_palette:
		palette_in_focus = palette_in_focus.duplicate()
		palette_in_focus.is_project_palette = true
		Palettes.undo_redo_add_palette(palette_in_focus)
		undo_redo.add_do_property(
			palette_grid, "grid_window_origin", palette_grid.grid_window_origin
		)
	undo_redo.add_do_method(palette_in_focus.remove_color.bind(index))
	undo_redo.add_undo_method(palette_in_focus.add_color.bind(old_color, index))
	undo_redo.add_do_method(redraw_current_palette)
	undo_redo.add_do_method(toggle_add_delete_buttons)
	undo_redo.add_undo_method(redraw_current_palette)
	undo_redo.add_undo_method(toggle_add_delete_buttons)
	commit_undo()
