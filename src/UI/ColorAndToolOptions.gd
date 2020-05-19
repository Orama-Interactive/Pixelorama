extends VBoxContainer


var previous_left_color := Color.black
var previous_right_color := Color.white


func _on_ColorSwitch_pressed() -> void:
	var temp: Color = Global.left_color_picker.color
	Global.left_color_picker.color = Global.right_color_picker.color
	Global.right_color_picker.color = temp
	Global.update_left_custom_brush()
	Global.update_right_custom_brush()


func _on_ColorPickerButton_color_changed(color : Color, right : bool):
	# If the color changed while it's on full transparency, make it opaque (GH issue #54)
	if right:
		if color.a == 0:
			if previous_right_color.r != color.r or previous_right_color.g != color.g or previous_right_color.b != color.b:
				Global.right_color_picker.color.a = 1
		Global.update_right_custom_brush()
		previous_right_color = color
	else:
		if color.a == 0:
			if previous_left_color.r != color.r or previous_left_color.g != color.g or previous_left_color.b != color.b:
				Global.left_color_picker.color.a = 1
		Global.update_left_custom_brush()
		previous_left_color = color


func _on_ColorPickerButton_pressed() -> void:
	Global.can_draw = false


func _on_ColorPickerButton_popup_closed() -> void:
	Global.can_draw = true


func _on_ColorDefaults_pressed() -> void:
	Global.left_color_picker.color = Color.black
	Global.right_color_picker.color = Color.white
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
		Global.brushes_popup.popup(Rect2(Global.right_brush_type_button.rect_global_position, Vector2(226, 72)))
		Global.brush_type_window_position = "right"
	else:
		Global.brushes_popup.popup(Rect2(Global.left_brush_type_button.rect_global_position, Vector2(226, 72)))
		Global.brush_type_window_position = "left"


func _on_BrushSizeEdit_value_changed(value : float, right : bool) -> void:
	var new_size = int(value)
	if right:
		Global.right_brush_size_edit.value = value
		Global.right_brush_size_slider.value = value
		Global.right_brush_size = new_size
		Global.update_right_custom_brush()
	else:
		Global.left_brush_size_edit.value = value
		Global.left_brush_size_slider.value = value
		Global.left_brush_size = new_size
		Global.update_left_custom_brush()


func _on_PixelPerfectMode_toggled(button_pressed : bool, right : bool) -> void:
	if right:
		Global.right_pixel_perfect = button_pressed
	else:
		Global.left_pixel_perfect = button_pressed


func _on_InterpolateFactor_value_changed(value : float, right : bool) -> void:
	if right:
		Global.right_interpolate_spinbox.value = value
		Global.right_interpolate_slider.value = value
		Global.update_right_custom_brush()
	else:
		Global.left_interpolate_spinbox.value = value
		Global.left_interpolate_slider.value = value
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
			Global.right_fill_pattern_container.visible = true
		else:
			Global.right_fill_pattern_container.visible = false
	else:
		Global.left_fill_with = ID
		if ID == 1:
			Global.left_fill_pattern_container.visible = true
		else:
			Global.left_fill_pattern_container.visible = false


func _on_PatternTypeButton_pressed(right : bool) -> void:
	if right:
		Global.pattern_window_position = "right"
		Global.patterns_popup.popup(Rect2(Global.right_brush_type_button.rect_global_position, Vector2(226, 72)))
	else:
		Global.pattern_window_position = "left"
		Global.patterns_popup.popup(Rect2(Global.left_brush_type_button.rect_global_position, Vector2(226, 72)))


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
		Global.right_ld_amount_slider.value = value
		Global.right_ld_amount_spinbox.value = value
	else:
		Global.left_ld_amount = value / 100
		Global.left_ld_amount_slider.value = value
		Global.left_ld_amount_spinbox.value = value


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
