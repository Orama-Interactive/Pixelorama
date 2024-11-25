class_name TileSetPanel
extends PanelContainer

enum TileEditingMode { MANUAL, AUTO, STACK }

const TRANSPARENT_CHECKER := preload("res://src/UI/Nodes/TransparentChecker.tscn")
const MIN_BUTTON_SIZE := 36
const MAX_BUTTON_SIZE := 144

static var placing_tiles := false:
	set(value):
		placing_tiles = value
		_call_update_brushes()
static var tile_editing_mode := TileEditingMode.AUTO
static var selected_tile_index := 0:
	set(value):
		selected_tile_index = value
		_call_update_brushes()
var current_tileset: TileSetCustom
var button_size := 36:
	set(value):
		if button_size == value:
			return
		button_size = clampi(value, MIN_BUTTON_SIZE, MAX_BUTTON_SIZE)
		update_minimum_size()
		Global.config_cache.set_value("tileset_panel", "button_size", button_size)
		for button: Control in tile_button_container.get_children():
			button.custom_minimum_size = Vector2(button_size, button_size)
			button.size = Vector2(button_size, button_size)

@onready var place_tiles: CheckBox = $VBoxContainer/PlaceTiles
@onready var tile_button_container: HFlowContainer = %TileButtonContainer


func _ready() -> void:
	Tools.selected_tile_index_changed.connect(select_tile)
	Global.cel_switched.connect(_on_cel_switched)
	#Global.project_switched.connect(_on_cel_switched)


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
	current_tileset = tileset
	if (
		is_instance_valid(current_tileset)
		and not current_tileset.updated.is_connected(_update_tileset)
	):
		current_tileset.updated.connect(_update_tileset)


func _on_cel_switched() -> void:
	if Global.current_project.get_current_cel() is not CelTileMap:
		set_tileset(null)
		_clear_tile_buttons()
		return
	var cel := Global.current_project.get_current_cel() as CelTileMap
	set_tileset(cel.tileset)
	_update_tileset(cel)


func _update_tileset(cel: BaseCel) -> void:
	_clear_tile_buttons()
	if cel is not CelTileMap:
		return
	var tilemap_cel := cel as CelTileMap
	var tileset := tilemap_cel.tileset
	var button_group := ButtonGroup.new()
	if selected_tile_index >= tileset.tiles.size():
		selected_tile_index = 0
	for i in tileset.tiles.size():
		var tile := tileset.tiles[i]
		var texture := ImageTexture.create_from_image(tile.image)
		var button := _create_tile_button(texture, i, button_group)
		if i == selected_tile_index:
			button.set_pressed_no_signal(true)
		tile_button_container.add_child(button)


func _create_tile_button(texture: Texture2D, index: int, button_group: ButtonGroup) -> Button:
	var button := Button.new()
	button.button_group = button_group
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
	return button


func select_tile(tile_index: int) -> void:
	tile_button_container.get_child(tile_index).button_pressed = true


static func _call_update_brushes() -> void:
	for slot in Tools._slots.values():
		if slot.tool_node is BaseDrawTool:
			slot.tool_node.update_brush()


func _on_tile_button_toggled(toggled_on: bool, index: int) -> void:
	if toggled_on:
		selected_tile_index = index
		place_tiles.button_pressed = true


func _clear_tile_buttons() -> void:
	for child in tile_button_container.get_children():
		child.queue_free()


func _on_place_tiles_toggled(toggled_on: bool) -> void:
	placing_tiles = toggled_on


func _on_manual_toggled(toggled_on: bool) -> void:
	if toggled_on:
		tile_editing_mode = TileEditingMode.MANUAL


func _on_auto_toggled(toggled_on: bool) -> void:
	if toggled_on:
		tile_editing_mode = TileEditingMode.AUTO


func _on_stack_toggled(toggled_on: bool) -> void:
	if toggled_on:
		tile_editing_mode = TileEditingMode.STACK
