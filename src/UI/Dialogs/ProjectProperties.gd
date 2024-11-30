extends AcceptDialog

const DUPLICATE_TEXTURE := preload("res://assets/graphics/timeline/copy_frame.png")
const REMOVE_TEXTURE := preload("res://assets/graphics/misc/close.png")

@onready var size_value_label := $VBoxContainer/GridContainer/SizeValueLabel as Label
@onready var color_mode_value_label := $VBoxContainer/GridContainer/ColorModeValueLabel as Label
@onready var frames_value_label := $VBoxContainer/GridContainer/FramesValueLabel as Label
@onready var layers_value_label := $VBoxContainer/GridContainer/LayersValueLabel as Label
@onready var name_line_edit := $VBoxContainer/GridContainer/NameLineEdit as LineEdit
@onready var user_data_text_edit := $VBoxContainer/GridContainer/UserDataTextEdit as TextEdit
@onready var tilesets_container := $VBoxContainer/TilesetsContainer as VBoxContainer
@onready var tilesets_list := $VBoxContainer/TilesetsContainer/TilesetsList as Tree


func _on_visibility_changed() -> void:
	Global.dialog_open(visible)
	size_value_label.text = str(Global.current_project.size)
	if Global.current_project.get_image_format() == Image.FORMAT_RGBA8:
		color_mode_value_label.text = "RGBA8"
	else:
		color_mode_value_label.text = str(Global.current_project.get_image_format())
	if Global.current_project.is_indexed():
		color_mode_value_label.text += " (%s)" % tr("Indexed")
	frames_value_label.text = str(Global.current_project.frames.size())
	layers_value_label.text = str(Global.current_project.layers.size())
	name_line_edit.text = Global.current_project.name
	user_data_text_edit.text = Global.current_project.user_data
	tilesets_container.visible = Global.current_project.tilesets.size() > 0
	tilesets_list.clear()
	var root_item := tilesets_list.create_item()
	for i in Global.current_project.tilesets.size():
		_create_tileset_tree_item(i, root_item)


func _create_tileset_tree_item(i: int, root_item: TreeItem) -> void:
	var tileset := Global.current_project.tilesets[i]
	var tree_item := tilesets_list.create_item(root_item)
	var item_text := tileset.get_text_info(i)
	var using_layers := tileset.find_using_layers(Global.current_project)
	for j in using_layers.size():
		if j == 0:
			item_text += " ("
		item_text += using_layers[j].name
		if j == using_layers.size() - 1:
			item_text += ")"
		else:
			item_text += ", "
	tree_item.set_text(0, item_text)
	tree_item.set_metadata(0, i)
	tree_item.add_button(0, DUPLICATE_TEXTURE, -1, false, "Duplicate")
	tree_item.add_button(0, REMOVE_TEXTURE, -1, using_layers.size() > 0, "Delete")


func _on_name_line_edit_text_changed(new_text: String) -> void:
	Global.current_project.name = new_text


func _on_user_data_text_edit_text_changed() -> void:
	Global.current_project.user_data = user_data_text_edit.text


func _on_tilesets_list_button_clicked(item: TreeItem, column: int, id: int, _mbi: int) -> void:
	var tileset_index: int = item.get_metadata(column)
	var project := Global.current_project
	var tileset := project.tilesets[tileset_index]
	if id == 0:  # Duplicate
		var new_tileset := TileSetCustom.new(tileset.tile_size, tileset.name)
		for i in range(1, tileset.tiles.size()):
			var tile := tileset.tiles[i]
			var new_image := Image.new()
			new_image.copy_from(tile.image)
			new_tileset.add_tile(new_image, null)
		project.undos += 1
		project.undo_redo.create_action("Duplicate tileset")
		project.undo_redo.add_do_method(func(): project.tilesets.append(new_tileset))
		project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
		project.undo_redo.add_undo_method(func(): project.tilesets.erase(new_tileset))
		project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
		project.undo_redo.commit_action()
		_create_tileset_tree_item(item.get_parent().get_child_count(), item.get_parent())
	if id == 1:  # Delete
		if tileset.find_using_layers(project).size() > 0:
			return
		project.undos += 1
		project.undo_redo.create_action("Delete tileset")
		project.undo_redo.add_do_method(func(): project.tilesets.erase(tileset))
		project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
		project.undo_redo.add_undo_method(func(): project.tilesets.insert(tileset_index, tileset))
		project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
		project.undo_redo.commit_action()
		item.free()
