extends ConfirmationDialog

@onready var animation_timeline := get_parent() as Control
@onready var name_line_edit: LineEdit = $GridContainer/NameLineEdit
@onready var tileset_option_button: OptionButton = $GridContainer/TilesetOptionButton
@onready var tileset_name_line_edit: LineEdit = $GridContainer/TilesetNameLineEdit
@onready var tile_size_slider: ValueSliderV2 = $GridContainer/TileSizeSlider


func _on_confirmed() -> void:
	var project := Global.current_project
	var layer_name := name_line_edit.text
	var tileset_name := tileset_name_line_edit.text
	var tile_size := tile_size_slider.value
	var tileset: TileSetCustom
	if tileset_option_button.selected == 0:
		tileset = TileSetCustom.new(tile_size, tileset_name)
	else:
		tileset = project.tilesets[tileset_option_button.selected - 1]
	var layer := LayerTileMap.new(project, tileset, layer_name)
	animation_timeline.add_layer(layer, project)


func _on_visibility_changed() -> void:
	Global.dialog_open(visible)


func _on_about_to_popup() -> void:
	var project := Global.current_project
	var default_name := tr("Tilemap") + " %s" % (project.layers.size() + 1)
	name_line_edit.text = default_name
	tileset_option_button.clear()
	tileset_option_button.add_item("New tileset")
	for i in project.tilesets.size():
		var tileset := project.tilesets[i]
		tileset_option_button.add_item(tileset.get_text_info(i))
	_on_tileset_option_button_item_selected(tileset_option_button.selected)


func _on_tileset_option_button_item_selected(index: int) -> void:
	if index > 0:
		var tileset := Global.current_project.tilesets[index - 1]
		tileset_name_line_edit.text = tileset.name
		tile_size_slider.value = tileset.tile_size
	tileset_name_line_edit.editable = index == 0
	tile_size_slider.editable = tileset_name_line_edit.editable
