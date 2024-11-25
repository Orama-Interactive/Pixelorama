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
		tileset = TileSetCustom.new(tile_size, project, tileset_name)
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
		var item_string := " %s (%s×%s)" % [i, tileset.tile_size.x, tileset.tile_size.y]
		if not tileset.name.is_empty():
			item_string += ": " + tileset.name
		tileset_option_button.add_item(tr("Tileset" + item_string))