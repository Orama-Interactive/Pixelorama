extends ConfirmationDialog

var selected_tileset: TileSetCustom
var _tileset_rows := 1
var _tileset_transpose := false

@onready var tile_set_preview: TextureRect = %TileSetPreview
@onready var tile_set_shape_option_button: OptionButton = %TileSetShapeOptionButton
@onready var tile_set_size_value_slider: ValueSliderV2 = %TileSetSizeValueSlider
@onready var export_tileset_file_dialog: FileDialog = $ExportTilesetFileDialog


func _ready() -> void:
	export_tileset_file_dialog.use_native_dialog = Global.use_native_file_dialogs


func _update_tileset_preview() -> void:
	var image := selected_tileset.create_image_atlas(_tileset_rows, _tileset_transpose)
	tile_set_preview.texture = ImageTexture.create_from_image(image)


func _on_about_to_popup() -> void:
	tile_set_shape_option_button.select(selected_tileset.tile_shape)
	tile_set_size_value_slider.value = selected_tileset.tile_size
	_update_tileset_preview()


func _on_tile_set_rows_value_slider_value_changed(value: float) -> void:
	_tileset_rows = value
	_update_tileset_preview()


func _on_transpose_check_button_toggled(toggled_on: bool) -> void:
	_tileset_transpose = toggled_on
	_update_tileset_preview()


func _on_confirmed() -> void:
	export_tileset_file_dialog.popup_centered_clamped()


func _on_export_tileset_file_dialog_file_selected(path: String) -> void:
	if not is_instance_valid(selected_tileset):
		return
	var tile_shape := tile_set_shape_option_button.selected
	var tile_size := tile_set_size_value_slider.value
	match path.get_extension().to_lower():
		"png":
			var image := selected_tileset.create_image_atlas(_tileset_rows, _tileset_transpose)
			if is_instance_valid(image) and not image.is_empty():
				image.save_png(path)
		"tres":
			var godot_tileset := selected_tileset.create_godot_tileset(
				_tileset_rows, _tileset_transpose, tile_shape, tile_size
			)
			ResourceSaver.save(godot_tileset, path)
