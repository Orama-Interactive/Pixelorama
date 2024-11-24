class_name TileSetPanel
extends PanelContainer

enum TileEditingMode { MANUAL, AUTO, STACK }

static var tile_editing_mode := TileEditingMode.AUTO
var current_tileset: TileSetCustom

@onready var h_flow_container: HFlowContainer = $VBoxContainer/ScrollContainer/HFlowContainer


func _ready() -> void:
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
	for tile in tileset.tiles:
		var texture_rect := TextureButton.new()
		texture_rect.custom_minimum_size = Vector2i(32, 32)
		texture_rect.texture_normal = ImageTexture.create_from_image(tile.image)
		h_flow_container.add_child(texture_rect)


func _clear_tile_buttons() -> void:
	for child in h_flow_container.get_children():
		child.queue_free()


func _on_manual_toggled(toggled_on: bool) -> void:
	if toggled_on:
		tile_editing_mode = TileEditingMode.MANUAL


func _on_auto_toggled(toggled_on: bool) -> void:
	if toggled_on:
		tile_editing_mode = TileEditingMode.AUTO


func _on_stack_toggled(toggled_on: bool) -> void:
	if toggled_on:
		tile_editing_mode = TileEditingMode.STACK
