extends ConfirmationDialog

var image: Image

onready var x_basis_x_spinbox: SpinBox = $VBoxContainer/OptionsContainer/XBasisX
onready var x_basis_y_spinbox: SpinBox = $VBoxContainer/OptionsContainer/XBasisY
onready var y_basis_x_spinbox: SpinBox = $VBoxContainer/OptionsContainer/YBasisX
onready var y_basis_y_spinbox: SpinBox = $VBoxContainer/OptionsContainer/YBasisY
onready var preview_rect: TextureRect = $VBoxContainer/AspectRatioContainer/Preview
onready var tile_mode: Node2D = $VBoxContainer/AspectRatioContainer/Preview/TileMode


func _on_TileModeOffsets_about_to_show() -> void:
	tile_mode.tiles = Tiles.new(Global.current_project.size)
	tile_mode.tiles.mode = Tiles.MODE.BOTH
	tile_mode.tiles.x_basis = Global.current_project.tiles.x_basis
	tile_mode.tiles.y_basis = Global.current_project.tiles.y_basis
	x_basis_x_spinbox.value = tile_mode.tiles.x_basis.x
	x_basis_y_spinbox.value = tile_mode.tiles.x_basis.y
	y_basis_x_spinbox.value = tile_mode.tiles.y_basis.x
	y_basis_y_spinbox.value = tile_mode.tiles.y_basis.y
	preview_rect.get_node("TransparentChecker").rect_size = preview_rect.rect_size
	update_preview()


func _on_TileModeOffsets_confirmed() -> void:
	Global.current_project.tiles.x_basis = tile_mode.tiles.x_basis
	Global.current_project.tiles.y_basis = tile_mode.tiles.y_basis
	Global.canvas.tile_mode.update()
	Global.transparent_checker.update_rect()


func _on_XBasisX_value_changed(value: int) -> void:
	tile_mode.tiles.x_basis.x = value
	update_preview()


func _on_XBasisY_value_changed(value: int) -> void:
	tile_mode.tiles.x_basis.y = value
	update_preview()


func _on_YBasisX_value_changed(value: int) -> void:
	tile_mode.tiles.y_basis.x = value
	update_preview()


func _on_YBasisY_value_changed(value: int) -> void:
	tile_mode.tiles.y_basis.y = value
	update_preview()


func update_preview() -> void:
	var bounding_rect: Rect2 = tile_mode.tiles.get_bounding_rect()
	var offset := preview_rect.rect_position - bounding_rect.position
	var axis_scale := preview_rect.rect_size / bounding_rect.size
	var min_scale: Vector2 = preview_rect.rect_size / (tile_mode.tiles.tile_size * 3.0)
	var scale: float = [axis_scale.x, axis_scale.y, min_scale.x, min_scale.y].min()
	var t := Transform2D.IDENTITY.translated(offset).scaled(Vector2(scale, scale))
	var transformed_bounding_rect: Rect2 = t.xform(bounding_rect)
	var centering_offset := (preview_rect.rect_size - transformed_bounding_rect.size) / 2.0
	t = t.translated(centering_offset / scale)
	tile_mode.transform = t
	tile_mode.update()


func _on_TileModeOffsets_popup_hide() -> void:
	Global.dialog_open(false)
