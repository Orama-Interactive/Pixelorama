extends VBoxContainer


var previous_left_color := Color.black
var previous_right_color := Color.white


func _on_ColorSwitch_pressed() -> void:
	var temp: Color = Global.color_pickers[0].color
	Global.color_pickers[0].color = Global.color_pickers[1].color
	Global.color_pickers[1].color = temp
	Global.update_left_custom_brush()
	Global.update_right_custom_brush()


func _on_ColorPickerButton_color_changed(color : Color, right : bool):
	# If the color changed while it's on full transparency, make it opaque (GH issue #54)
	if right:
		if color.a == 0:
			if previous_right_color.r != color.r or previous_right_color.g != color.g or previous_right_color.b != color.b:
				Global.color_pickers[1].color.a = 1
		Global.update_right_custom_brush()
		previous_right_color = color
	else:
		if color.a == 0:
			if previous_left_color.r != color.r or previous_left_color.g != color.g or previous_left_color.b != color.b:
				Global.color_pickers[0].color.a = 1
		Global.update_left_custom_brush()
		previous_left_color = color


func _on_ColorPickerButton_pressed() -> void:
	Global.can_draw = false


func _on_ColorPickerButton_popup_closed() -> void:
	Global.can_draw = true


func _on_ColorDefaults_pressed() -> void:
	Global.color_pickers[0].color = Color.black
	Global.color_pickers[1].color = Color.white
	Global.update_left_custom_brush()
	Global.update_right_custom_brush()


func _on_FitToFrameButton_pressed() -> void:
	Global.camera.fit_to_frame(Global.canvas.size)


func _on_100ZoomButton_pressed() -> void:
	Global.camera.zoom = Vector2.ONE
	Global.camera.offset = Global.canvas.size / 2
	Global.zoom_level_label.text = str(round(100 / Global.camera.zoom.x)) + " %"
	Global.horizontal_ruler.update()
	Global.vertical_ruler.update()


func _on_BrushTypeButton_pressed(right : bool) -> void:
	if right:
		Global.brushes_popup.popup(Rect2(Global.brush_type_buttons[1].rect_global_position, Vector2(226, 72)))
		Global.brush_type_window_position = "right"
	else:
		Global.brushes_popup.popup(Rect2(Global.brush_type_buttons[0].rect_global_position, Vector2(226, 72)))
		Global.brush_type_window_position = "left"


func _on_BrushSizeEdit_value_changed(value : float, right : bool) -> void:
	var new_size = int(value)
	if right:
		Global.brush_size_edits[1].value = value
		Global.brush_size_sliders[1].value = value
		Global.right_brush_size = new_size
		Global.update_right_custom_brush()
	else:
		Global.brush_size_edits[0].value = value
		Global.brush_size_sliders[0].value = value
		Global.left_brush_size = new_size
		Global.update_left_custom_brush()


func _on_PixelPerfectMode_toggled(button_pressed : bool, right : bool) -> void:
	if right:
		Global.right_pixel_perfect = button_pressed
	else:
		Global.left_pixel_perfect = button_pressed


func _on_InterpolateFactor_value_changed(value : float, right : bool) -> void:
	if right:
		Global.interpolate_spinboxes[1].value = value
		Global.interpolate_sliders[1].value = value
		Global.update_right_custom_brush()
	else:
		Global.interpolate_spinboxes[0].value = value
		Global.interpolate_sliders[0].value = value
		Global.update_left_custom_brush()


func _on_FillAreaOptions_item_selected(ID : int, right : bool) -> void:
	if right:
		Global.right_fill_area = ID
	else:
		Global.left_fill_area = ID


func _on_FillWithOptions_item_selected(ID : int, right : bool) -> void:
	if right:
		Global.right_fill_with = ID
		if ID == 1:
			Global.fill_pattern_containers[1].visible = true
		else:
			Global.fill_pattern_containers[1].visible = false
	else:
		Global.left_fill_with = ID
		if ID == 1:
			Global.fill_pattern_containers[0].visible = true
		else:
			Global.fill_pattern_containers[0].visible = false


func _on_PatternTypeButton_pressed(right : bool) -> void:
	if right:
		Global.pattern_window_position = "right"
		Global.patterns_popup.popup(Rect2(Global.brush_type_buttons[1].rect_global_position, Vector2(226, 72)))
	else:
		Global.pattern_window_position = "left"
		Global.patterns_popup.popup(Rect2(Global.brush_type_buttons[0].rect_global_position, Vector2(226, 72)))


func _on_PatternOffsetX_value_changed(value : float, right : bool) -> void:
	if right:
		Global.right_fill_pattern_offset.x = value
	else:
		Global.left_fill_pattern_offset.x = value


func _on_PatternOffsetY_value_changed(value : float, right : bool) -> void:
	if right:
		Global.right_fill_pattern_offset.y = value
	else:
		Global.left_fill_pattern_offset.y = value


func _on_LightenDarken_item_selected(ID : int, right : bool) -> void:
	if right:
		Global.right_ld = ID
	else:
		Global.left_ld = ID


func _on_LDAmount_value_changed(value : float, right : bool) -> void:
	if right:
		Global.right_ld_amount = value / 100
		Global.ld_amount_sliders[1].value = value
		Global.ld_amount_spinboxes[1].value = value
	else:
		Global.left_ld_amount = value / 100
		Global.ld_amount_sliders[0].value = value
		Global.ld_amount_spinboxes[0].value = value


func _on_ForColorOptions_item_selected(ID : int, right : bool) -> void:
	if right:
		Global.right_color_picker_for = ID
	else:
		Global.left_color_picker_for = ID


func _on_ZoomModeOptions_item_selected(ID : int, right : bool) -> void:
	if right:
		Global.right_zoom_mode = ID
	else:
		Global.left_zoom_mode = ID


func _on_HorizontalMirroring_toggled(button_pressed : bool, right : bool) -> void:
	if right:
		Global.right_horizontal_mirror = button_pressed
	else:
		Global.left_horizontal_mirror = button_pressed


func _on_VerticalMirroring_toggled(button_pressed : bool, right : bool) -> void:
	if right:
		Global.right_vertical_mirror = button_pressed
	else:
		Global.left_vertical_mirror = button_pressed
