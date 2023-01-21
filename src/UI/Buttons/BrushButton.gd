extends BaseButton

var brush = Global.brushes_popup.Brush.new()


func _ready():
	$TransparentChecker.fit_rect($BrushTexture.get_rect())


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
