class_name TileSetPanel
extends PanelContainer

enum TileEditingMode { MANUAL, AUTO, STACK }

const TRANSPARENT_CHECKER := preload("res://src/UI/Nodes/TransparentChecker.tscn")

static var placing_tiles := false
static var tile_editing_mode := TileEditingMode.AUTO
static var selected_tile_index := 0
var current_tileset: TileSetCustom

@onready var tile_button_container: HFlowContainer = %TileButtonContainer


func _ready() -> void:
	Tools.selected_tile_index_changed.connect(select_tile)
	Global.cel_switched.connect(_on_cel_switched)
	Global.project_switched.connect(_on_cel_switched)


func _on_cel_switched() -> void:
	if Global.current_project.get_current_cel() is not CelTileMap:
		_clear_tile_buttons()
		return
	var cel := Global.current_project.get_current_cel() as CelTileMap
	if not cel.tileset.updated.is_connected(_update_tileset):
		cel.tileset.updated.connect(_update_tileset.bind(cel))
	_update_tileset(cel)


func _update_tileset(cel: BaseCel) -> void:
	_clear_tile_buttons()
	if cel is not CelTileMap:
		return
	var tilemap_cel := cel as CelTileMap
	if tilemap_cel != Global.current_project.get_current_cel():
		tilemap_cel.tileset.updated.disconnect(_update_tileset)
	var tileset := tilemap_cel.tileset
	var button_group := ButtonGroup.new()
	if selected_tile_index >= tileset.tiles.size():
		selected_tile_index = 0
	for i in tileset.tiles.size():
		var tile := tileset.tiles[i]
		var texture := ImageTexture.create_from_image(tile.image)
		var button := _create_tile_button(texture, i, button_group)
		if i == selected_tile_index:
			button.button_pressed = true
		tile_button_container.add_child(button)


func _create_tile_button(texture: Texture2D, index: int, button_group: ButtonGroup) -> Button:
	var button := Button.new()
	button.button_group = button_group
	button.toggle_mode = true
	button.custom_minimum_size = Vector2i(36, 36)
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


func _on_tile_button_toggled(toggled_on: bool, index: int) -> void:
	if toggled_on:
		selected_tile_index = index


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
