extends ConfirmationDialog

onready var x_basis_x_spinbox: SpinBox = $VBoxContainer/HBoxContainer/OptionsContainer/XBasisX
onready var x_basis_y_spinbox: SpinBox = $VBoxContainer/HBoxContainer/OptionsContainer/XBasisY
onready var y_basis_x_spinbox: SpinBox = $VBoxContainer/HBoxContainer/OptionsContainer/YBasisX
onready var y_basis_y_spinbox: SpinBox = $VBoxContainer/HBoxContainer/OptionsContainer/YBasisY
onready var preview_rect: Control = $VBoxContainer/AspectRatioContainer/Preview
onready var tile_mode: Node2D = $VBoxContainer/AspectRatioContainer/Preview/TileMode
onready var load_button: Button = $VBoxContainer/HBoxContainer/Mask/LoadMask
onready var reset_mask: Button = $VBoxContainer/HBoxContainer/Mask/ResetMask
onready var mask_hint: TextureRect = $VBoxContainer/HBoxContainer/Mask/MaskHint


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

	reset_mask.disabled = true
	if Global.current_project.tiles.has_mask:
		reset_mask.disabled = false

	update_preview()


func _show_options():
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
	var offset := -bounding_rect.position
	var axis_scale := preview_rect.rect_size / bounding_rect.size
	var min_scale: Vector2 = preview_rect.rect_size / (tile_mode.tiles.tile_size * 3.0)
	var scale: float = [axis_scale.x, axis_scale.y, min_scale.x, min_scale.y].min()
	var t := Transform2D.IDENTITY.translated(offset).scaled(Vector2(scale, scale))
	var transformed_bounding_rect: Rect2 = t.xform(bounding_rect)
	var centering_offset := (preview_rect.rect_size - transformed_bounding_rect.size) / 2.0
	t = t.translated(centering_offset / scale)
	tile_mode.transform = t
	tile_mode.update()
	preview_rect.get_node("TransparentChecker").rect_size = preview_rect.rect_size

	# Also update the tile_mask preview
	var tex := ImageTexture.new()
	tex.create_from_image(Global.current_project.tiles.tile_mask)
	mask_hint.texture = tex


func _on_TileModeOffsetsDialog_popup_hide() -> void:
	Global.dialog_open(false)


func _on_TileModeOffsetsDialog_item_rect_changed():
	if tile_mode:
		update_preview()


func _on_Reset_pressed():
	var size = Global.current_project.size
	tile_mode.tiles.x_basis = Vector2(size.x, 0)
	tile_mode.tiles.y_basis = Vector2(0, size.y)
	x_basis_x_spinbox.value = size.x
	x_basis_y_spinbox.value = 0
	y_basis_x_spinbox.value = 0
	y_basis_y_spinbox.value = size.y
	update_preview()


func _on_LoadMask_pressed() -> void:
	var frame_idx = Global.current_project.current_frame
	var current_frame = Global.current_project.frames[frame_idx]
	var tiles = Global.current_project.tiles
	var size = tiles.tile_size
	var image := Image.new()
	image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	Export.blend_layers(image, current_frame)
	if image.get_used_rect().size == Vector2.ZERO:
		reset_mask.disabled = true
		tiles.reset_mask()
	else:
		load_mask(image)
	update_preview()


func load_mask(image: Image):
	reset_mask.disabled = false
	Global.current_project.tiles.tile_mask = image
	Global.current_project.tiles.has_mask = true


func _on_ResetMask_pressed() -> void:
	reset_mask.disabled = true
	Global.current_project.tiles.reset_mask()
	update_preview()
