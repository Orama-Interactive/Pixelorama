extends ConfirmationDialog

@onready var x_basis_x_spinbox: SpinBox = $VBoxContainer/HBoxContainer/OptionsContainer/XBasisX
@onready var x_basis_y_spinbox: SpinBox = $VBoxContainer/HBoxContainer/OptionsContainer/XBasisY
@onready var y_basis_x_spinbox: SpinBox = $VBoxContainer/HBoxContainer/OptionsContainer/YBasisX
@onready var y_basis_y_spinbox: SpinBox = $VBoxContainer/HBoxContainer/OptionsContainer/YBasisY
@onready var preview_rect: Control = $VBoxContainer/AspectRatioContainer/Preview
@onready var tile_mode: Node2D = $VBoxContainer/AspectRatioContainer/Preview/TileMode


func _ready() -> void:
	Global.project_switched.connect(change_mask)
	Global.cel_switched.connect(change_mask)
	await get_tree().process_frame
	change_mask()


func _on_TileModeOffsetsDialog_about_to_show() -> void:
	tile_mode.draw_center = true
	tile_mode.tiles = Tiles.new(Global.current_project.size)
	tile_mode.tiles.mode = Tiles.MODE.BOTH
	if Global.current_project.tiles.mode != Tiles.MODE.NONE:
		tile_mode.tiles.mode = Global.current_project.tiles.mode
	if Global.current_project.tiles.mode != Tiles.MODE.NONE:
		tile_mode.tiles.mode = Global.current_project.tiles.mode
	tile_mode.tiles.x_basis = Global.current_project.tiles.x_basis
	tile_mode.tiles.y_basis = Global.current_project.tiles.y_basis
	x_basis_x_spinbox.value = tile_mode.tiles.x_basis.x
	x_basis_y_spinbox.value = tile_mode.tiles.x_basis.y
	y_basis_x_spinbox.value = tile_mode.tiles.y_basis.x
	y_basis_y_spinbox.value = tile_mode.tiles.y_basis.y

	_show_options()
	if Global.current_project.tiles.mode == Tiles.MODE.X_AXIS:
		y_basis_x_spinbox.visible = false
		y_basis_y_spinbox.visible = false
		$VBoxContainer/HBoxContainer/OptionsContainer/YBasisXLabel.visible = false
		$VBoxContainer/HBoxContainer/OptionsContainer/YBasisYLabel.visible = false
	elif Global.current_project.tiles.mode == Tiles.MODE.Y_AXIS:
		x_basis_x_spinbox.visible = false
		x_basis_y_spinbox.visible = false
		$VBoxContainer/HBoxContainer/OptionsContainer/XBasisXLabel.visible = false
		$VBoxContainer/HBoxContainer/OptionsContainer/XBasisYLabel.visible = false

	update_preview()


func _show_options() -> void:
	x_basis_x_spinbox.visible = true
	x_basis_y_spinbox.visible = true
	y_basis_x_spinbox.visible = true
	y_basis_y_spinbox.visible = true
	$VBoxContainer/HBoxContainer/OptionsContainer/YBasisXLabel.visible = true
	$VBoxContainer/HBoxContainer/OptionsContainer/YBasisYLabel.visible = true
	$VBoxContainer/HBoxContainer/OptionsContainer/XBasisXLabel.visible = true
	$VBoxContainer/HBoxContainer/OptionsContainer/XBasisYLabel.visible = true


func _on_TileModeOffsetsDialog_confirmed() -> void:
	Global.current_project.tiles.x_basis = tile_mode.tiles.x_basis
	Global.current_project.tiles.y_basis = tile_mode.tiles.y_basis
	Global.canvas.tile_mode.queue_redraw()
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
	var offset := -bounding_rect.position
	var axis_scale := preview_rect.size / bounding_rect.size
	var min_scale: Vector2 = preview_rect.size / (tile_mode.tiles.tile_size * 3.0)
	var scale: float = [axis_scale.x, axis_scale.y, min_scale.x, min_scale.y].min()
	var t := Transform2D.IDENTITY.translated(offset).scaled(Vector2(scale, scale))
	var transformed_bounding_rect: Rect2 = t * (bounding_rect)
	var centering_offset := (preview_rect.size - transformed_bounding_rect.size) / 2.0
	t = t.translated(centering_offset / scale)
	tile_mode.transform = t
	tile_mode.queue_redraw()
	preview_rect.get_node("TransparentChecker").size = preview_rect.size


func _on_TileModeOffsetsDialog_visibility_changed() -> void:
	Global.dialog_open(false)


func _on_TileModeOffsetsDialog_size_changed() -> void:
	if tile_mode:
		update_preview()


func _on_Reset_pressed() -> void:
	tile_mode.tiles.x_basis = Vector2i(Global.current_project.size.x, 0)
	tile_mode.tiles.y_basis = Vector2i(0, Global.current_project.size.y)
	x_basis_x_spinbox.value = Global.current_project.size.x
	x_basis_y_spinbox.value = 0
	y_basis_x_spinbox.value = 0
	y_basis_y_spinbox.value = Global.current_project.size.y
	update_preview()


func change_mask() -> void:
	if Global.current_project.tiles.mode == Tiles.MODE.NONE:
		return
	var frame_idx := Global.current_project.current_frame
	var current_frame := Global.current_project.frames[frame_idx]
	var tiles := Global.current_project.tiles
	var tiles_size := tiles.tile_size
	var image := Image.create(tiles_size.x, tiles_size.y, false, Image.FORMAT_RGBA8)
	DrawingAlgos.blend_layers(image, current_frame)
	if (
		image.get_used_rect().size == Vector2i.ZERO
		or not $VBoxContainer/HBoxContainer/Masking.button_pressed
	):
		tiles.reset_mask()
	else:
		load_mask(image)


func load_mask(image: Image) -> void:
	Global.current_project.tiles.tile_mask = image
	Global.current_project.tiles.has_mask = true


func _on_Masking_toggled(_button_pressed: bool) -> void:
	change_mask()
