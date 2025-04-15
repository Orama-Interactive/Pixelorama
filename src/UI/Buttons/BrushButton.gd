extends BaseButton

var brush = Global.brushes_popup.Brush.new()


func _ready() -> void:
	Tools.flip_rotated.connect(_flip_rotate_updated)


func _on_BrushButton_pressed() -> void:
	# Delete the brush on middle mouse press
	if Input.is_action_just_released("middle_mouse"):
		_on_DeleteButton_pressed()
	else:
		Global.brushes_popup.select_brush(brush)


func _on_DeleteButton_pressed() -> void:
	if brush.type != Global.brushes_popup.CUSTOM:
		return

	Global.brushes_popup.remove_brush(self)


func _on_BrushButton_mouse_entered() -> void:
	if brush.type == Global.brushes_popup.CUSTOM:
		$DeleteButton.visible = true


func _on_BrushButton_mouse_exited() -> void:
	if brush.type == Global.brushes_popup.CUSTOM:
		$DeleteButton.visible = false


func _flip_rotate_updated(flip_x: bool, flip_y: bool, transposed: bool) -> void:
	var brush_texture_rotation := 0
	if transposed == true:
		brush_texture_rotation -= 90
	$BrushTexture.rotation_degrees = brush_texture_rotation
	$BrushTexture.set_flip_h(flip_x)
	$BrushTexture.set_flip_v(flip_y)
