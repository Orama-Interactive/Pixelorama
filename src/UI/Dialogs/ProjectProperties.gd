extends AcceptDialog

const SAVE_TEXTURE := preload("uid://cvc120a27s57m")
const DUPLICATE_TEXTURE := preload("res://assets/graphics/timeline/copy_frame.png")
const REMOVE_TEXTURE := preload("res://assets/graphics/misc/close.png")

var _selected_tileset: TileSetCustom
var _current_tileset_name_filter: String

@onready var size_value_label := $VBoxContainer/GridContainer/SizeValueLabel as Label
@onready var color_mode_value_label := $VBoxContainer/GridContainer/ColorModeValueLabel as Label
@onready var frames_value_label := $VBoxContainer/GridContainer/FramesValueLabel as Label
@onready var layers_value_label := $VBoxContainer/GridContainer/LayersValueLabel as Label
@onready var name_line_edit := $VBoxContainer/GridContainer/NameLineEdit as LineEdit
@onready var user_data_text_edit := $VBoxContainer/GridContainer/UserDataTextEdit as TextEdit
@onready var tilesets_container := $VBoxContainer/TilesetsContainer as VBoxContainer
@onready var tilesets_list := %TilesetsList as Tree
@onready var filter_by_name_edit := %FilterByNameEdit as LineEdit
@onready var export_tileset_file_dialog: FileDialog = $ExportTilesetFileDialog


func _ready() -> void:
	export_tileset_file_dialog.use_native_dialog = Global.use_native_file_dialogs


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
	filter_by_name_edit.text = ""
	tilesets_list.clear()
	var root_item := tilesets_list.create_item()
	for i in Global.current_project.tilesets.size():
		_create_tileset_tree_item(i, root_item)


func _on_filter_by_name_line_edit_text_changed(new_text: String) -> void:
	_current_tileset_name_filter = new_text.strip_edges()
	apply_search_filters()


func apply_search_filters() -> void:
	var tree_item: TreeItem = tilesets_list.get_root().get_first_child()
	var results: Array[TreeItem] = []
	var should_reset := _current_tileset_name_filter.is_empty()
	while tree_item != null:  # Loop through Tree's TreeItems.
		if not _current_tileset_name_filter.is_empty():
			if _current_tileset_name_filter.is_subsequence_ofn(tree_item.get_text(0)):
				results.append(tree_item)
		if should_reset:
			tree_item.visible = true
		else:
			tree_item.collapsed = true
			tree_item.visible = false
		tree_item = tree_item.get_next_in_tree()
	var expanded: Array[TreeItem] = []
	for result in results:
		var item: TreeItem = result
		while item.get_parent():
			if expanded.has(item):
				break
			item.collapsed = false
			item.visible = true
			expanded.append(item)
			item = item.get_parent()
	if not results.is_empty():
		tilesets_list.scroll_to_item(results[0])


func _create_tileset_tree_item(i: int, root_item: TreeItem) -> void:
	var tileset := Global.current_project.tilesets[i]
	var tree_item := tilesets_list.create_item(root_item)
	var item_text := tileset.get_text_info(i)
	var using_layers := tileset.find_using_layers(Global.current_project)
	for tile: TileSetCustom.Tile in tileset.tiles:
		var preview: Image = tile.image
		if not preview.get_used_rect().size == Vector2i.ZERO:
			var icon := Image.create_from_data(
				preview.get_width(),
				preview.get_height(),
				preview.has_mipmaps(),
				preview.get_format(),
				preview.get_data()
			)
			var tex := ImageTexture.create_from_image(icon)
			tex.set_size_override(Vector2i(32, 32))
			tree_item.set_icon(0, tex)
			break
	for j in using_layers.size():
		if j == 0:
			item_text += "\n┖╴ Used by: "
		item_text += using_layers[j].name
		if j != using_layers.size() - 1:
			item_text += ", "
	tree_item.set_text(0, item_text)
	tree_item.set_metadata(0, i)
	tree_item.add_button(0, SAVE_TEXTURE, -1, false, "Export")
	tree_item.add_button(0, DUPLICATE_TEXTURE, -1, false, "Duplicate")
	tree_item.add_button(0, REMOVE_TEXTURE, -1, using_layers.size() > 0, "Delete")


func _on_tilesets_list_item_activated() -> void:
	var item := tilesets_list.get_selected()
	if item:
		# Setting it to editable here shows line edit only on double click
		item.set_editable(0, true)
		var tileset_index: int = item.get_metadata(0)
		var tileset: TileSetCustom = Global.current_project.tilesets.get(tileset_index)
		if tileset:
			# track old name for undo
			item.set_text(0, tileset.name)
		tilesets_list.edit_selected()


func _on_tilesets_list_item_edited() -> void:
	var item := tilesets_list.get_edited()
	if item:
		var tileset_index: int = item.get_metadata(0)
		var tileset: TileSetCustom = Global.current_project.tilesets.get(tileset_index)
		if tileset:
			var project := Global.current_project
			var old_name := tileset.name
			var new_name = item.get_text(0).strip_edges()
			if new_name.is_empty():
				new_name = old_name
			item.set_editable(0, false)
			project.undo_redo.create_action("Rename tileset")
			project.undo_redo.add_do_property(tileset, "name", new_name)
			project.undo_redo.add_undo_property(tileset, "name", old_name)
			project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
			project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
			project.undo_redo.commit_action()

			# Update the entry in the list
			var item_text := tileset.get_text_info(tileset_index)
			var using_layers := tileset.find_using_layers(Global.current_project)
			for j in using_layers.size():
				if j == 0:
					item_text += "\n┖╴ Used by: "
				item_text += using_layers[j].name
				if j != using_layers.size() - 1:
					item_text += ", "
			item.set_text(0, item_text)


func _on_name_line_edit_text_changed(new_text: String) -> void:
	new_text = new_text.strip_edges()
	if new_text.is_empty() or !new_text.is_valid_filename():
		new_text = tr("untitled")
	Global.current_project.name = new_text


func _on_user_data_text_edit_text_changed() -> void:
	Global.current_project.user_data = user_data_text_edit.text


func _on_tilesets_list_button_clicked(item: TreeItem, column: int, id: int, _mbi: int) -> void:
	var tileset_index: int = item.get_metadata(column)
	var project := Global.current_project
	var tileset: TileSetCustom
	if tileset_index < project.tilesets.size():
		tileset = project.tilesets[tileset_index]
	else:
		tileset = project.tilesets[-1]
	_selected_tileset = tileset
	if id == 0:  # Export
		export_tileset_file_dialog.popup_centered_clamped()
	elif id == 1:  # Duplicate
		var new_tileset := tileset.duplicate()
		for i in range(1, tileset.tiles.size()):
			var tile := tileset.tiles[i]
			var new_image := Image.new()
			new_image.copy_from(tile.image)
			new_tileset.add_tile(new_image, null)
		project.undo_redo.create_action("Duplicate tileset")
		project.undo_redo.add_do_method(func(): project.tilesets.append(new_tileset))
		project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
		project.undo_redo.add_undo_method(func(): project.tilesets.erase(new_tileset))
		project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
		project.undo_redo.commit_action()
		_create_tileset_tree_item(item.get_parent().get_child_count(), item.get_parent())
	elif id == 2:  # Delete
		if tileset.find_using_layers(project).size() > 0:
			return
		project.undo_redo.create_action("Delete tileset")
		project.undo_redo.add_do_method(func(): project.tilesets.erase(tileset))
		project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
		project.undo_redo.add_undo_method(func(): project.tilesets.insert(tileset_index, tileset))
		project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
		project.undo_redo.commit_action()
		item.free()


func _on_export_tileset_file_dialog_file_selected(path: String) -> void:
	if not is_instance_valid(_selected_tileset):
		return
	match path.get_extension().to_lower():
		"png":
			var image := _selected_tileset.create_image_atlas()
			if is_instance_valid(image) and not image.is_empty():
				image.save_png(path)
		"tres":
			var godot_tileset := _selected_tileset.create_godot_tileset()
			ResourceSaver.save(godot_tileset, path)
