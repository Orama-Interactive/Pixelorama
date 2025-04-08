class_name TileSetPanel
extends PanelContainer

enum TileEditingMode { MANUAL, AUTO, STACK }

const TRANSPARENT_CHECKER := preload("res://src/UI/Nodes/TransparentChecker.tscn")
const MIN_BUTTON_SIZE := 36
const MAX_BUTTON_SIZE := 144
## A matrix with every possible flip/transpose combination,
## sorted by what comes next when you rotate.
## Taken from Godot's rotation matrix found in:
## https://github.com/godotengine/godot/blob/master/editor/plugins/tiles/tile_map_layer_editor.cpp
const ROTATION_MATRIX: Array[bool] = [
	0, 0, 0, 0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 1
]

static var placing_tiles := false:
	set(value):
		placing_tiles = value
		_call_update_brushes()
static var tile_editing_mode := TileEditingMode.AUTO
static var selected_tile_index := 0:
	set(value):
		selected_tiles = [value]
		_call_update_brushes()
	get:
		if is_instance_valid(current_tileset):
			return current_tileset.pick_random_tile(selected_tiles)
		return selected_tiles[0]
static var selected_tiles: Array[int] = [0]
static var is_flipped_h := false:
	set(value):
		is_flipped_h = value
		_call_update_brushes()
static var is_flipped_v := false:
	set(value):
		is_flipped_v = value
		_call_update_brushes()
static var is_transposed := false:
	set(value):
		is_transposed = value
		_call_update_brushes()
static var current_tileset: TileSetCustom
var button_size := 36:
	set(value):
		if button_size == value:
			return
		button_size = clampi(value, MIN_BUTTON_SIZE, MAX_BUTTON_SIZE)
		tile_size_slider.value = button_size
		update_minimum_size()
		Global.config_cache.set_value("tileset_panel", "button_size", button_size)
		for button: Control in tile_button_container.get_children():
			button.custom_minimum_size = Vector2(button_size, button_size)
			button.size = Vector2(button_size, button_size)
var show_empty_tile := true
var tile_index_menu_popped := 0

@onready var place_tiles: Button = %PlaceTiles
@onready var transform_buttons_container: HFlowContainer = %TransformButtonsContainer
@onready var tile_button_container: HFlowContainer = %TileButtonContainer
@onready var mode_buttons_container: HFlowContainer = %ModeButtonsContainer
@onready var option_button: Button = %OptionButton
@onready var options: Popup = $Options
@onready var tile_size_slider: ValueSlider = %TileSizeSlider
@onready var tile_button_popup_menu: PopupMenu = $TileButtonPopupMenu
@onready var tile_properties: AcceptDialog = $TileProperties
@onready var tile_probability_slider: ValueSlider = %TileProbabilitySlider
@onready var tile_user_data_text_edit: TextEdit = %TileUserDataTextEdit


func _ready() -> void:
	Tools.selected_tile_index_changed.connect(select_tile)
	Global.cel_switched.connect(_on_cel_switched)
	for child: Button in transform_buttons_container.get_children():
		Global.disable_button(child, true)
	update_tip()
	tile_size_slider.min_value = MIN_BUTTON_SIZE
	tile_size_slider.max_value = MAX_BUTTON_SIZE
	tile_size_slider.value = button_size


func _gui_input(event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_CTRL):
		var zoom := 2 * int(event.is_action("zoom_in")) - 2 * int(event.is_action("zoom_out"))
		button_size += zoom
		if zoom != 0:
			get_viewport().set_input_as_handled()


func set_tileset(tileset: TileSetCustom) -> void:
	if tileset == current_tileset:
		return
	if is_instance_valid(current_tileset) and current_tileset.updated.is_connected(_update_tileset):
		current_tileset.updated.disconnect(_update_tileset)
		current_tileset.tile_added.disconnect(_update_tileset_dummy_params)
		current_tileset.tile_removed.disconnect(_update_tileset_dummy_params)
		current_tileset.tile_replaced.disconnect(_update_tileset_dummy_params)
		current_tileset.resized_content.disconnect(_call_update_brushes)
	current_tileset = tileset
	if (
		is_instance_valid(current_tileset)
		and not current_tileset.updated.is_connected(_update_tileset)
	):
		current_tileset.updated.connect(_update_tileset)
		current_tileset.tile_added.connect(_update_tileset_dummy_params)
		current_tileset.tile_removed.connect(_update_tileset_dummy_params)
		current_tileset.tile_replaced.connect(_update_tileset_dummy_params)
		current_tileset.resized_content.connect(_call_update_brushes)


func update_tip() -> void:
	var tip := %Tip
	tip.get_parent().visible = true
	if placing_tiles:
		tip.text = tr("Select a tile to place it on the canvas.")
	else:
		tip.text = tr("Modify tiles on the canvas.")


func _on_cel_switched() -> void:
	if Global.current_project.get_current_cel() is not CelTileMap:
		set_tileset(null)
		_clear_tile_buttons()
		return
	var cel := Global.current_project.get_current_cel() as CelTileMap
	set_tileset(cel.tileset)
	_update_tileset()
	if cel.place_only_mode:
		place_tiles.button_pressed = true
	place_tiles.visible = not cel.place_only_mode


func _update_tileset() -> void:
	_clear_tile_buttons()
	for tile_index in selected_tiles:
		if tile_index >= current_tileset.tiles.size():
			selected_tiles.erase(tile_index)
	if selected_tiles.is_empty():
		selected_tile_index = 0
	for i in current_tileset.tiles.size():
		var tile := current_tileset.tiles[i]
		var texture := ImageTexture.create_from_image(tile.image)
		var button := _create_tile_button(texture, i)
		if i in selected_tiles:
			button.set_pressed_no_signal(true)
		tile_button_container.add_child(button)


func _update_tileset_dummy_params(_cel: BaseCel, _index: int) -> void:
	_update_tileset()


func _create_tile_button(texture: Texture2D, index: int) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(button_size, button_size)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var texture_rect := TextureRect.new()
	texture_rect.texture = texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.set_anchor_and_offset(SIDE_LEFT, 0, 6)
	texture_rect.set_anchor_and_offset(SIDE_RIGHT, 1, -6)
	texture_rect.set_anchor_and_offset(SIDE_TOP, 0, 6)
	texture_rect.set_anchor_and_offset(SIDE_BOTTOM, 1, -6)
	texture_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	texture_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	var transparent_checker := TRANSPARENT_CHECKER.instantiate() as ColorRect
	transparent_checker.set_anchors_preset(Control.PRESET_FULL_RECT)
	transparent_checker.show_behind_parent = true
	texture_rect.add_child(transparent_checker)
	button.add_child(texture_rect)
	button.tooltip_text = str(index)
	button.toggled.connect(_on_tile_button_toggled.bind(index))
	button.gui_input.connect(_on_tile_button_gui_input.bind(index))
	if index == 0 and not show_empty_tile:
		button.visible = false
	return button


func select_tile(tile_index: int) -> void:
	tile_button_container.get_child(tile_index).button_pressed = true


static func _call_update_brushes() -> void:
	for slot in Tools._slots.values():
		if slot.tool_node is BaseDrawTool:
			slot.tool_node.update_brush()


func _on_tile_button_toggled(_toggled_on: bool, index: int) -> void:
	if Input.is_action_pressed("shift"):
		selected_tiles.sort()
		var diff_sign := signi(index - selected_tiles[-1])
		if diff_sign == 0:
			diff_sign = 1
		for i in range(selected_tiles[-1], index + diff_sign, diff_sign):
			if not selected_tiles.has(i):
				selected_tiles.append(i)
				tile_button_container.get_child(i).set_pressed_no_signal(true)
	elif Input.is_action_pressed("ctrl"):
		if selected_tiles.has(index):
			if selected_tiles.size() > 1:
				selected_tiles.erase(index)
		else:
			selected_tiles.append(index)
	else:
		selected_tile_index = index
		for i in tile_button_container.get_child_count():
			var child_button := tile_button_container.get_child(i) as BaseButton
			child_button.set_pressed_no_signal(i == index)
	place_tiles.button_pressed = true


func _on_tile_button_gui_input(event: InputEvent, index: int) -> void:
	if event.is_action(&"right_mouse"):
		tile_button_popup_menu.popup_on_parent(Rect2(get_global_mouse_position(), Vector2.ONE))
		tile_index_menu_popped = index
		tile_button_popup_menu.set_item_disabled(
			1, not current_tileset.tiles[index].can_be_removed()
		)


func _clear_tile_buttons() -> void:
	for child in tile_button_container.get_children():
		child.queue_free()


func _on_place_tiles_toggled(toggled_on: bool) -> void:
	placing_tiles = toggled_on
	transform_buttons_container.visible = placing_tiles
	mode_buttons_container.visible = !placing_tiles
	for child: Button in transform_buttons_container.get_children():
		Global.disable_button(child, not toggled_on)
	update_tip()


func _on_manual_toggled(toggled_on: bool) -> void:
	place_tiles.button_pressed = false
	if toggled_on:
		tile_editing_mode = TileEditingMode.MANUAL


func _on_auto_toggled(toggled_on: bool) -> void:
	place_tiles.button_pressed = false
	if toggled_on:
		tile_editing_mode = TileEditingMode.AUTO


func _on_stack_toggled(toggled_on: bool) -> void:
	place_tiles.button_pressed = false
	if toggled_on:
		tile_editing_mode = TileEditingMode.STACK


func _on_flip_horizontal_button_pressed() -> void:
	is_flipped_h = not is_flipped_h


func _on_flip_vertical_button_pressed() -> void:
	is_flipped_v = not is_flipped_v


func _on_rotate_pressed(clockwise: bool) -> void:
	for i in ROTATION_MATRIX.size():
		var final_i := i
		if (
			is_flipped_h == ROTATION_MATRIX[i * 3]
			&& is_flipped_v == ROTATION_MATRIX[i * 3 + 1]
			&& is_transposed == ROTATION_MATRIX[i * 3 + 2]
		):
			if clockwise:
				@warning_ignore("integer_division")
				final_i = i / 4 * 4 + posmod(i - 1, 4)
			else:
				@warning_ignore("integer_division")
				final_i = i / 4 * 4 + (i + 1) % 4
			is_flipped_h = ROTATION_MATRIX[final_i * 3]
			is_flipped_v = ROTATION_MATRIX[final_i * 3 + 1]
			is_transposed = ROTATION_MATRIX[final_i * 3 + 2]
			break


func _on_option_button_pressed() -> void:
	var pos := Vector2i(option_button.global_position) - options.size
	options.popup_on_parent(Rect2i(pos.x - 16, pos.y + 32, options.size.x, options.size.y))


func _on_tile_size_slider_value_changed(value: float) -> void:
	button_size = value


func _on_show_empty_tile_toggled(toggled_on: bool) -> void:
	show_empty_tile = toggled_on
	if tile_button_container.get_child_count() > 0:
		tile_button_container.get_child(0).visible = show_empty_tile


func _on_tile_button_popup_menu_index_pressed(index: int) -> void:
	var selected_tile := current_tileset.tiles[tile_index_menu_popped]
	if index == 0:  # Properties
		tile_probability_slider.value = selected_tile.probability
		tile_user_data_text_edit.text = selected_tile.user_data
		tile_properties.popup_centered()
	elif index == 1:  # Delete
		if tile_index_menu_popped == 0:
			return
		if selected_tile.can_be_removed():
			var project := Global.current_project
			var tilemap_cels: Array[CelTileMap] = []
			for cel in project.get_all_pixel_cels():
				if cel is not CelTileMap:
					continue
				if cel.tileset == current_tileset:
					tilemap_cels.append(cel)
			var undo_data_tileset := current_tileset.serialize_undo_data()
			var undo_data_tilemaps := {}
			for cel in tilemap_cels:
				undo_data_tilemaps[cel] = cel.serialize_undo_data(true)
			current_tileset.remove_tile_at_index(tile_index_menu_popped, null)
			var redo_data_tileset := current_tileset.serialize_undo_data()
			var redo_data_tilemaps := {}
			for cel in tilemap_cels:
				redo_data_tilemaps[cel] = cel.serialize_undo_data(true)
			project.undo_redo.create_action("Delete tile")
			project.undo_redo.add_do_method(
				current_tileset.deserialize_undo_data.bind(redo_data_tileset, null)
			)
			project.undo_redo.add_undo_method(
				current_tileset.deserialize_undo_data.bind(undo_data_tileset, null)
			)
			for cel in tilemap_cels:
				cel.deserialize_undo_data(redo_data_tilemaps[cel], project.undo_redo, false)
				cel.deserialize_undo_data(undo_data_tilemaps[cel], project.undo_redo, true)
			project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
			project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
			project.undo_redo.commit_action()


func _on_tile_probability_slider_value_changed(value: float) -> void:
	current_tileset.tiles[tile_index_menu_popped].probability = value


func _on_tile_user_data_text_edit_text_changed() -> void:
	current_tileset.tiles[tile_index_menu_popped].user_data = tile_user_data_text_edit.text
