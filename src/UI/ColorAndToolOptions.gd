extends VBoxContainer


var previous_colors := [Color.black, Color.white]


func _on_ColorSwitch_pressed() -> void:
	var temp : Color = Global.color_pickers[0].color
	Global.color_pickers[0].color = Global.color_pickers[1].color
	Global.color_pickers[1].color = temp
	Global.update_custom_brush(0)
	Global.update_custom_brush(1)


func _on_ColorPickerButton_color_changed(color : Color, right : bool):
	var mouse_button := int(right)
	# If the color changed while it's on full transparency, make it opaque (GH issue #54)
	if color.a == 0:
		if previous_colors[mouse_button].r != color.r or previous_colors[mouse_button].g != color.g or previous_colors[mouse_button].b != color.b:
			Global.color_pickers[mouse_button].color.a = 1
	Global.update_custom_brush(mouse_button)
	previous_colors[mouse_button] = color


func _on_ColorPickerButton_pressed() -> void:
	Global.can_draw = false


func _on_ColorPickerButton_popup_closed() -> void:
	Global.can_draw = true


func _on_ColorDefaults_pressed() -> void:
	Global.color_pickers[0].color = Color.black
	Global.color_pickers[1].color = Color.white
	Global.update_custom_brush(0)
	Global.update_custom_brush(1)


func _on_FitToFrameButton_pressed() -> void:
	Global.camera.fit_to_frame(Global.canvas.size)


func _on_100ZoomButton_pressed() -> void:
	Global.camera.zoom = Vector2.ONE
	Global.camera.offset = Global.canvas.size / 2
	Global.zoom_level_label.text = str(round(100 / Global.camera.zoom.x)) + " %"
	Global.horizontal_ruler.update()
	Global.vertical_ruler.update()


func _on_BrushTypeButton_pressed(right : bool) -> void:
	var mouse_button := int(right)
	Global.brushes_popup.popup(Rect2(Global.brush_type_buttons[mouse_button].rect_global_position, Vector2(226, 72)))
	Global.brush_type_window_position = mouse_button


func _on_BrushSizeEdit_value_changed(value : float, right : bool) -> void:
	var mouse_button := int(right)
	var new_size = int(value)
	Global.brush_size_edits[mouse_button].value = value
	Global.brush_size_sliders[mouse_button].value = value
	Global.brush_sizes[mouse_button] = new_size
	Global.update_custom_brush(mouse_button)


func _on_PixelPerfectMode_toggled(button_pressed : bool, right : bool) -> void:
	var mouse_button := int(right)
	Global.pixel_perfect[mouse_button] = button_pressed


func _on_InterpolateFactor_value_changed(value : float, right : bool) -> void:
	var mouse_button := int(right)
	Global.interpolate_spinboxes[mouse_button].value = value
	Global.interpolate_sliders[mouse_button].value = value
	Global.update_custom_brush(mouse_button)


func _on_FillAreaOptions_item_selected(ID : int, right : bool) -> void:
	var mouse_button := int(right)
	Global.fill_areas[mouse_button] = ID


func _on_FillWithOptions_item_selected(ID : int, right : bool) -> void:
	var mouse_button := int(right)
	Global.fill_with[mouse_button] = ID
	if ID == 1:
		Global.fill_pattern_containers[mouse_button].visible = true
	else:
		Global.fill_pattern_containers[mouse_button].visible = false


func _on_PatternTypeButton_pressed(right : bool) -> void:
	var mouse_button := int(right)
	Global.pattern_window_position = mouse_button
	Global.patterns_popup.popup(Rect2(Global.brush_type_buttons[mouse_button].rect_global_position, Vector2(226, 72)))


func _on_PatternOffsetX_value_changed(value : float, right : bool) -> void:
	var mouse_button := int(right)
	Global.fill_pattern_offsets[mouse_button].x = value


func _on_PatternOffsetY_value_changed(value : float, right : bool) -> void:
	var mouse_button := int(right)
	Global.fill_pattern_offsets[mouse_button].y = value


func _on_LightenDarken_item_selected(ID : int, right : bool) -> void:
	var mouse_button := int(right)
	Global.ld_modes[mouse_button] = ID


func _on_LDAmount_value_changed(value : float, right : bool) -> void:
	var mouse_button := int(right)
	Global.ld_amounts[mouse_button] = value / 100
	Global.ld_amount_sliders[mouse_button].value = value
	Global.ld_amount_spinboxes[mouse_button].value = value


func _on_ForColorOptions_item_selected(ID : int, right : bool) -> void:
	var mouse_button := int(right)
	Global.color_picker_for[mouse_button] = ID


func _on_ZoomModeOptions_item_selected(ID : int, right : bool) -> void:
	var mouse_button := int(right)
	Global.zoom_modes[mouse_button] = ID


func _on_HorizontalMirroring_toggled(button_pressed : bool, right : bool) -> void:
	var mouse_button := int(right)
	Global.horizontal_mirror[mouse_button] = button_pressed


func _on_VerticalMirroring_toggled(button_pressed : bool, right : bool) -> void:
	var mouse_button := int(right)
	Global.vertical_mirror[mouse_button] = button_pressed
