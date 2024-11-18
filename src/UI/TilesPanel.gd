extends ScrollContainer

@onready var h_flow_container: HFlowContainer = $PanelContainer/HFlowContainer


func _ready() -> void:
	Global.project_switched.connect(_on_project_switched)
	Global.project_switched.connect(_update_tilesets)
	Global.current_project.tilesets_updated.connect(_update_tilesets)


func _on_project_switched() -> void:
	if not Global.current_project.tilesets_updated.is_connected(_update_tilesets):
		Global.current_project.tilesets_updated.connect(_update_tilesets)


# TODO: Handle signal methods better and rename them to avoid confusion.
func _update_tilesets() -> void:
	for child in h_flow_container.get_children():
		child.queue_free()
	if Global.current_project.tilesets.size() == 0:
		return
	var tileset := Global.current_project.tilesets[0]
	if not tileset.updated.is_connected(_update_tileset):
		tileset.updated.connect(_update_tileset)


func _update_tileset() -> void:
	for child in h_flow_container.get_children():
		child.queue_free()
	var tileset := Global.current_project.tilesets[0]
	for tile in tileset.tiles:
		var texture_rect := TextureButton.new()
		texture_rect.custom_minimum_size = Vector2i(32, 32)
		texture_rect.texture_normal = ImageTexture.create_from_image(tile)
		h_flow_container.add_child(texture_rect)
